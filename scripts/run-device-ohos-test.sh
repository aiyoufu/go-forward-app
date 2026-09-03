#!/bin/sh
# 真机 Hypium：构建/安装 entry|common|service|components ohosTest 并执行
# 依赖：DevEco SDK、已连接设备
# 用法：
#   scripts/run-device-ohos-test.sh              # 全量四模块
#   scripts/run-device-ohos-test.sh entry common  # 指定模块
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVECO="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
export JAVA_HOME="${JAVA_HOME:-$DEVECO/jbr/Contents/Home}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO/sdk}"
export PATH="$JAVA_HOME/bin:$DEVECO/tools/node/bin:$DEVECO/sdk/default/openharmony/toolchains:$PATH"

NODE="$DEVECO/tools/node/bin/node"
HVIGOR="$DEVECO/tools/hvigor/hvigor/bin/hvigor.js"
HDC="$DEVECO/sdk/default/openharmony/toolchains/hdc"

TARGET="${HDC_TARGET:-$($HDC list targets 2>/dev/null | head -1)}"
if [ -z "$TARGET" ] || [ "$TARGET" = "[Empty]" ]; then
  echo "No hdc target. Connect device." >&2
  exit 1
fi
echo "Device: $TARGET"

if [ "$#" -gt 0 ]; then
  MODS="$*"
else
  MODS="entry common service components"
fi

echo "[1] local smoke"
node scripts/run-all-smoke.mjs

echo "[2] build + install + test: $MODS"
for m in $MODS; do
  case "$m" in
    entry)
      $NODE $HVIGOR assembleHap -p product=default --no-daemon
      $NODE $HVIGOR --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon
      $HDC -t "$TARGET" install entry/build/default/outputs/default/entry-default-signed.hap
      $HDC -t "$TARGET" install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
      echo "=== aa test entry_test ==="
      $HDC -t "$TARGET" shell aa test -b com.goforward.app -m entry_test \
        -s unittest TestRunner -s timeout 300000
      ;;
    common)
      $NODE $HVIGOR --mode module -p module=common@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      $HDC -t "$TARGET" install common/build/default/outputs/ohosTest/common-ohosTest-signed.hap
      echo "=== aa test common_test ==="
      $HDC -t "$TARGET" shell aa test -b com.goforward.app -m common_test \
        -s unittest TestRunner -s timeout 300000
      ;;
    service)
      $NODE $HVIGOR --mode module -p module=service@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      $HDC -t "$TARGET" install service/build/default/outputs/ohosTest/service-ohosTest-signed.hap
      echo "=== aa test service_test ==="
      $HDC -t "$TARGET" shell aa test -b com.goforward.app -m service_test \
        -s unittest TestRunner -s timeout 300000
      ;;
    components)
      $NODE $HVIGOR --mode module -p module=components@ohosTest -p product=default genOnDeviceTestHap --no-daemon
      $HDC -t "$TARGET" install components/build/default/outputs/ohosTest/components-ohosTest-signed.hap
      echo "=== aa test components_test ==="
      $HDC -t "$TARGET" shell aa test -b com.goforward.app -m components_test \
        -s unittest TestRunner -s timeout 300000
      ;;
    *)
      echo "Unknown module: $m (entry|common|service|components)" >&2
      exit 1
      ;;
  esac
done

echo "Done."
