# -------------------------------------------------------
# ECR REPOSITORIES
# One per service — stores Docker images that EKS pulls
# on deploy. GitHub Actions builds and pushes images here.
# -------------------------------------------------------

locals {
  services = ["listings-service", "users-service", "negotiation-service"]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "MUTABLE" # Allows re-tagging — useful for :latest in dev

  image_scanning_configuration {
    scan_on_push = true # Scans for vulnerabilities on every push
  }

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# LIFECYCLE POLICIES
# Keep the last 10 images per repo, delete the rest.
# Prevents ECR storage costs creeping up over time.
# -------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = toset(local.services)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
