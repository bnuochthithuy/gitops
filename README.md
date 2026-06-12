# GitOps API Monitoring Email Alert

README này ghi lại cách cấu hình Alertmanager gửi email cá nhân khi API phát sinh alert từ Prometheus.

## Nộp bài

Checklist cần có khi nộp:

- Repo GitOps chứa đầy đủ manifest qua Git:
  - `Rollout` cho API canary.
  - `AnalysisTemplate` query Prometheus để quyết định promote hoặc abort.
  - `ServiceMonitor` để Prometheus scrape metric `/metrics`.
  - `PrometheusRule` cho SLO, recording rule và alert.
  - Cấu hình Alertmanager gửi email cá nhân.
- README giải thích rõ:
  - Query Prometheus dùng để tính success rate hoặc error rate.
  - Ngưỡng SLO đang dùng và lý do chọn ngưỡng.
  - Điều kiện nào làm rollout pass.
  - Điều kiện nào làm rollout auto-abort.
  - Cách alert được route sang email.
- Clip hoặc ảnh chứng minh:
  - Canary rollout bắt đầu chạy.
  - Version lỗi tạo HTTP 5xx.
  - AnalysisTemplate fail vì metric dưới ngưỡng.
  - Rollout tự động `Aborted`.
  - Stable version vẫn phục vụ traffic hoặc hệ thống rollback về bản ổn định.
  - Alert xuất hiện trong Prometheus/Alertmanager.
  - Email cảnh báo được gửi thành công.

## Manifest trong repo

Các file chính cần nộp đều nằm trong repo GitOps:

```text
k8s-api/api.yaml                         # Rollout API canary + Service
k8s-api/analysis.yaml                    # AnalysisTemplate query Prometheus
k8s-api/servicemonitor.yaml              # ServiceMonitor scrape /metrics
k8s-api/monitoring/prometheus-rule.yaml  # Recording rules + SLO alerts
argocd/apps/api.yaml                     # ArgoCD app cho API
argocd/apps/api-monitoring.yaml          # ArgoCD app cho monitoring rules
argocd/apps/kube-prometheus-stack.yaml   # Prometheus + Alertmanager stack
secrets/apply-alertmanager-secret.ps1    # Tạo Secret email local
secrets/.env.example                     # Mẫu cấu hình email, không chứa password thật
```

## Query và ngưỡng canary

`AnalysisTemplate` trong `k8s-api/analysis.yaml` dùng query:

```promql
sum(rate(flask_http_request_total{namespace="demo",status=~"5.."}[1m])) or vector(0)
```

Ý nghĩa:

- `flask_http_request_total` là metric HTTP request do Flask exporter expose tại `/metrics`.
- `status=~"5.."` chỉ lấy các request HTTP 5xx.
- `rate(...[1m])` tính tốc độ lỗi trong cửa sổ 1 phút gần nhất.
- `sum(...)` cộng lỗi từ tất cả pod API trong namespace `demo`.
- `or vector(0)` giúp query trả về `0` khi chưa có lỗi hoặc chưa có series phù hợp, tránh analysis fail vì dữ liệu rỗng.

Ngưỡng pass/fail:

```yaml
successCondition: result[0] < 0.01
interval: 15s
count: 3
failureLimit: 0
```

Điều kiện rollout pass là error rate nhỏ hơn `0.01`, tức thấp hơn 1%. Vì `failureLimit: 0`, chỉ cần một lần đo không đạt là `AnalysisRun` fail và rollout bị abort. Cách này phù hợp demo canary vì phản ứng nhanh khi version mới tạo lỗi 5xx.

Canary steps trong `k8s-api/api.yaml`:

```yaml
steps:
  - setWeight: 25
  - analysis:
      templates:
        - templateName: api-error-rate
  - setWeight: 50
  - pause:
      duration: 30s
  - setWeight: 100
```

Luồng này đưa canary lên 25%, chạy analysis, nếu metric đạt thì tiếp tục lên 50% và 100%. Nếu analysis fail, Argo Rollouts tự động dừng rollout ở revision lỗi và giữ stable ReplicaSet đang phục vụ traffic.

