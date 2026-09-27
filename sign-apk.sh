#!/bin/bash
# NOVA APK signing script: zipalign + apksigner (run inside WSL)
# Keystore: nova-release.keystore next to this script (auto-generated if missing).
# Override via env: NOVA_KEYSTORE / NOVA_KEYSTORE_PASS / NOVA_KEY_ALIAS
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}
export PATH=$JAVA_HOME/bin:$PATH

BT=$(ls -d android-sdk/build-tools/* | sort -V | tail -n 1)
SRC=$(find Video/build/outputs/apk -name "*-unsigned.apk" | head -n 1)
[ -z "$SRC" ] && { echo "ERROR: no unsigned apk found, run build-apk.sh first"; exit 1; }

BASE=$(basename "$SRC" -unsigned.apk)
OUT="$SCRIPT_DIR/${BASE}-signed.apk"

KS=${NOVA_KEYSTORE:-$SCRIPT_DIR/nova-release.keystore}
PASS=${NOVA_KEYSTORE_PASS:-nova123456}
ALIAS=${NOVA_KEY_ALIAS:-nova}

# 1. Generate keystore if missing (self-signed, for personal/local installs)
if [ ! -f "$KS" ]; then
  echo "NOTE: generating a new self-signed keystore at $KS"
  echo "      (keep it! a different key means the APK cannot upgrade-install)"
  keytool -genkeypair -keystore "$KS" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=Nova Local Build, OU=Dev, O=Local, C=CN"
fi

# 2. zipalign
"$BT/zipalign" -f 4 "$SRC" /tmp/nova-aligned.apk
echo "zipalign done"

# 3. sign
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$PASS" --key-pass "pass:$PASS" --out "$OUT" /tmp/nova-aligned.apk
echo "signed"

# 4. verify
"$BT/apksigner" verify "$OUT" && echo "signature verified"
ls -lh "$OUT"
