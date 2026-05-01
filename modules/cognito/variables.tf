variable "project" {
  description = "Project name"
  type        = string
}

variable "subdomain" {
  description = "Frontend subdomain — used for Cognito callback URLs"
  type        = string
}
