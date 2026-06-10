param(
  [string]$RepoOwner = "YOUR_GITHUB_OWNER",
  [string]$RepoName = "xiangdao-ai-avatar-delivery",
  [string]$OutDir = "dist"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$OutPath = Join-Path $RepoRoot $OutDir
$WorkDir = Join-Path $RepoRoot ".installer-build"
$Nsis = "C:\Users\Administrator\Documents\Codex\2026-06-10\duix-avatar\builder-cache\nsis\nsis-3.0.4.1\Bin\makensis.exe"

if (-not (Test-Path $Nsis)) {
  throw "未找到 makensis.exe: $Nsis"
}

New-Item -ItemType Directory -Force -Path $OutPath, $WorkDir | Out-Null

$bootstrap = Get-Content (Join-Path $ScriptRoot "bootstrap.ps1") -Raw
$bootstrap = $bootstrap.Replace('YOUR_GITHUB_OWNER', $RepoOwner).Replace('xiangdao-ai-avatar-delivery', $RepoName)
$preparedBootstrap = Join-Path $WorkDir "bootstrap.ps1"
Set-Content -LiteralPath $preparedBootstrap -Value $bootstrap -Encoding UTF8

$nsi = Join-Path $WorkDir "online-installer.nsi"
$icon = Join-Path $ScriptRoot "aduidui.ico"
$outExe = Join-Path $OutPath "XiangdaoAI-online-installer.exe"

@"
Unicode true
RequestExecutionLevel admin
Name "Xiangdao AI Installer"
OutFile "$outExe"
Icon "$icon"
UninstallIcon "$icon"
SilentInstall normal
ShowInstDetails show

Section
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL "Xiangdao AI will install a local digital human system on this Windows PC.$\r$\n$\r$\nRequirements:$\r$\n- Windows 10/11, run as Administrator.$\r$\n- NVIDIA GPU and NVIDIA driver.$\r$\n- Docker Desktop / WSL2 will be installed or used.$\r$\n- Internet access to GitHub and Docker Hub.$\r$\n- At least 150GB free disk space is recommended.$\r$\n$\r$\nThe first setup may take a long time because AI backend images and models will be downloaded.$\r$\n$\r$\nClick OK to continue, or Cancel to exit." IDOK +2
  Abort
  SetOutPath "`$TEMP\XiangdaoAIInstaller"
  File "$preparedBootstrap"
  DetailPrint "Starting Xiangdao AI deployment..."
  ExecWait 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$TEMP\XiangdaoAIInstaller\bootstrap.ps1"'
SectionEnd
"@ | Set-Content -LiteralPath $nsi -Encoding UTF8

& $Nsis $nsi
if ($LASTEXITCODE -ne 0) { throw "NSIS 打包失败。" }
Get-Item $outExe

