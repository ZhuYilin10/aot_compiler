#!/usr/bin/env bash
# 打包 KernelSU / Magisk 模块
#
#   ./build.sh            打包到 dist/ 并同步一份到 download/
#   ./build.sh --dist-only 只打包到 dist/
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(grep -E '^version=' module.prop | cut -d= -f2)"
VERSION_CODE="$(grep -E '^versionCode=' module.prop | cut -d= -f2)"
ID="$(grep -E '^id=' module.prop | cut -d= -f2)"
OUT="${ID}-${VERSION}.zip"

echo "==> ${ID} ${VERSION} (versionCode ${VERSION_CODE})"

find . -name '.DS_Store' -delete 2>/dev/null || true
chmod 755 bin/aot.sh customize.sh

rm -rf dist
mkdir -p dist
zip -rX "dist/${OUT}" module.prop customize.sh bin webroot -x '*.DS_Store' >/dev/null

if [ "${1:-}" != "--dist-only" ]; then
    mkdir -p download
    rm -f download/*.zip
    cp "dist/${OUT}" "download/${OUT}"
    echo "==> 已同步到 download/${OUT}"
fi

echo "==> 产物:"
ls -l dist/ download/ 2>/dev/null || ls -l dist/
