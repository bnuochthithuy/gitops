# W9 Lab System Design

## 1. Mục Tiêu Hệ Thống

Lab này mô phỏng một pipeline triển khai ứng dụng trên Kubernetes theo mô hình GitOps. Toàn bộ trạng thái mong muốn của hệ thống được khai báo trong Git, sau đó ArgoCD đồng bộ vào cluster.

Mục tiêu chính:

- Quản lý workload Kubernetes bằng GitOps.
- Dùng ArgoCD App-of-Apps để quản lý nhiều application con.
- Dùng Argo Rollouts để triển khai API theo canary.
- Dùng Prometheus để đo metric runtime thật từ API.
- Dùng AnalysisTemplate để tự động quyết định canary pass hoặc abort.
- Dùng PrometheusRule để tạo SLO alert.
- Dùng Alertmanager để route alert sang email cá nhân.
- Không commit SMTP password thật vào Git, chỉ tạo Secret local từ `.env`.

Điểm quan trọng của lab: Git là source of truth, Kubernetes là môi trường chạy workload, ArgoCD là controller reconcile, Argo Rollouts là controller release, Prometheus là nguồn dữ liệu đánh giá, Alertmanager là lớp gửi cảnh báo.

## 2. Kiến Trúc Tổng Thể

Các namespace/thành phần chính:

- `argocd`: chứa ArgoCD và các `Application`.
- `demo`: chứa web demo và API canary.
- `shop`: chứa ứng dụng shop frontend/backend.
- `monitoring`: chứa kube-prometheus-stack gồm Prometheus, Alertmanager, Grafana và Prometheus Operator.
- `argo-rollouts`: chứa Argo Rollouts controller.

Luồng hoạt động:

1. Người dùng sửa manifest trong repo.
2. Commit và push lên branch `main`.
3. ArgoCD đọc repo remote và phát hiện thay đổi.
4. ArgoCD sync manifest vào cluster.
5. Với API, Argo Rollouts điều khiển rollout canary.
6. API expose metric qua `/metrics`.
7. Prometheus scrape metric bằng `ServiceMonitor`.
8. `AnalysisTemplate` query Prometheus để kiểm tra error rate.
9. Nếu metric đạt ngưỡng, rollout tiếp tục promote.
10. Nếu metric vượt ngưỡng, rollout bị abort.
11. `PrometheusRule` tạo alert khi SLO bị vi phạm.
12. Alertmanager route alert tới email cá nhân qua SMTP.

## 3. Vì Sao Chọn GitOps

GitOps giúp mọi thay đổi có lịch sử commit, diff và rollback rõ ràng. Nếu sửa trực tiếp bằng `kubectl`, trạng thái live trong cluster dễ bị lệch so với mong muốn và khó audit.

Trong lab này, ArgoCD chỉ đọc repo remote:

```text
https://github.com/bnuochthithuy/gitops.git
```

Vì vậy, sửa file local chưa đủ. Muốn ArgoCD thấy thay đổi, manifest phải được commit và push lên branch mà ArgoCD đang theo dõi.

## 4. ArgoCD App-of-Apps

Root application:

```text
argocd/root.yaml
```

Root app trỏ tới:

```text
argocd/apps
```

Các application con:

```text
argocd/apps/web.yaml
argocd/apps/shop.yaml
argocd/apps/api.yaml
argocd/apps/api-monitoring.yaml
argocd/apps/argo-rollouts.yaml
argocd/apps/kube-prometheus-stack.yaml
```

Root app bật:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Ý nghĩa:

- `automated`: ArgoCD tự sync khi Git thay đổi.
- `prune`: resource bị xóa khỏi Git sẽ bị xóa khỏi cluster.
- `selfHeal`: nếu live state bị sửa tay, ArgoCD đưa về đúng manifest trong Git.

## 5. Các Application Con

### 5.1 App `web`

File:

```text
argocd/apps/web.yaml
```

Source path:

```text
k8s
```

Destination namespace:

```text
demo
```

App này triển khai web demo cơ bản bằng manifest trong `k8s/`.

### 5.2 App `shop`

File:

```text
argocd/apps/shop.yaml
```

Source path:

```text
shop
```

Destination namespace:

```text
shop
```

App này triển khai frontend/backend shop.

### 5.3 App `api`

File:

```text
argocd/apps/api.yaml
```

Source path:

```text
k8s-api
```

Destination namespace:

```text
demo
```

App này chứa:

