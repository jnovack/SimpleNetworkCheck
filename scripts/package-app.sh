#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Simple Network Check"
PRODUCT_NAME="SimpleNetworkCheck"
BUNDLE_ID="com.boomertechsupport.parentnetworkcheck"
MIN_MACOS="14.0"
ICON_PATH="$ROOT_DIR/assets/SimpleNetworkCheck.icns"

DEFAULT_APP_VERSION="0.1.0"
APP_VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

if [[ -z "$APP_VERSION" ]]; then
  if GIT_TAG="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null)" && [[ "$GIT_TAG" == v* ]]; then
    APP_VERSION="${GIT_TAG#v}"
  else
    APP_VERSION="$DEFAULT_APP_VERSION"
  fi
fi

# Git tags are expected as vX.Y.Z; normalize when callers pass the raw tag.
if [[ "$APP_VERSION" == v* ]]; then
  APP_VERSION="${APP_VERSION#v}"
fi

APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
BINARY_PATH="$BUILD_DIR/release/$PRODUCT_NAME"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"

mkdir -p "$DIST_DIR"

# Build both Apple Silicon and Intel binaries, then merge with lipo.
swift build -c release --arch arm64 --product "$PRODUCT_NAME"
swift build -c release --arch x86_64 --product "$PRODUCT_NAME"

ARM_BINARY_PATH="$ROOT_DIR/.build/arm64-apple-macosx/release/$PRODUCT_NAME"
X86_BINARY_PATH="$ROOT_DIR/.build/x86_64-apple-macosx/release/$PRODUCT_NAME"

if [[ ! -x "$ARM_BINARY_PATH" ]]; then
  echo "Expected arm64 binary not found: $ARM_BINARY_PATH" >&2
  exit 1
fi

if [[ ! -x "$X86_BINARY_PATH" ]]; then
  echo "Expected x86_64 binary not found: $X86_BINARY_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

lipo -create "$ARM_BINARY_PATH" "$X86_BINARY_PATH" -output "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

if [[ -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/SimpleNetworkCheck.icns"
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>SimpleNetworkCheck</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

xattr -cr "$APP_DIR" >/dev/null 2>&1 || true

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "App bundle: $APP_DIR"
echo "Zip archive: $ZIP_PATH"
echo "Version: $APP_VERSION ($BUILD_NUMBER)"
