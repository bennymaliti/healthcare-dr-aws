# Healthcare Compliance Guide

## HIPAA Alignment

### Technical Safeguards

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Encryption at Rest | KMS encryption for RDS, S3 | ✅ |
| Encryption in Transit | TLS 1.2+ | ✅ |
| Access Controls | IAM roles, VPC isolation | ✅ |
| Audit Controls | CloudTrail, VPC Flow Logs | ✅ |
| Integrity Controls | S3 versioning, checksums | ✅ |

### Administrative Safeguards

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Contingency Plan | DR runbook, tested quarterly | ✅ |
| Data Backup | AWS Backup, 35-day retention | ✅ |
| Disaster Recovery | Multi-region, Pilot Light | ✅ |
| Access Management | IAM, least privilege | ✅ |

### Physical Safeguards

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Facility Access | AWS data centers (SOC2) | ✅ |
| Workstation Security | VPC, security groups | ✅ |
| Device Controls | Encryption, access logs | ✅ |

## AWS Shared Responsibility

### AWS Responsibility
- Physical security
- Network infrastructure
- Hypervisor security
- Service availability

### Customer Responsibility (This Project)
- IAM configuration
- Data encryption
- Network configuration
- Application security
- Backup and recovery

## Compliance Checklist

### Data Protection
- [x] PHI encrypted at rest
- [x] PHI encrypted in transit
- [x] No public access to data stores
- [x] Cross-region replication for durability

### Access Control
- [x] IAM roles with least privilege
- [x] No root account usage
- [x] MFA recommended for users
- [x] Security groups restrict access

### Audit & Monitoring
- [x] CloudTrail enabled
- [x] VPC Flow Logs enabled
- [x] S3 access logging enabled
- [x] CloudWatch alarms configured

### Business Continuity
- [x] Automated backups (35 days)
- [x] Cross-region backup copies
- [x] DR runbook documented
- [x] Quarterly DR testing

## AWS BAA

A Business Associate Agreement (BAA) with AWS is required before storing PHI.

**Note**: Customer must execute BAA with AWS separately.

## Audit Evidence

| Evidence Type | Location |
|---------------|----------|
| Infrastructure Config | Terraform state |
| Access Logs | CloudTrail |
| Network Logs | VPC Flow Logs |
| Backup Reports | AWS Backup console |
| DR Test Results | docs/dr-tests/ |
