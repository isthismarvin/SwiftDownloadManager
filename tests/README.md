# Tests

Swift Download Manager uses **standalone test runners** (no XCTest target yet). This keeps CI simple and avoids linking the full SwiftUI/SwiftData app graph.

## Quick run

```bash
./scripts/run-tests.sh
```

## What is tested

| Module | Coverage |
|--------|----------|
| `FileNameSanitizer` | Filename sanitization |
| `HTTPHeaderHelper` | Content-Disposition parsing |
| `SegmentPlanner` | Segment boundary planning |
| `SpeedLimiter` | Throughput limiting |
| `DomainRuleStore` | Host rules, wildcards, migration |
| `DestinationConflictResolver` | Rename preview, conflict messages |

## Manual compilation

Equivalent to `scripts/run-tests.sh`:

```bash
swiftc \
  SwiftDownloadManager/Core/DownloadEngine/DownloadEngine.swift \
  SwiftDownloadManager/Utilities/RequestHeadersHelper.swift \
  SwiftDownloadManager/Utilities/HTTPHeaderHelper.swift \
  SwiftDownloadManager/Utilities/FileNameSanitizer.swift \
  SwiftDownloadManager/Utilities/SegmentPlanner.swift \
  SwiftDownloadManager/Utilities/DomainRuleStore.swift \
  SwiftDownloadManager/Utilities/DestinationConflictResolver.swift \
  tests/TestStubs.swift \
  tests/DomainRuleStoreTests.swift \
  tests/main.swift \
  -o tests/unittests && ./tests/unittests
```

## Integration smoke tests (`smoke/`)

End-to-end tests for `DownloadEngine` against a real HTTP server:

```bash
swiftc SwiftDownloadManager/Core/DownloadEngine/DownloadEngine.swift \
  smoke/main.swift -o smoke/enginetest

# Terminal 1 — test file server
mkdir -p /tmp/srv && dd if=/dev/urandom of=/tmp/srv/big.bin bs=1m count=200
python3 -m http.server 8765 --directory /tmp/srv

# Terminal 2 — run test
./smoke/enginetest http://127.0.0.1:8765/big.bin 209715200 complete
```

Modes: `complete`, `pause`, `limit [bytesPerSecond]`

Verify checksum after each run: `shasum -a 256 /tmp/srv/big.bin`

## CI

GitHub Actions runs `./scripts/run-tests.sh` on every push/PR. See `.github/workflows/ci.yml`.

## Adding tests

1. Add cases to `tests/main.swift` or a new `tests/*Tests.swift` file
2. Extend `tests/TestStubs.swift` if new app types are required
3. Update `scripts/run-tests.sh` source list if you add new production files
4. Run `./scripts/run-tests.sh` locally before opening a PR
