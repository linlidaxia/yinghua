<#
.SYNOPSIS
  生成自建更新清单 update.json，并把 APK 一起复制到 NAS 的更新目录。

.DESCRIPTION
  自建更新源只需要两个文件：
    - yinghua-<版本>.apk
    - update.json（App 读取的版本清单）

  清单里的 apk 用相对文件名，App 会相对清单地址解析，
  所以 NAS 上放到哪个目录、用哪个端口都不影响。

.EXAMPLE
  # 只生成到 dist/nas/，之后手动用 File Station 拖到 NAS
  pwsh tool/publish_nas.ps1 1.0.21

.EXAMPLE
  # 直接写入已挂载的 NAS 共享目录（SMB 映射盘 / UNC 路径）
  pwsh tool/publish_nas.ps1 1.0.21 -Dest '\\DiskStation\web\yinghua'

.EXAMPLE
  # 通过 SSH/SCP 推送（需要 NAS 开启 SSH）
  pwsh tool/publish_nas.ps1 1.0.21 -SshTarget 'admin@diskstation.local' -RemoteDir '/volume1/web/yinghua'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Version,

  # dist/yinghua-<版本>.apk
  [string]$Apk,

  # 直接给更新说明（默认读 CHANGELOG.md 对应章节）
  [string]$Notes,

  # 已挂载的目录或 UNC 路径，例如 \\DiskStation\web\yinghua
  [string]$Dest,

  # 通过 scp 推送，例如 admin@diskstation.local
  [string]$SshTarget,

  # scp 目标目录，例如 /volume1/web/yinghua
  [string]$RemoteDir
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $root "dist/yinghua-$Version.apk" }
if (-not (Test-Path $Apk)) {
  throw "找不到 APK：$Apk，请先 flutter build apk --release 并复制到 dist/"
}

# 说明优先取参数，其次 CHANGELOG 的 ## v<版本> 章节
if (-not $Notes) {
  $changelog = Join-Path $root 'CHANGELOG.md'
  if (Test-Path $changelog) {
    $text = Get-Content $changelog -Raw
    $pattern = "(?ms)^## v$([regex]::Escape($Version))\s*\r?\n(.*?)(?=^## |\z)"
    $m = [regex]::Match($text, $pattern)
    if ($m.Success) { $Notes = $m.Groups[1].Value.Trim() }
  }
}
if (-not $Notes) { $Notes = "莺花 $Version" }

$apkItem = Get-Item $Apk
$apkName = "yinghua-$Version.apk"
$sha256 = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLowerInvariant()

$manifest = [ordered]@{
  version      = $Version
  notes        = $Notes
  apk          = $apkName
  size         = $apkItem.Length
  sha256       = $sha256
  published_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

$stage = Join-Path $root 'dist/nas'
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$stagedApk = Join-Path $stage $apkName
Copy-Item $Apk $stagedApk -Force

# 不带 BOM，避免部分 JSON 解析器把 BOM 当内容
$json = $manifest | ConvertTo-Json -Depth 5
$manifestPath = Join-Path $stage 'update.json'
[System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "已生成清单：$manifestPath"
Write-Host "安装包：$stagedApk（$([math]::Round($apkItem.Length / 1MB, 2)) MB）"
Write-Host "SHA-256：$sha256"

if ($Dest) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item $stagedApk (Join-Path $Dest $apkName) -Force
  Copy-Item $manifestPath (Join-Path $Dest 'update.json') -Force
  Write-Host "已写入：$Dest"
}

if ($SshTarget -and $RemoteDir) {
  Write-Host "正在通过 scp 推送…"
  & scp $stagedApk "${SshTarget}:${RemoteDir}/$apkName"
  if ($LASTEXITCODE -ne 0) { throw 'scp 上传 APK 失败' }
  & scp $manifestPath "${SshTarget}:${RemoteDir}/update.json"
  if ($LASTEXITCODE -ne 0) { throw 'scp 上传 update.json 失败' }
  Write-Host "已推送：${SshTarget}:${RemoteDir}"
}

Write-Host ''
Write-Host '把这两个文件放到 NAS 的 Web 目录后，在 App 设置 → 更新源里填：'
Write-Host '  http://[你的NAS-IPv6地址]:端口/目录/update.json'
