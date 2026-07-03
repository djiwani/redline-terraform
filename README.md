# Redline — Infrastructure (Terraform)

Live: [redline.fourallthedogs.com](https://redline.fourallthedogs.com)

Infrastructure as code for Redline — an AI-powered car marketplace where autonomous buyer and seller agents negotiate vehicle prices on behalf of users using Amazon Bedrock.

Built as the third and most complex project in a three-project AWS portfolio. Demonstrates modular Terraform with remote state, EKS with per-service IRSA, and multi-AZ VPC design with a deliberate NAT Gateway cost tradeoff.

11 Terraform modules, 79 resources.

---

## Architecture

```
                        ┌─────────────────────┐
                        │      CloudFront      │
                        │   + WAF + ACM (*)   │
                        └──────────┬───────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               │                                       │
        ┌──────▼──────┐                       ┌────────▼────────┐
        │ S3 (Static  │                       │  ALB            │
        │  Frontend)  │                       │ (IngressGroup   │
        └─────────────┘                       │  via LBC)       │
                                              └────────┬────────┘
                                                       │ path-based routing
                                    ┌──────────────────┼──────────────────┐
                                    │                  │                  │
                             ┌──────▼──────┐   ┌───────▼──────┐  ┌───────▼──────┐
                             │  listings   │   │    users     │  │ negotiation  │
                             │  service   │   │   service    │  │  service     │
                             │ (FastAPI)  │   │  (FastAPI)   │  │  (FastAPI)   │
                             └──────┬──────┘   └───────┬──────┘  └───────┬──────┘
                                    │                  │                  │
                             ┌──────▼──────┐   ┌───────▼──────┐  ┌───────▼──────┐
                             │    RDS      │   │  Secrets     │  │  DynamoDB    │
                             │ PostgreSQL  │   │  Manager     │  │ (Sessions    │
                             │ (listings, │   │  (DB creds)  │  │  + GSI)      │
                             │  users)    │   └──────────────┘  ├──────────────┤
                             └─────────────┘                    │   Bedrock    │
                                                                │(Claude Haiku)│
                                                                ├──────────────┤
                                                                │     SNS      │
                                                                │(Notifications│
                                                                └──────────────┘

(*) ACM and WAF provisioned in us-east-1 via provider alias — required for CloudFront
```

---

## Networking Design — Single NAT Gateway

**VPC:** `10.5.0.0/16`, two AZs
**Public subnets:** ALB, NAT Gateway
**Private subnets:** EKS nodes, RDS

A single NAT Gateway is shared across both private subnet AZs. This is a deliberate cost tradeoff: a per-AZ setup would cost an additional ~$32/month with no meaningful reliability benefit at portfolio scale. OpenCourt (a companion project) eliminates the NAT Gateway entirely using VPC endpoints — demonstrating the inverse decision for a security-first workload.

**Security group chain:**

```
Internet → CloudFront → ALB SG → EKS Nodes SG → RDS SG
```

Each layer allows traffic only from the security group immediately before it, not from CIDRs. RDS accepts connections only from the EKS nodes security group on port 5432. Nothing else in the VPC can reach RDS.

**EKS dual security group gotcha:**

EKS creates two security groups — the custom one defined in Terraform and an AWS-managed cluster SG that is attached to nodes automatically. The RDS security group must allow inbound from both. Allowing only the custom SG causes silent connection failures from pods because node traffic originates from the cluster-managed SG.

The cluster-managed SG rule (`aws_security_group_rule.eks_cluster_to_rds`) is added in the EKS module rather than the networking module. The cluster-managed SG does not exist until after the EKS cluster is created, so defining it in networking would create a circular dependency.

---

## Modules

| Module | What It Provisions |
|--------|-------------------|
| `networking` | VPC, public/private subnets, IGW, NAT Gateway, EIP, route tables, ALB/EKS/RDS security groups |
| `eks` | EKS cluster, managed node group, OIDC provider, cluster-managed SG rule for RDS |
| `irsa` | Four IAM roles scoped per service via IRSA with OIDC trust conditions |
| `rds` | RDS PostgreSQL 15, subnet group, parameter group, Secrets Manager credential storage |
| `dynamodb` | Negotiation sessions table, GSI on `user_id`, 7-day TTL |
| `sns` | Deal reached, negotiation failed, and owner alert topics |
| `cognito` | User Pool, app client, hosted UI domain |
| `ecr` | Container repositories for all three microservices |
| `cloudfront` | CloudFront distribution, S3 origin, WAF WebACL, ACM cert (us-east-1 provider alias) |
| `route53` | Hosted zone, apex and API subdomain DNS records |
| `cloudwatch` | Container Insights, log groups, CloudWatch dashboard, alarms wired to SNS |

Helm is used directly in `main.tf` to install the AWS Load Balancer Controller onto the cluster after EKS and IRSA are provisioned.

---

## IRSA — Per-Service IAM

Each microservice has its own IAM role with the minimum permissions required. No shared roles. Trust policies use an OIDC condition scoped to the specific Kubernetes service account and namespace — a pod running as the wrong service account cannot assume another service's role.

| Service | Permissions |
|---------|------------|
| `listings` | `secretsmanager:GetSecretValue` on the DB secret ARN only |
| `users` | `secretsmanager:GetSecretValue` on the DB secret ARN only |
| `negotiation` | `bedrock:InvokeModel` on Claude Haiku inference profile only; `dynamodb:PutItem/GetItem/UpdateItem/Query/DeleteItem` on the sessions table and its GSI only; `sns:Publish` on deal reached and negotiation failed topic ARNs only; `secretsmanager:GetSecretValue` on the DB secret ARN only |
| `aws-load-balancer-controller` | Official AWS-provided LBC policy (EC2/ELB permissions for ALB provisioning) |

Note: Cognito JWT verification in the users service uses the Cognito public JWKS endpoint over HTTPS — no IAM permissions required for that.

---

## Remote State

State is stored in S3 with DynamoDB locking:

```hcl
backend "s3" {
  bucket         = "redline-terraform-state"
  key            = "redline/terraform.tfstate"
  region         = "us-east-1"
  profile        = "dev"
  dynamodb_table = "redline-terraform-locks"
  encrypt        = true
}
```

Prevents state corruption if multiple applies run concurrently and ensures state is never lost if the local machine is unavailable.

---

## Multi-Region Provider Configuration

CloudFront requires ACM certificates and WAF WebACLs in `us-east-1` regardless of the primary region. A secondary provider alias handles this:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  profile = "dev"
}
```

The `cloudfront` module receives both the default provider and the aliased provider, using the alias specifically for ACM and WAF resources.

---

## CI/CD

Three independent GitHub Actions pipelines — one per microservice — triggered by path-based filters. A commit touching only the listings service triggers only the listings pipeline. No unnecessary rebuilds.

Each pipeline: builds the Docker image → pushes to ECR → triggers a rolling EKS deployment.

---

## Infrastructure Summary

| Resource | Config |
|----------|--------|
| EKS cluster | `redline-cluster`, `us-east-1`, Kubernetes 1.31 |
| Node group | 2x `t3.medium`, private subnets |
| RDS | PostgreSQL 15, `db.t3.micro`, private subnets |
| DynamoDB | On-demand billing, TTL 7 days, GSI on `user_id` |
| Bedrock model | `us.anthropic.claude-haiku-4-5-20251001-v1:0` cross-region inference profile |
| CloudFront | Wildcard ACM cert covering apex and API subdomain |

---

## Deployment

### Prerequisites

- AWS CLI configured with `dev` profile
- Terraform 1.5+
- `kubectl` and `helm` installed

### Apply

```bash
terraform init
terraform apply
```

> ACM certificate validation pauses the apply at the certificate resource. Update nameservers in the parent hosted zone when prompted and wait for DNS propagation before the apply continues.

Post-apply steps:

1. Build and push Docker images to ECR for all three services
2. Confirm pods are running: `kubectl get pods -n redline`
3. Retrieve the ALB DNS name and update the Route53 API subdomain record — the ALB is created by the Load Balancer Controller after `terraform apply` completes, so its DNS name is not known until after Helm deploys

### Teardown

```bash
terraform destroy --auto-approve
```

EKS takes 15-20 minutes to fully deprovision.

---

## Related Repositories

- [redline-api](https://github.com/djiwani/redline-api) — FastAPI microservices (listings, users, negotiation)
- [redline-frontend](https://github.com/djiwani/redline-frontend) — Static frontend
- [opencourt-terraform](https://github.com/djiwani/opencourt-terraform) — Prior project: ECS Fargate, no NAT Gateway, VPC endpoints
- [coffee-terraform](https://github.com/djiwani/coffee-terraform) — First project: fully serverless, no VPC
