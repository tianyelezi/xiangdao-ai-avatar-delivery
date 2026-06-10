param(
  [string]$OutDir = "dist"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$OutPath = Join-Path $RepoRoot $OutDir
$WorkDir = Join-Path $RepoRoot ".installer-build"
$Nsis = "C:\Users\Administrator\Documents\Codex\2026-06-10\duix-avatar\builder-cache\nsis\nsis-3.0.4.1\Bin\makensis.exe"

if (-not (Test-Path $Nsis)) {
  throw "makensis.exe was not found: $Nsis"
}

New-Item -ItemType Directory -Force -Path $OutPath, $WorkDir | Out-Null

$nsi = Join-Path $WorkDir "local-installer.nsi"
$icon = Join-Path $ScriptRoot "aduidui.ico"
$bootstrap = Join-Path $ScriptRoot "bootstrap.ps1"
$deploy = Join-Path $RepoRoot "deploy\*.*"
$releaseAsset = Join-Path $RepoRoot "release-assets\XiangdaoAI-client-portable.zip"
$notice = Join-Path $RepoRoot "NOTICE.txt"
$license = Join-Path $RepoRoot "LICENSE-DUIX"
$outExe = Join-Path $OutPath "XiangdaoAI-full-installer.exe"

if (-not (Test-Path $releaseAsset)) {
  throw "Missing portable client asset: $releaseAsset"
}

@"
Unicode true
RequestExecutionLevel admin
Name "Xiangdao AI Full Installer"
OutFile "$outExe"
Icon "$icon"
UninstallIcon "$icon"
SilentInstall normal
ShowInstDetails show

Section
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL "Xiangdao AI will install a local digital human system on this Windows PC.$\r$\n$\r$\nRequirements:$\r$\n- Windows 10/11, run as Administrator.$\r$\n- NVIDIA GPU and NVIDIA driver.$\r$\n- Docker Desktop / WSL2 will be installed or used.$\r$\n- Internet access to GitHub and Docker Hub.$\r$\n- At least 150GB free disk space is recommended.$\r$\n$\r$\nThe first setup may take a long time because AI backend images and models will be downloaded.$\r$\n$\r$\nClick OK to continue, or Cancel to exit." IDOK +2
  Abort
  SetOutPath "`$TEMP\XiangdaoAIInstaller\installer"
  File "$bootstrap"
  SetOutPath "`$TEMP\XiangdaoAIInstaller\deploy"
  File /r "$deploy"
  SetOutPath "`$TEMP\XiangdaoAIInstaller\release-assets"
  File "$releaseAsset"
  SetOutPath "`$TEMP\XiangdaoAIInstaller"
  File "$notice"
  File "$license"
  DetailPrint "Starting Xiangdao AI full deployment..."
  ExecWait 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$TEMP\XiangdaoAIInstaller\installer\bootstrap.ps1" -LocalAssets'
SectionEnd
"@ | Set-Content -LiteralPath $nsi -Encoding UTF8

& $Nsis $nsi
if ($LASTEXITCODE -ne 0) { throw "NSIS packaging failed." }
Get-Item $outExe
