locals {
  name_prefix = trimsuffix(substr(replace(replace(lower(var.project_name), " ", "-"), "_", "-"), 0, 32), "-")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "cloudwatch-agent"
  }
}

data "aws_iam_role" "ec2_role" {
  name = var.existing_ec2_role_name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = data.aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
