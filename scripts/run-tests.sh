#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swiftc \
  SwiftDownloadManager/Core/DownloadEngine/SpeedLimiter.swift \
  SwiftDownloadManager/Core/DownloadEngine/ActiveDownload.swift \
  SwiftDownloadManager/Core/DownloadEngine/DownloadEngine.swift \
  SwiftDownloadManager/Utilities/HTTPRequestParser.swift \
  SwiftDownloadManager/Utilities/URLSchemeParser.swift \
  SwiftDownloadManager/Utilities/RequestHeadersHelper.swift \
  SwiftDownloadManager/Utilities/HTTPHeaderHelper.swift \
  SwiftDownloadManager/Utilities/FileNameSanitizer.swift \
  SwiftDownloadManager/Utilities/SegmentPlanner.swift \
  SwiftDownloadManager/Core/Settings/SegmentCountTier.swift \
  SwiftDownloadManager/Utilities/DomainRuleStore.swift \
  SwiftDownloadManager/Utilities/DestinationConflictResolver.swift \
  SwiftDownloadManager/Utilities/ClipboardMonitor.swift \
  SwiftDownloadManager/Utilities/BatchURLParser.swift \
  SwiftDownloadManager/Utilities/FileChecksumService.swift \
  SwiftDownloadManager/Core/Models/DownloadPriority.swift \
  SwiftDownloadManager/Utilities/SiteCredentialStore.swift \
  SwiftDownloadManager/Utilities/ArchiveExtractionService.swift \
  SwiftDownloadManager/Views/DownloadTable/TableColumnLayout.swift \
  tests/TestStubs.swift \
  tests/DomainRuleStoreTests.swift \
  tests/SiteCredentialStoreAndArchiveTests.swift \
  tests/ChaosTests.swift \
  tests/UITests.swift \
  tests/main.swift \
  -o tests/unittests

./tests/unittests
