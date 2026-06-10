$ErrorActionPreference = "Stop"

$InstallRoot = "__INSTALL_ROOT__"
$DeployRoot = Join-Path $InstallRoot "deploy"
$AppCandidates = @(
  "$env:ProgramFiles\向导AI\XiangdaoAI.exe",
  "$env:LOCALAPPDATA\Programs\向导AI\XiangdaoAI.exe",
  "D:\duix_avatar_data\DuixAvatarApp\Duix.Avatar.exe"
)

$docker = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
if (-not (Test-Path $docker)) {
  throw "未检测到 Docker Desktop，请先运行一键部署器完成安装。"
}

$highPerformance = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg /setactive $highPerformance *> $null

$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;C:\Program Files\Docker\cli-plugins;$env:PATH"
& $docker desktop start | Out-Null

$deadline = (Get-Date).AddMinutes(8)
do {
  Start-Sleep -Seconds 5
  & $docker info *> $null
  $ready = $LASTEXITCODE -eq 0
} until ($ready -or (Get-Date) -gt $deadline)
if (-not $ready) {
  throw "Docker Desktop 未在限定时间内启动完成。"
}

Get-Process | Where-Object { $_.ProcessName -match "Docker|docker|com\.docker|vmmem" } | ForEach-Object {
  try { $_.PriorityClass = "High" } catch {}
}

Push-Location $DeployRoot
try {
  & $docker compose -f .\docker-compose.yml up -d | Out-Null
} finally {
  Pop-Location
}

foreach ($port in @(8383, 18180, 10095)) {
  $deadline = (Get-Date).AddMinutes(5)
  do {
    Start-Sleep -Seconds 3
    $ok = Test-NetConnection 127.0.0.1 -Port $port -InformationLevel Quiet
  } until ($ok -or (Get-Date) -gt $deadline)
}

$app = $AppCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $app) {
  throw "未找到向导AI客户端，请重新运行一键部署器。"
}

Start-Process -FilePath $app

