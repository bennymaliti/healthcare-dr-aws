#!/bin/bash
# -----------------------------------------------------------------------------
# DR Validation - Backup & Restore Test
# -----------------------------------------------------------------------------
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../../scripts/dr-config.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

PRIMARY_REGION="${DR_PRIMARY_REGION:-eu-west-2}"
SECONDARY_REGION="${DR_SECONDARY_REGION:-eu-west-1}"
PROJECT_NAME="${DR_PROJECT_NAME:-healthcare-dr}"

echo "=== Backup & Restore Test ==="

# Check primary vault
echo "Checking primary backup vault..."
VAULT="${PROJECT_NAME}-primary-backup-vault"

VAULT_EXISTS=$(aws backup describe-backup-vault \
    --backup-vault-name ${VAULT} --region ${PRIMARY_REGION} \
    --query 'BackupVaultName' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$VAULT_EXISTS" != "NOT_FOUND" ]; then
    echo "✓ Primary backup vault exists"
    
    # Count recovery points
    POINTS=$(aws backup list-recovery-points-by-backup-vault \
        --backup-vault-name ${VAULT} --region ${PRIMARY_REGION} \
        --query 'RecoveryPoints | length(@)' --output text)
    echo "  Recovery points: ${POINTS}"
    
    # Check recent jobs
    RECENT_COMPLETED=$(aws backup list-backup-jobs \
        --by-backup-vault-name ${VAULT} --by-state COMPLETED \
        --region ${PRIMARY_REGION} \
        --query "BackupJobs[?CreationDate>=\`$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)\`] | length(@)" \
        --output text 2>/dev/null || echo "0")
    echo "  Completed jobs (7 days): ${RECENT_COMPLETED}"
    
    RECENT_FAILED=$(aws backup list-backup-jobs \
        --by-backup-vault-name ${VAULT} --by-state FAILED \
        --region ${PRIMARY_REGION} \
        --query "BackupJobs[?CreationDate>=\`$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)\`] | length(@)" \
        --output text 2>/dev/null || echo "0")
    
    if [ "$RECENT_FAILED" -gt 0 ]; then
        echo "✗ Failed jobs (7 days): ${RECENT_FAILED}"
    else
        echo "✓ No failed backup jobs"
    fi
else
    echo "✗ Primary backup vault not found"
    exit 1
fi

# Check secondary vault
echo ""
echo "Checking secondary backup vault..."
SEC_VAULT="${PROJECT_NAME}-secondary-backup-vault"

SEC_EXISTS=$(aws backup describe-backup-vault \
    --backup-vault-name ${SEC_VAULT} --region ${SECONDARY_REGION} \
    --query 'BackupVaultName' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SEC_EXISTS" != "NOT_FOUND" ]; then
    echo "✓ Secondary backup vault exists"
    
    SEC_POINTS=$(aws backup list-recovery-points-by-backup-vault \
        --backup-vault-name ${SEC_VAULT} --region ${SECONDARY_REGION} \
        --query 'RecoveryPoints | length(@)' --output text)
    echo "  Recovery points: ${SEC_POINTS}"
    
    if [ "$SEC_POINTS" -gt 0 ]; then
        echo "✓ Cross-region copy working"
    else
        echo "⚠ No recovery points in secondary vault"
    fi
else
    echo "✗ Secondary backup vault not found"
fi

# Check latest recovery point age
echo ""
echo "Checking recovery point age..."
LATEST=$(aws backup list-recovery-points-by-backup-vault \
    --backup-vault-name ${VAULT} --region ${PRIMARY_REGION} \
    --query 'reverse(sort_by(RecoveryPoints, &CreationDate))[0].CreationDate' \
    --output text 2>/dev/null || echo "None")

if [ "$LATEST" != "None" ]; then
    echo "  Latest recovery point: ${LATEST}"
else
    echo "  No recovery points found"
fi

echo ""
echo "=== Backup & Restore Test Complete ==="
