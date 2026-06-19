output "s3_bucket_name" {
  description = "S3 bucket containing the sensitive data file that Macie scans."
  value       = aws_s3_bucket.sensitive_data.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.sensitive_data.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives Macie finding alerts."
  value       = aws_sns_topic.macie_alerts.arn
}

output "sns_subscription_email" {
  description = "Email address subscribed to the Macie alert SNS topic."
  value       = var.alert_email
}

output "macie_job_id" {
  description = "ID of the Macie classification job."
  value       = aws_macie2_classification_job.sensitive_data_scan.id
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that routes Macie findings to SNS."
  value       = aws_cloudwatch_event_rule.macie_findings.arn
}

output "next_steps" {
  description = "Manual steps to complete after terraform apply."
  value       = <<-EOT
    1. Kiem tra email "${var.alert_email}" va nhan "Confirm subscription" tu AWS SNS.
    2. Doi Macie classification job chay xong (khoang 5-15 phut).
    3. Vao Macie Console -> Findings de xem PII / Credit Card findings.
    4. Kiem tra email de nhan canh bao JSON tu EventBridge -> SNS.
  EOT
}
