output "sns_topic_arn" {
  description = "SNS topic ARN used by the CloudWatch alarm."
  value       = aws_sns_topic.cpu_alerts.arn
}

output "email_subscription_arn" {
  description = "SNS subscription ARN. It remains PendingConfirmation until the email link is confirmed."
  value       = aws_sns_topic_subscription.email.arn
}

output "cloudwatch_alarm_name" {
  description = "Name of the CloudWatch alarm monitoring EC2 CPU."
  value       = aws_cloudwatch_metric_alarm.ec2_cpu_high.alarm_name
}
