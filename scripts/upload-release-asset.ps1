<#--
  本地签名包上传到 GitHub Release（HarmonyOS 需本机 DevEco 签名，CI 不出包）。
  用法：
    pwsh -File scripts/upload-release-asset.ps1 -Tag v1.0.0 -HapPath "entry/build/default/outputs/default/entry-default-signed.hap"
    pwsh -File scripts/upload-release-asset.ps1 -Tag v1.0.0 -HapPath "path/to/*.hap" -AppPath "path/to/*.app"
  前置：gh auth login（且对本仓库有 release 写权限）。
#>
param(
  [Parameter(Mandatory = $true)][string]$Tag,
  [string]$HapPath = "",
  [string]$AppPath = "",
  [string]$DistDir = "dist"
)

$ErrorActionPreference = "Stop"

function Resolve-Files($pattern) {
  if ([string]::IsNullOrWhiteSpace($pattern)) { return @() }
  # 支持通配符与直接路径
  $items = @(Get-Item $pattern -ErrorAction SilentlyContinue)
  if ($items.Count -eq 0 -and (-not $pattern.Contains("*")) -and (-not $pattern.Contains("?"))) {
    throw "找不到文件: $pattern"
  }
  return $items
}

$files = @()
$files += Resolve-Files $HapPath
$files += Resolve-Files $AppPath

if ($files.Count -eq 0) {
  # 兜底：自动搜寻 hvigor 默认输出目录
  $auto = @(Get-ChildItem -Path "entry/build/default/outputs" -Recurse -Include *.hap, *.app -ErrorAction SilentlyContinue)
  if ($auto.Count -gt 0) {
    Write-Host "未指定 -HapPath/-AppPath，自动发现以下产物："
    $auto | ForEach-Object { Write-Host "  $($_.FullName)" }
    $files = $auto
  } else {
    throw "没有可上传的安装包。请先在 DevEco 执行 Build Hap(s)/App(s)，再用 -HapPath 指定 .hap 路径。"
  }
}

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
foreach ($f in $files) {
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $DistDir $f.Name) -Force
  Write-Host "已复制: $($f.Name)"
}

Push-Location $DistDir
try {
  $entries = @(Get-ChildItem -File | Where-Object { $_.Extension -in ".hap", ".hsp", ".app" } | Sort-Object Name)
  if ($entries.Count -eq 0) { throw "dist/ 下没有 .hap/.hsp/.app，停止上传。" }
  Get-FileHash -Algorithm SHA256 -Path $entries.FullName |
    ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path $_.Path -Leaf)" } |
    Set-Content -Path "SHA256SUMS.txt" -Encoding ascii
  Write-Host "SHA256SUMS.txt 已生成"
} finally {
  Pop-Location
}

$upload = @(Get-ChildItem -Path $DistDir -File | Where-Object { $_.Extension -in ".hap", ".hsp", ".app" -or $_.Name -eq "SHA256SUMS.txt" } | Sort-Object Name | ForEach-Object { $_.FullName })
Write-Host "上传到 Release ${Tag}："
$upload | ForEach-Object { Write-Host "  $_" }

& gh release view $Tag 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "远端尚无 $Tag 的 Release，现在创建空 Release 再上传…"
  & gh release create $Tag --title $Tag --generate-notes
  if ($LASTEXITCODE -ne 0) { throw "gh release create 失败" }
}

& gh release upload $Tag $upload --clobber
if ($LASTEXITCODE -ne 0) { throw "gh release upload 失败" }
Write-Host "上传完成：gh release view $Tag"
