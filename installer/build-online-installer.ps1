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
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL "向导AI 将在这台 Windows 电脑上部署本地数字人系统。$\r$\n$\r$\n运行条件：$\r$\n- Windows 10/11，并以管理员身份运行。$\r$\n- 需要 NVIDIA 显卡和 NVIDIA 驱动。$\r$\n- 将安装或使用 Docker Desktop / WSL2。$\r$\n- 需要能访问 GitHub 和 Docker Hub。$\r$\n- 建议磁盘至少预留 150GB。$\r$\n$\r$\n首次安装会比较久，因为需要下载 AI 后端镜像和模型。$\r$\n$\r$\n点击“确定”继续安装，点击“取消”退出。" IDOK +2
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