## Query và ngưỡng SLO alert

`PrometheusRule` trong `k8s-api/monitoring/prometheus-rule.yaml` có recording rule tính success rate 5 phút:

```promql
sum(rate(flask_http_request_total{namespace="demo", status!~"5.."}[5m]))
/
sum(rate(flask_http_request_total{namespace="demo"}[5m]))
```

Ý nghĩa:

- Mẫu số là tổng request API trong 5 phút.
- Tử số là request không phải HTTP 5xx.
- Kết quả là success rate của API.

Error budget remaining:

```promql
1 - (
  (1 - api:http_request_success_rate:5m)
  / (1 - 0.99)
)
```

SLO target là `99%`, nên allowed error rate là `1%`. Nếu API lỗi đúng 1%, error budget còn khoảng `0`. Nếu lỗi vượt 1%, error budget âm.

Alert `ApiSLOBreach` dùng query:

```promql
sum(rate(flask_http_request_total{namespace="demo", status=~"5.."}[5m]))
/
sum(rate(flask_http_request_total{namespace="demo"}[5m]))
> 0.01
```

Ngưỡng này bắn alert khi error rate 5xx lớn hơn `1%` liên tục `5m`.

Alert `ApiSLOErrorBudgetLow` dùng:

```promql
api:slo_error_budget_remaining < 0.5
```

Alert này cảnh báo khi error budget còn dưới 50% trong `2m`.

## Evidence

Thư mục `Evidence/` chứa ảnh chứng minh luồng GitOps, canary abort và alert:

| File | Nội dung chứng minh |
| --- | --- |
| `Evidence/argocd-app.png` | ArgoCD quản lý các app GitOps trong repo. |
| `Evidence/kube-prometheus-stack.png` | App `kube-prometheus-stack` được sync để cài Prometheus/Alertmanager. |
| `Evidence/api-monitoring.png` | App `api-monitoring` quản lý rule/API monitoring qua Git. |
| `Evidence/get-rollout.png` | Trạng thái rollout API trong namespace `demo`. |
| `Evidence/analysis-failed.png` | `AnalysisRun` fail vì metric `error-rate` vượt ngưỡng, query Prometheus trả value lỗi cao. |
| `Evidence/rollout-aborted.png` | Rollout API bị `Abort: true`, analysis status `Failed`, chứng minh canary auto-abort. |
| `Evidence/prometheus-alert.png` | Prometheus có alert API ở trạng thái firing. |
| `Evidence/ApiEmailTest-prometheus-alert.png` | Alert test email `ApiEmailTest` firing. |
| `Evidence/ApiSLOBreach-prometheus-alert.png` | Alert `ApiSLOBreach` firing khi error rate vượt 1%. |
| `Evidence/ApiSLOErrorBudgetLow-prometheus-alert.png` | Alert `ApiSLOErrorBudgetLow` firing khi error budget thấp. |
| `Evidence/smtp-error-log.png` | Alertmanager đã route alert vào receiver email nhưng Gmail SMTP trả `535 BadCredentials`. |

Kết luận từ evidence:

- Canary rollout đã chạy qua Argo Rollouts.
- Version lỗi tạo HTTP 5xx làm metric `error-rate` vượt ngưỡng.
- `AnalysisTemplate` fail vì `failureLimit: 0`.
- Rollout tự động chuyển sang trạng thái aborted.
- Prometheus tạo các alert SLO/API ở trạng thái firing.
- Alertmanager đã nhận và route alert tới receiver `personal-email`.

Lưu ý về email: `Evidence/smtp-error-log.png` hiện chứng minh Alertmanager đã thử gửi email nhưng Gmail từ chối xác thực SMTP với lỗi `535 5.7.8 Username and Password not accepted`. Để hoàn tất bằng chứng email thành công, cần sửa Gmail App Password trong `secrets/.env`, apply lại Secret, restart Alertmanager, rồi bổ sung ảnh inbox/email thành công, ví dụ:

```text
Evidence/alert-email.png
```

