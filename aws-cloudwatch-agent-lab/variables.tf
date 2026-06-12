variable "region" {
  description = "AWS region where the EC2 instance runs."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used for IAM resource names and tags."
  type        = string
  default     = "cloudwatch-agent-lab"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "lab"
}

variable "ec2_instance_id" {
  description = "ID of the EC2 instance that will run CloudWatch Agent."
  type        = string
  default     = "i-0349b4fa02b794fea"

  validation {
    condition     = can(regex("^i-[0-9a-f]+$", var.ec2_instance_id))
    error_message = "ec2_instance_id must look like an EC2 instance id, for example i-0123456789abcdef0."
  }
}

variable "existing_ec2_role_name" {
  description = "Existing IAM role already attached to the EC2 instance profile."
  type        = string
  default     = "EC2InstanceProfileRole"
}
