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
Name "向导AI 一键部署器"
OutFile "$outExe"
Icon "$icon"
UninstallIcon "$icon"
SilentInstall normal
ShowInstDetails show

Section
  SetOutPath "`$TEMP\XiangdaoAIInstaller"
  File "$preparedBootstrap"
  DetailPrint "正在启动向导AI一键部署..."
  ExecWait 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$TEMP\XiangdaoAIInstaller\bootstrap.ps1"'
SectionEnd
"@ | Set-Content -LiteralPath $nsi -Encoding UTF8

& $Nsis $nsi
if ($LASTEXITCODE -ne 0) { throw "NSIS 打包失败。" }
Get-Item $outExe

