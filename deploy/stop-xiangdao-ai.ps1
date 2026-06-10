$ErrorActionPreference = "Stop"

$InstallRoot = "__INSTALL_ROOT__"
$DeployRoot = Join-Path $InstallRoot "deploy"
$docker = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"

Get-Process | Where-Object { $_.ProcessName -like "*Xiangdao*" -or $_.ProcessName -like "*Duix*" } | Stop-Process -Force -ErrorAction SilentlyContinue

if ((Test-Path $docker) -and (Test-Path $DeployRoot)) {
  Push-Location $DeployRoot
  try {
    & $docker compose -f .\docker-compose.yml down | Out-Null
  } finally {
    Pop-Location
  }
}

