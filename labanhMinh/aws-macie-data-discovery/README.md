# AWS Macie Data Discovery & Alerts Lab

Lab nay trien khai he thong tu dong phat hien du lieu nhay cam tren Amazon S3 va gui canh bao thoi gian thuc qua email bang cach ket hop Amazon Macie, EventBridge va SNS.

## Kien truc

```
sensitive-data.txt
      │
      ▼
   S3 Bucket
      │  (Macie scans)
      ▼
Amazon Macie ──► Macie Finding
                      │
                      ▼
              Amazon EventBridge
              (source: aws.macie)
              (detail-type: Macie Finding)
                      │
                      ▼
              Amazon SNS Topic
              (Macie-Alerts-Topic)
                      │
                      ▼
               Email Notification
```

## Tai nguyen Terraform tao ra

| Tai nguyen | Ten |
|---|---|
| S3 Bucket | `macie-data-discovery-<account_id>` |
| S3 Object | `sensitive-data.txt` |
| SNS Topic | `Macie-Alerts-Topic` |
| SNS Subscription | Email dang ky |
| Macie Account | Bat Macie tai ap-southeast-1 |
| Macie Classification Job | `macie-data-discovery-scan-job` (One-time) |
| EventBridge Rule | `macie-data-discovery-findings-rule` |
| EventBridge Target | SNS Topic |

## Buoc 1: Chuan bi

Tao file `terraform.tfvars` tu file mau:

```powershell
cd D:\gitOps\gitops\labanhMinh\aws-macie-data-discovery
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
notepad .\terraform.tfvars
```

Sua `alert_email` thanh email thuc cua ban:

```hcl
region       = "ap-southeast-1"
aws_profile  = "default"
alert_email  = "your-email@example.com"
```

## Buoc 2: Deploy bang Terraform

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Terraform se tao toan bo kien truc trong mot lan apply.

## Buoc 3: Xac nhan email SNS (bat buoc)

Sau khi apply xong:

1. Mo hop thu email da dang ky.
2. Tim email tieu de: **AWS Notification - Subscription Confirmation**.
3. Nhan vao link **Confirm subscription**.
4. Trang web hien thi: `Subscription confirmed!`

**Quan trong**: Neu khong confirm, SNS se khong gui email canh bao.

## Buoc 4: Theo doi Macie Job

Vao AWS Console:

```
Amazon Macie -> Jobs -> chon job "macie-data-discovery-scan-job"
```

Job co trang thai:
- `Active` / `Running`: dang quet
- `Complete`: da quet xong, co the xem Findings

Thoi gian chay thuong tu 5 den 15 phut.

## Buoc 5: Xem Findings tren Macie Console

```
Amazon Macie -> Findings
```

Can thay findings voi:
- **Finding type**: `SensitiveData:S3Object/Personal` hoac `SensitiveData:S3Object/Financial`
- **Severity**: High
- **Resource**: ten S3 bucket va file `sensitive-data.txt`

Nhan vao tung Finding de xem chi tiet loai du lieu nhay cam duoc phat hien (SSN, Credit Card, v.v.).

## Buoc 6: Kiem tra email canh bao

Sau khi Macie tao ra Findings, EventBridge bat su kien va gui qua SNS.

Kiem tra email dang ky. Nhan duoc email chua payload JSON dang:

```json
{
  "version": "0",
  "id": "...",
  "source": "aws.macie",
  "detail-type": "Macie Finding",
  "detail": {
    "severity": { "description": "High" },
    "type": "SensitiveData:S3Object/Personal",
    "resourcesAffected": {
      "s3Bucket": { "name": "macie-data-discovery-..." },
      "s3Object": { "key": "sensitive-data.txt" }
    }
  }
}
```

## Don dep sau lab

```powershell
terraform destroy
```

Luu y: `terraform destroy` se:
- Tat Amazon Macie (co the mat phi neu bat lai)
- Xoa S3 bucket va file du lieu
- Xoa SNS topic va subscription
- Xoa EventBridge rule

## Evidence can chup

| # | Noi dung | Vi tri chup |
|---|---|---|
| 1 | SNS Subscription da Confirmed | SNS -> Subscriptions -> Status = Confirmed |
| 2 | Macie Job trang thai Complete | Macie -> Jobs |
| 3 | Macie Findings hien thi SensitiveData:S3Object/Personal | Macie -> Findings |
| 4 | Chi tiet Finding (SSN, Credit Card) | Nhan vao tung Finding |
| 5 | EventBridge Rule da tao | EventBridge -> Rules |
| 6 | Email canh bao nhan duoc (tong quan) | Hop thu email |
| 7 | Email canh bao noi dung JSON chi tiet | Hop thu email |

## Ghi chu

- File `sensitive-data.txt` chua du lieu gia lap hoan toan (SSN, Credit Card, Passport) de Macie nhan dien. Khong phai du lieu that.
- Region su dung: `ap-southeast-1` (Singapore) theo yeu cau bai lab.
- Macie co mien phi 30 ngay dau tien khi bat lan dau. Sau do co phi theo so luong object duoc quet.
