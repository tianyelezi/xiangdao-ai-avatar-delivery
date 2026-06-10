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
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL "向导AI 将在这台 Windows 电脑上部署本地数字人系统。$\r$\n$\r$\n运行条件：$\r$\n- Windows 10/11，并以管理员身份运行。$\r$\n- 需要 NVIDIA 显卡和 NVIDIA 驱动。$\r$\n- 将安装或使用 Docker Desktop / WSL2。$\r$\n- 需要能访问 GitHub 和 Docker Hub。$\r$\n- 建议磁盘至少预留 150GB。$\r$\n$\r$\n首次安装会比较久，因为需要下载 AI 后端镜像和模型。$\r$\n$\r$\n点击“确定”继续安装，点击“取消”退出。" IDOK +2
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
