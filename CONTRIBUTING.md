# Contributing to Swift Download Manager

Thank you for your interest in contributing! This project is an open source community project. By submitting a pull request, you agree to the [CLA](CLA.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Table of Contents
- [What You May & May Not Do](#what-you-may--may-not-do)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Engineering Do's and Don'ts](#engineering-dos-and-donts)
- [Branch & Commit Strategy](#branch--commit-strategy)
- [Pull Request Checklist](#pull-request-checklist)
- [Chrome Extension Integration](#chrome-extension-integration)
- [Security Disclosures](#security-disclosures)

---

## What You May & May Not Do

### You May:
- Open issues, bug reports, and feature requests using our GitHub issue forms.
- Submit pull requests for bug fixes, performance optimizations, and features.
- Clone and build the project locally for testing and development.
- Inspect and study the codebase.

### You May Not:
- Commit secrets, tokens, private keys, or machine-specific absolute file paths.
- Bypass security boundaries (macOS App Sandbox, security-scoped bookmarks, loopback verification).
- Introduce heavy external third-party dependencies when native Foundation/Swift concurrency solutions suffice.

---

## Prerequisites

- **macOS**: macOS 26.0 (Tahoe) or newer.
- **Xcode**: Xcode 26.0 or newer.
- **Command Line Tools**: Swift 5+ compiler toolchain (`swiftc`, `xcodebuild`).
- **Linters & Formatters** (recommended):
  ```bash
  brew install swiftlint swiftformat
  ```

---

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/isthismarvin/SwiftDownloadManager.git
   cd SwiftDownloadManager
   ```

2. **Open in Xcode:**
   ```bash
   open SwiftDownloadManager.xcodeproj
   ```

3. **Verify the test suite passes:**
   ```bash
   ./scripts/run-tests.sh
   ```

4. **Verify linter:**
   ```bash
   swiftlint
   ```

---

## Engineering Do's and Don'ts

To maintain architectural integrity, safety, and swift execution, all contributions must adhere to these principles:

### Concurrency & State Management
| Do | Don't |
|---|---|
| :white_check_mark: Use `@MainActor` for UI bindings, SwiftUI view models, and `@Observable` classes. | :x: Don't execute heavy network calculations or file I/O on `@MainActor`. |
| :white_check_mark: Use Swift Concurrency (`Task`, `async/await`, `AsyncStream`) for asynchronous flows. | :x: Don't use legacy `NSLock` or unstructured manual thread dispatch when modern concurrency tools apply. |
| :white_check_mark: Keep background tasks responsive to `Task.isCancelled` / cancellation signals. | :x: Don't ignore cancellation tokens during downloads or file hashing. |

### Memory & File Streaming
| Do | Don't |
|---|---|
| :white_check_mark: Stream downloaded segments directly to disk via `FileHandle` / chunk buffers. | :x: Don't load multi-gigabyte files into memory (`Data(contentsOf:)`). |
| :white_check_mark: Use streamed chunked hashing (`FileChecksumService`) for MD5 and SHA-256. | :x: Don't buffer entire downloads in RAM to calculate hashes. |
| :white_check_mark: Always close file descriptors and handles in `defer` blocks or teardown handlers. | :x: Don't leak file handles during abrupt disconnections or pause actions. |

### Security & Sandbox
| Do | Don't |
|---|---|
| :white_check_mark: Always resolve file access through **Security-Scoped Bookmarks** (`BookmarkHelper`). | :x: Don't attempt to write to arbitrary root/user paths outside App Sandbox entitlements. |
| :white_check_mark: Sanitize all filenames with `FileNameSanitizer` before creating files. | :x: Don't allow directory traversal sequences (`../`, control characters) in filenames. |
| :white_check_mark: Store Basic Auth and Bearer tokens in `SiteCredentialStore` and scope to matching hosts. | :x: Don't log sensitive passwords, tokens, or auth headers in console logs or crash dumps. |
| :white_check_mark: Keep local companion server isolated strictly to loopback (`127.0.0.1:6789`). | :x: Don't bind IPC servers to all interfaces (`0.0.0.0`). |

### UI & Aesthetics
| Do | Don't |
|---|---|
| :white_check_mark: Design sleek, responsive interfaces adhering to Apple's Human Interface Guidelines (HIG). | :x: Don't use generic or harsh primary colors; use curated semantic theme tokens (`AppTheme`). |
| :white_check_mark: Ensure full dynamic support for both **Dark** and **Light** appearance modes. | :x: Don't hardcode fixed foreground/background colors that break in opposite appearance modes. |
| :white_check_mark: Localize user-facing strings using String Catalogs (`Localizable.xcstrings`). | :x: Don't commit hardcoded English or German strings into SwiftUI views. |

### Git & Code Hygiene
| Do | Don't |
|---|---|
| :white_check_mark: Run `./scripts/run-tests.sh` and `swiftlint` prior to committing. | :x: Don't push commits with failing unit tests or linter errors. |
| :white_check_mark: Write atomic, well-described commits using Conventional Commits (`feat:`, `fix:`, `refactor:`). | :x: Don't squash unrelated bug fixes and feature redesigns into a giant monolithic commit. |
| :white_check_mark: Keep binary files (`.dmg`, `.zip`, `.ipa`, `.xcuserstate`) out of git tracking. | :x: Don't commit local IDE configs with absolute user paths (`buildServer.json`). |

---

## Branch & Commit Strategy

- `main`: Production and release branch. Must always build cleanly and pass CI.
- `feature/<name>`: New feature branches.
- `fix/<name>`: Bug fix branches.

### Commit Format
We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:
- `feat: add site credential matching with wildcards`
- `fix: prevent race condition during segment pause`
- `perf: optimize checksum calculation chunk size`
- `docs: update Chrome extension pairing instructions`

---

## Pull Request Checklist

Before opening a pull request, ensure the following steps are satisfied:

- [ ] Project compiles cleanly in Xcode (`⌘B`) without warnings or errors.
- [ ] `./scripts/run-tests.sh` passes 100%.
- [ ] `swiftlint` reports 0 serious violations.
- [ ] No hardcoded tokens, passwords, or absolute home directory paths exist in code.
- [ ] All new UI components properly handle Dark and Light modes.
- [ ] New user-facing strings are localized in `Localizable.xcstrings`.
- [ ] You have verified that tests cover newly introduced business logic.

---

## Chrome Extension Integration

When updating the companion Chrome extension:
1. Make changes in the `ChromeExtension/` root directory.
2. Synchronize resources into the Xcode project target:
   ```bash
   ./scripts/sync-chrome-extension.sh
   ```
3. Ensure extension version in `ChromeExtension/manifest.json`, `AppConstants.chromeExtensionVersion`, and `MARKETING_VERSION` in `project.pbxproj` match.

---

## Security Disclosures

Please report security issues privately via [GitHub Security Advisories](https://github.com/isthismarvin/SwiftDownloadManager/security/advisories/new) or refer to [SECURITY.md](SECURITY.md). Do not open public issues for vulnerabilities.
