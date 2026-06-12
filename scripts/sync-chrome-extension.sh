#!/usr/bin/env bash
# Sync ChromeExtension source to the app bundle Resources folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ChromeExtension"
DEST="$ROOT/SwiftDownloadManager/Resources/ChromeExtension"

if [[ ! -d "$SRC" ]]; then
  echo "error: ChromeExtension/ not found at $SRC" >&2
  exit 1
fi

APPICON="$ROOT/SwiftDownloadManager/Assets.xcassets/AppIcon.appiconset"
ICONS="$SRC/icons"

if [[ -d "$APPICON" ]]; then
  mkdir -p "$ICONS"
  cp "$APPICON/16.png" "$ICONS/icon16.png"
  cp "$APPICON/128.png" "$ICONS/icon128.png"
  sips -z 48 48 "$APPICON/64.png" --out "$ICONS/icon48.png" >/dev/null
fi

mkdir -p "$DEST"
rsync -a --delete "$SRC/" "$DEST/"
echo "Synced ChromeExtension → SwiftDownloadManager/Resources/ChromeExtension/"
