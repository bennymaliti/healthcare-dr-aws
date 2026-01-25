#!/bin/bash
# -----------------------------------------------------------------------------
# Healthcare DR - Health Check Script
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

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }

check_aurora_primary() {
    log_check "Primary Aurora cluster..."
    STATUS=$(aws rds describe-db-clusters \
        --db-cluster-identifier "${PROJECT_NAME}-primary-aurora" \
        --region ${PRIMARY_REGION} \
        --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    [ "$STATUS" == "available" ] && log_pass "Primary Aurora: available" || log_fail "Primary Aurora: ${STATUS}"
}

check_aurora_replica() {
    log_check "Secondary Aurora replica..."
    STATUS=$(aws rds describe-db-clusters \
        --db-cluster-identifier "${PROJECT_NAME}-secondary-aurora" \
        --region ${SECONDARY_REGION} \
        --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$STATUS" == "available" ]; then
        log_pass "Secondary Aurora: available"
        
        SOURCE=$(aws rds describe-db-clusters \
            --db-cluster-identifier "${PROJECT_NAME}-secondary-aurora" \
            --region ${SECONDARY_REGION} \
            --query 'DBClusters[0].ReplicationSourceIdentifier' --output text 2>/dev/null || echo "")
        
        [ -n "$SOURCE" ] && [ "$SOURCE" != "None" ] && \
            log_pass "Replication configured" || \
            log_warn "No replication source (may be promoted)"
    else
        log_fail "Secondary Aurora: ${STATUS}"
    fi
}

check_replica_lag() {
    log_check "Aurora replica lag..."
    LAG=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/RDS \
        --metric-name AuroraReplicaLag \
        --dimensions Name=DBClusterIdentifier,Value="${PROJECT_NAME}-secondary-aurora" \
        --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --period 300 --statistics Average \
        --region ${SECONDARY_REGION} \
        --query 'Datapoints[-1].Average' --output text 2>/dev/null || echo "N/A")
    
    if [ "$LAG" != "N/A" ] && [ "$LAG" != "None" ]; then
        LAG_SEC=$(echo "scale=2; $LAG / 1000" | bc)
        if (( $(echo "$LAG_SEC < 60" | bc -l) )); then
            log_pass "Replica lag: ${LAG_SEC}s"
        elif (( $(echo "$LAG_SEC < 300" | bc -l) )); then
            log_warn "Replica lag: ${LAG_SEC}s (elevated)"
        else
            log_fail "Replica lag: ${LAG_SEC}s (exceeds RPO)"
        fi
    else
        log_warn "Could not get replica lag"
    fi
}

check_s3_buckets() {
    log_check "S3 buckets..."
    
    PRIMARY_BUCKET="${PROJECT_NAME}-primary-healthcare-data"
    SECONDARY_BUCKET="${PROJECT_NAME}-secondary-healthcare-data"
    
    aws s3api head-bucket --bucket ${PRIMARY_BUCKET} --region ${PRIMARY_REGION} 2>/dev/null && \
        log_pass "Primary S3 bucket exists" || log_fail "Primary S3 bucket missing"
    
    aws s3api head-bucket --bucket ${SECONDARY_BUCKET} --region ${SECONDARY_REGION} 2>/dev/null && \
        log_pass "Secondary S3 bucket exists" || log_fail "Secondary S3 bucket missing"
    
    # Check replication
    REP_STATUS=$(aws s3api get-bucket-replication \
        --bucket ${PRIMARY_BUCKET} --region ${PRIMARY_REGION} \
        --query 'ReplicationConfiguration.Rules[0].Status' --output text 2>/dev/null || echo "NOT_CONFIGURED")
    
    [ "$REP_STATUS" == "Enabled" ] && \
        log_pass "S3 replication enabled" || log_warn "S3 replication: ${REP_STATUS}"
}

check_backups() {
    log_check "AWS Backup..."
    
    VAULT="${PROJECT_NAME}-primary-backup-vault"
    EXISTS=$(aws backup describe-backup-vault \
        --backup-vault-name ${VAULT} --region ${PRIMARY_REGION} \
        --query 'BackupVaultName' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$EXISTS" != "NOT_FOUND" ]; then
        log_pass "Primary backup vault exists"
        
        RECENT=$(aws backup list-backup-jobs \
            --by-backup-vault-name ${VAULT} --by-state COMPLETED \
            --region ${PRIMARY_REGION} \
            --query "BackupJobs[?CreationDate>=\`$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)\`] | length(@)" \
            --output text 2>/dev/null || echo "0")
        
        [ "$RECENT" -gt 0 ] && \
            log_pass "Backup jobs (24h): ${RECENT}" || \
            log_warn "No recent backup jobs"
    else
        log_fail "Primary backup vault missing"
    fi
    
    # Secondary vault
    SEC_VAULT="${PROJECT_NAME}-secondary-backup-vault"
    SEC_EXISTS=$(aws backup describe-backup-vault \
        --backup-vault-name ${SEC_VAULT} --region ${SECONDARY_REGION} \
        --query 'BackupVaultName' --output text 2>/dev/null || echo "NOT_FOUND")
    
    [ "$SEC_EXISTS" != "NOT_FOUND" ] && \
        log_pass "Secondary backup vault exists" || log_fail "Secondary backup vault missing"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "DR HEALTH CHECK SUMMARY"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC}   ${PASSED}"
    echo -e "${YELLOW}Warnings:${NC} ${WARNINGS}"
    echo -e "${RED}Failed:${NC}   ${FAILED}"
    echo "=========================================="
    
    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}DR READINESS: NOT READY${NC}"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}DR READINESS: READY WITH WARNINGS${NC}"
        exit 0
    else
        echo -e "${GREEN}DR READINESS: FULLY READY${NC}"
        exit 0
    fi
}

main() {
    echo "=========================================="
    echo "HEALTHCARE DR - HEALTH CHECK"
    echo "=========================================="
    echo "Primary: ${PRIMARY_REGION}"
    echo "Secondary: ${SECONDARY_REGION}"
    echo "=========================================="
    echo ""
    
    check_aurora_primary
    check_aurora_replica
    check_replica_lag
    check_s3_buckets
    check_backups
    
    print_summary
}

main "$@"
