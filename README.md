# Redline — Infrastructure (Terraform)

Infrastructure-as-code for [Redline](https://redline.fourallthedogs.com), an AI-powered car marketplace where autonomous buyer and seller bots negotiate vehicle prices on behalf of users.

This repository provisions all AWS infrastructure across 12 services and 79 resources using modular Terraform.

## Architecture

```
                        ┌─────────────────┐
                        │   CloudFront    │
                        │   + WAF + ACM   │
                        └────────┬────────┘
                                 │
               ┌─────────────────┴─────────────────┐
               │                                   │
        ┌──────▼──────┐                    ┌───────▼──────┐
        │  S3 Frontend │                   │  ALB Ingress  │
        └─────────────┘                    └───────┬───────┘
                                                   │
                                        ┌──────────▼──────────┐
                                        │     EKS Cluster      │
                                        │  ┌────────────────┐  │
                                        │  │listings-service│  │
                                        │  ├────────────────┤  │
                                        │  │ users-service  │  │
                                        │  ├────────────────┤  │
                                        │  │negotiation-svc │  │
                                        │  └────────────────┘  │
                                        └──────────┬───────────┘
                                                   │
                    ┌──────────────────────────────┼───────────────────┐
                    │                              │                   │
             ┌──────▼──────┐              ┌────────▼──────┐   ┌───────▼──────┐
             │RDS PostgreSQL│              │   DynamoDB    │   │   Bedrock    │
             │  (listings,  │              │ (negotiation  │   │(Claude Haiku)│
             │    users)    │              │   sessions)   │   └──────────────┘
             └─────────────┘              └───────────────┘
```

## Modules

| Module | Resources |
|--------|-----------|
| `networking` | VPC, subnets, NAT Gateway, route tables, security groups |
| `eks` | EKS cluster, node group, OIDC provider, aws-load-balancer-controller |
| `irsa` | IAM roles scoped per service via IRSA |
| `rds` | RDS PostgreSQL instance, subnet group, parameter group |
| `dynamodb` | Negotiation sessions table with GSI and TTL |
| `sns` | Deal reached and negotiation failed topics |
| `cognito` | User pool, client, hosted UI domain |
| `ecr` | Repositories for all 3 microservices |
| `cloudfront` | Distribution, S3 origin, WAF WebACL |
| `route53` | DNS records for apex and API subdomain |
| `cloudwatch` | Container Insights, dashboard, log groups |
| `secretsmanager` | DB credentials secret |

## Key Design Decisions

**NAT Gateway over VPC Endpoints** — At dev/portfolio scale, a single NAT Gateway is more cost-effective than per-service VPC interface endpoints. OpenCourt (a companion project) uses VPC endpoints for the inverse reason — demonstrating conscious, context-driven tradeoffs.

**IRSA scoped per service** — Each microservice has its own IAM role with least-privilege permissions. The negotiation service can access Bedrock, DynamoDB, SNS, and Secrets Manager. The listings service can only access RDS credentials. No shared roles.

**Local Terraform backend** — Remote S3 backend was attempted but abandoned due to persistent HeadObject 403 errors in the dev account. State is managed locally for this portfolio project.

## Infrastructure

- **EKS**: `redline-cluster`, 2x t3.medium nodes, `us-east-1`
- **RDS**: PostgreSQL 15, `db.t3.micro`, private subnet
- **DynamoDB**: On-demand billing, 7-day TTL on negotiation sessions
- **Bedrock**: `us.anthropic.claude-haiku-4-5-20251001-v1:0` inference profile
- **CloudFront**: `E1FYHMQIX40Q8P`, wildcard ACM cert covering apex and API subdomain

## Prerequisites

- AWS CLI configured with `dev` profile
- Terraform >= 1.5
- `kubectl` and `helm` installed

## Usage

```bash
cd redline-terraform
terraform init
terraform plan
terraform apply
```

> ACM certificate validation requires a manual nameserver update in the parent hosted zone during first apply. Watch for the apply to pause at the certificate resource and update nameservers accordingly.

## Tear Down

```bash
terraform destroy --auto-approve
```

EKS takes 15–20 minutes to fully deprovision.

## Related Repositories

- [redline-api](https://github.com/djiwani/redline-api) — FastAPI microservices
- [redline-frontend](https://github.com/djiwani/redline-frontend) — Static frontend