## Đối chiếu lệnh và evidence

Bảng này nối từng lệnh kiểm tra với kết quả cần thấy và ảnh evidence tương ứng.

| Bước | Lệnh kiểm tra | Kết quả chứng minh | Evidence |
| --- | --- | --- | --- |
| Kiểm tra ArgoCD app | `kubectl -n argocd get applications` | Các app GitOps được ArgoCD quản lý, gồm API, monitoring và kube-prometheus-stack. | `Evidence/argocd-app.png` |
| Kiểm tra kube-prometheus-stack | `kubectl -n argocd get application kube-prometheus-stack` | App monitoring stack tồn tại và được sync qua ArgoCD. | `Evidence/kube-prometheus-stack.png` |
| Kiểm tra app monitoring API | `kubectl -n argocd get application api-monitoring` | Rule và cấu hình API monitoring được quản lý qua Git. | `Evidence/api-monitoring.png` |
| Kiểm tra rollout API | `kubectl -n demo get rollout api` | Rollout `api` tồn tại, desired/current/up-to-date/available đều hiển thị. | `Evidence/get-rollout.png` |
| Kiểm tra AnalysisRun fail | `kubectl -n demo describe analysisrun <analysisrun-name>` | Metric `error-rate` failed vì value vượt ngưỡng, phase `Failed`. | `Evidence/analysis-failed.png` |
| Kiểm tra rollout auto-abort | `kubectl -n demo describe rollout api` | Rollout có `Abort: true`, analysis run status `Failed`, rollout bị pause/abort ở revision lỗi. | `Evidence/rollout-aborted.png` |
| Kiểm tra tổng quan alert Prometheus | Mở `http://localhost:9090/alerts` sau khi port-forward Prometheus | Prometheus hiển thị các alert API đang firing. | `Evidence/prometheus-alert.png` |
| Kiểm tra alert test email | `http://localhost:9090/alerts` -> `ApiEmailTest` | `ApiEmailTest` firing, dùng để test route email nhanh. | `Evidence/ApiEmailTest-prometheus-alert.png` |
| Kiểm tra SLO breach | `http://localhost:9090/alerts` -> `ApiSLOBreach` | `ApiSLOBreach` firing khi error rate 5xx lớn hơn 1% trong 5 phút. | `Evidence/ApiSLOBreach-prometheus-alert.png` |
| Kiểm tra error budget | `http://localhost:9090/alerts` -> `ApiSLOErrorBudgetLow` | `ApiSLOErrorBudgetLow` firing khi error budget còn dưới 50%. | `Evidence/ApiSLOErrorBudgetLow-prometheus-alert.png` |
| Kiểm tra Alertmanager gửi email | `kubectl -n monitoring logs pod/alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --tail=100` | Alertmanager đã route alert tới `personal-email`; hiện Gmail từ chối SMTP do `535 BadCredentials`. | `Evidence/smtp-error-log.png` |

Các lệnh port-forward để mở UI khi cần chụp evidence:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Sau đó mở:

```text
http://localhost:9090/alerts
http://localhost:9093
```

## Cơ chế hoạt động

Luồng cảnh báo:

```text
API /metrics
-> ServiceMonitor
-> Prometheus scrape metric
-> PrometheusRule tạo alert
-> Alertmanager nhận alert
-> Gmail SMTP gửi email
```

Các alert API hiện dùng labels:

```text
namespace=demo
service=api
team=api
```

Alertmanager route email match theo:

```yaml
namespace="demo"
alertname=~"Api.*"
```

Vì vậy các alert như `ApiEmailTest`, `ApiSLOBreach`, `ApiSLOErrorBudgetLow` đều được gửi vào receiver email cá nhân.

## Cấu hình email cá nhân

Tạo file `.env` từ file mẫu:

```powershell
cd D:\gitOps\gitops
Copy-Item .\secrets\.env.example .\secrets\.env
notepad .\secrets\.env
```

Nội dung cần điền:

