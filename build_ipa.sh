#!/usr/bin/env bash
# 在 macOS 上一键出未签名 ipa
# 用法: ./build_ipa.sh
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="FastCode"
VERSION="1.17"

echo "[1/5] 检查工具链"
command -v xcodebuild >/dev/null || { echo "缺少 xcodebuild，先装 Xcode"; exit 1; }
if ! command -v xcodegen >/dev/null; then
  echo "缺少 xcodegen，执行: brew install xcodegen"
  exit 1
fi

echo "[2/5] 生成工程"
xcodegen generate

echo "[3/5] 归档"
rm -rf build
xcodebuild archive \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "build/${APP_NAME}.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  | tail -20

echo "[4/5] 打包 ipa"
mkdir -p build/Payload
cp -R "build/${APP_NAME}.xcarchive/Products/Applications/${APP_NAME}.app" build/Payload/
cd build
zip -qry "${APP_NAME}-${VERSION}-unsigned.ipa" Payload
cd ..

echo "[5/5] 完成"
ls -lh "build/${APP_NAME}-${VERSION}-unsigned.ipa"
echo
echo "安装方式（任选）："
echo "  - TrollStore 2：直接点开 ipa 安装，永久签名（iOS 15.0-16.6.1 arm64e 设备）"
echo "  - Sideloadly / AltStore：用你自己的 Apple ID 自签，7 天有效期"
echo "  - Xcode 真机：连上设备直接 Run，无需 ipa"
