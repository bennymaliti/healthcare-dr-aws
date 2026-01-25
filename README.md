# Healthcare Application Disaster Recovery & Business Continuity on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade disaster recovery and business continuity solution for healthcare applications on AWS, implementing a **Pilot Light** DR strategy with automated failover capabilities.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              DISASTER RECOVERY ARCHITECTURE                              │
│                                  Pilot Light Strategy                                    │
│                          RPO: 1 hour | RTO: 15-30 minutes                               │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    ┌─────────────────┐
                                    │   Route 53      │
                                    │  Health Checks  │
                                    │  & DNS Failover │
                                    └────────┬────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     │                                               │
                     ▼                                               ▼
┌────────────────────────────────────────┐     ┌────────────────────────────────────────┐
│         PRIMARY REGION (eu-west-2)     │     │       SECONDARY REGION (eu-west-1)     │
│              London - ACTIVE           │     │           Ireland - STANDBY            │
├────────────────────────────────────────┤     ├────────────────────────────────────────┤
│                                        │     │                                        │
│  ┌──────────────────────────────────┐  │     │  ┌──────────────────────────────────┐  │
│  │         VPC (10.0.0.0/16)        │  │     │  │         VPC (10.1.0.0/16)        │  │
│  │  ┌─────────────┬─────────────┐   │  │     │  │  ┌─────────────┬─────────────┐   │  │
│  │  │ Public AZ-a │ Public AZ-b │   │  │     │  │  │ Public AZ-a │ Public AZ-b │   │  │
│  │  │ 10.0.1.0/24 │ 10.0.2.0/24 │   │  │     │  │  │ 10.1.1.0/24 │ 10.1.2.0/24 │   │  │
│  │  └──────┬──────┴──────┬──────┘   │  │     │  │  └──────┬──────┴──────┬──────┘   │  │
│  │         │     ALB     │          │  │     │  │         │     ALB     │          │  │
│  │         └──────┬──────┘          │  │     │  │         └──────┬──────┘          │  │
│  │  ┌─────────────┴─────────────┐   │  │     │  │  ┌─────────────┴─────────────┐   │  │
│  │  │Private AZ-a │Private AZ-b │   │  │     │  │  │Private AZ-a │Private AZ-b │   │  │
│  │  │10.0.10.0/24 │10.0.11.0/24 │   │  │     │  │  │10.1.10.0/24 │10.1.11.0/24 │   │  │
│  │  └──────┬──────┴──────┬──────┘   │  │     │  │  └──────┬──────┴──────┬──────┘   │  │
│  │    ┌────┴────┐  ┌─────┴─────┐    │  │     │  │    ┌────┴────┐  ┌─────┴─────┐    │  │
│  │    │   ECS   │  │    ECS    │    │  │     │  │    │   ECS   │  │    ECS    │    │  │
│  │    │ Fargate │  │  Fargate  │    │  │     │  │    │ (Scaled │  │  (Scaled  │    │  │
│  │    │ (Active)│  │  (Active) │    │  │     │  │    │  Down)  │  │   Down)   │    │  │
│  │    └────┬────┘  └─────┬─────┘    │  │     │  │    └────┬────┘  └─────┬─────┘    │  │
│  │  ┌──────┴─────────────┴───────┐  │  │     │  │  ┌──────┴─────────────┴───────┐  │  │
│  │  │  Database Subnets          │  │  │     │  │  │  Database Subnets          │  │  │
│  │  │  10.0.20.0/24, 10.0.21.0/24│  │  │     │  │  │  10.1.20.0/24, 10.1.21.0/24│  │  │
│  │  │  ┌─────────────────────┐   │  │  │     │  │  │  ┌─────────────────────┐   │  │  │
│  │  │  │   Aurora MySQL      │   │  │  │     │  │  │  │  Aurora MySQL       │   │  │  │
│  │  │  │  (Primary Writer)   │───┼──┼──┼─────┼──┼──┼──│  (Read Replica)     │   │  │  │
│  │  │  └─────────────────────┘   │  │  │ CRR │  │  │  └─────────────────────┘   │  │  │
│  │  └────────────────────────────┘  │  │     │  │  └────────────────────────────┘  │  │
│  └──────────────────────────────────┘  │     │  └──────────────────────────────────┘  │
│                                        │     │                                        │
│  ┌──────────────────────────────────┐  │     │  ┌──────────────────────────────────┐  │
│  │ S3: healthcare-data-primary      │──┼─────┼──│ S3: healthcare-data-replica      │  │
│  │ AWS Backup Vault                 │──┼─────┼──│ AWS Backup Vault (Copy)          │  │
│  └──────────────────────────────────┘  │     │  └──────────────────────────────────┘  │
└────────────────────────────────────────┘     └────────────────────────────────────────┘
```

## 🎯 Key Outcomes

| Metric | Target | Implementation |
|--------|--------|----------------|
| **RPO** | ≤ 1 hour | Aurora cross-region replication + S3 CRR |
| **RTO** | 15-30 min | Pilot Light with automated failover |
| **Durability** | 99.999999999% | S3 Cross-Region Replication |
| **Backup Retention** | 35 days | AWS Backup with lifecycle policies |

## 📁 Project Structure

```mermaid
healthcare-dr-project/
├── README.md
├── LICENSE
├── .gitignore
├── terraform/
│   ├── modules/
│   │   ├── vpc/                          # Multi-AZ VPC module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── rds/                          # Aurora MySQL module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── s3-replication/               # S3 with CRR module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── backup/                       # AWS Backup module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── route53/                      # DNS failover module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── cloudformation-stacksets/     # DR templates
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── primary/                      # eu-west-2 (London)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── providers.tf
│       │   └── terraform.tfvars.example
│       └── secondary/                    # eu-west-1 (Ireland)
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           ├── providers.tf
│           └── terraform.tfvars.example
├── scripts/
│   ├── failover.sh                       # Execute DR failover
│   ├── failback.sh                       # Return to primary
│   ├── health-check.sh                   # Validate DR readiness
│   └── dr-test.sh                        # DR drill automation
├── docs/
│   ├── RUNBOOK.md                        # Operational procedures
│   ├── RISK_ASSESSMENT.md                # Risk analysis
│   ├── COMPLIANCE.md                     # Healthcare compliance
│   ├── PORTFOLIO_GUIDE.md                # Portfolio documentation
│   └── images/
│       └── architecture-diagram.png
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
git clone https://github.com/YOUR_USERNAME/healthcare-dr-aws.git
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

### Configuration Files

| File | Purpose | Commit to Git? |
|------|---------|----------------|
| `terraform.tfvars.example` | Template for Terraform variables | ✅ Yes |
| `terraform.tfvars` | Your actual Terraform variables | ❌ No |
| `backend.hcl.example` | Template for backend config | ✅ Yes |
| `backend.hcl` | Your actual backend config | ❌ No |
| `dr-config.env.example` | Template for script config | ✅ Yes |
| `dr-config.env` | Your actual script config | ❌ No |

### Security Notes

- **Database Password**: Leave `database_password` empty in terraform.tfvars to auto-generate a secure password stored in AWS Secrets Manager
- **No Hardcoded Values**: All account IDs, ARNs, and sensitive values are derived from data sources or variables
- **Backend State**: Use S3 with encryption and DynamoDB locking for Terraform state

## 📚 Documentation

- [Operational Runbook](docs/RUNBOOK.md)
- [Risk Assessment](docs/RISK_ASSESSMENT.md)
- [Compliance Guide](docs/COMPLIANCE.md)
- [Portfolio Guide](docs/PORTFOLIO_GUIDE.md)

## 👤 Author

**Ben** - Cloud Engineer

## 📄 License

MIT License - see [LICENSE](LICENSE)
