output "iam_role_name" {
  description = "Existing IAM role that received CloudWatchAgentServerPolicy."
  value       = data.aws_iam_role.ec2_role.name
}

output "ec2_instance_id" {
  description = "EC2 instance configured for CloudWatch Agent."
  value       = var.ec2_instance_id
}

output "cloudwatch_agent_config_path" {
  description = "Local CloudWatch Agent config file to copy into EC2."
  value       = "${path.module}/amazon-cloudwatch-agent.json"
}
