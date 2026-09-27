# Complete Settings Catalog — SwiftDownloadManager v2.1.1

## A. SettingsSection Definitions (Sidebar Navigation)

| # | Enum Case | German Title | English Title | SF Symbol | Help (EN) |
|---|-----------|-------------|--------------|-----------|-----------|
| 1 | `.general` | Allgemein | General | `gearshape` | Language, default folder, sorting, and table columns. |
| 2 | `.downloads` | Downloads | Downloads | `arrow.down.circle` | Queue, connections, and file conflicts. |
| 3 | `.network` | Netzwerk | Network | `network` | Speed limit, Wi-Fi, and network options. |
| 4 | `.integration` | Integration | Integration | `puzzlepiece.extension` | Chrome extension, domain rules, and learned suggestions. |
| 5 | `.intelligence` | Intelligenz | Intelligence | `sparkles` | Learning, suggestions, stall detection, and smart filters. |
| 6 | `.notifications` | Benachrichtigungen | Notifications | `bell` | System notifications, stalls, queue backlog, and Dock badge. |
| 7 | `.hotkeys` | Tastenkürzel | Hotkeys | `keyboard` | Customize menu keyboard shortcuts and avoid conflicts. |
| 8 | `.advanced` | Erweitert | Advanced | `wrench.and.screwdriver` | History, diagnostics, and reset. |
| 9 | `.about` | Über | About | `info.circle` | App version and information. |


## B. Every Setting by Panel

### Legend
- **Type**: Toggle = Bool switch, Picker = dropdown/segmented, Stepper = +/- counter, Slider = continuous slider, Button = action button, Info = display-only text
- **Key**: UserDefaults key from `AppSettings.swift`


### PANEL 1: GENERAL — `GeneralSettingsPanel.swift`

#### Language & Folder
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 1 | Language | Picker (System / English / German) | `appLanguage` | `.system` | Sets the language for menus, dialogs, and settings. |
| 2 | Default destination folder | Button ("Change…" + "Reset") | `defaultSaveDirectoryBookmark` | `nil` (system Downloads) | Destination for new downloads when no other folder is chosen. |

#### Download List
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 3 | Sort By | Picker (Date, Name, Progress, Speed, Status, Size, ETA) | `downloadSortOrder` | `.dateAdded` | Default sort for the download table. |
| 4 | Sort direction | Segmented (Descending / Ascending) | `downloadSortAscending` | `false` (Desc) | Direction for the current sort. |
| 5 | Column order | Up/Down buttons per column + "Restore defaults" | `tableColumnOrder` | Default data columns | Name column stays fixed on left. Drag & drop also supported. |

#### Startup & Menu Bar
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 6 | Launch at login | Toggle | `launchAtLogin` | `true` | Starts in background so extension and scheduled downloads stay available. |
| 7 | Start in background | Toggle | `startInBackground` | `true` | Shows only menu bar icon on launch. |
| 8 | Show menu bar icon | Toggle | `showMenuBarIcon` | `true` | Shows app in macOS menu bar. |
| 9 | Hide Dock icon when window closed | Toggle | `hideDockWhenInBackground` | `true` | Hides Dock icon when only menu bar is active. Disabled when menu bar icon is off. |

#### Dialogs & Quit
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 10 | Completion dialog after download | Toggle | `showCompletionDialog` | `true` | Shows window after download with Open, Finder, and Extract options. |
| 11 | Confirmation dialog before start | Toggle | `showConfirmationDialog` | `true` | Asks for confirmation before starting external downloads. |
| 12 | Pause downloads on quit | Toggle | `pauseDownloadsOnQuit` | `true` | Pauses active downloads when quitting to preserve progress. |


### PANEL 2: DOWNLOADS — `DownloadsSettingsPanel.swift`

#### Queue
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 13 | Parallel downloads | Stepper (1–8) | `maxConcurrentDownloads` | `2` | How many downloads may run at once. |
| 14 | Hold new downloads in queue | Toggle | `holdNewDownloadsInQueue` | `false` | New downloads don't start automatically. |

#### Connections
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 15 | Default connections | Stepper (1–8) | `defaultSegmentsCount` | `4` | Fallback segment count when size unknown. |
| 16 | Connections by file size | Toggle | `sizeBasedSegmentCountEnabled` | `true` | Enables tier-based segment count config. |

**Size-based tiers** (`segmentCountTiersJSON`):
| Tier | Max Size (MB) | Connections |
|------|--------------|-------------|
| 1 | 4 | 1 |
| 2 | 50 | 2 |
| 3 | 200 | 4 |
| 4 | 1,024 | 6 |
| Catch-all | unlimited | 8 |

Tier management: "Add tier" and "Remove last tier" buttons.

#### Destination File
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 17 | Post-download action | Picker (None / Finder / Open / Extract) | `defaultPostDownloadAction` | `.none` | Default action after download completes. |
| 18 | File conflicts | Picker (Rename / Overwrite / Ask every time) | `destinationConflictPolicy` | `.rename` | Behavior when file with same name exists at destination. |


### PANEL 3: NETWORK — `NetworkSettingsPanel.swift`

