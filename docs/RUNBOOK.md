# Healthcare DR Operational Runbook

## Overview

| Region | Role | Location |
|--------|------|----------|
| eu-west-2 | Primary (Active) | London |
| eu-west-1 | Secondary (Standby) | Ireland |

**RPO**: ≤ 1 hour | **RTO**: 15-30 minutes

## Daily Operations

### Health Check
```bash
./scripts/health-check.sh
```

### Key Metrics to Monitor
| Metric | Threshold | Action |
|--------|-----------|--------|
| Aurora Replica Lag | > 5 min | Investigate network/DB |
| S3 Replication Latency | > 15 min | Check replication status |
| Backup Jobs Failed | > 0 | Review backup config |

## Failover Procedures

### When to Failover
- Primary region completely unavailable
- Primary database corrupted
- Network connectivity lost > 30 minutes

### Do NOT Failover For
- Single AZ failures
- Temporary network blips (< 5 min)
- Scheduled maintenance

### Failover Steps

1. **Assess** (5 min)
```bash
./scripts/health-check.sh
```

2. **Notify Stakeholders**

3. **Execute Failover** (10-15 min)
```bash
./scripts/failover.sh
```

4. **Update Application**
   - Update connection strings
   - Deploy configuration changes
   - Clear caches

5. **Verify**
```bash
curl -f https://app.example.com/health
```

## Failback Procedures

```bash
./scripts/failback.sh
```

Follow on-screen instructions for manual steps.

## DR Testing

### Quarterly Drill
```bash
./scripts/dr-test.sh --mode simulation
```

### Full Test (with approval)
```bash
./scripts/dr-test.sh --mode full
```

## Troubleshooting

### High Replica Lag
1. Check network connectivity
2. Review database write patterns
3. Check for long-running transactions

### S3 Replication Backlog
1. Check replication configuration
2. Verify IAM permissions
3. Monitor for large file uploads

### Backup Failures
1. Check IAM role permissions
2. Verify resource tags (Backup=true)
3. Check backup window conflicts

## Contacts

| Role | Contact |
|------|---------|
| On-Call | benmaliti@hotmail.com |
| DBA | benmaliti@hotmail.com |
| Security | benmaliti@hotmail.com |
