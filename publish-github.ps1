param(
  [string]$RepoName = "xiangdao-ai-avatar-delivery",
  [string]$Visibility = "private",
  [string]$Tag = "v1.0.6"
)

$ErrorActionPreference = "Stop"
$env:PATH = "C:\Program Files\GitHub CLI;$env:PATH"

gh auth status

$owner = (gh api user --jq ".login").Trim()
if (-not $owner) { throw "Unable to resolve GitHub user." }

Write-Host "GitHub owner: $owner"
Write-Host "Repository: $RepoName"

git init
git branch -M main
git add .
git commit -m "Initial Xiangdao AI delivery package"

$exists = $true
gh repo view "$owner/$RepoName" *> $null
if ($LASTEXITCODE -ne 0) { $exists = $false }

if (-not $exists) {
  gh repo create "$owner/$RepoName" "--$Visibility" --source . --remote origin --push
} else {
  git remote remove origin 2>$null
  git remote add origin "https://github.com/$owner/$RepoName.git"
  git push -u origin main
}

.\installer\build-online-installer.ps1 -RepoOwner $owner -RepoName $RepoName

$clientAsset = Join-Path $PSScriptRoot "release-assets\XiangdaoAI-client-setup.exe"
$onlineInstaller = Join-Path $PSScriptRoot "dist\XiangdaoAI-online-installer.exe"

if (-not (Test-Path $clientAsset)) { throw "Missing release asset: $clientAsset" }
if (-not (Test-Path $onlineInstaller)) { throw "Missing release asset: $onlineInstaller" }

$releaseExists = $true
gh release view $Tag --repo "$owner/$RepoName" *> $null
if ($LASTEXITCODE -ne 0) { $releaseExists = $false }

if (-not $releaseExists) {
  gh release create $Tag --repo "$owner/$RepoName" --title "向导AI $Tag" --notes "向导AI / 啊对对队自动化数字人系统客户交付版。"
}

gh release upload $Tag $clientAsset $onlineInstaller --repo "$owner/$RepoName" --clobber

Write-Host ""
Write-Host "Done."
Write-Host "Repository: https://github.com/$owner/$RepoName"
Write-Host "Customer installer: https://github.com/$owner/$RepoName/releases/latest/download/XiangdaoAI-online-installer.exe"
