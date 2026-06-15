# AWS Root Account Login Alert Lab

Lab nay tao canh bao khi AWS root account duoc su dung. Day la security best practice quan trong vi root account co quyen cao nhat trong AWS account va gan nhu khong nen duoc dung hang ngay.

Muc tieu cua lab:

- Bat CloudTrail de ghi lai AWS account activity.
- Gui CloudTrail logs sang CloudWatch Logs.
- Tao Metric Filter de phat hien event co `userIdentity.type = Root`.
- Tao custom metric `Security/RootAccountLoginCount`.
- Tao CloudWatch Alarm khi root activity xuat hien.
- Gui canh bao qua SNS email.

## Kien truc

```text
AWS root account login/activity
    -> CloudTrail multi-region trail
    -> CloudWatch Logs log group
    -> Metric Filter: userIdentity.type = Root, eventType != AwsServiceEvent
    -> Custom metric: Security/RootAccountLoginCount
    -> CloudWatch Alarm: RootAccountLoginCount >= 1 trong 5 phut
    -> SNS Topic
    -> Email notification
```

## Tai nguyen Terraform tao ra

- `aws_cloudtrail.security`: CloudTrail multi-region ghi management events.
- `aws_cloudwatch_log_group.cloudtrail`: log group nhan CloudTrail logs.
- `aws_cloudwatch_log_metric_filter.root_account_login`: metric filter bat root account activity.
- `aws_cloudwatch_metric_alarm.root_account_login`: alarm khi metric `RootAccountLoginCount >= 1`.
- `aws_sns_topic.security_alerts`: SNS Topic nhan alarm action.
- `aws_sns_topic_subscription.email`: email subscription nhan canh bao.
- `aws_s3_bucket.cloudtrail`: S3 bucket luu CloudTrail logs.
- `aws_iam_role.cloudtrail_to_cloudwatch`: IAM role cho CloudTrail ghi vao CloudWatch Logs.

## Cau hinh lab hien tai

File `terraform.tfvars` dang cau hinh:

```hcl
region             = "us-east-1"
aws_profile        = "default"
notification_email = "bnuochthithuy13032005@gmail.com"
```

Voi default `project_name = "root-login-alert-lab"`, cac resource chinh co ten:

```text
CloudTrail trail: root-login-alert-lab-trail
CloudWatch log group: /aws/cloudtrail/root-login-alert-lab
Metric filter: root-login-alert-lab-root-account-login
CloudWatch alarm: root-login-alert-lab-root-account-login
SNS topic: root-login-alert-lab-security-alerts
Metric namespace: Security
Metric name: RootAccountLoginCount
```

## Chay lab tu dau

Tao file cau hinh tu file mau:

```powershell
cd D:\gitOps\gitops\labanhMinh\aws-root-account-login-alert
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
notepad .\terraform.tfvars
```

Sua email nhan canh bao:

```hcl
region             = "us-east-1"
aws_profile        = "default"
notification_email = "email-cua-ban@example.com"
```

Khoi tao va apply Terraform:

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Sau khi apply, mo email va bam link `Confirm subscription` cua AWS SNS. Neu subscription con `Pending confirmation`, CloudWatch Alarm co vao `ALARM` thi SNS van chua gui email canh bao duoc.

## Metric Filter

Metric filter dung pattern:

```text
{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }
```

Y nghia:

- `$.userIdentity.type = "Root"`: bat su kien do root account thuc hien.
- `$.eventType != "AwsServiceEvent"`: bo qua su kien noi bo do AWS service sinh ra.

Metric duoc tao:

```text
Namespace: Security
Metric name: RootAccountLoginCount
Metric value: 1
```

## CloudWatch Alarm

Alarm dung cau hinh:

- Metric: `Security/RootAccountLoginCount`
- Statistic: `Sum`
- Threshold: `>= 1`
- Period: `300` giay, tuc 5 phut
- Evaluation: `1 out of 1`
- Missing data: `notBreaching`
- Alarm action: gui message den SNS Topic `root-login-alert-lab-security-alerts`
- OK action: gui message den SNS Topic khi alarm quay ve `OK`

## Cach test root login alert

Cach test dung nhat la dang nhap AWS Console bang root account mot lan. Chi dung root account de test lab, khong tao/sua/xoa resource bang root, va logout ngay sau khi test.

Quy trinh test:

1. Apply Terraform thanh cong.
2. Confirm SNS email subscription.
3. Dang nhap AWS Console bang root user email cua AWS account.
4. Cho CloudTrail deliver event sang CloudWatch Logs. Thuong mat vai phut.
5. CloudWatch metric filter match event root activity va day metric `RootAccountLoginCount`.
6. CloudWatch Alarm chuyen tu `OK` sang `In alarm`.
7. SNS gui email canh bao den email da confirm.

