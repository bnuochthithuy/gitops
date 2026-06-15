variable "region" {
  description = "AWS region where the EC2 instance and CloudWatch alarm are managed."
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "cloudwatch-cpu-alert-lab"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "lab"
}

variable "ec2_instance_id" {
  description = "ID of the EC2 instance to monitor, for example i-0123456789abcdef0."
  type        = string

  validation {
    condition     = can(regex("^i-[0-9a-f]+$", var.ec2_instance_id))
    error_message = "ec2_instance_id must look like an EC2 instance id, for example i-0123456789abcdef0."
  }
}

variable "notification_email" {
  description = "Email address that will receive SNS alarm notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "cpu_threshold_percent" {
  description = "CPU percentage threshold that puts the alarm into ALARM state."
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_threshold_percent > 0 && var.cpu_threshold_percent <= 100
    error_message = "cpu_threshold_percent must be between 1 and 100."
  }
}

variable "alarm_period_seconds" {
  description = "CloudWatch metric period in seconds. 300 seconds equals 5 minutes."
  type        = number
  default     = 300
}

variable "alarm_evaluation_periods" {
  description = "Number of consecutive periods evaluated by the alarm."
  type        = number
  default     = 1
}

variable "send_ok_notification" {
  description = "When true, send an SNS email when the alarm returns to OK."
  type        = bool
  default     = true
}
