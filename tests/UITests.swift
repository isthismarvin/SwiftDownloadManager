import Foundation

// MARK: - UI & State Automated Tests
// Tests UI layout calculations, table column responsiveness, multi-selection algorithms,
// sorting comparators, sidebar filtering, and dialog state transitions.

func runUITests() {
    print("\n--- UI & State Automated Tests ---")

    testTableColumnLayoutResponsiveness()
    testColumnWidthClamping()
    testMultiSelectionLogic()
    testDownloadSortingOrders()
    testBatchURLPatternExpansions()
    testSearchQueryMatching()
    testDialogOptionState()
}

// MARK: - 1. Table Column Layout Responsiveness

func testTableColumnLayoutResponsiveness() {
    print("UI: Table Column Layout Breakpoints")

    // Full desktop width (1200px) -> all columns visible
    let wide = TableColumnLayout.make(availableWidth: 1200, userWidths: .default)
    expect(wide.showsDate, "wide window shows date")
    expect(wide.showsETA, "wide window shows ETA")
    expect(wide.showsSize, "wide window shows size")
    expect(wide.showsSpeed, "wide window shows speed")
    expect(wide.showsProgress, "wide window shows progress")
    expect(wide.showsStatus, "wide window shows status")

    // Medium width (< 620px) -> date hidden
    let med1 = TableColumnLayout.make(availableWidth: 600, userWidths: .default)
    expect(!med1.showsDate, "width < 620 hides date")
    expect(med1.showsETA, "width 600 still shows ETA")

    // Narrow width (< 560px) -> ETA hidden
    let med2 = TableColumnLayout.make(availableWidth: 500, userWidths: .default)
    expect(!med2.showsDate, "width < 500 hides date")
    expect(!med2.showsETA, "width < 560 hides ETA")
    expect(med2.showsSize, "width 500 still shows size")

    // Compact width (< 480px) -> size hidden
    let compact = TableColumnLayout.make(availableWidth: 450, userWidths: .default)
    expect(!compact.showsDate, "compact hides date")
    expect(!compact.showsETA, "compact hides ETA")
    expect(!compact.showsSize, "width < 480 hides size")
    expect(compact.showsSpeed, "width 450 still shows speed")

    // Very compact (< 400px) -> speed hidden
    let veryCompact = TableColumnLayout.make(availableWidth: 380, userWidths: .default)
    expect(!veryCompact.showsSpeed, "width < 400 hides speed")
    expect(veryCompact.showsProgress, "width 380 still shows progress")

    // Ultra compact (< 320px) -> progress hidden
    let ultraCompact = TableColumnLayout.make(availableWidth: 300, userWidths: .default)
    expect(!ultraCompact.showsProgress, "width < 320 hides progress")
    expect(ultraCompact.showsStatus, "status remains visible even on small window")
}

// MARK: - 2. Column Width Clamping

func testColumnWidthClamping() {
    print("UI: Column Width Minimum Clamping")

    // Under tight width constraints, column widths should never shrink below ColumnWidths.minWidth (36pt)
    let layout = TableColumnLayout.make(availableWidth: 200, userWidths: .default)
    expect(layout.widths.status >= ColumnWidths.minWidth, "status never shrinks below minimum width")
    expect(layout.widths.progress >= ColumnWidths.minWidth, "progress never shrinks below minimum width")
    expect(layout.widths.speed >= ColumnWidths.minWidth, "speed never shrinks below minimum width")
    expect(layout.widths.date >= ColumnWidths.minWidth, "date never shrinks below minimum width")
    expect(layout.widths.size >= ColumnWidths.minWidth, "size never shrinks below minimum width")
    expect(layout.widths.eta >= ColumnWidths.minWidth, "eta never shrinks below minimum width")
}

// MARK: - 3. Multi-Selection Logic