- `Rollout/api`
- `Service/api`
- `AnalysisTemplate/api-error-rate`
- `ServiceMonitor/api`

`ServerSideApply=true` được bật để apply ổn định hơn với CRD như `Rollout`, `AnalysisTemplate` và `ServiceMonitor`.

### 5.4 App `api-monitoring`

File:

```text
argocd/apps/api-monitoring.yaml
```

Source path:

```text
k8s-api/monitoring
```

Destination namespace:

```text
monitoring
```

App này quản lý `PrometheusRule` cho API SLO và alert email test.

### 5.5 App `argo-rollouts`

File:

```text
argocd/apps/argo-rollouts.yaml
```

Helm chart:

```text
repo: https://argoproj.github.io/argo-helm
chart: argo-rollouts
version: 2.37.7
```

App này cài controller xử lý `Rollout`, `AnalysisTemplate` và `AnalysisRun`.

### 5.6 App `kube-prometheus-stack`

File:

```text
argocd/apps/kube-prometheus-stack.yaml
```

Helm chart:

```text
repo: https://prometheus-community.github.io/helm-charts
chart: kube-prometheus-stack
version: 65.1.1
```

Setting quan trọng:

```yaml
alertmanager:
  alertmanagerSpec:
    useExistingSecret: true
    configSecret: alertmanager-private-config
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    ruleSelectorNilUsesHelmValues: false
    ruleNamespaceSelector: {}
```

Ý nghĩa:

- Alertmanager đọc config từ Secret local `alertmanager-private-config`.
- Prometheus có thể đọc `ServiceMonitor` và `PrometheusRule` ở nhiều namespace.
- API nằm ở namespace `demo`, còn Prometheus nằm ở `monitoring`, nên `serviceMonitorNamespaceSelector` và `ruleNamespaceSelector` cần mở.

## 6. API Canary Với Argo Rollouts

Manifest:

```text
k8s-api/api.yaml
```

Resource chính:

- `Rollout/api`
- `Service/api`

Cấu hình API:

```yaml
replicas: 4
image: w9-api:4
ERROR_RATE: "100"
VERSION: "v3"
```

`ERROR_RATE` là biến môi trường điều khiển lỗi giả lập. Trong app Python:

```python
if random.random() < ERR:
    return jsonify(error="injected", version=VER), 500
```

Khi `ERROR_RATE` cao, API trả nhiều HTTP 500 để test canary abort và SLO alert.

Canary steps:

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

Luồng:

1. Đưa canary lên 25%.
2. Chạy analysis `api-error-rate`.
3. Nếu analysis pass, rollout tiếp tục lên 50%.
4. Nếu analysis fail, rollout bị abort và revision lỗi không được promote.

## 7. API Demo App

Source app:

```text
app/app.py
```

Ứng dụng dùng:

- Flask
- `prometheus_flask_exporter`
- Env `ERROR_RATE`
- Env `VERSION`

Endpoint:

- `/`: trả JSON OK hoặc HTTP 500 giả lập.
- `/healthz`: readiness probe.
- `/metrics`: metric Prometheus do exporter expose.

Metric chính:

```text
flask_http_request_total
```

Metric này có label HTTP status, nên Prometheus có thể tính request 5xx, success rate và error budget.

## 8. ServiceMonitor

Manifest:

```text
k8s-api/servicemonitor.yaml
```

Cấu hình:

```yaml
selector:
  matchLabels:
    app: api
endpoints:
  - port: http
    path: /metrics
    interval: 15s
```

ServiceMonitor khai báo cho Prometheus Operator biết phải scrape service `app=api` ở path `/metrics` mỗi 15 giây.

## 9. AnalysisTemplate

Manifest:

```text
k8s-api/analysis.yaml
```

Metric:

```yaml
name: error-rate
interval: 15s
count: 3
failureLimit: 0
successCondition: result[0] < 0.01
```

Query:

```promql
sum(rate(flask_http_request_total{namespace="demo",status=~"5.."}[1m])) or vector(0)
```

Ý nghĩa:

- `status=~"5.."`: chỉ lấy HTTP 5xx.
- `[1m]`: đo trong cửa sổ 1 phút.
- `sum(rate(...))`: tính tốc độ lỗi của toàn bộ pod API.
- `or vector(0)`: tránh query rỗng khi chưa có series lỗi.

Ngưỡng:

- Pass nếu kết quả nhỏ hơn `0.01`.
- Fail nếu kết quả từ `0.01` trở lên.
- `failureLimit: 0` nghĩa là chỉ cần một lần fail là rollout abort.

