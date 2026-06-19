locals {
  name_prefix = trimsuffix(substr(replace(replace(lower(var.project_name), " ", "-"), "_", "-"), 0, 32), "-")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "macie-data-discovery"
  }
}

# ─────────────────────────────────────────────
# 1. S3 BUCKET
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "sensitive_data" {
  bucket        = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload sensitive-data.txt vao S3
resource "aws_s3_object" "sensitive_data_file" {
  bucket = aws_s3_bucket.sensitive_data.id
  key    = "sensitive-data.txt"
  source = "${path.module}/sensitive-data.txt"
  etag   = filemd5("${path.module}/sensitive-data.txt")

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.sensitive_data]
}

# ─────────────────────────────────────────────
# 2. SNS TOPIC & SUBSCRIPTION
# ─────────────────────────────────────────────

resource "aws_sns_topic" "macie_alerts" {
  name = "Macie-Alerts-Topic"
}

resource "aws_sns_topic_policy" "macie_alerts" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─────────────────────────────────────────────
# 3. AMAZON MACIE
# ─────────────────────────────────────────────

resource "aws_macie2_account" "this" {
  status                       = "ENABLED"
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Cho Macie service-linked role propagate truoc khi tao job
resource "time_sleep" "wait_for_macie_role" {
  create_duration = "30s"
  depends_on      = [aws_macie2_account.this]
}

resource "aws_macie2_classification_job" "sensitive_data_scan" {
  name       = "${local.name_prefix}-scan-job"
  job_type   = "ONE_TIME"
  depends_on = [time_sleep.wait_for_macie_role]

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.sensitive_data.id]
    }
  }
}

# ─────────────────────────────────────────────
# 4. EVENTBRIDGE RULE → SNS
# ─────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "macie_findings" {
  name        = "${local.name_prefix}-findings-rule"
  description = "Capture all Macie findings and forward to SNS for email alerting."

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
  })

  depends_on = [aws_macie2_account.this]
}

resource "aws_cloudwatch_event_target" "macie_findings_to_sns" {
  rule      = aws_cloudwatch_event_rule.macie_findings.name
  target_id = "MacieFindingsToSNS"
  arn       = aws_sns_topic.macie_alerts.arn
}

# ─────────────────────────────────────────────
# DATA SOURCES
# ─────────────────────────────────────────────

data "aws_caller_identity" "current" {}