#### Speed
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 19 | Global speed limit | Preset buttons (∞, 500K, 1M, 2M, 5M) | `globalSpeedLimitBytesPerSecond` | `0` (unlimited) | Caps speed across all active downloads. |
| 20 | Custom speed | Toggle | `useCustomSpeedLimit` | `false` | Use slider instead of presets. |
| 21 | Custom limit | Slider (0.1–50 MB/s) | `customSpeedLimitBytesPerSecond` | `3,000,000` | Custom max combined speed. |

#### Connection
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 22 | Start on Wi-Fi only | Toggle | `defaultStartWhenOnWiFi` | `false` | New downloads wait for Wi-Fi connection. |
| 23 | HTTP (Plaintext) | Info display | — | Allowed (ATS) | Unencrypted HTTP is allowed. |

#### Advanced
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 24 | Probe timeout | Stepper (5–120s, step 5) | `probeTimeoutSeconds` | `30` | Max wait when probing file metadata before download. |
| 25 | Segment retries | Stepper (1–10) | `segmentRetries` | `3` | Retries for failed segments before aborting download. |


### PANEL 4: INTEGRATION — `IntegrationSettingsPanel.swift`

#### Chrome Extension
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 26 | Chrome Extension status | Info card | — | — | Shows connection status. "Open Extension Folder" button. |
| 27 | Send Cookies & Referrer | Toggle | `sendBrowserHeadersByDefault` | `true` | Sends browser session for protected extension downloads. |

#### Domain Rules (`DomainRuleStore`)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 28 | Domain Rules | TextField (pattern) + Picker (Default / Auto-Start / Always Ask / Blocked) + Add + per-rule Delete | `domainRules` | none | Host or wildcard (*.example.com). Longer patterns take precedence. |

#### Learned Rules (`DownloadLearningStore`)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 29 | Learned hosts | Per-host delete + "Clear host data" button | `intelligence.hostPreferences` | none | Remembered folder per host. |
| 30 | Learned file types | Per-type delete + "Clear type rules" button | `intelligence.extensionRules` | none | Remembered post-download actions by extension. |


### PANEL 5: INTELLIGENCE — `IntelligenceSettingsPanel.swift`

#### General (never disabled)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| **31** | **Enable smart features** | **Toggle (MASTER SWITCH)** | `smartFeaturesEnabled` | `true` | Master switch for all smart suggestions, filters, and automations. Gate for items 32–41. |

#### Learning & Suggestions (disabled when #31 is off)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 32 | Remember folder per domain | Toggle | `rememberFolderPerHost` | `true` | Suggests last-used save location per host. |
| 33 | Detect content duplicates | Toggle | `detectContentDuplicates` | `true` | Warns when filename + size match existing completed download. |
| 34 | Post-download actions by type | Toggle | `smartPostDownloadActions` | `true` | Suggests extract for archives, open for DMG, etc. |

#### Download Engine (disabled when #31 is off)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 35 | Fair bandwidth sharing | Toggle | `fairBandwidthSharing` | `true` | Splits global speed limit evenly across active downloads. |
| 36 | Stall detection | Toggle | `stallDetectionEnabled` | `true` | Detects downloads with no progress. |
| 37 | Stall timeout (seconds) | Stepper (30–600, step 30) | `stallTimeoutSeconds` | `120` | Time without progress before considered stalled. |
| 38 | Auto-retry on stall | Toggle | `stallAutoRetry` | `true` | Pauses and resumes stalled downloads automatically. |

#### UI & Filters (disabled when #31 is off)
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 39 | Inspector insights | Toggle | `showInspectorInsights` | `true` | Contextual hints in download inspector. |
| 40 | Smart sidebar filters | Toggle | `showSmartSidebarFilters` | `true` | Shows File Missing, Today, Large Files filters. |
| 41 | Large files from (GB) | Stepper (1–50) | `largeFileThresholdGB` | `1` | Threshold for Large Files sidebar filter. |


### PANEL 6: NOTIFICATIONS — `NotificationsSettingsPanel.swift`

#### System Notifications
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 42 | Download completed | Toggle | `notifyOnComplete` | `true` | Notification when download finishes. |
| 43 | Download failed | Toggle | `notifyOnFailed` | `true` | Notification on errors with file name and error. |
| 44 | Download stalled | Toggle | `notifyOnStall` | `true` | Notification when download stops making progress. |
| 45 | Queue backlog | Toggle | `notifyOnQueueBacklog` | `false` | Notification when many downloads waiting. |
| 46 | Queue backlog threshold | Stepper (3–20) | `queueBacklogThreshold` | `5` | Count of waiting downloads before notification. |
| 47 | Play sound | Toggle | `playNotificationSound` | `true` | System sound for notifications. |

#### Dock
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 48 | Show active downloads in Dock | Toggle | `showDockBadge` | `true` | Badge count on Dock icon. |

#### System Settings
| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 49 | Notifications in System Settings | Action button | — | — | Opens macOS notification permissions. |


### PANEL 7: HOTKEYS — `HotkeysSettingsPanel.swift`

