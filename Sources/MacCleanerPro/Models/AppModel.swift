import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var scanResults: [ScanResult] = [] {
        didSet { recomputeStats() }
    }
    @Published var lastScanDate: Date?
    @Published var lastReport: CleanReport?
    /// Cached totals. Views read these instead of walking 100,000+ files on every redraw.
    @Published private(set) var stats = ScanStats()

    let scannerService = ScannerService()
    let cleanerService = CleanerService()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Views read scanner/cleaner state through this model, so pass their changes on.
        // Throttled: progress can change hundreds of times a second during a scan.
        // receive(on:) delivers after the change has landed, so a redraw never shows stale values.
        scannerService.objectWillChange
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(60), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        cleanerService.objectWillChange
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(60), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Re-total when files are checked, unchecked or deleted.
        ScanItem.changed
            .throttle(for: .milliseconds(80), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.recomputeStats() }
            .store(in: &cancellables)
    }

    var isScanning: Bool { scannerService.isScanning }
    var isCleaning: Bool { cleanerService.isCleaning }

    var totalJunkSize: Int64 { stats.totalActiveSize }
    var selectedSize: Int64 { stats.selectedSize }

    /// Exactly what "Clean" will act on: checked and not already deleted.
    var selectedItems: [ScanItem] {
        scanResults.flatMap { $0.items }.filter { $0.isSelected && $0.isActive }
    }

    /// One pass over every file: category totals, selection totals and group totals.
    func recomputeStats() {
        var next = ScanStats()
        for result in scanResults {
            var category = ScanStats.CategoryStats()
            var allSelected = true
            for item in result.items where item.isActive {
                category.activeCount += 1
                category.activeSize += item.size
                if item.isSelected {
                    next.selectedSize += item.size
                    next.selectedCount += 1
                } else {
                    allSelected = false
                }
            }
            category.allSelected = category.activeCount > 0 && allSelected
            next.totalActiveSize += category.activeSize
            next.categories[result.category] = category

            for group in result.groups { group.refreshStats() }
        }
        stats = next
    }

    func startScan() async {
        _ = PermissionManager.shared.checkFullDiskAccess()
        scanResults = []
        lastReport = nil
        let results = await scannerService.scan(categories: CleanupCategory.allCases)
        scanResults = results
        lastScanDate = Date()
    }

    /// Text for the confirmation dialog: what will be removed, from where, and how.
    func cleanupSummary() -> String {
        let lines = CleanupCategory.allCases.compactMap { category -> String? in
            guard let result = scanResults.first(where: { $0.category == category }) else { return nil }
            var count = 0
            var size: Int64 = 0
            for item in result.items where item.isActive && item.isSelected {
                count += 1
                size += item.size
            }
            guard count > 0 else { return nil }
            let how = category.deletesPermanently ? "deleted" : "moved to Trash"
            return "• \(category.rawValue): \(count) items, \(formatBytes(size)) (\(how))"
        }
        return lines.joined(separator: "\n")
    }

    func performCleanup() async {
        let report = await cleanerService.clean(items: selectedItems)
        lastReport = report
        recomputeStats()
    }

    /// One line describing the last cleanup, or nil if there wasn't one.
    func lastReportText() -> String? {
        guard let r = lastReport else { return nil }
        var parts: [String] = []
        if r.freedBytes > 0 { parts.append("Deleted \(formatBytes(r.freedBytes))") }
        if r.trashedBytes > 0 { parts.append("\(formatBytes(r.trashedBytes)) moved to Trash (empty it to free the space)") }
        if !r.wasDryRun { parts.append("disk free \(r.diskFreeChange >= 0 ? "+" : "−")\(formatBytes(abs(r.diskFreeChange)))") }
        if r.skippedCount > 0 { parts.append("\(r.skippedCount) skipped") }
        if r.failedCount > 0 { parts.append("\(r.failedCount) failed") }
        if r.wasCancelled { parts.append("stopped early") }
        return parts.isEmpty ? "Nothing was removed" : parts.joined(separator: " · ")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter
    }()

    func formatBytes(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }
}
