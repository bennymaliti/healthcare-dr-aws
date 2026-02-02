# Risk Assessment

## Risk Matrix

**Likelihood**: 1 (Rare) - 5 (Certain)
**Impact**: 1 (Negligible) - 5 (Catastrophic)
**Risk = Likelihood × Impact**

## Identified Risks

| Risk ID | Description | L | I | Score | Mitigation | Residual |
|---------|-------------|---|---|-------|------------|----------|
| NAT-001 | Region Outage | 2 | 5 | 10 | Multi-region deployment | 3 |
| NAT-002 | AZ Failure | 3 | 3 | 9 | Multi-AZ resources | 2 |
| INF-001 | Database Corruption | 2 | 5 | 10 | Backups, PITR | 4 |
| INF-002 | Storage Failure | 1 | 4 | 4 | S3 11 9s durability | 1 |
| SEC-001 | Ransomware | 3 | 5 | 15 | Immutable backups | 6 |
| SEC-002 | Data Breach | 3 | 5 | 15 | Encryption, IAM | 6 |
| SEC-003 | DDoS Attack | 4 | 3 | 12 | AWS Shield | 4 |
| HUM-001 | Accidental Deletion | 4 | 4 | 16 | Versioning, backups | 4 |
| HUM-002 | Misconfiguration | 4 | 3 | 12 | IaC, code review | 6 |
| COM-001 | UK GDPR Violation | 2 | 5 | 10 | Encryption, logging | 4 |

## Mitigation Summary

### Technical Controls
- Multi-region deployment
- Aurora cross-region replication
- S3 Cross-Region Replication
- AWS Backup with cross-region copy
- Encryption at rest/transit
- VPC isolation
- IAM least privilege

### Operational Controls
- Infrastructure as Code
- DR testing quarterly
- Monitoring and alerting
- Operational runbooks

## Recommendations

### High Priority
1. Enable AWS GuardDuty
2. Implement AWS WAF
3. Enable AWS Config Rules
4. Conduct quarterly DR drills

### Medium Priority
1. AWS Security Hub
2. CloudFront for DDoS protection
3. AWS Macie for data discovery

## Review Schedule
- Risk Assessment: Quarterly
- DR Test: Quarterly
- Compliance Audit: Annually
