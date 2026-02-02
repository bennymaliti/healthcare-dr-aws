# Healthcare Application Disaster Recovery & Business Continuity on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade disaster recovery and business continuity solution for healthcare applications on AWS, implementing a **Pilot Light** DR strategy with automated failover capabilities.

## 🏗️ Architecture Overview

![DR Architecture](diagrams/architecture-diagram.png)
```

## 🎯 Key Outcomes

| Metric | Target | Implementation |
|--------|--------|----------------|
| **RPO** | ≤ 1 hour | Aurora cross-region replication + S3 CRR |
| **RTO** | 15-30 min | Pilot Light with automated failover |
| **Durability** | 99.999999999% | S3 Cross-Region Replication |
| **Backup Retention** | 35 days | AWS Backup with lifecycle policies |

## 📁 Project Structure

healthcare-dr-aws/
├── README.md
├── LICENSE
├── .gitignore
├── .github/
│   └── workflows/
│       ├── terraform.yml                 # Terraform CI/CD
│       ├── container.yml                 # Container build & deploy
│       └── dr-validation.yml             # DR testing automation
├── application/
│   ├── package.json
│   ├── src/
│   │   └── server.js                     # Node.js healthcare app
│   └── docker/
│       └── Dockerfile                    # Multi-stage container build
├── terraform/
│   ├── modules/
│   │   ├── vpc/                          # Multi-AZ VPC module
│   │   ├── rds/                          # Aurora MySQL module
│   │   ├── s3-replication/               # S3 with CRR module
│   │   ├── backup/                       # AWS Backup module
│   │   ├── route53/                      # DNS failover module
│   │   ├── ecs/                          # ECS Fargate module
│   │   ├── waf/                          # AWS WAF module
│   │   ├── guardduty/                    # Threat detection module
│   │   ├── cost-monitoring/              # Budget & cost alerts
│   │   └── cloudformation-stacksets/     # DR templates
│   └── environments/
│       ├── primary/                      # eu-west-2 (London)
│       └── secondary/                    # eu-west-1 (Ireland)
├── scripts/
│   ├── failover.sh                       # Execute DR failover
│   ├── failback.sh                       # Return to primary
│   ├── health-check.sh                   # Validate DR readiness
│   ├── dr-test.sh                        # DR drill automation
│   └── dr-config.env.example             # Script configuration
├── docs/
│   ├── RUNBOOK.md                        # Operational procedures
│   ├── RISK_ASSESSMENT.md                # Risk analysis
│   ├── COMPLIANCE.md                     # Healthcare compliance
│   ├── GITHUB_ACTIONS_SETUP.md           # CI/CD setup guide
└── tests/
    └── dr-validation/
        ├── test_failover.sh              # Failover test
        ├── test_replication.sh           # Replication test
        └── test_backup_restore.sh        # Backup test
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI v2 configured
- Terraform >= 1.5.0
- Two AWS regions enabled (eu-west-2, eu-west-1)

### Deployment

```bash
# 1. Clone repository
git clone https://github.com/bennymaliti/healthcare-dr-aws.git
cd healthcare-dr-aws

# 2. Configure Scripts
cd scripts
cp dr-config.env.example dr-config.env
# Edit dr-config.env with your values

# 3. Deploy Secondary Region First (creates destination resources)
cd ../terraform/environments/secondary
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit both files with your values
terraform init -backend-config=backend.hcl
terraform apply

# 4. Deploy Primary Region
cd ../primary
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit both files with your values
# Add secondary outputs to terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply

# 5. Verify DR Readiness
cd ../../../scripts
./health-check.sh
```

### Security Notes

- **Database Password**: Leave `database_password` empty in terraform.tfvars to auto-generate a secure password stored in AWS Secrets Manager
- **No Hardcoded Values**: All account IDs, ARNs, and sensitive values are derived from data sources or variables
- **Backend State**: Use S3 with encryption and DynamoDB locking for Terraform state

## 📚 Documentation

- [Operational Runbook](docs/RUNBOOK.md)
- [Risk Assessment](docs/RISK_ASSESSMENT.md)
- [Compliance Guide](docs/COMPLIANCE.md)
- [GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md)

## 🆕 Enhanced Features

### 1. GitHub Actions CI/CD

Automated pipelines for infrastructure and application deployment:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform.yml` | Push/PR to main | Validate, scan, plan, and apply Terraform |
| `container.yml` | Push to main | Build, scan, and deploy containers |
| `dr-validation.yml` | Weekly/Manual | Automated DR health checks |

**Features:**

- Terraform format and validation checks
- Security scanning with tfsec and Checkov
- Container vulnerability scanning with Trivy
- OIDC authentication (no stored credentials)
- Environment-based deployments with approvals

### 2. Containerized Application Layer

ECS Fargate Deployment:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     ALB     │────▶│ ECS Fargate │────▶│   Aurora    │
│  (HTTPS)    │     │  (Node.js)  │     │   MySQL     │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Features:**

- Multi-stage Docker builds
- ECR with vulnerability scanning
- Auto-scaling (CPU/Memory based)
- Health checks and circuit breakers
- Secrets Manager integration

### 3. AWS WAF Protection

Web Application Firewall with managed rules:

| Rule Set | Protection |
|----------|------------|
| Common Rule Set | OWASP Top 10 |
| Known Bad Inputs | Log4j, etc. |
| SQL Injection | SQLi attacks |
| Linux OS | OS-specific attacks |
| Rate Limiting | DDoS protection |

### 4. GuardDuty Threat Detection

Intelligent threat detection:

- **S3 Protection**: Detects suspicious data access
- **Malware Protection**: Scans EBS volumes
- **Event Notifications**: SNS alerts for findings
- **Auto-Remediation**: Optional Lambda response

### 5. Cost Monitoring Dashboard

Budget alerts and cost visibility:

| Budget | Default Limit | Alerts |
|--------|---------------|--------|
| Monthly Total | $500 | 50%, 80%, 100% |
| RDS | $200 | 80% |
| Compute | $100 | 80% |
| Data Transfer | $50 | 80% |

**Features:**

- CloudWatch cost dashboard
- Cost anomaly detection
- Email notifications
- Service-level budgets

## 👤 Author

**Benny Maliti** - Cloud Engineer

## 📄 License

MIT License - see [LICENSE](LICENSE)
