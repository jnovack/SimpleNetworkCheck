#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Simple Network Check"
VOL_NAME="Simple Network Check Installer"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
DMG_RW="$DIST_DIR/$APP_NAME-tmp.dmg"
DMG_FINAL="$DIST_DIR/$APP_NAME.dmg"

mkdir -p "$DIST_DIR"

STAGING_DIR="$(mktemp -d "$DIST_DIR/.dmg-staging.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
  rm -f "$DMG_RW"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/package-app.sh"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_RW" "$DMG_FINAL"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  "$DMG_RW" >/dev/null

DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_DIR="/Volumes/$VOL_NAME"

if [[ -n "${DEVICE:-}" && -d "$MOUNT_DIR" && "${CI:-}" != "true" ]]; then
  osascript <<APPLESCRIPT || true
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 860, 520}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set position of item "$APP_NAME.app" of container window to {220, 230}
    set position of item "Applications" of container window to {560, 230}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
fi

sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$DEVICE" -force -quiet

hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null

if [[ -f "$ZIP_PATH" ]]; then
  echo "Zip archive: $ZIP_PATH"
fi

echo "DMG package: $DMG_FINAL"
