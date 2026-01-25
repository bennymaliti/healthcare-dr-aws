#!/bin/bash
# -----------------------------------------------------------------------------
# DR Validation - Failover Test
# -----------------------------------------------------------------------------
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../../scripts/dr-config.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

SECONDARY_REGION="${DR_SECONDARY_REGION:-eu-west-1}"
PROJECT_NAME="${DR_PROJECT_NAME:-healthcare-dr}"
CLUSTER="${PROJECT_NAME}-secondary-aurora"

echo "=== Failover Test ==="

# Check cluster can be promoted
echo "Checking cluster promotion eligibility..."

STATUS=$(aws rds describe-db-clusters \
    --db-cluster-identifier ${CLUSTER} \
    --region ${SECONDARY_REGION} \
    --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STATUS" == "available" ]; then
    echo "✓ Cluster is available for promotion"
    
    SOURCE=$(aws rds describe-db-clusters \
        --db-cluster-identifier ${CLUSTER} \
        --region ${SECONDARY_REGION} \
        --query 'DBClusters[0].ReplicationSourceIdentifier' --output text)
    
    if [ -n "$SOURCE" ] && [ "$SOURCE" != "None" ]; then
        echo "✓ Cluster is configured as replica"
        echo "  Source: ${SOURCE}"
    else
        echo "⚠ Cluster is not a replica (may already be promoted)"
    fi
else
    echo "✗ Cluster not available: ${STATUS}"
    exit 1
fi

# Check instance health
echo ""
echo "Checking instance health..."
INSTANCES=$(aws rds describe-db-cluster-instances \
    --db-cluster-identifier ${CLUSTER} \
    --region ${SECONDARY_REGION} \
    --query 'DBInstances[].DBInstanceStatus' --output text)

echo "Instance statuses: ${INSTANCES}"

echo ""
echo "=== Failover Test Complete ==="
