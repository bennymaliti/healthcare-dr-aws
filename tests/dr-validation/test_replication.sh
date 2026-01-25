#!/bin/bash
# -----------------------------------------------------------------------------
# DR Validation - Replication Test
# -----------------------------------------------------------------------------
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../../scripts/dr-config.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

PRIMARY_REGION="${DR_PRIMARY_REGION:-eu-west-2}"
SECONDARY_REGION="${DR_SECONDARY_REGION:-eu-west-1}"
PROJECT_NAME="${DR_PROJECT_NAME:-healthcare-dr}"

echo "=== Replication Test ==="

# Test Aurora Replication
echo "Testing Aurora replication..."
CLUSTER="${PROJECT_NAME}-secondary-aurora"

LAG=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name AuroraReplicaLag \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER} \
    --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 60 --statistics Average \
    --region ${SECONDARY_REGION} \
    --query 'Datapoints | sort_by(@, &Timestamp) | [-1].Average' --output text 2>/dev/null || echo "N/A")

if [ "$LAG" != "N/A" ] && [ "$LAG" != "None" ]; then
    LAG_SEC=$(echo "scale=2; $LAG / 1000" | bc)
    echo "✓ Aurora replica lag: ${LAG_SEC}s"
    
    if (( $(echo "$LAG_SEC < 300" | bc -l) )); then
        echo "✓ Lag within RPO threshold (5 min)"
    else
        echo "✗ Lag exceeds RPO threshold"
        exit 1
    fi
else
    echo "⚠ Could not retrieve replica lag"
fi

# Test S3 Replication
echo ""
echo "Testing S3 replication..."

PRIMARY_BUCKET="${PROJECT_NAME}-primary-healthcare-data"

REP_STATUS=$(aws s3api get-bucket-replication \
    --bucket ${PRIMARY_BUCKET} --region ${PRIMARY_REGION} \
    --query 'ReplicationConfiguration.Rules[0].Status' --output text 2>/dev/null || echo "NOT_CONFIGURED")

if [ "$REP_STATUS" == "Enabled" ]; then
    echo "✓ S3 replication is enabled"
    
    # Check replication metrics
    LATENCY=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/S3 \
        --metric-name ReplicationLatency \
        --dimensions Name=SourceBucket,Value=${PRIMARY_BUCKET} \
        --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --period 300 --statistics Average \
        --region ${PRIMARY_REGION} \
        --query 'Datapoints | sort_by(@, &Timestamp) | [-1].Average' --output text 2>/dev/null || echo "N/A")
    
    if [ "$LATENCY" != "N/A" ] && [ "$LATENCY" != "None" ]; then
        echo "✓ S3 replication latency: ${LATENCY}s"
    fi
else
    echo "⚠ S3 replication status: ${REP_STATUS}"
fi

echo ""
echo "=== Replication Test Complete ==="
