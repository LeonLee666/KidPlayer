#!/bin/bash
# =============================================================================
# Android SDK 组件安装脚本（WSL 内运行，Linux 版组件装到 E 盘）
# 前置：android-sdk/cmdline-tools/latest 已就位（见 BUILDGUIDE 步骤 4）
# =============================================================================
set -e

SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/android-sdk" && pwd)"
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}
export PATH=$JAVA_HOME/bin:$PATH

cd "$SDK_DIR"
SDKMGR="cmdline-tools/latest/bin/sdkmanager"

echo "=== 接受 licenses ==="
yes | $SDKMGR --licenses > /dev/null 2>&1 || true

# 逐个安装，避免一个失败阻塞全部（注意 platforms;android-37.0 是带小数点的 37.0）
PACKAGES=(
  "platform-tools"
  "build-tools;36.0.0"
  "platforms;android-36"
  "platforms;android-37.0"
  "ndk;27.2.12479018"
  "cmake;3.22.1"
)

FAILED=0
for pkg in "${PACKAGES[@]}"; do
  echo "=== 安装 $pkg ==="
  if ! yes | $SDKMGR "$pkg" 2>&1 | grep -v '^\[' | tail -3; then
    echo "!!! $pkg 安装失败"
    FAILED=1
  fi
done

echo ""
echo "=== 安装结果 ==="
ls -d platform-tools build-tools/36.0.0 platforms/android-36 platforms/android-37.0 ndk/27.2.12479018 cmake/3.22.1 2>/dev/null || true
[ "$FAILED" -eq 0 ] && echo "✓ SDK 组件全部就绪" || echo "✗ 有组件安装失败，请重跑"
exit $FAILED
