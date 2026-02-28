# Healthcare Application Disaster Recovery & Business Continuity on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade disaster recovery and business continuity solution for healthcare applications on AWS, implementing a **Pilot Light** DR strategy with automated failover capabilities.

## 🏗️ Architecture Overview

![DR Architecture](diagrams/architecture-diagram.png)

```text
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Multi-Region DR Architecture                        │
├─────────────────────────────────────┬───────────────────────────────────────────────┤
│         PRIMARY REGION              │              SECONDARY REGION                  │
│         (eu-west-2 London)          │              (eu-west-1 Ireland)               │
├─────────────────────────────────────┼───────────────────────────────────────────────┤
│                                     │                                                │
│  ┌─────────────────────────────┐    │    ┌─────────────────────────────┐            │
│  │           WAF               │    │    │         (Standby)           │            │
│  │    (OWASP Protection)       │    │    │                             │            │
│  └─────────────┬───────────────┘    │    └─────────────────────────────┘            │
│                │                    │                                                │
│  ┌─────────────▼───────────────┐    │    ┌─────────────────────────────┐            │
│  │   Application Load Balancer │    │    │         (Standby)           │            │
│  └─────────────┬───────────────┘    │    └─────────────────────────────┘            │
│                │                    │                                                │
│  ┌─────────────▼───────────────┐    │    ┌─────────────────────────────┐            │
│  │     ECS Fargate Cluster     │    │    │         (Standby)           │            │
│  │    ┌─────────┬─────────┐    │    │    │                             │            │
│  │    │  Task   │  Task   │    │    │    │                             │            │
│  │    └─────────┴─────────┘    │    │    └─────────────────────────────┘            │
│  └─────────────┬───────────────┘    │                                                │
│                │                    │                                                │
│  ┌─────────────▼───────────────┐    │    ┌─────────────────────────────┐            │
│  │    Aurora MySQL Cluster     │────┼───▶│   Aurora MySQL (Replica)   │            │
│  │  (Writer + Reader Instance) │    │    │    (Cross-Region Replica)   │            │
│  └─────────────────────────────┘    │    └─────────────────────────────┘            │
│                                     │                                                │
│  ┌─────────────────────────────┐    │    ┌─────────────────────────────┐            │
│  │         S3 Bucket           │────┼───▶│      S3 Bucket (Replica)    │            │
│  │    (Healthcare Data)        │ CRR│    │                             │            │
│  └─────────────────────────────┘    │    └─────────────────────────────┘            │
│                                     │                                                │
│  ┌─────────────────────────────┐    │    ┌─────────────────────────────┐            │
│  │     AWS Backup Vault        │────┼───▶│   Backup Vault (Copy)       │            │
│  └─────────────────────────────┘    │    └─────────────────────────────┘            │
│                                     │                                                │
│  ┌─────────────────────────────┐    │    ┌─────────────────────────────┐            │
│  │        GuardDuty            │    │    │        GuardDuty            │            │
│  │   (Threat Detection)        │    │    │   (Threat Detection)        │            │
│  └─────────────────────────────┘    │    └─────────────────────────────┘            │
│                                     │                                                │
└─────────────────────────────────────┴───────────────────────────────────────────────┘
```

## 🎯 Project Objectives

- **RTO (Recovery Time Objective):** 15-30 minutes
- **RPO (Recovery Point Objective):** < 1 hour
- **DR Strategy:** Pilot Light (minimal footprint in secondary region, scale up on failover)
- **Compliance:** HIPAA-ready architecture with encryption at rest and in transit

## 🛠️ Technologies Used

| Category | Technologies |
| --- | --- |
| **Infrastructure as Code** | Terraform (11 modules) |
| **Cloud Platform** | AWS (Multi-Region) |
| **Compute** | ECS Fargate, Application Load Balancer |
| **Database** | Aurora MySQL (Cross-Region Replication) |
| **Storage** | S3 (Cross-Region Replication), AWS Backup |
| **Security** | WAF, GuardDuty, KMS, Secrets Manager |
| **Networking** | VPC, NAT Gateway, Route 53 |
| **Monitoring** | CloudWatch, SNS, Cost Explorer |
| **CI/CD** | GitHub Actions (3 pipelines) |
| **Container** | Docker, ECR |
| **Application** | Node.js, Express.js |

## 📁 Project Structure

