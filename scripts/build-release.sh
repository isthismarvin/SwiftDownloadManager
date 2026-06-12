#!/usr/bin/env bash
# Build Release .app and package GitHub release assets (.dmg + .zip).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_PATH="$ROOT/.derivedData/Build/Products/Release/SwiftDownloadManager.app"
DIST="$ROOT/dist"
DMG_STAGING="$DIST/dmg-staging"

echo "→ Syncing Chrome extension…"
"$ROOT/scripts/sync-chrome-extension.sh"

echo "→ Building Release…"
xcodebuild \
  -scheme SwiftDownloadManager \
  -destination 'platform=macOS' \
  -configuration Release \
  -derivedDataPath "$ROOT/.derivedData" \
  build | tail -3

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
EXT_VERSION="$(python3 -c "import json; print(json.load(open('$ROOT/ChromeExtension/manifest.json'))['version'])")"

if [[ "$EXT_VERSION" != "$APP_VERSION" ]]; then
  echo "error: extension version ($EXT_VERSION) != app version ($APP_VERSION)" >&2
  echo "       bump MARKETING_VERSION, ChromeExtension/manifest.json, and AppConstants.chromeExtensionVersion together." >&2
  exit 1
fi

APP_DMG="$DIST/SwiftDownloadManager-macOS-v${APP_VERSION}.dmg"
APP_ZIP="$DIST/SwiftDownloadManager-macOS-v${APP_VERSION}.zip"
EXT_ZIP="$DIST/SwiftDownloadManager-ChromeExtension-v${APP_VERSION}.zip"

mkdir -p "$DIST"
rm -rf "$DIST"/*
rm -rf "$DMG_STAGING"

echo "→ Creating DMG…"
mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/SwiftDownloadManager.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "Swift Download Manager" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$APP_DMG" >/dev/null

rm -rf "$DMG_STAGING"

echo "→ Packaging macOS app (zip fallback)…"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"

echo "→ Packaging Chrome extension…"
(
  cd "$ROOT/ChromeExtension"
  zip -r -X "$EXT_ZIP" . -x "*.DS_Store" -x "__MACOSX/*"
)

echo ""
echo "Release assets ready (v${APP_VERSION}):"
echo "  $APP_DMG"
echo "  $APP_ZIP"
echo "  $EXT_ZIP"
echo ""
echo "Create GitHub release:"
echo "  gh release create v${APP_VERSION} \\"
echo "    --title \"v${APP_VERSION}\" \\"
echo "    --notes \"Release notes…\" \\"
echo "    \"$APP_DMG\" \"$APP_ZIP\" \"$EXT_ZIP\""
