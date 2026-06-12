locals {
  name_prefix = trimsuffix(substr(replace(replace(lower(var.project_name), " ", "-"), "_", "-"), 0, 32), "-")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "cloudwatch-cpu-alert"
  }
}

resource "aws_sns_topic" "cpu_alerts" {
  name = "${local.name_prefix}-cpu-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cpu_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${local.name_prefix}-${var.ec2_instance_id}-cpu-high"
  alarm_description   = "Alarm when EC2 CPUUtilization is greater than ${var.cpu_threshold_percent}% for ${var.alarm_period_seconds / 60} minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_threshold_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  datapoints_to_alarm = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  alarm_actions = [
    aws_sns_topic.cpu_alerts.arn
  ]

  ok_actions = var.send_ok_notification ? [
    aws_sns_topic.cpu_alerts.arn
  ] : []
}
