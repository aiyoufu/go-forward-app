# 真机 Hypium：构建/安装 entry|common|service|components ohosTest 并执行（Windows）
# 依赖：本机已装 DevEco、hdc 能列出设备
# 用法：
#   pwsh -File scripts/run-device-ohos-test.ps1
#   pwsh -File scripts/run-device-ohos-test.ps1 entry common
# 环境变量：DEVECO_HOME（默认 Huawei DevEco Studio 安装目录）、HDC_TARGET
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $PSScriptRoot) {
  $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
  $Root = Split-Path -Parent $Root
}
Set-Location $Root

$DevEco = if ($env:DEVECO_HOME) { $env:DEVECO_HOME } else {
  'C:\Program Files\Huawei\DevEco Studio'
}
$env:JAVA_HOME = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { Join-Path $DevEco 'jbr' }
$env:DEVECO_SDK_HOME = if ($env:DEVECO_SDK_HOME) { $env:DEVECO_SDK_HOME } else { Join-Path $DevEco 'sdk' }
$hdc = Join-Path $env:DEVECO_SDK_HOME 'default\openharmony\toolchains\hdc.exe'
$hvigor = Join-Path $DevEco 'tools\hvigor\hvigor\bin\hvigor.js'
$node = Join-Path $DevEco 'tools\node\node.exe'
if (-not (Test-Path $node)) {
  $node = 'node'
}

$target = $env:HDC_TARGET
if (-not $target) {
  $listed = & $hdc list targets 2>$null
  $target = ($listed | Where-Object { $_ -and $_ -ne '[Empty]' } | Select-Object -First 1)
}
if (-not $target) {
  Write-Error 'No hdc target. Connect device.'
}

Write-Host "Device: $target"
$mods = if ($args.Count -gt 0) { $args } else { @('entry', 'common', 'service', 'components') }

Write-Host '[1] local smoke'
& node scripts/run-all-smoke.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[2] build + install + test: $mods"
foreach ($m in $mods) {
  switch ($m) {
    'entry' {
      & $node $hvigor assembleHap -p product=default --no-daemon
      & $node $hvigor --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon
      & $hdc -t $target install entry/build/default/outputs/default/entry-default-signed.hap
      & $hdc -t $target install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
      Write-Host '=== aa test entry_test ==='
      & $hdc -t $target shell aa test -b com.goforward.app -m entry_test -s unittest TestRunner -s timeout 300000
    }
    'common' {
      & $node $hvigor --mode module -p module=common@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      & $hdc -t $target install common/build/default/outputs/ohosTest/common-ohosTest-signed.hap
      Write-Host '=== aa test common_test ==='
      & $hdc -t $target shell aa test -b com.goforward.app -m common_test -s unittest TestRunner -s timeout 300000
    }
    'service' {
      & $node $hvigor --mode module -p module=service@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      & $hdc -t $target install service/build/default/outputs/ohosTest/service-ohosTest-signed.hap
      Write-Host '=== aa test service_test ==='
      & $hdc -t $target shell aa test -b com.goforward.app -m service_test -s unittest TestRunner -s timeout 300000
    }
    'components' {
      & $node $hvigor --mode module -p module=components@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      & $hdc -t $target install components/build/default/outputs/ohosTest/components-ohosTest-signed.hap
      Write-Host '=== aa test components_test ==='
      & $hdc -t $target shell aa test -b com.goforward.app -m components_test -s unittest TestRunner -s timeout 300000
    }
    default {
      Write-Error "Unknown module: $m (entry|common|service|components)"
    }
  }
}
Write-Host 'Done.'
