<#
.SYNOPSIS
  把编译好的 APK 发布到 GitHub Release（可重复执行，自动跳过已存在的版本 / 附件）。

.DESCRIPTION
  约定：
    - 版本号取自 pubspec.yaml 的 version，APK 位于 dist/yinghua-<版本>.apk
    - Release 标签为 v<版本>，标题为「莺花 <版本>」
    - 发布说明默认从 CHANGELOG.md 中对应章节读取
  鉴权：
    - 优先使用环境变量 GITHUB_TOKEN；否则从本机 git 凭据（git credential fill）读取
    - token 只在本进程内存中使用，不写入任何文件

.EXAMPLE
  pwsh tool/release.ps1 1.0.19

.EXAMPLE
  pwsh tool/release.ps1 1.0.19 -Notes "本次修复了xxx" -Prerelease
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Version,

  [string]$Repo = 'linlidaxia/yinghua',

  # 默认 dist/yinghua-<版本>.apk
  [string]$Apk,

  # 直接给发布说明（优先级高于 NotesFile / CHANGELOG）
  [string]$Notes,

  # 从文件读取发布说明（Markdown）
  [string]$NotesFile,

  [switch]$Prerelease,

  [switch]$Draft
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $root "dist/yinghua-$Version.apk" }
if (-not (Test-Path $Apk)) {
  throw "找不到 APK：$Apk，请先 flutter build apk --release 并复制到 dist/"
}

$apkItem = Get-Item $Apk
$sizeMb = [math]::Round($apkItem.Length / 1MB, 2)
$sha256 = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLowerInvariant()
$tag = "v$Version"

# ---- 发布说明 ----
if (-not $Notes -and $NotesFile) {
  if (-not (Test-Path $NotesFile)) { throw "找不到说明文件：$NotesFile" }
  $Notes = (Get-Content $NotesFile -Raw).Trim()
}
if (-not $Notes) {
  $changelog = Join-Path $root 'CHANGELOG.md'
  if (Test-Path $changelog) {
    $text = Get-Content $changelog -Raw
    $pattern = "(?ms)^## v$([regex]::Escape($Version))\s*\r?\n(.*?)(?=^## |\z)"
    $m = [regex]::Match($text, $pattern)
    if ($m.Success) { $Notes = $m.Groups[1].Value.Trim() }
  }
}
if (-not $Notes) { $Notes = "见 CHANGELOG.md 的 $Version 章节。" }

$body = @"
$Notes

---

**安装包**：``yinghua-$Version.apk``（$sizeMb MB，versionCode 见文件名对应提交）
**SHA-256**：``$sha256``
"@

# ---- 鉴权 ----
$token = $env:GITHUB_TOKEN
if (-not $token) {
  $res = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
  $token = (($res -split "`n" | Where-Object { $_ -match '^password=' }) -replace '^password=', '').Trim()
}
if (-not $token) {
  throw '缺少 GitHub 凭据：请设置环境变量 GITHUB_TOKEN，或先让 git 记住 github.com 的凭据。'
}

$headers = @{
  Authorization          = "Bearer $token"
  'User-Agent'           = 'yinghua-release'
  Accept                 = 'application/vnd.github+json'
}
$api = "https://api.github.com/repos/$Repo"

function Invoke-GitHubJson {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Uri,
    [object]$Payload
  )
  if ($null -eq $Payload) {
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -TimeoutSec 60
  }
  $json = $Payload | ConvertTo-Json -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $bytes `
    -ContentType 'application/json; charset=utf-8' -TimeoutSec 120
}

# ---- 创建 / 复用 Release ----
$release = $null
try {
  $release = Invoke-GitHubJson -Method Get -Uri "$api/releases/tags/$tag"
  Write-Host "Release $tag 已存在，检查附件…"
}
catch {
  if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
}

if (-not $release) {
  $release = Invoke-GitHubJson -Method Post -Uri "$api/releases" -Payload ([ordered]@{
      tag_name         = $tag
      target_commitish = 'main'
      name             = "莺花 $Version"
      body             = $body
      draft            = [bool]$Draft
      prerelease       = [bool]$Prerelease
    })
  Write-Host "已创建 Release $tag：$($release.html_url)"
}

# ---- 上传 APK（已存在则跳过）----
$assetName = "yinghua-$Version.apk"
$assets = Invoke-GitHubJson -Method Get -Uri "$api/releases/$($release.id)/assets"
$existing = $assets | Where-Object { $_.name -eq $assetName }
if ($existing) {
  Write-Host "附件已存在：$($existing.name)（$([math]::Round($existing.size / 1MB, 2)) MB），跳过上传。"
}
else {
  $uploadHeaders = @{
    Authorization  = "Bearer $token"
    'User-Agent'   = 'yinghua-release'
    Accept         = 'application/vnd.github+json'
    'Content-Type' = 'application/vnd.android.package-archive'
  }
  $upload = Invoke-RestMethod -Method Post `
    -Uri "https://uploads.github.com/repos/$Repo/releases/$($release.id)/assets?name=$assetName" `
    -Headers $uploadHeaders -InFile $Apk -TimeoutSec 1800
  Write-Host "已上传附件：$($upload.name)（$([math]::Round($upload.size / 1MB, 2)) MB）"
}

Write-Host "SHA-256：$sha256"
Write-Host "发布页：$($release.html_url)"
