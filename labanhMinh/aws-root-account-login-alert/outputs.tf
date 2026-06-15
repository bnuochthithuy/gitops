output "sns_topic_arn" {
  description = "SNS topic ARN used by the root login alarm."
  value       = aws_sns_topic.security_alerts.arn
}

output "email_subscription_arn" {
  description = "SNS subscription ARN. It remains PendingConfirmation until the email link is confirmed."
  value       = aws_sns_topic_subscription.email.arn
}

output "cloudtrail_name" {
  description = "CloudTrail trail name."
  value       = aws_cloudtrail.security.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs group receiving CloudTrail events."
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "metric_filter_name" {
  description = "CloudWatch Logs metric filter name for root account activity."
  value       = aws_cloudwatch_log_metric_filter.root_account_login.name
}

output "cloudwatch_alarm_name" {
  description = "CloudWatch alarm name for root account login/activity."
  value       = aws_cloudwatch_metric_alarm.root_account_login.alarm_name
}

output "cloudtrail_s3_bucket_name" {
  description = "S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.bucket
}