Neu mentor lam theo README nay voi cung AWS account, region `us-east-1`, email da confirm va dang nhap root account de test, ket qua se giong evidence ben duoi. Thoi gian alarm co the lech vai phut do CloudTrail va CloudWatch Logs can thoi gian deliver event.

## Lenh kiem tra

Xem output Terraform:

```powershell
terraform output
```

Kiem tra CloudTrail:

```powershell
aws cloudtrail describe-trails --region us-east-1 --trail-name-list $(terraform output -raw cloudtrail_name)
```

Kiem tra SNS subscription da confirm:

```powershell
aws sns list-subscriptions-by-topic --region us-east-1 --topic-arn $(terraform output -raw sns_topic_arn)
```

Kiem tra metric filter:

```powershell
aws logs describe-metric-filters --region us-east-1 --log-group-name $(terraform output -raw cloudwatch_log_group_name)
```

Kiem tra alarm:

```powershell
aws cloudwatch describe-alarms --region us-east-1 --alarm-names $(terraform output -raw cloudwatch_alarm_name)
```

Kiem tra metric root login:

```powershell
aws cloudwatch get-metric-statistics `
  --region us-east-1 `
  --namespace Security `
  --metric-name RootAccountLoginCount `
  --statistics Sum `
  --period 300 `
  --start-time 2026-06-15T00:00:00Z `
  --end-time 2026-06-16T00:00:00Z
```

## Evidence

Bo evidence nay chung minh lab da hoat dong end-to-end: CloudTrail ghi log, CloudWatch Logs nhan log, Metric Filter tao metric, Alarm trigger, SNS da confirm va email alert da duoc gui.

### 1. CloudTrail dang logging

Anh nay cho thay trail `root-login-alert-lab-trail` da duoc tao va dang o trang thai `Logging`. Day la nguon event dau vao cua toan bo lab.

![CloudTrail logging](<./Evidence/CloudTrail logging.png>)

### 2. CloudWatch Log Group nhan CloudTrail logs

Anh nay cho thay log group `/aws/cloudtrail/root-login-alert-lab` da duoc tao, co retention 1 thang va co 1 metric filter. CloudTrail gui events vao log group nay de CloudWatch Logs co the filter.

![CloudWatch Log Group](<./Evidence/CloudWatch Log Group.png>)

### 3. Metric Filter bat root account activity

Anh nay cho thay metric filter `root-login-alert-lab-root-account-login` dang dung pattern:

```text
{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }
```

Metric duoc tao la `Security / RootAccountLoginCount` voi value `1`.

![Metric Filter root account](<./Evidence/Metric Filter root account.png>)

### 4. CloudWatch Alarm config

Anh nay cho thay alarm `root-login-alert-lab-root-account-login` dang o trang thai `In alarm`. Alarm dung namespace `Security`, metric `RootAccountLoginCount`, statistic `Sum`, period `5 minutes`, threshold `RootAccountLoginCount >= 1`.

![CloudWatch Alarm config](<./Evidence/CloudWatch Alarm config.png>)

### 5. Alarm action gui den SNS

Anh nay cho thay CloudWatch Alarm da bat action va se gui notification den SNS Topic `root-login-alert-lab-security-alerts` khi alarm chuyen sang `In alarm` va khi quay ve `OK`.

![SNS action](<./Evidence/SNS action.png>)

### 6. SNS subscription da confirmed

Anh nay cho thay SNS Topic `root-login-alert-lab-security-alerts` co email subscription `bnuochthithuy13032005@gmail.com` va trang thai `Confirmed`. Neu buoc nay chua confirmed thi email alert se khong duoc gui.

![SNS subscription confirmed](<./Evidence/SNS subscription confirmed.png>)

### 7. Email alert da nhan duoc

Anh nay la ket qua cuoi cung cua lab. Email tu `AWS Notifications <no-reply@sns.amazonaws.com>` xac nhan alarm `root-login-alert-lab-root-account-login` da chuyen `OK -> ALARM` vi metric `RootAccountLoginCount` vuot threshold.

![Email alert received](<./Evidence/Email alert received.png>)

## Ket luan

Lab da dat dung muc tieu cua bai `Hands-On: Alert on AWS Root Account Login`:

```text
Enable CloudTrail and send logs to CloudWatch
-> Create CloudWatch Metric Filter
-> Create CloudWatch Alarm
-> Notify via SNS email
```

Khi root account duoc su dung, CloudTrail ghi event, metric filter tao metric `RootAccountLoginCount`, CloudWatch Alarm vao `In alarm`, va SNS gui email canh bao den nguoi quan tri.

## Don dep

```powershell
terraform destroy
```

Luu y: `terraform.tfvars`, `terraform.tfstate`, `tfplan` va `.terraform/` chua thong tin moi truong rieng cua ban, khong nen commit len Git public.