27 customizable shortcuts across 5 categories. Each has a Record button and Reset button. Stored in `AppShortcutSettings` (`appShortcutOverrides` key).

#### File
| Action | Default |
|--------|---------|
| Add Download | ⌘N |
| Add Download from Clipboard | ⇧⌘V |
| Open File | ⌘O |
| Reveal in Finder | ⇧⌘R |
| Copy URL | ⇧⌘C |
| Open Downloads Folder | ⇧⌘D |
| New Folder | ⇧⌘N |

#### Edit
| Action | Default |
|--------|---------|
| Select All | ⌘A |
| Deselect All | Esc |
| Delete | ⌘⌫ |
| Clear Completed | ⇧⌘K |

#### Download
| Action | Default |
|--------|---------|
| Search Downloads | ⌘F |
| Resume | ⌘R |
| Pause | ⌥⌘P |
| Cancel | ⌘. |
| Resume All | ⌥⌘R |
| Pause All | ⇧⌘P |

#### View
| Action | Default |
|--------|---------|
| History | ⌘Y |
| Toggle Inspector | ⌘I |
| Settings | ⌘, |

#### Sidebar
| Action | Default |
|--------|---------|
| All Downloads | ⌘1 |
| Queue | ⌘2 |
| Downloading | ⌘3 |
| Paused | ⌘4 |
| Completed | ⌘5 |
| Failed | ⌘6 |
| Scheduled | ⌘7 |

**Reset All** button at the bottom.


### PANEL 8: ADVANCED — `AdvancedSettingsPanel.swift`

| # | Setting (EN) | Type | Key | Default | What it does |
|---|-------------|------|-----|---------|-------------|
| 50 | Keep history for | Stepper (7–365 days, step 7) | `historyRetentionDays` | `30` | Auto-deletes history entries after this period. |
| 51 | Clear history | Destructive button | calls `downloadManager.clearHistory()` | — | Immediately deletes all history entries. |
| 52 | Recently Used Destination Folders | List + "Reset list" button | `RecentDestinationsStore` | — | Up to 5 recently used folders for quick pick in confirmation dialog. |
| 53 | Export diagnostics… | Action button | calls `SandboxDiagnostics.exportDiagnosticReport()` | — | Saves system info, paths, settings as .txt for troubleshooting. |
| 54 | Reset all settings… | Destructive button (with confirm) | calls `appSettings.resetAllSettings()` | — | Resets all settings, domain rules, and destinations to defaults. |
| 55 | Database | Info display | — | `~/Library/Application Support/default.store` | Path to SwiftData database. |


### PANEL 9: ABOUT — `AboutSettingsPanel.swift`

| # | Element | Details |
|---|---------|---------|
| 56 | App icon | 64×64 NSApp.applicationIconImage |
| 57 | App name | "Swift Download Manager" |
| 58 | Version | `CFBundleShortVersionString (CFBundleVersion)` |
| 59 | Chrome Extension version | `AppConstants.chromeExtensionVersionLabel` |
| 60 | Developer | "Marvin" |
| 61 | Platform | "macOS" |
| 62 | Description | "Multi-segment downloads, browser integration, and confirmation dialogs for safe downloads." |


## C. Non-UI Settings (defined in AppSettings but not shown in settings UI)

| Property | Key | Default |
|----------|-----|---------|
| Inspector collapsed state | `inspectorCollapsed` | `false` |
| Inspector expanded height | `inspectorExpandedHeight` | `AppTheme.inspectorExpandedHeightDefault` |
| Adaptive segment count | `adaptiveSegmentCount` | `true` |


## D. Settings File Map

| File | Contains |
|------|----------|
| `Core/Settings/AppSettings.swift` | All UserDefaults-backed properties |
| `Core/Settings/AppShortcutSettings.swift` | Hotkey overrides persistence |
| `Core/Settings/AppShortcutAction.swift` | All 27 shortcut action definitions |
| `Core/Settings/StoredShortcut.swift` | Shortcut data model |
| `Views/Settings/SettingsView.swift` | Settings root (sidebar + detail) |
| `Views/Settings/SettingsSection.swift` | Section enum (9 sections) |
| `Views/Settings/SettingsNavigation.swift` | Navigation helpers |
| `Views/Settings/SettingsShared.swift` | Shared layout constants |
| `Views/Settings/Panels/GeneralSettingsPanel.swift` | Panel 1 |
| `Views/Settings/Panels/DownloadsSettingsPanel.swift` | Panel 2 |
| `Views/Settings/Panels/NetworkSettingsPanel.swift` | Panel 3 |
| `Views/Settings/Panels/IntegrationSettingsPanel.swift` | Panel 4 |
| `Views/Settings/Panels/IntelligenceSettingsPanel.swift` | Panel 5 |
| `Views/Settings/Panels/NotificationsSettingsPanel.swift` | Panel 6 |
| `Views/Settings/Panels/HotkeysSettingsPanel.swift` | Panel 7 |
| `Views/Settings/Panels/AdvancedSettingsPanel.swift` | Panel 8 |
| `Views/Settings/Panels/AboutSettingsPanel.swift` | Panel 9 |
| `Views/Settings/Components/` | 20 reusable settings UI components |
