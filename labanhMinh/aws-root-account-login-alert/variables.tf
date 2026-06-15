variable "region" {
  description = "AWS region where CloudTrail, CloudWatch, SNS, and S3 resources are managed."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "root-login-alert-lab"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "lab"
}

variable "notification_email" {
  description = "Email address that will receive SNS root login alarm notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for CloudTrail events."
  type        = number
  default     = 30
}

variable "alarm_period_seconds" {
  description = "CloudWatch metric alarm period in seconds. 300 seconds equals 5 minutes."
  type        = number
  default     = 300
}

variable "alarm_evaluation_periods" {
  description = "Number of periods evaluated by the root login alarm."
  type        = number
  default     = 1
}

variable "send_ok_notification" {
  description = "When true, send an SNS email when the alarm returns to OK."
  type        = bool
  default     = true
}
