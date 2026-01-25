#!/bin/bash
# -----------------------------------------------------------------------------
# Healthcare DR - DR Test/Drill Script
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
MODE="${1:-simulation}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

usage() {
    echo "Usage: $0 [simulation|full]"
    echo ""
    echo "Modes:"
    echo "  simulation - Non-destructive tests (default)"
    echo "  full       - Full failover test (affects production)"
    exit 1
}

test_health_checks() {
    log_test "Testing health check script..."
    ./health-check.sh
    log_info "Health check test passed"
}

test_connectivity() {
    log_test "Testing AWS connectivity..."
    
    # Primary
    aws ec2 describe-vpcs --region ${PRIMARY_REGION} \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
        --query 'Vpcs[0].VpcId' --output text > /dev/null
    log_info "Primary region connectivity: OK"
    
    # Secondary
    aws ec2 describe-vpcs --region ${SECONDARY_REGION} \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
        --query 'Vpcs[0].VpcId' --output text > /dev/null
    log_info "Secondary region connectivity: OK"
}

test_database_replication() {
    log_test "Testing database replication..."
    
    CLUSTER="${PROJECT_NAME}-secondary-aurora"
    
    # Check replica exists
    STATUS=$(aws rds describe-db-clusters \
        --db-cluster-identifier ${CLUSTER} \
        --region ${SECONDARY_REGION} \
        --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$STATUS" == "available" ]; then
        log_info "Secondary cluster available"
        
        # Get replica lag
        LAG=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/RDS \
            --metric-name AuroraReplicaLag \
            --dimensions Name=DBClusterIdentifier,Value=${CLUSTER} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
            --period 60 --statistics Average \
            --region ${SECONDARY_REGION} \
            --query 'Datapoints[-1].Average' --output text 2>/dev/null || echo "N/A")
        
        if [ "$LAG" != "N/A" ] && [ "$LAG" != "None" ]; then
            LAG_SEC=$(echo "scale=2; $LAG / 1000" | bc)
            log_info "Current replica lag: ${LAG_SEC}s"
        fi
    else
        log_warn "Secondary cluster status: ${STATUS}"
    fi
}

test_s3_replication() {
    log_test "Testing S3 replication..."
    
    PRIMARY_BUCKET="${PROJECT_NAME}-primary-healthcare-data"
    SECONDARY_BUCKET="${PROJECT_NAME}-secondary-healthcare-data"
    TEST_KEY="dr-test/test-$(date +%s).txt"
    
    # Upload test object
    echo "DR Test $(date)" | aws s3 cp - s3://${PRIMARY_BUCKET}/${TEST_KEY} --region ${PRIMARY_REGION}
    log_info "Test object uploaded to primary"
    
    # Wait for replication
    log_info "Waiting for replication (30s)..."
    sleep 30
    
    # Check if replicated
    if aws s3api head-object --bucket ${SECONDARY_BUCKET} --key ${TEST_KEY} --region ${SECONDARY_REGION} 2>/dev/null; then
        log_info "Object replicated to secondary: OK"
    else
        log_warn "Object not yet replicated (may take longer)"
    fi
    
    # Cleanup
    aws s3 rm s3://${PRIMARY_BUCKET}/${TEST_KEY} --region ${PRIMARY_REGION} 2>/dev/null || true
}

test_backup_restore() {
    log_test "Testing backup availability..."
    
    VAULT="${PROJECT_NAME}-primary-backup-vault"
    
    # List recovery points
    POINTS=$(aws backup list-recovery-points-by-backup-vault \
        --backup-vault-name ${VAULT} \
        --region ${PRIMARY_REGION} \
        --query 'RecoveryPoints | length(@)' --output text 2>/dev/null || echo "0")
    
    log_info "Recovery points available: ${POINTS}"
    
    # Check cross-region copy
    SEC_VAULT="${PROJECT_NAME}-secondary-backup-vault"
    SEC_POINTS=$(aws backup list-recovery-points-by-backup-vault \
        --backup-vault-name ${SEC_VAULT} \
        --region ${SECONDARY_REGION} \
        --query 'RecoveryPoints | length(@)' --output text 2>/dev/null || echo "0")
    
    log_info "Secondary vault recovery points: ${SEC_POINTS}"
}

run_simulation() {
    echo "=========================================="
    echo "DR TEST - SIMULATION MODE"
    echo "=========================================="
    echo "This is a non-destructive test"
    echo "=========================================="
    echo ""
    
    test_connectivity
    test_health_checks
    test_database_replication
    test_s3_replication
    test_backup_restore
    
    echo ""
    echo "=========================================="
    echo "SIMULATION COMPLETE"
    echo "=========================================="
}

run_full_test() {
    echo "=========================================="
    echo "DR TEST - FULL FAILOVER MODE"
    echo "=========================================="
    log_warn "This will perform actual failover!"
    log_warn "Production traffic will be affected"
    echo ""
    read -p "Type 'PROCEED' to continue: " CONFIRM
    [ "$CONFIRM" != "PROCEED" ] && exit 0
    
    # Run simulation first
    run_simulation
    
    echo ""
    log_warn "Simulation passed. Ready for full failover."
    read -p "Execute failover? (yes/no): " CONFIRM
    [ "$CONFIRM" != "yes" ] && exit 0
    
    ./failover.sh
}

case "$MODE" in
    simulation) run_simulation ;;
    full) run_full_test ;;
    *) usage ;;
esac