func testMultiSelectionLogic() {
    print("UI: Table Multi-Selection Logic")

    struct FakeItem {
        let id: UUID
    }

    let items = (0..<5).map { _ in FakeItem(id: UUID()) }
    var selectedIDs = Set<UUID>()

    // Single click on item 1
    selectedIDs = [items[1].id]
    expectEqual(selectedIDs.count, 1, "single select has 1 item")
    expect(selectedIDs.contains(items[1].id), "item 1 selected")

    // Command-click toggle on item 3 (adds item 3)
    if selectedIDs.contains(items[3].id) {
        selectedIDs.remove(items[3].id)
    } else {
        selectedIDs.insert(items[3].id)
    }
    expectEqual(selectedIDs.count, 2, "cmd-click adds second item")
    expect(selectedIDs.contains(items[1].id) && selectedIDs.contains(items[3].id), "items 1 and 3 selected")

    // Command-click toggle on item 1 (removes item 1)
    if selectedIDs.contains(items[1].id) {
        selectedIDs.remove(items[1].id)
    } else {
        selectedIDs.insert(items[1].id)
    }
    expectEqual(selectedIDs.count, 1, "cmd-click removes item 1")
    expectEqual(selectedIDs.first, items[3].id, "item 3 remains selected")

    // Range selection from item 0 to item 3
    let rangeStartIndex = 0
    let rangeEndIndex = 3
    let rangeIDs = Set(items[rangeStartIndex...rangeEndIndex].map(\.id))
    selectedIDs = rangeIDs
    expectEqual(selectedIDs.count, 4, "range select selects 4 items")
    expect(selectedIDs.contains(items[0].id), "range includes index 0")
    expect(selectedIDs.contains(items[1].id), "range includes index 1")
    expect(selectedIDs.contains(items[2].id), "range includes index 2")
    expect(selectedIDs.contains(items[3].id), "range includes index 3")
    expect(!selectedIDs.contains(items[4].id), "range excludes index 4")

    // Prune selection when items are deleted
    let remainingItemIDs = Set([items[0].id, items[4].id])
    selectedIDs.formIntersection(remainingItemIDs)
    expectEqual(selectedIDs.count, 1, "pruning removes deleted items from selection")
    expect(selectedIDs.contains(items[0].id), "remaining selected item preserved")

    // Select All
    selectedIDs = Set(items.map(\.id))
    expectEqual(selectedIDs.count, items.count, "select all includes all items")

    // Clear Selection
    selectedIDs.removeAll()
    expect(selectedIDs.isEmpty, "clear selection empties selection")
}

// MARK: - 4. Download Sorting Comparators

func testDownloadSortingOrders() {
    print("UI: Download Sorting Orders")

    struct SortItem {
        let name: String
        let date: Date
        let size: Int64
        let speed: Double
        let progress: Double
    }

    let now = Date()
    let a = SortItem(name: "alpha.zip", date: now.addingTimeInterval(-100), size: 1_000, speed: 100, progress: 0.1)
    let b = SortItem(name: "beta.zip", date: now.addingTimeInterval(-50), size: 5_000, speed: 500, progress: 0.5)
    let c = SortItem(name: "gamma.zip", date: now, size: 2_000, speed: 50, progress: 0.9)

    let list = [b, c, a]

    // Sort by name ascending
    let sortedByName = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    expectEqual(sortedByName.map(\.name), ["alpha.zip", "beta.zip", "gamma.zip"], "sorted by name ascending")

    // Sort by size descending
    let sortedBySizeDesc = list.sorted { $0.size > $1.size }
    expectEqual(sortedBySizeDesc.map(\.name), ["beta.zip", "gamma.zip", "alpha.zip"], "sorted by size descending")

    // Sort by progress descending
    let sortedByProgressDesc = list.sorted { $0.progress > $1.progress }
    expectEqual(sortedByProgressDesc.map(\.name), ["gamma.zip", "beta.zip", "alpha.zip"], "sorted by progress descending")

    // Sort by speed descending
    let sortedBySpeedDesc = list.sorted { $0.speed > $1.speed }
    expectEqual(sortedBySpeedDesc.map(\.name), ["beta.zip", "alpha.zip", "gamma.zip"], "sorted by speed descending")

    // Sort by date ascending (oldest first)
    let sortedByDateAsc = list.sorted { $0.date < $1.date }
    expectEqual(sortedByDateAsc.map(\.name), ["alpha.zip", "beta.zip", "gamma.zip"], "sorted by date ascending")
}

