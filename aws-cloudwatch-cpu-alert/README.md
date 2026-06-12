# AWS CloudWatch EC2 CPU Email Alert Lab

Lab nay tao SNS Topic, dang ky email nhan canh bao, va tao CloudWatch Alarm cho EC2 khi CPU vuot 80% trong 5 phut.

## Kien truc

```text
EC2 CPUUtilization metric
    -> CloudWatch Alarm: CPU > 80%, period 300s, evaluation 1/1
    -> SNS Topic
    -> Email subscription
    -> Quan tri vien nhan email canh bao
```

## Tai nguyen duoc tao

- `aws_sns_topic.cpu_alerts`: SNS Topic nhan tin hieu canh bao.
- `aws_sns_topic_subscription.email`: dang ky email nhan thong bao.
- `aws_cloudwatch_metric_alarm.ec2_cpu_high`: alarm theo doi metric `AWS/EC2 CPUUtilization`.

## Chay lab

Tao file cau hinh tu file mau:

```powershell
cd D:\gitOps\gitops\aws-cloudwatch-cpu-alert
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
notepad .\terraform.tfvars
```

Sua cac gia tri bat buoc:

```hcl
region             = "us-west-2"
aws_profile        = "default"
ec2_instance_id    = "i-xxxxxxxxxxxxxxxxx"
notification_email = "email-cua-ban@example.com"
```

Apply Terraform:

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Sau khi apply, mo email va bam link `Confirm subscription` cua AWS SNS. Neu chua confirm, SNS se khong gui email canh bao.

## Cau hinh Alarm

Alarm dang dung cau hinh dung voi yeu cau lab:

- Metric: `AWS/EC2 CPUUtilization`
- Dimension: `InstanceId = var.ec2_instance_id`
- Statistic: `Average`
- Dieu kien: `GreaterThanThreshold`
- Threshold: `80`
- Period: `300` giay, tuc 5 phut
- Evaluation: `1 out of 1`
- Alarm action: gui den SNS Topic
- OK action: gui email khi trang thai tro lai `OK`

## Kiem tra bang cach tao CPU load

SSH vao EC2 can monitor, cai cong cu stress va tao tai CPU.

Amazon Linux 2023:

```bash
sudo dnf install -y stress-ng
stress-ng --cpu 2 --timeout 420s --metrics-brief
```

Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y stress-ng
stress-ng --cpu 2 --timeout 420s --metrics-brief
```

Cho hon 5 phut de CloudWatch nhan du metric. Khi CPU trung binh vuot 80%, alarm chuyen sang `ALARM` va SNS gui email. Khi dung stress va CPU giam lai, alarm se chuyen ve `OK` va gui email neu `send_ok_notification = true`.

## Lenh kiem tra

Xem output Terraform:

```powershell
terraform output
```

Kiem tra subscription da confirm hay chua:

```powershell
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)
```

Kiem tra trang thai alarm:

```powershell
aws cloudwatch describe-alarms --alarm-names $(terraform output -raw cloudwatch_alarm_name)
```

## Don dep

```powershell
terraform destroy
```

Luu y: file `terraform.tfvars` chua email va instance id rieng cua ban, khong nen commit file nay len Git.