Thiết kế này ưu tiên demo nhanh: version lỗi sẽ bị chặn ngay khi Prometheus thấy 5xx tăng.

## 10. PrometheusRule Và SLO

Manifest:

```text
k8s-api/monitoring/prometheus-rule.yaml
```

### 10.1 Recording Rule Success Rate

```promql
sum(rate(flask_http_request_total{namespace="demo", status!~"5.."}[5m]))
/
sum(rate(flask_http_request_total{namespace="demo"}[5m]))
```

Ý nghĩa:

- Tử số: request không phải HTTP 5xx.
- Mẫu số: tổng request.
- Kết quả: success rate API trong 5 phút.

### 10.2 Error Budget Remaining

```promql
1 - (
  (1 - api:http_request_success_rate:5m)
  / (1 - 0.99)
)
```

SLO target là 99%, nên allowed error rate là 1%.

- Error rate đúng 1% thì budget gần `0`.
- Error rate dưới 1% thì budget còn dương.
- Error rate vượt 1% thì budget âm.

### 10.3 Alert `ApiEmailTest`

```yaml
alert: ApiEmailTest
expr: vector(1)
for: 30s
```

Alert này luôn firing sau 30 giây, dùng để test route email nhanh.

Sau khi test xong nên đổi:

```yaml
expr: vector(0)
```

### 10.4 Alert `ApiSLOBreach`

```promql
sum(rate(flask_http_request_total{namespace="demo", status=~"5.."}[5m]))
/
sum(rate(flask_http_request_total{namespace="demo"}[5m]))
> 0.01
```

Alert firing khi error rate 5xx lớn hơn 1% liên tục 5 phút.

Labels quan trọng:

```yaml
namespace: demo
service: api
severity: critical
team: api
```

### 10.5 Alert `ApiSLOErrorBudgetLow`

```promql
api:slo_error_budget_remaining < 0.5
```

Alert firing khi error budget còn dưới 50% trong 2 phút.

## 11. Alertmanager Và Email Cá Nhân

Script tạo Secret:

```text
secrets/apply-alertmanager-secret.ps1
```

File mẫu:

```text
secrets/.env.example
```

File thật không commit:

```text
secrets/.env
```

Các biến cần có:

```env
ALERT_EMAIL_TO=email-nhan@gmail.com
ALERT_EMAIL_FROM=email-gui@gmail.com
SMTP_SMARTHOST=smtp.gmail.com:587
SMTP_AUTH_USERNAME=email-gui@gmail.com
SMTP_AUTH_PASSWORD=app-password-gmail
```

Script tạo Secret:

```text
monitoring/alertmanager-private-config
```

Secret chứa key:

```text
alertmanager.yaml
```

Route Alertmanager:

```yaml
route:
  receiver: 'null'
  routes:
    - receiver: personal-email
      matchers:
        - namespace="demo"
        - alertname=~"Api.*"
receivers:
  - name: 'null'
  - name: personal-email
    email_configs:
      - smarthost: smtp.gmail.com:587
```

Default receiver là `null` để tránh spam email bởi alert hệ thống khác. Chỉ alert trong namespace `demo` và tên bắt đầu bằng `Api` mới được gửi email.

## 12. Luồng Auto-Abort Và Rollback

Khi version lỗi được deploy:

1. Rollout tạo revision mới.
2. Canary nhận 25% traffic.
3. API trả HTTP 500 do `ERROR_RATE` cao.
4. Prometheus scrape metric `flask_http_request_total`.
5. `AnalysisTemplate` query error rate.
6. Query trả value vượt ngưỡng `0.01`.
7. `AnalysisRun` fail.
8. Argo Rollouts abort rollout.
9. Revision lỗi không được promote lên 100%.
10. Stable ReplicaSet tiếp tục phục vụ traffic.

Evidence tương ứng:

```text
Evidence/analysis-failed.png
Evidence/rollout-aborted.png
Evidence/get-rollout.png
```

## 13. Luồng Alert Email

Khi API lỗi vượt SLO:

1. Prometheus đánh giá `PrometheusRule`.
2. `ApiSLOBreach` hoặc `ApiSLOErrorBudgetLow` chuyển sang `firing`.
3. Prometheus gửi alert sang Alertmanager.
4. Alertmanager match route:

```yaml
namespace="demo"
alertname=~"Api.*"
```

