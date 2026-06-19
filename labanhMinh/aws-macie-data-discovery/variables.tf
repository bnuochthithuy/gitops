variable "region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used for resource naming and tags."
  type        = string
  default     = "macie-data-discovery"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "lab"
}

variable "alert_email" {
  description = "Email address that receives Macie finding alerts via SNS."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "alert_email must be a valid email address, for example user@example.com."
  }
}
