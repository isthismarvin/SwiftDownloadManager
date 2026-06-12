# Chrome Extension

The **Swift Download Manager Companion** is a Manifest V3 extension that sends download URLs to the macOS app over loopback HTTP.

**Requirements:** macOS **26.0+** (Tahoe) with the companion app installed and running (starts the local HTTP server on first launch).

## How It Works

```
Browser → POST http://127.0.0.1:6789/add  →  LocalHTTPServer  →  DownloadManager
Health  → GET  http://127.0.0.1:6789/ping
```

The server binds **only to 127.0.0.1** — it is not reachable from other machines.

## Installation

### From GitHub Release (recommended)

1. Download [SwiftDownloadManager-ChromeExtension-v2.0.1.zip](https://github.com/isthismarvin/SwiftDownloadManager/releases/latest/download/SwiftDownloadManager-ChromeExtension-v2.0.1.zip)
2. Unzip the archive
3. Launch the macOS app
4. In Chrome: `chrome://extensions` → **Developer mode** → **Load unpacked** → select the unzipped folder

### From repository (development)

1. Build and run the macOS app once (starts the local server)
2. Open **Settings → Integration → Open Extension Folder**
3. In Chrome: `chrome://extensions`
4. Enable **Developer mode**
5. Click **Load unpacked** and select:
   - `ChromeExtension/` at the repo root (recommended for development), or
   - `SwiftDownloadManager/Resources/ChromeExtension/` (bundled copy)

## Source vs Bundle Copy

| Path | Purpose |
|------|---------|
| `ChromeExtension/` | **Edit here** — canonical source in the repo |
| `SwiftDownloadManager/Resources/ChromeExtension/` | Copy bundled into the `.app` for Release |

After editing the extension, sync to Resources:

```bash
./scripts/sync-chrome-extension.sh
```

## Versioning

Keep these in sync when releasing (same version everywhere):

- `SwiftDownloadManager.xcodeproj` → `MARKETING_VERSION`
- `ChromeExtension/manifest.json` → `"version"`
- `SwiftDownloadManager/Core/AppConstants.swift` → `chromeExtensionVersion`

`./scripts/build-release.sh` fails if app and extension versions differ.

## Permissions

The extension requests cookies and broad host permissions to forward browser session headers for protected downloads. The app sends cookies only when enabled in Settings → Integration.

## Troubleshooting

| Problem | Check |
|---------|--------|
| Extension shows offline | App running? Settings shows server active on port 6789 |
| Download not appearing | Confirmation dialog enabled? Check domain rules |
| CORS / network errors | Server must be on 127.0.0.1, not a remote host |
