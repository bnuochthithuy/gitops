param(
  [string]$EnvFile = "$PSScriptRoot\.env",
  [string]$Namespace = "monitoring",
  [string]$SecretName = "alertmanager-private-config"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
  param([string]$Path)

  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) {
      continue
    }

    $parts = $trimmed -split "=", 2
    if ($parts.Count -ne 2) {
      continue
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")
    $values[$key] = $value
  }

  return $values
}

function Get-ConfigValue {
  param(
    [hashtable]$DotEnv,
    [string]$Name,
    [switch]$Required
  )

  $value = [Environment]::GetEnvironmentVariable($Name)
  if (-not $value -and $DotEnv.ContainsKey($Name)) {
    $value = $DotEnv[$Name]
  }

  if ($Required -and -not $value) {
    throw "Missing required value: $Name. Set it in $EnvFile or as an environment variable."
  }

  return $value
}

function Quote-Yaml {
  param([string]$Value)
  return "'" + ($Value -replace "'", "''") + "'"
}

$dotenv = Read-DotEnv -Path $EnvFile

$to = Get-ConfigValue -DotEnv $dotenv -Name "ALERT_EMAIL_TO" -Required
$from = Get-ConfigValue -DotEnv $dotenv -Name "ALERT_EMAIL_FROM" -Required
$smarthost = Get-ConfigValue -DotEnv $dotenv -Name "SMTP_SMARTHOST" -Required
$username = Get-ConfigValue -DotEnv $dotenv -Name "SMTP_AUTH_USERNAME" -Required
$password = Get-ConfigValue -DotEnv $dotenv -Name "SMTP_AUTH_PASSWORD" -Required

$alertmanagerConfig = @"
global:
  resolve_timeout: 5m
route:
  receiver: 'null'
  group_by:
    - alertname
    - namespace
    - service
  group_wait: 15s
  group_interval: 1m
  repeat_interval: 30m
  routes:
    - receiver: personal-email
      matchers:
        - namespace="demo"
        - alertname=~"Api.*"
receivers:
  - name: 'null'
  - name: personal-email
    email_configs:
      - to: $(Quote-Yaml $to)
        from: $(Quote-Yaml $from)
        smarthost: $(Quote-Yaml $smarthost)
        auth_username: $(Quote-Yaml $username)
        auth_password: $(Quote-Yaml $password)
        require_tls: true
        send_resolved: true
"@

$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ("alertmanager-secret-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
  $configPath = Join-Path $tmpDir "alertmanager.yaml"
  Set-Content -LiteralPath $configPath -Value $alertmanagerConfig -Encoding UTF8

  kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n $Namespace create secret generic $SecretName `
    --from-file=alertmanager.yaml=$configPath `
    --dry-run=client -o yaml | kubectl apply -f -

  Write-Host "Applied Secret $Namespace/$SecretName from $EnvFile"
}
finally {
  Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
