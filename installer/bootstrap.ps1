param(
  [string]$RepoOwner = "YOUR_GITHUB_OWNER",
  [string]$RepoName = "xiangdao-ai-avatar-delivery",
  [string]$Branch = "main",
  [string]$InstallRoot = "",
  [switch]$LocalAssets
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Warn($Message) {
  Write-Host "!! $Message" -ForegroundColor Yellow
}

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run the installer as Administrator."
  }
}

function Invoke-Download($Url, $OutFile) {
  Write-Host "下载: $Url"
  New-Item -ItemType Directory -Force -Path (Split-Path $OutFile -Parent) | Out-Null
  Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function New-Shortcut($Path, $Target, $Arguments = "", $Icon = "") {
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($Path)
  $shortcut.TargetPath = $Target
  $shortcut.Arguments = $Arguments
  if ($Icon) { $shortcut.IconLocation = $Icon }
  $shortcut.WorkingDirectory = Split-Path $Target -Parent
  $shortcut.Save()
}

function Get-DockerPath {
  $candidates = @(
    "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
  )
  return ($candidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Ensure-DockerDesktop {
  $docker = Get-DockerPath
  if ($docker) {
    Write-Host "Docker Desktop detected."
    return $docker
  }

  Write-Step "Installing Docker Desktop"
  $dockerInstaller = Join-Path $TempRoot "DockerDesktopInstaller.exe"
  $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
  Invoke-Download $dockerUrl $dockerInstaller
  Start-Process -FilePath $dockerInstaller -ArgumentList "install --quiet --accept-license --backend=wsl-2" -Wait

  $docker = Get-DockerPath
  if (-not $docker) {
    throw "Docker Desktop was not found after installation. Please reboot and run this installer again."
  }
  return $docker
}

function Start-DockerDesktop($DockerPath) {
  Write-Step "Starting Docker Desktop"
  $env:PATH = "C:\Program Files\Docker\Docker\resources\bin;C:\Program Files\Docker\cli-plugins;$env:PATH"
  & $DockerPath desktop start | Out-Null

  $deadline = (Get-Date).AddMinutes(10)
  do {
    Start-Sleep -Seconds 5
    & $DockerPath info *> $null
    $ready = $LASTEXITCODE -eq 0
  } until ($ready -or (Get-Date) -gt $deadline)

  if (-not $ready) {
    throw "Docker Desktop did not become ready. If this is the first install, reboot and run this installer again."
  }
}

function Pull-Image($DockerPath, $Image) {
  Write-Host "Pull image: $Image"
  & $DockerPath pull $Image
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to pull image: $Image"
  }
}

Assert-Admin

if (-not $InstallRoot) {
  if (Test-Path "D:\") {
    $InstallRoot = "D:\duix_avatar_data"
  } else {
    $InstallRoot = "C:\duix_avatar_data"
  }
}

$TempRoot = Join-Path $env:TEMP ("xiangdao-ai-install-" + [Guid]::NewGuid().ToString("N"))
$RepoRoot = Join-Path $InstallRoot "repo"
$DeployRoot = Join-Path $InstallRoot "deploy"
$PatchRoot = Join-Path $InstallRoot "patches"
$ClientZip = Join-Path $TempRoot "XiangdaoAI-client-portable.zip"
$Desktop = [Environment]::GetFolderPath("Desktop")

New-Item -ItemType Directory -Force -Path $InstallRoot, $DeployRoot, $PatchRoot, $TempRoot | Out-Null

Write-Step "Checking GPU environment"
try {
  nvidia-smi | Out-Null
  Write-Host "NVIDIA driver detected."
} catch {
  Write-Warn "nvidia-smi was not found. GPU generation requires a working NVIDIA driver."
}

Write-Step "Fetching deployment files"
if ($LocalAssets) {
  $sourceRoot = Split-Path $PSScriptRoot -Parent
  if (Test-Path $RepoRoot) {
    Remove-Item -LiteralPath $RepoRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
  Get-ChildItem -LiteralPath $sourceRoot -Force |
    Where-Object { $_.Name -notin @(".git", ".installer-build", "dist") } |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $RepoRoot -Recurse -Force
    }
} else {
  if ($RepoOwner -eq "YOUR_GITHUB_OWNER") {
    throw "The GitHub repository owner is not configured. Rebuild this installer with the real RepoOwner."
  }
  $repoZip = Join-Path $TempRoot "repo.zip"
  $repoUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
  Invoke-Download $repoUrl $repoZip
  Expand-Archive -LiteralPath $repoZip -DestinationPath $TempRoot -Force
  $expanded = Get-ChildItem $TempRoot -Directory | Where-Object { $_.Name -like "$RepoName-*" } | Select-Object -First 1
  if (-not $expanded) { throw "Failed to extract repository archive." }
  if (Test-Path $RepoRoot) { Remove-Item -LiteralPath $RepoRoot -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
  Get-ChildItem -LiteralPath $expanded.FullName -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $RepoRoot -Recurse -Force
  }
}

Copy-Item -Path (Join-Path $RepoRoot "deploy\*") -Destination $DeployRoot -Recurse -Force
Copy-Item -Path (Join-Path $RepoRoot "deploy\patches\*") -Destination $PatchRoot -Recurse -Force

$dockerRoot = ($InstallRoot -replace "\\", "/").ToLower()
(Get-Content (Join-Path $DeployRoot "docker-compose.template.yml") -Raw).
  Replace("__DATA_ROOT_DOCKER__", $dockerRoot) |
  Set-Content (Join-Path $DeployRoot "docker-compose.yml") -Encoding UTF8

foreach ($scriptName in @("start-xiangdao-ai.ps1", "stop-xiangdao-ai.ps1")) {
  $scriptPath = Join-Path $DeployRoot $scriptName
  (Get-Content $scriptPath -Raw).Replace("__INSTALL_ROOT__", $InstallRoot) |
    Set-Content $scriptPath -Encoding UTF8
}

Write-Step "Installing desktop client"
$clientDir = Join-Path $InstallRoot "XiangdaoAIApp"
$localClient = Join-Path (Split-Path $PSScriptRoot -Parent) "release-assets\XiangdaoAI-client-portable.zip"
Get-Process | Where-Object {
  $_.ProcessName -like "*Xiangdao*" -or $_.ProcessName -like "*Duix*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

if ($LocalAssets -and (Test-Path $localClient)) {
  Copy-Item -LiteralPath $localClient -Destination $ClientZip -Force
} else {
  $clientUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/XiangdaoAI-client-portable.zip"
  Invoke-Download $clientUrl $ClientZip
}

if (Test-Path $clientDir) {
  Remove-Item -LiteralPath $clientDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $clientDir | Out-Null
Expand-Archive -LiteralPath $ClientZip -DestinationPath $clientDir -Force

Write-Step "Preparing Docker backend"
$docker = Ensure-DockerDesktop
Start-DockerDesktop $docker

Write-Step "Pulling backend images"
Pull-Image $docker "guiji2025/fish-speech-ziming"
Pull-Image $docker "guiji2025/duix.avatar"
& $docker pull "guiji2025/fun-asr"
if ($LASTEXITCODE -ne 0) {
  Write-Warn "Official ASR image pull failed, trying mirror."
  & $docker pull "docker.1ms.run/guiji2025/fun-asr"
  if ($LASTEXITCODE -ne 0) { throw "Failed to pull ASR image." }
  & $docker tag "docker.1ms.run/guiji2025/fun-asr" "guiji2025/fun-asr"
}

Write-Step "Starting services"
Push-Location $DeployRoot
try {
  & $docker compose -f .\docker-compose.yml up -d
  if ($LASTEXITCODE -ne 0) { throw "Failed to start backend services." }
} finally {
  Pop-Location
}

Write-Step "Creating desktop shortcuts"
$powerShell = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$appExe = Join-Path $clientDir "XiangdaoAI.exe"
$icon = if (Test-Path $appExe) { "$appExe,0" } else { "" }
New-Shortcut (Join-Path $Desktop "Start Xiangdao AI.lnk") $powerShell "-ExecutionPolicy Bypass -File `"$DeployRoot\start-xiangdao-ai.ps1`"" $icon
New-Shortcut (Join-Path $Desktop "Stop Xiangdao AI.lnk") $powerShell "-ExecutionPolicy Bypass -File `"$DeployRoot\stop-xiangdao-ai.ps1`"" $icon

Write-Step "Done"
Write-Host "Install root: $InstallRoot"
Write-Host "Desktop shortcut: Start Xiangdao AI"
Write-Host "The first startup may take a while because models need to load."

Start-Process -FilePath $powerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$DeployRoot\start-xiangdao-ai.ps1`""

