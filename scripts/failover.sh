#!/bin/bash
# -----------------------------------------------------------------------------
# Healthcare DR - Failover Script
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
SECONDARY_CLUSTER="${PROJECT_NAME}-secondary-aurora"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."
    command -v aws &> /dev/null || { log_error "AWS CLI not installed"; exit 1; }
    aws sts get-caller-identity &> /dev/null || { log_error "AWS CLI not configured"; exit 1; }
    log_info "Prerequisites OK"
}

check_replica_lag() {
    log_info "Checking Aurora replica lag..."
    LAG=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/RDS \
        --metric-name AuroraReplicaLag \
        --dimensions Name=DBClusterIdentifier,Value=${SECONDARY_CLUSTER} \
        --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --period 60 --statistics Average \
        --region ${SECONDARY_REGION} \
        --query 'Datapoints[0].Average' --output text 2>/dev/null || echo "N/A")
    
    if [ "$LAG" != "N/A" ] && [ "$LAG" != "None" ]; then
        LAG_SEC=$(echo "$LAG / 1000" | bc)
        log_info "Replica lag: ${LAG_SEC}s"
        if (( $(echo "$LAG_SEC > 300" | bc -l) )); then
            log_warn "Lag > 5 min. Data loss may occur."
            read -p "Continue? (yes/no): " CONFIRM
            [ "$CONFIRM" != "yes" ] && exit 0
        fi
    fi
}

promote_aurora() {
    log_info "Promoting Aurora replica..."
    
    STATUS=$(aws rds describe-db-clusters \
        --db-cluster-identifier ${SECONDARY_CLUSTER} \
        --region ${SECONDARY_REGION} \
        --query 'DBClusters[0].Status' --output text)
    
    log_info "Cluster status: ${STATUS}"
    
    if [ "$STATUS" == "available" ]; then
        SOURCE=$(aws rds describe-db-clusters \
            --db-cluster-identifier ${SECONDARY_CLUSTER} \
            --region ${SECONDARY_REGION} \
            --query 'DBClusters[0].ReplicationSourceIdentifier' --output text)
        
        if [ "$SOURCE" != "None" ] && [ -n "$SOURCE" ]; then
            log_info "Promoting from: ${SOURCE}"
            aws rds promote-read-replica-db-cluster \
                --db-cluster-identifier ${SECONDARY_CLUSTER} \
                --region ${SECONDARY_REGION}
            
            log_info "Waiting for promotion..."
            aws rds wait db-cluster-available \
                --db-cluster-identifier ${SECONDARY_CLUSTER} \
                --region ${SECONDARY_REGION}
            log_info "Promotion complete!"
        else
            log_warn "Already promoted or not a replica"
        fi
    else
        log_error "Cluster not available: ${STATUS}"
        exit 1
    fi
}

show_endpoint() {
    ENDPOINT=$(aws rds describe-db-clusters \
        --db-cluster-identifier ${SECONDARY_CLUSTER} \
        --region ${SECONDARY_REGION} \
        --query 'DBClusters[0].Endpoint' --output text)
    
    echo ""
    echo "=========================================="
    echo "FAILOVER COMPLETE"
    echo "=========================================="
    echo "New Endpoint: ${ENDPOINT}"
    echo "Region: ${SECONDARY_REGION}"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Update application connection strings"
    echo "2. Verify application connectivity"
    echo "3. Monitor CloudWatch dashboards"
    echo "=========================================="
}

send_notification() {
    TOPIC=$(aws sns list-topics --region ${SECONDARY_REGION} \
        --query "Topics[?contains(TopicArn, '${PROJECT_NAME}')].TopicArn" \
        --output text | head -1)
    
    if [ -n "$TOPIC" ]; then
        aws sns publish --topic-arn ${TOPIC} \
            --subject "Healthcare DR - FAILOVER EXECUTED" \
            --message "Failover to ${SECONDARY_REGION} at $(date)" \
            --region ${SECONDARY_REGION}
        log_info "Notification sent"
    fi
}

main() {
    echo "=========================================="
    echo "HEALTHCARE DR - FAILOVER"
    echo "=========================================="
    echo "Primary: ${PRIMARY_REGION}"
    echo "Secondary: ${SECONDARY_REGION}"
    echo "=========================================="
    
    log_warn "THIS WILL INITIATE DR FAILOVER"
    read -p "Type 'FAILOVER' to confirm: " CONFIRM
    [ "$CONFIRM" != "FAILOVER" ] && { log_info "Cancelled"; exit 0; }
    
    check_prerequisites
    check_replica_lag
    promote_aurora
    show_endpoint
    send_notification
}

main "$@"
