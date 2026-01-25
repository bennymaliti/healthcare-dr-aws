#!/bin/bash
# -----------------------------------------------------------------------------
# Healthcare DR - Failback Script
# Returns operations to primary region after DR event
# -----------------------------------------------------------------------------
set -e

# Load configuration from environment or config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/dr-config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Configuration (override via environment variables or dr-config.env)
PRIMARY_REGION="${DR_PRIMARY_REGION:-eu-west-2}"
SECONDARY_REGION="${DR_SECONDARY_REGION:-eu-west-1}"
PROJECT_NAME="${DR_PROJECT_NAME:-healthcare-dr}"
PRIMARY_CLUSTER="${PROJECT_NAME}-primary-aurora"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_primary_health() {
    log_info "Checking primary region health..."
    
    # Check VPC
    VPC=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
        --region ${PRIMARY_REGION} \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$VPC" == "None" ]; then
        log_error "Primary VPC not found"
        return 1
    fi
    log_info "Primary VPC: ${VPC}"
    
    # Check connectivity
    if ! aws ec2 describe-availability-zones --region ${PRIMARY_REGION} &>/dev/null; then
        log_error "Cannot reach primary region"
        return 1
    fi
    log_info "Primary region accessible"
    return 0
}

restore_primary_database() {
    log_info "Restoring primary database..."
    
    # Get latest snapshot
    SNAPSHOT=$(aws rds describe-db-cluster-snapshots \
        --db-cluster-identifier ${PRIMARY_CLUSTER} \
        --snapshot-type automated \
        --region ${PRIMARY_REGION} \
        --query 'reverse(sort_by(DBClusterSnapshots, &SnapshotCreateTime))[0].DBClusterSnapshotIdentifier' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$SNAPSHOT" == "None" ]; then
        log_warn "No automated snapshots found"
        log_info "Manual restoration required"
        return 1
    fi
    
    log_info "Latest snapshot: ${SNAPSHOT}"
    echo ""
    log_warn "To restore from snapshot, run:"
    echo "aws rds restore-db-cluster-from-snapshot \\"
    echo "  --db-cluster-identifier ${PRIMARY_CLUSTER}-restored \\"
    echo "  --snapshot-identifier ${SNAPSHOT} \\"
    echo "  --engine aurora-mysql \\"
    echo "  --region ${PRIMARY_REGION}"
    return 0
}

update_dns() {
    log_info "DNS update instructions..."
    echo ""
    echo "Update Route 53 to point back to primary:"
    echo "1. Go to Route 53 console"
    echo "2. Find the failover record set"
    echo "3. Ensure primary health check is healthy"
    echo "4. Traffic will automatically route to primary"
    echo ""
}

scale_down_secondary() {
    log_info "Secondary region scale-down instructions..."
    echo ""
    echo "After verifying primary is stable:"
    echo "1. Scale down ECS tasks in secondary region"
    echo "2. Optionally delete promoted Aurora cluster"
    echo "3. Re-create cross-region replica from primary"
    echo ""
}

main() {
    echo "=========================================="
    echo "HEALTHCARE DR - FAILBACK"
    echo "=========================================="
    echo "Returning operations to: ${PRIMARY_REGION}"
    echo "=========================================="
    
    log_warn "Ensure primary region is fully recovered before failback"
    read -p "Continue? (yes/no): " CONFIRM
    [ "$CONFIRM" != "yes" ] && exit 0
    
    check_primary_health || { log_error "Primary not healthy"; exit 1; }
    restore_primary_database
    update_dns
    scale_down_secondary
    
    echo "=========================================="
    echo "FAILBACK PREPARATION COMPLETE"
    echo "=========================================="
    echo "Manual steps required - see above instructions"
    echo "=========================================="
}

main "$@"
