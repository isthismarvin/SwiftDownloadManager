# Contributing to Swift Download Manager

Thank you for your interest in contributing! This project is **source available** — not open source under MIT/GPL. By submitting a pull request, you agree to [CLA.md](CLA.md).

## What you may do

- Open issues and discussions
- Submit pull requests to the [official repository](https://github.com/isthismarvin/SwiftDownloadManager)
- Clone and build locally for learning and testing (see [LICENSE](LICENSE))

## What you may not do

- Publish, redistribute, or commercialize the code without written permission
- Use the project name or branding for unofficial builds (see [TRADEMARK.md](TRADEMARK.md))

Forking on GitHub **only to submit a PR back** to the official repo is allowed. Do not use forks to distribute a separate product.

## Prerequisites

- macOS 26+ (Tahoe) and Xcode 26+
- SwiftLint and SwiftFormat (recommended): `brew install swiftlint swiftformat`

## Getting Started

1. Clone the repository (or fork **only** if you need a PR branch)
2. Open `SwiftDownloadManager.xcodeproj` in Xcode
3. Build and run (⌘R) to verify the app launches
4. Run unit tests: `./scripts/run-tests.sh`
5. **Editor (optional):** copy `.vscode/settings.json.example` → `.vscode/settings.json` for SweetPad/Xcode paths on your machine (the file is gitignored).
6. Open a pull request against `main` and confirm you agree to [CLA.md](CLA.md)

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, release-ready code |
| `develop` | Integration branch for features (optional) |
| `feature/*` | New features |
| `fix/*` | Bug fixes |

Open pull requests against `main` (or `develop` if your fork uses it).

## Pull Request Checklist

- [ ] I agree to [CLA.md](CLA.md)
- [ ] Project builds in Xcode without errors
- [ ] `./scripts/run-tests.sh` passes
- [ ] `swiftlint` passes (no new warnings you introduced)
- [ ] User-facing strings use `L10n.t(de:en:)` or String Catalog keys
- [ ] No secrets, API keys, or machine-local paths committed
- [ ] UI changes tested on macOS (light/dark mode if applicable)

## Code Style

- Follow existing patterns: `@Observable` view models, `@MainActor` for UI-adjacent code
- Prefer small, focused changes — avoid unrelated refactors in the same PR
- Use `os.Logger` instead of `print()` in production code
- Match naming and file placement of surrounding code

## Project Layout Conventions

| Path | Put here |
|------|----------|
| `SwiftDownloadManager/Views/` | SwiftUI views only |
| `SwiftDownloadManager/ViewModels/` | `@Observable` UI logic |
| `SwiftDownloadManager/Core/` | Business logic, models, engine |
| `SwiftDownloadManager/Utilities/` | Stateless helpers |
| `tests/` | Standalone unit tests (swiftc runner) |

## Chrome Extension Changes

1. Edit files in `ChromeExtension/` at the repo root
2. Copy to `SwiftDownloadManager/Resources/ChromeExtension/` before release builds:
   ```bash
   rsync -a --delete ChromeExtension/ SwiftDownloadManager/Resources/ChromeExtension/
   ```
3. Bump **one shared version** in all of:
   - `SwiftDownloadManager.xcodeproj` → `MARKETING_VERSION`
   - `ChromeExtension/manifest.json` → `"version"`
   - `AppConstants.chromeExtensionVersion`

## Reporting Issues

Include:

- macOS and Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (Console.app, filter `nrw.marvin.SwiftDownloadManager`)

## Questions

Open a GitHub Discussion or issue if something is unclear before starting large changes.

See also [GOVERNANCE.md](GOVERNANCE.md) for maintainer roles and decision-making.