```env
ALERT_EMAIL_TO=email-nhan@gmail.com
ALERT_EMAIL_FROM=email-gui@gmail.com
SMTP_SMARTHOST=smtp.gmail.com:587
SMTP_AUTH_USERNAME=email-gui@gmail.com
SMTP_AUTH_PASSWORD=app-password-gmail
```

Lưu ý:

- `SMTP_AUTH_PASSWORD` phải là Gmail App Password, không phải mật khẩu Gmail thường.
- Gmail gửi mail phải bật 2-Step Verification.
- `SMTP_AUTH_USERNAME` nên giống `ALERT_EMAIL_FROM`.
- Không commit file `secrets/.env` lên Git.

## Apply Secret Alertmanager

Sau khi sửa `.env`, chạy:

```powershell
cd D:\gitOps\gitops
.\secrets\apply-alertmanager-secret.ps1
```

Script này tạo Kubernetes Secret:

```text
namespace: monitoring
secret: alertmanager-private-config
key: alertmanager.yaml
```

Kiểm tra Secret:

```powershell
kubectl -n monitoring get secret alertmanager-private-config
```

## Sync ArgoCD

Nếu dùng ArgoCD UI, sync hai app:

```text
kube-prometheus-stack
api-monitoring
```

Nếu chỉ dùng `kubectl`, kiểm tra app:

```powershell
kubectl -n argocd get applications
```

Refresh app:

```powershell
kubectl -n argocd annotate application kube-prometheus-stack argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd annotate application api-monitoring argocd.argoproj.io/refresh=hard --overwrite
```

## Restart Alertmanager

Sau khi apply Secret, restart Alertmanager để đọc config mới:

```powershell
kubectl -n monitoring rollout restart statefulset alertmanager-kube-prometheus-stack-alertmanager
```

Chờ pod chạy lại:

```powershell
kubectl -n monitoring get pod alertmanager-kube-prometheus-stack-alertmanager-0
```

## Test Alert Email

Mở Prometheus:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Truy cập:

```text
http://localhost:9090/alerts
```

Kiểm tra các alert:

```text
ApiEmailTest
ApiSLOBreach
ApiSLOErrorBudgetLow
```

Nếu state là `firing`, Prometheus đã tạo alert thành công.

Mở Alertmanager:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Truy cập:

```text
http://localhost:9093
```

Nếu thấy alert trong Alertmanager, route đã nhận alert.

## Kiểm tra lỗi gửi mail

Xem log Alertmanager:

```powershell
kubectl -n monitoring logs pod/alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --tail=100
```

Lọc lỗi email:

```powershell
kubectl -n monitoring logs pod/alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --tail=200 | Select-String -Pattern "notify|email|smtp|failed|error|535|auth|password"
```

Nếu thấy lỗi:

```text
535 5.7.8 Username and Password not accepted
BadCredentials
```

Nguyên nhân là Gmail từ chối đăng nhập SMTP. Cách sửa:

1. Bật 2-Step Verification cho Gmail.
2. Tạo Gmail App Password mới.
3. Cập nhật `SMTP_AUTH_PASSWORD` trong `secrets/.env`.
4. Chạy lại:

```powershell
.\secrets\apply-alertmanager-secret.ps1
kubectl -n monitoring rollout restart statefulset alertmanager-kube-prometheus-stack-alertmanager
```

## Tạo lỗi 5xx để test SLO

Port-forward API:

```powershell
kubectl -n demo port-forward svc/api 8080:8080
```

Terminal khác chạy:

```powershell
for ($i=0; $i -lt 700; $i++) {
  curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:8080/
  Start-Sleep -Milliseconds 500
}
```

Sau đó chờ rule đủ thời gian `for`, rồi kiểm tra Prometheus Alerts.

## Tắt alert test sau khi kiểm tra

Sau khi email đã gửi thành công, nên tắt alert test để tránh gửi lặp lại.

Trong file:

```text
k8s-api/monitoring/prometheus-rule.yaml
```

Đổi:

```yaml
expr: vector(1)
```

thành:

```yaml
expr: vector(0)
```

Sau đó sync lại app `api-monitoring`.
