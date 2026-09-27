# Security Policy

Swift Download Manager takes security seriously. As a native macOS utility that interfaces with external networks, executes multi-segment transfers, handles user credentials, and communicates with a local browser companion extension, maintaining a strong security posture is vital.

---

## Supported Versions

Only the latest release and the preceding minor version receive security updates and patches.

| Version | Supported          |
| ------- | ------------------ |
| 2.3.x   | :white_check_mark: |
| 2.2.x   | :white_check_mark: |
| < 2.2.0 | :x:                |

---

## Reporting a Vulnerability

If you discover a security vulnerability or potential exposure within Swift Download Manager, please report it responsibly:

> [!IMPORTANT]
> **Do not open a public GitHub issue for security vulnerabilities.**

### Preferred Method
Submit a report privately via **[GitHub Private Vulnerability Reporting](https://github.com/isthismarvin/SwiftDownloadManager/security/advisories/new)**.

### Alternative Method
If GitHub Private Vulnerability Reporting is unavailable, send an email to the project maintainers via the email address listed in the repository profile or maintainer commit metadata, prefixing the subject line with:
`[SECURITY] Vulnerability Report: SwiftDownloadManager`

### What to Include in Your Report
To help us triage and resolve the issue quickly, please provide:
1. **Description**: A clear explanation of the vulnerability and its potential impact.
2. **Reproduction Steps**: Step-by-step instructions or proof-of-concept (PoC) code/URL.
3. **Environment**: App version, macOS version, and architecture (Apple Silicon / Intel).
4. **Proposed Fix**: Any suggested mitigations or patches (optional).

### Response Timeline
- **Initial Acknowledgement**: Within 48 hours.
- **Triage & Assessment**: Within 5 business days.
- **Fix & Public Advisory**: Coordinated release following patch validation.

---

## Security Architecture & Best Practices

Swift Download Manager is designed with defense-in-depth principles:

### 1. App Sandbox Compliance
- Swift Download Manager runs inside the macOS **App Sandbox**.
- File system access is restricted to the app container and user-explicitly selected download directories via **Security-Scoped Bookmarks**.
- Arbitrary file writes outside designated paths are rejected by macOS sandbox policy.

### 2. Local Loopback Isolation
- The Chrome extension companion server listens exclusively on loopback `127.0.0.1:6789`.
- It never binds to external interfaces (`0.0.0.0`).
- Origin headers and request payloads are validated prior to queueing any download.

### 3. Credential Protection
- HTTP Basic Auth and Bearer tokens configured in **Site Logins** are stored securely in local app storage and applied only to matching domain hosts.
- Credentials and authentication headers are never written to unencrypted log files or debug traces.

### 4. Filename & Path Sanitization
- Downloaded filenames received from HTTP `Content-Disposition` or URL paths are sanitized to prevent directory traversal (`../`) attacks and control character injection.

### 5. Checksum & Archive Verification
- Cryptographic hash calculation (SHA-256 / MD5) uses streamed chunked hashing to avoid buffer overflow risks and out-of-memory states.
- Archive extraction strictly validates target paths before extracting contents.
