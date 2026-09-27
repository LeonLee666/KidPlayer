#!/bin/bash
# NOVA APK build script (run inside WSL)
# Usage: bash build-apk.sh [release|debug]
set -e

# Resolve project root relative to this script (works on any machine)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_SDK_ROOT="$SCRIPT_DIR/android-sdk"
export ANDROID_HOME=$ANDROID_SDK_ROOT

VARIANT=${1:-release}

echo "=== Java ==="
java -version 2>&1 | head -1
echo "=== Building $VARIANT APK (project root: $SCRIPT_DIR) ==="

cd Video
if [ "$VARIANT" = "release" ]; then
    ./gradlew -Puniversal assembleNoamazonRelease
else
    ./gradlew -Puniversal assembleNoamazonDebug
fi

echo "=== Build done, APK output: ==="
find build/outputs/apk -name "*.apk" -exec ls -lh {} \;
