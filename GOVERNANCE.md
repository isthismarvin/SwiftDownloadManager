# Governance

This document describes how the **Swift Download Manager** project is maintained.

## Project owner

- **Marvin** — copyright holder, final decision authority on releases, licensing, and trademark use.

## Maintainer roles

| Role | Permissions | Restrictions |
|------|-------------|--------------|
| **Owner** | Full repository access, releases, license & trademark decisions | — |
| **Maintainer** | Merge approved PRs, triage issues, cut releases when delegated | May not publish or license the codebase separately; may not grant trademark use |
| **Contributor** | Open issues and pull requests | Subject to [LICENSE](LICENSE) and [CLA](CLA.md) |

Maintainers are listed in this file and/or in GitHub repository collaborators.

### Current maintainers

| Name | Role | GitHub |
|------|------|--------|
| Marvin | Owner | @isthismarvin |

## Decision making

1. **Day-to-day changes** — merged via pull request review by a maintainer.
2. **Breaking changes, architecture, licensing** — require owner approval.
3. **New maintainers** — invited by the owner; listed here after acceptance.
4. **Disputes** — owner has final say.

## Releases

- Version numbers are shared between the macOS app and Chrome extension (see [docs/CHROME_EXTENSION.md](docs/CHROME_EXTENSION.md)).
- Only maintainers authorized by the owner may publish GitHub Releases.
- Release assets are built with `./scripts/build-release.sh`.

## Stepping down

Maintainers may step down at any time by opening a PR to remove themselves from this file.

## Relationship to the license

Maintainer status grants **collaboration rights inside this repository only**. It does not transfer copyright or permit separate distribution of the software. See [LICENSE](LICENSE).