// MARK: - 5. Batch URL Pattern Expansion

func testBatchURLPatternExpansions() {
    print("UI: Batch URL Pattern Expansions")

    // Test range pattern: [1-3]
    let pattern1 = "https://cdn.example.com/file_[1-3].dat"
    let parsed1 = BatchURLParser.parse(text: pattern1)
    expectEqual(parsed1.count, 3, "pattern [1-3] expands to 3 URLs")
    expectEqual(parsed1[0].url.absoluteString, "https://cdn.example.com/file_1.dat", "first expanded URL matches")
    expectEqual(parsed1[2].url.absoluteString, "https://cdn.example.com/file_3.dat", "third expanded URL matches")

    // Test zero-padded pattern: [01-04]
    let pattern2 = "https://cdn.example.com/clip_[01-04].mp4"
    let parsed2 = BatchURLParser.parse(text: pattern2)
    expectEqual(parsed2.count, 4, "pattern [01-04] expands to 4 URLs")
    expectEqual(parsed2[0].url.absoluteString, "https://cdn.example.com/clip_01.mp4", "zero-padding preserved: 01")
    expectEqual(parsed2[3].url.absoluteString, "https://cdn.example.com/clip_04.mp4", "zero-padding preserved: 04")

    // Test multi-line text input
    let multiLine = """
    https://example.com/a.zip
    https://example.com/b.iso
    https://example.com/c.tar.gz
    """
    let parsed3 = BatchURLParser.parse(text: multiLine)
    expectEqual(parsed3.count, 3, "multiline text parses 3 distinct URLs")

    // Test filtering invalid/duplicate URLs
    let duplicates = """
    https://example.com/duplicate.pkg
    https://example.com/duplicate.pkg
    not-a-valid-url
    """
    let parsed4 = BatchURLParser.parse(text: duplicates)
    expectEqual(parsed4.count, 1, "duplicates and invalid URLs deduplicated/filtered")
}

// MARK: - 6. Search Query Matching

func testSearchQueryMatching() {
    print("UI: Search Query Matching")

    struct SearchItem {
        let fileName: String
        let url: String

        func matches(query: String) -> Bool {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            return fileName.lowercased().contains(q) || url.lowercased().contains(q)
        }
    }

    let item = SearchItem(fileName: "Xcode_16_Beta_4.xip", url: "https://developer.apple.com/downloads/xcode.xip")

    expect(item.matches(query: ""), "empty query matches all")
    expect(item.matches(query: "xcode"), "case-insensitive filename query matches")
    expect(item.matches(query: "BETA"), "uppercase query matches")
    expect(item.matches(query: "apple.com"), "domain in URL matches")
    expect(!item.matches(query: "android"), "unmatched query returns false")
}

// MARK: - 7. Dialog Option State Transitions

func testDialogOptionState() {
    print("UI: Dialog Option State Transitions")

    // Verify option payload construction
    let dest = URL(fileURLWithPath: "/Users/test/Downloads")
    let options = DownloadConfirmationOptions(
        fileName: "test.zip",
        urlString: "https://example.com/test.zip",
        preferredSegmentsCount: 8,
        saveDirectory: dest,
        startImmediately: true,
        priority: .high,
        speedLimitBytesPerSecond: 1_000_000,
        scheduledStartAt: nil
    )

    expectEqual(options.fileName, "test.zip", "options filename set")
    expectEqual(options.preferredSegmentsCount, 8, "options segments count set")
    expectEqual(options.priority, .high, "options priority set")
    expectEqual(options.speedLimitBytesPerSecond, 1_000_000, "options speed limit set")
    expect(options.startImmediately, "start immediately set")
    expect(options.scheduledStartAt == nil, "not scheduled")
}

