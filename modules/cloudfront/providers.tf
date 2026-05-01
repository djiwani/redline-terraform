# This module uses the us_east_1 provider alias for ACM and WAF.
# CloudFront requires both to be in us-east-1 regardless of
# where the rest of the infrastructure lives.
# The alias is passed in from the root main.tf provider block.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
