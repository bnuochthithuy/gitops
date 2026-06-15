# AWS CloudWatch Agent Lab

Lab nay cai CloudWatch Agent tren EC2, gan IAM Role co policy `CloudWatchAgentServerPolicy`, cau hinh Agent thu thap metric CPU, memory, disk, swap, disk I/O va kiem tra metric trong CloudWatch namespace `CWAgent`.

## Muc tieu

- Gan IAM Role cho EC2 de CloudWatch Agent co quyen day metric.
- Cai dat CloudWatch Agent tren EC2.
- Cau hinh Agent bang file JSON.
- Khoi dong va enable Agent.
- Kiem tra Agent chay thanh cong.
- Kiem tra metric trong CloudWatch `CWAgent`.

## EC2 dang dung

```text
Region: us-east-1
Instance ID: i-0349b4fa02b794fea
Public IPv4: 98.92.31.148
IAM Role hien co: EC2InstanceProfileRole
```

Instance nay co `KeyName = None`, nen khong dung SSH bang `.pem`. Hay vao EC2 bang AWS Console:

```text
EC2 -> Instances -> chon i-0349b4fa02b794fea -> Connect -> EC2 Instance Connect -> Connect
```

## Buoc 1: Gan quyen CloudWatch Agent cho IAM Role cua EC2

Tao file `terraform.tfvars` tu file mau:

```powershell
cd D:\gitOps\gitops\aws-cloudwatch-agent-lab
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
notepad .\terraform.tfvars
```

Noi dung dang dung:

```hcl
region                 = "us-east-1"
aws_profile            = "default"
ec2_instance_id        = "i-0349b4fa02b794fea"
existing_ec2_role_name = "EC2InstanceProfileRole"
```

Apply Terraform:

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Terraform se tao:

- Doc IAM Role hien co cua EC2: `EC2InstanceProfileRole`
- Attach AWS managed policy `CloudWatchAgentServerPolicy` vao role nay

EC2 hien da co instance profile `EC2InstanceProfileRole`, nen lab khong tao instance profile moi de tranh loi AWS chi cho mot instance profile tren moi EC2.

Kiem tra:

```powershell
terraform output
aws iam list-attached-role-policies --role-name EC2InstanceProfileRole
```

## Buoc 2: Cai CloudWatch Agent tren EC2

Mo terminal vao EC2 bang `EC2 Instance Connect`.

Amazon Linux 2023:

```bash
sudo dnf install -y amazon-cloudwatch-agent
```

Amazon Linux 2:

```bash
sudo yum install -y amazon-cloudwatch-agent
```

Ubuntu:

```bash
sudo apt update
sudo apt install -y amazon-cloudwatch-agent
```

Kiem tra da cai thanh cong:

```bash
amazon-cloudwatch-agent-ctl -h
```

Neu EC2 dung RPM package, co the kiem tra them:

```bash
rpm -qa | grep cloudwatch
```

## Buoc 3: Tao file cau hinh Agent

Trong EC2, tao file:

```bash
sudo vi /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

Dan noi dung tu file trong repo:

```text
aws-cloudwatch-agent-lab/amazon-cloudwatch-agent.json
```

File nay cau hinh Agent thu thap:

- CPU: `cpu_usage_idle`, `cpu_usage_iowait`, `cpu_usage_user`, `cpu_usage_system`
- Memory: `mem_used_percent`
- Disk: `used_percent`
- Swap: `swap_used_percent`
- Disk I/O: `io_time`, `write_bytes`, `read_bytes`, `writes`, `reads`

## Buoc 4: Khoi dong Agent

Nap config va start Agent:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
```

Bat Agent tu dong chay khi EC2 reboot:

```bash
sudo systemctl enable amazon-cloudwatch-agent
```

Kiem tra service:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

Ket qua dung can thay:

```text
Active: active (running)
```

## Buoc 5: Kiem tra bang lenh Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

Ket qua thanh cong co dang:

```json
{
  "status": "running",
  "starttime": "2026-06-12T10:30:00Z",
  "configstatus": "configured"
}
```

Y nghia:

- `running`: Agent dang hoat dong.
- `configured`: Agent da doc file cau hinh hop le.

## Buoc 6: Kiem tra tren AWS Console

Vao:

```text
CloudWatch -> Metrics -> All metrics -> CWAgent
```

Can thay cac metric nhu:

- `mem_used_percent`
- `disk_used_percent`
- `swap_used_percent`
- `cpu_usage_user`
- `cpu_usage_system`
- `diskio_reads`
- `diskio_writes`

Neu metric xuat hien trong namespace `CWAgent`, CloudWatch Agent da gui du lieu len CloudWatch thanh cong.

## Evidence can chup

Can chup cac hinh sau:

1. EC2 da gan IAM Role:

```text
EC2 -> Instances -> chon instance -> Security -> IAM role = EC2InstanceProfileRole
```

2. IAM Role co policy CloudWatch Agent:

```text
IAM -> Roles -> EC2InstanceProfileRole -> Permissions -> CloudWatchAgentServerPolicy
```

3. Terraform apply thanh cong:

```text
Outputs hien role name va instance id
```

4. CloudWatch Agent da cai:

```bash
amazon-cloudwatch-agent-ctl -h
```

5. Service dang chay:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

Can thay `Active: active (running)`.

6. Agent status:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

Can thay `status: running` va `configstatus: configured`.

7. Metric tren CloudWatch:

```text
CloudWatch -> Metrics -> CWAgent
```

Chup metric memory/disk/CPU custom da xuat hien.

## Don dep

Neu muon go policy attachment do lab tao:

```powershell
terraform destroy
```

Luu y: chi destroy sau khi khong can Agent lab nua, vi lenh nay se go `CloudWatchAgentServerPolicy` khoi role `EC2InstanceProfileRole`.