5. Alertmanager gửi SMTP qua Gmail.

Evidence hiện có:

```text
Evidence/ApiEmailTest-prometheus-alert.png
Evidence/ApiSLOBreach-prometheus-alert.png
Evidence/ApiSLOErrorBudgetLow-prometheus-alert.png
Evidence/smtp-error-log.png
```

Log hiện tại cho thấy Alertmanager đã route đúng nhưng Gmail trả:

```text
535 5.7.8 Username and Password not accepted
BadCredentials
```

Điều này không phải lỗi Prometheus hoặc routing. Đây là lỗi credential Gmail/App Password.

## 14. Cách Test Hệ Thống

### 14.1 Kiểm tra ArgoCD apps

```powershell
kubectl -n argocd get applications
```

### 14.2 Kiểm tra Rollout

```powershell
kubectl -n demo get rollout api
kubectl -n demo describe rollout api
```

### 14.3 Kiểm tra AnalysisRun

```powershell
kubectl -n demo get analysisrun
kubectl -n demo describe analysisrun <analysisrun-name>
```

### 14.4 Kiểm tra Prometheus alerts

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Mở:

```text
http://localhost:9090/alerts
```

### 14.5 Kiểm tra Alertmanager

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Mở:

```text
http://localhost:9093
```

### 14.6 Kiểm tra log email

```powershell
kubectl -n monitoring logs pod/alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --tail=100
```

## 15. Lỗi Thường Gặp

### 15.1 Alert firing nhưng không có email

Nếu log có:

```text
535 5.7.8 Username and Password not accepted
BadCredentials
```

Nguyên nhân là Gmail từ chối SMTP. Cách sửa:

1. Bật 2-Step Verification cho Gmail.
2. Tạo Gmail App Password mới.
3. Cập nhật `SMTP_AUTH_PASSWORD` trong `secrets/.env`.
4. Apply lại Secret:

```powershell
.\secrets\apply-alertmanager-secret.ps1
```

5. Restart Alertmanager:

```powershell
kubectl -n monitoring rollout restart statefulset alertmanager-kube-prometheus-stack-alertmanager
```

### 15.2 ArgoCD OutOfSync

Nguyên nhân thường gặp:

- File local đã sửa nhưng chưa push lên Git.
- ArgoCD chưa refresh.
- CRD/controller mutate field.
- App con chưa sync theo thứ tự mong muốn.

Kiểm tra:

```powershell
kubectl -n argocd get applications
```

### 15.3 Prometheus không thấy metric API

Kiểm tra:

```powershell
kubectl -n demo get servicemonitor api
kubectl -n demo get svc api
```

Prometheus query:

```promql
flask_http_request_total{namespace="demo"}
```

Nếu không có dữ liệu, cần tạo traffic vào endpoint `/` của API.

## 16. Trade-off Hiện Tại

Điểm mạnh:

- Có GitOps App-of-Apps.
- Có canary rollout bằng Argo Rollouts.
- Có analysis tự động dựa trên Prometheus.
- Có SLO alert và email routing.
- Không commit password thật vào Git.
- Có evidence cho auto-abort và alert firing.

Điểm chưa production-grade:

- Secret email dùng `.env` local và script thủ công, chưa dùng External Secrets/SOPS/Sealed Secrets.
- Image `w9-api:4` là image lab/local, chưa có registry immutable tag.
- Alert email đang phụ thuộc Gmail App Password cá nhân.
- `ApiEmailTest` đang dùng `vector(1)`, nên cần tắt sau khi test để tránh gửi lặp.
- Evidence email hiện là SMTP error log; cần thêm ảnh email thành công sau khi credential hợp lệ.

## 17. Kết Luận

Hệ thống trong repo này thể hiện đầy đủ pipeline GitOps cho API canary:

```text
Git -> ArgoCD -> Argo Rollouts -> Prometheus -> AnalysisTemplate -> PrometheusRule -> Alertmanager
```

Khi version lỗi tạo nhiều HTTP 5xx, Prometheus ghi nhận metric, AnalysisTemplate fail, Argo Rollouts tự động abort rollout, PrometheusRule tạo alert và Alertmanager route alert sang email cá nhân.

Các file `README.md`, `evidence.md` và `system.md` bổ trợ nhau:

- `README.md`: cách chạy, query/ngưỡng và hướng dẫn test.
- `evidence.md`: ảnh chứng minh từng bước.
- `system.md`: thiết kế hệ thống và lý do chọn từng thành phần.