```text
├── healthcare-dr-aws/
├── .github/
│   └── workflows/
│       ├── terraform.yml       # IaC validation & deployment
│       ├── container.yml       # Docker build & push to ECR
│       └── dr-validation.yml   # Weekly DR health checks
├── application/
│   ├── docker/
│   │   └── Dockerfile          # Multi-stage production build
│   ├── src/
│   │   └── server.js           # Express.js healthcare API
│   └── package.json
├── terraform/
│   ├── environments/
│   │   ├── primary/            # eu-west-2 (London)
│   │   └── secondary/          # eu-west-1 (Ireland)
│   └── modules/
│       ├── vpc/                # VPC with public/private subnets
│       ├── rds/                # Aurora MySQL cluster
│       ├── ecs/                # ECS Fargate service
│       ├── s3-replication/     # S3 with cross-region replication
│       ├── backup/             # AWS Backup configuration
│       ├── waf/                # Web Application Firewall
│       ├── guardduty/          # Threat detection
│       ├── monitoring/         # CloudWatch dashboards & alarms
│       ├── cost-monitoring/    # Budget alerts
│       └── ...
├── scripts/
│   ├── health-check.sh         # DR readiness validation
│   └── dr-config.env           # DR configuration
├── tests/
│   └── dr-validation/
│       └── test_replication.sh # Replication testing
└── docs/
    └── architecture-diagram.html
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Docker Desktop
- Node.js >= 18

### Deployment

1. **Clone the repository**

   ```bash
   git clone https://github.com/bennymaliti/healthcare-dr-aws.git
   cd healthcare-dr-aws
   ```

2. **Create Terraform backend**

   ```bash
   aws s3 mb s3://your-terraform-state-bucket --region eu-west-2
   aws dynamodb create-table \
       --table-name terraform-state-lock \
       --attribute-definitions AttributeName=LockID,AttributeType=S \
       --key-schema AttributeName=LockID,KeyType=HASH \
       --billing-mode PAY_PER_REQUEST \
       --region eu-west-2
   ```

3. **Deploy Secondary Region first**

   ```bash
   cd terraform/environments/secondary
   terraform init -backend-config=backend.hcl
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. **Deploy Primary Region**

   ```bash
   cd ../primary
   # Update terraform.tfvars with secondary region outputs
   terraform init -backend-config=backend.hcl
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

5. **Build and push container**

   ```bash
   cd ../../../application
   aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-2.amazonaws.com
   docker build -f docker/Dockerfile -t healthcare-app .
   docker tag healthcare-app:latest <account-id>.dkr.ecr.eu-west-2.amazonaws.com/healthcare-dr-primary-app:latest
   docker push <account-id>.dkr.ecr.eu-west-2.amazonaws.com/healthcare-dr-primary-app:latest
   ```

## 🔄 CI/CD Pipelines

### Terraform CI/CD (`terraform.yml`)

- **Triggers:** Push to main, Pull Requests
- **Jobs:**
  - Validate Terraform formatting
  - Security scan (tfsec, Checkov)
  - Plan changes (requires approval)
  - Apply changes (manual trigger only)

### Container Build (`container.yml`)

- **Triggers:** Changes to `application/` directory
- **Jobs:**
  - Build Docker image
  - Run Trivy vulnerability scan
  - Push to ECR (both regions)
  - Deploy to ECS (manual trigger)

### DR Validation (`dr-validation.yml`)

- **Triggers:** Weekly schedule, manual
- **Jobs:**
  - Health check all components
  - Test replication
  - Generate DR readiness report

## 🔐 Security Features

| Feature | Implementation |
| ------- | ------------- |
| **WAF** | OWASP Top 10 rules, SQL injection protection, XSS protection |
| **GuardDuty** | Threat detection in both regions |
| **KMS** | Multi-region keys for S3 and RDS encryption |
| **Secrets Manager** | Database credentials management |
| **VPC** | Private subnets, NAT Gateway, security groups |
| **IAM** | Least privilege roles for all services |

## 📊 Monitoring & Alerting

- **CloudWatch Dashboards:** Infrastructure metrics visualization
- **CloudWatch Alarms:** CPU, memory, replication lag alerts
- **SNS Notifications:** Email alerts for critical events
- **Cost Monitoring:** Budget alerts and anomaly detection

## 💰 Cost Estimation

| Component | Monthly Estimate |
| --------- | ---------------- |
| Aurora MySQL (2 regions) | $150-200 |
| VPC/NAT Gateways | $70-100 |
| ECS Fargate (when enabled) | $50-90 |
| S3 + Replication | $5-10 |
| WAF | $5-10 |
| Other (Backup, GuardDuty, etc.) | $20-40 |
| **Total** | **$300-450/month** |

## 🧪 DR Testing

### Manual Failover Test

```bash
# 1. Promote secondary Aurora to standalone
aws rds promote-read-replica-db-cluster \
    --db-cluster-identifier healthcare-dr-secondary-aurora \
    --region eu-west-1

# 2. Update Route 53 to point to secondary
# 3. Scale up ECS in secondary region
# 4. Verify application health
```

### Automated Health Check

```bash
./scripts/health-check.sh
```

## 📚 Lessons Learned

1. **Aurora Cross-Region Replication** requires binary logging (`binlog_format = MIXED`)
2. **S3 Replication** with KMS needs proper key policies in both regions
3. **ECS Fargate** requires ECR image before service creation
4. **Terraform State** should use remote backend with locking for team collaboration
5. **Cost Optimization:** Use single NAT Gateway in secondary region for Pilot Light

## 🏆 Key Achievements

- ✅ Production-grade multi-region architecture
- ✅ 15-minute RTO / 1-hour RPO targets met
- ✅ 11 reusable Terraform modules
- ✅ 3 automated CI/CD pipelines
- ✅ Enterprise security controls (WAF, GuardDuty, KMS)
- ✅ Comprehensive monitoring and alerting
- ✅ Cost-optimized Pilot Light strategy

## 👤 Author

### Benny Maliti

- Website: [bennymaliti.co.uk](https://bennymaliti.co.uk)
- LinkedIn: [linkedin.com/in/benny-maliti](https://linkedin.com/in/benny-maliti)
- GitHub: [github.com/bennymaliti](https://github.com/bennymaliti)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
