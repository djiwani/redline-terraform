variable "project" {
  description = "Project name"
  type        = string
}

variable "notification_email" {
  description = "Email address for deal reached / negotiation failed notifications"
  type        = string
}

variable "owner_email" {
  description = "Email address for owner operational alerts"
  type        = string
}
