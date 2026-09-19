#!/usr/bin/env bash
# 打包 KernelSU / Magisk 模块
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(grep -E '^version=' module.prop | cut -d= -f2)"
VERSION_CODE="$(grep -E '^versionCode=' module.prop | cut -d= -f2)"
ID="$(grep -E '^id=' module.prop | cut -d= -f2)"
OUT_DIR="dist"
OUT="${OUT_DIR}/${ID}-${VERSION}.zip"

echo "==> ${ID} ${VERSION} (versionCode ${VERSION_CODE})"

find . -name '.DS_Store' -delete 2>/dev/null || true
chmod 755 bin/aot.sh customize.sh

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

zip -rX "$OUT" module.prop customize.sh bin webroot -x '*.DS_Store' >/dev/null

echo "==> 已生成 $OUT"
unzip -l "$OUT"
