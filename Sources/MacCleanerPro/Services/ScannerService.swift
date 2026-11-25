import Foundation
import Darwin
import AppKit

/// How scanning works:
/// 1. Every category has a list of folders ("targets") to walk.
/// 2. All categories are walked in parallel. Each regular file becomes a ScanItem with its
///    real on-disk size. Symlinks, hard-linked files and too-recent files are skipped.
/// 3. Files found by more than one category are kept only once (CleanupCategory.claimOrder).
/// 4. Files are grouped by app/folder. Groups under 5 MB are collected into one
///    "Small folders" group so the list stays readable.
/// Groups smaller than this are put together in one "Small folders" group.
private let smallGroupThreshold: Int64 = 5 * 1024 * 1024

/// A folder to walk, and how to name the groups inside it.
fileprivate struct ScanTarget {
    let root: URL
    /// Fixed group name. When nil, the first sub-folder under `root` is used.
    let fixedGroup: String?
    /// Skip files modified more recently than this (seconds). Stops deleting files that are still in use.
    var minAge: TimeInterval = 0
    /// Top-level sub-folders of `root` to leave alone.
    var excluded: Set<String> = []
}

@MainActor
final class ScannerService: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentStatus: String = ""
    @Published var currentScannedSize: Int64 = 0

    /// Categories that stopped responding during the last scan (usually a macOS permission prompt).
    @Published var skippedCategories: [CleanupCategory] = []

    /// A category that sends no progress for this long is treated as stuck and skipped,
    /// so one blocked folder can't freeze the whole scan (the old version waited forever).
    private let stallTimeout: TimeInterval = 45

    func scan(categories: [CleanupCategory]) async -> [ScanResult] {
        isScanning = true
        progress = 0.0
        currentScannedSize = 0
        skippedCategories = []
        currentStatus = "Scanning..."

        // Running apps count as installed (for App Leftovers). Read here, on the main thread.
        let running: [LeftoverFinder.RunningApp] = NSWorkspace.shared.runningApplications.map {
            ($0.bundleIdentifier, $0.localizedName)
        }

        let monitor = ScanMonitor(categories: categories)
        let found: [CleanupCategory: [ScanItem]] = await withCheckedContinuation { continuation in
            monitor.onComplete = { continuation.resume(returning: $0) }

            // Each category runs on its own. If one gets stuck, the others still finish
            // and the stuck one is left behind instead of holding up the scan.
            for category in categories {
                Task.detached(priority: .userInitiated) { [weak self] in
                    let items = ScannerService.scanCategory(category, running: running) { bytes in
                        Task { @MainActor in
                            self?.currentScannedSize += bytes
                            monitor.touch(category)
                        }
                    }
                    await MainActor.run { monitor.finish(category, items: items) }
                }
            }

            // Watchdog: refresh the status line and give up on categories that went silent.
            Task { @MainActor [weak self] in
                while !monitor.isComplete {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self else { return }
                    monitor.abandonStalled(after: self.stallTimeout)
                    self.progress = monitor.fractionDone
                    let pending = monitor.pendingNames
                    self.currentStatus = pending.isEmpty ? "Organizing results..." : "Scanning \(pending.joined(separator: ", "))"
                }
            }

            monitor.completeIfDone()
        }

        skippedCategories = monitor.abandoned
        progress = 1.0
        currentStatus = "Organizing results..."
        let results = await Task.detached(priority: .userInitiated) {
            ScannerService.buildResults(from: found)
        }.value

        isScanning = false
        currentStatus = "Scan Complete"
        return results
    }

    // MARK: - Results

    nonisolated private static func buildResults(from found: [CleanupCategory: [ScanItem]]) -> [ScanResult] {
        var claimed = Set<String>()
        var claimedFolders = Set<String>()
        var results: [ScanResult] = []

        for category in CleanupCategory.claimOrder {
            guard let items = found[category] else { continue }
            // Each file belongs to exactly one category, so unchecking it in one list really unchecks it.
            // Files inside a folder that is already listed as a whole (an app leftover) are skipped too.
            let unique = items.filter { item in
                if isInside(item.path, anyOf: claimedFolders) { return false }
                return claimed.insert(item.path).inserted
            }
            for item in unique where item.isDirectory { claimedFolders.insert(item.path) }
            guard !unique.isEmpty else { continue }
            results.append(ScanResult(category: category, items: unique, groups: makeGroups(unique)))
        }

        results.sort { $0.category.rawValue < $1.category.rawValue }
        return results
    }

    nonisolated private static func isInside(_ path: String, anyOf folders: Set<String>) -> Bool {
        guard !folders.isEmpty else { return false }
        var current = path
        while true {
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current || parent.isEmpty || parent == "/" { return false }
            if folders.contains(parent) { return true }
            current = parent
        }
    }

    nonisolated private static func makeGroups(_ items: [ScanItem]) -> [ScanGroup] {
        var buckets: [String: [ScanItem]] = [:]
        for item in items {
            buckets[item.groupName, default: []].append(item)
        }

        var large: [ScanGroup] = []
        var small: [ScanGroup] = []
        for (name, groupItems) in buckets {
            let group = ScanGroup(name: name, items: groupItems.sorted { $0.size > $1.size })
            if group.totalSize < smallGroupThreshold {
                small.append(group)
            } else {
                large.append(group)
            }
        }
        large.sort { $0.totalSize > $1.totalSize }
        small.sort { $0.totalSize > $1.totalSize }

        if small.count >= 2 {
            let bucket = ScanGroup(
                name: "Small folders under 5 MB (\(small.count))",
                items: small.flatMap { $0.items },
                subgroups: small
            )
            large.append(bucket)
        } else {
            large.append(contentsOf: small)
        }
        return large
    }

    // MARK: - Targets

    nonisolated private static func targets(for category: CleanupCategory) -> [ScanTarget] {
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let caches = library.appendingPathComponent("Caches")

        switch category {
        case .systemCaches:
            return [ScanTarget(
                root: caches,
                fixedGroup: nil,
                // TemporaryItems belongs to Temporary Files (with an age limit).
                // iCloud and download-daemon caches can hold data that isn't synced or finished yet.
                excluded: ["TemporaryItems", "com.apple.bird", "CloudKit", "com.apple.nsurlsessiond"]
            )]

        case .browserData:
            let browsers: [(String, String)] = [
                ("Google/Chrome", "Chrome"),
                ("com.apple.Safari", "Safari"),
                ("Firefox", "Firefox"),
                ("Mozilla/Firefox", "Firefox"),
                ("Microsoft Edge", "Edge"),
                ("BraveSoftware", "Brave"),
                ("com.operasoftware.Opera", "Opera"),
                ("com.operasoftware.OperaGX", "Opera GX"),
                ("company.thebrowser.Browser", "Arc")
            ]
            return browsers.map { ScanTarget(root: caches.appendingPathComponent($0.0), fixedGroup: $0.1) }

        case .applicationCaches:
            var result: [ScanTarget] = []
            // Sandboxed apps keep their caches inside their container.
            let containers = library.appendingPathComponent("Containers")
            if let ids = try? fileManager.contentsOfDirectory(atPath: containers.path) {
                for id in ids where !id.hasPrefix(".") {
                    let cacheDir = containers.appendingPathComponent(id).appendingPathComponent("Data/Library/Caches")
                    result.append(ScanTarget(root: cacheDir, fixedGroup: id))
                }
            }
            // Cache folders inside Application Support (Electron apps, VS Code, Discord, Slack...).
            // The old version scanned ALL of Application Support, which is app data, not cache.
            result.append(contentsOf: appSupportCacheTargets(library.appendingPathComponent("Application Support")))
            return result

        case .logs:
            return [
                ScanTarget(root: library.appendingPathComponent("Logs"), fixedGroup: nil, minAge: 86_400),
                ScanTarget(root: library.appendingPathComponent("Application Support/CrashReporter"), fixedGroup: "CrashReporter", minAge: 86_400)
            ]

        case .temporaryFiles:
            return [
                ScanTarget(root: URL(fileURLWithPath: NSTemporaryDirectory()), fixedGroup: nil, minAge: 2 * 86_400),
                ScanTarget(root: caches.appendingPathComponent("TemporaryItems"), fixedGroup: "TemporaryItems", minAge: 2 * 86_400)
            ]

        case .oldDownloads, .appLeftovers:
            return [] // handled by scanDownloads / scanLeftovers
        }
    }

    /// Finds folders named like caches (see SafetyManager.cacheFolderNames) inside Application Support.
    nonisolated private static func appSupportCacheTargets(_ appSupport: URL) -> [ScanTarget] {
        let fileManager = FileManager.default
        let root = appSupport.resolvingSymlinksInPath()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let baseCount = root.pathComponents.count
        var result: [ScanTarget] = []

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isDirectory == true, values.isSymbolicLink != true else { continue }

            let components = url.pathComponents
            let depth = components.count - baseCount
            let name = url.lastPathComponent

            if depth == 1 && (name == "MobileSync" || name == "CrashReporter") {
                enumerator.skipDescendants()   // backups (protected) / handled by Logs
            } else if SafetyManager.cacheFolderNames.contains(name.lowercased()) {
                let app = components.count > baseCount ? components[baseCount] : name
                result.append(ScanTarget(root: url, fixedGroup: app))
                enumerator.skipDescendants()
            } else if depth >= 5 {
                enumerator.skipDescendants()   // caches are never this deep; don't walk huge data trees
            }
        }
        return result
    }

    // MARK: - Walking

    nonisolated private static func scanCategory(_ category: CleanupCategory, running: [LeftoverFinder.RunningApp], report: (Int64) -> Void) -> [ScanItem] {
        if category == .oldDownloads {
            return scanDownloads(report: report)
        }
        if category == .appLeftovers {
            return scanLeftovers(running: running, report: report)
        }
        return targets(for: category).flatMap { collect($0, category: category, report: report) }
    }

    nonisolated private static func collect(_ target: ScanTarget, category: CleanupCategory, report: (Int64) -> Void) -> [ScanItem] {
        let fileManager = FileManager.default
        // Resolve /var -> /private/var etc. once, so the same file always has the same path.
        let root = target.root.resolvingSymlinksInPath()
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey
        ]
        let keySet = Set(keys)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }   // keep going past folders we can't read
        ) else { return [] }

        let cutoff = Date().addingTimeInterval(-target.minAge)
        let rootCount = root.pathComponents.count
        var items: [ScanItem] = []
        var pendingBytes: Int64 = 0

        for case let url as URL in enumerator {
            autoreleasepool {
                let components = url.pathComponents
                if components.count == rootCount + 1, target.excluded.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    return
                }
                guard let values = try? url.resourceValues(forKeys: keySet),
                      values.isRegularFile == true, values.isSymbolicLink != true else { return }

                let modified = values.contentModificationDate ?? .distantPast
                if target.minAge > 0 && modified > cutoff { return }

                // Real space on disk. The old code used the logical size, which over-reports
                // sparse and compressed files.
                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                guard size > 0 else { return }

                // A file with several hard links frees nothing when one link is removed.
                if hardLinkCount(url.path) > 1 { return }

                let group = target.fixedGroup ?? (components.count > rootCount + 1 ? components[rootCount] : "Loose files")
                items.append(ScanItem(url: url, category: category, groupName: group, size: size, lastModified: modified))

                pendingBytes += size
                if items.count % 200 == 0 {
                    report(pendingBytes)
                    pendingBytes = 0
                }
            }
        }
        if pendingBytes > 0 { report(pendingBytes) }
        return items
    }

    /// Top-level items in Downloads that arrived 30+ days ago and haven't been opened since.
    /// Folders and apps are listed as one item each (the old code listed the files inside .app bundles).
    nonisolated private static func scanDownloads(report: (Int64) -> Void) -> [ScanItem] {
        let fileManager = FileManager.default
        let downloads = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").resolvingSymlinksInPath()
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .addedToDirectoryDateKey,
            .contentAccessDateKey, .contentModificationDateKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
        ]
        guard let entries = try? fileManager.contentsOfDirectory(
            at: downloads, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        var items: [ScanItem] = []

        for url in entries {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { continue }

            // The old code used the modification date, so a fresh download of an old file
            // (zip contents keep their original dates) was treated as "old".
            let added = values.addedToDirectoryDate ?? values.contentModificationDate ?? .distantPast
            guard added < cutoff else { continue }
            if let accessed = values.contentAccessDate, accessed > cutoff { continue }

            let isDirectory = values.isDirectory == true
            let size = isDirectory
                ? directorySize(url, report: report)
                : Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size > 0 else { continue }

            let group = downloadsGroup(for: url, isDirectory: isDirectory, isPackage: values.isPackage == true)
            items.append(ScanItem(url: url, category: .oldDownloads, groupName: group, size: size, lastModified: added, isDirectory: isDirectory))
            report(size)
        }
        return items
    }

    /// Whole folders/files left behind by deleted apps, grouped by app.
    nonisolated private static func scanLeftovers(running: [LeftoverFinder.RunningApp], report: (Int64) -> Void) -> [ScanItem] {
        let leftovers = LeftoverFinder.find(running: running)
        report(0)   // finding is done; tell the watchdog we're alive

        // Measure all leftover folders in parallel (the old loop did them one by one).
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        var sizes = [Int64](repeating: 0, count: leftovers.count)
        var dates = [Date](repeating: .distantPast, count: leftovers.count)
        sizes.withUnsafeMutableBufferPointer { sizePointer in
            dates.withUnsafeMutableBufferPointer { datePointer in
                let sizeBuffer = sizePointer
                let dateBuffer = datePointer
                DispatchQueue.concurrentPerform(iterations: leftovers.count) { index in
                    let leftover = leftovers[index]
                    let values = try? leftover.url.resourceValues(forKeys: keys)
                    dateBuffer[index] = values?.contentModificationDate ?? .distantPast
                    sizeBuffer[index] = leftover.isDirectory
                        ? directorySize(leftover.url, report: report)
                        : Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                }
            }
        }

        var items: [ScanItem] = []
        for (index, leftover) in leftovers.enumerated() where sizes[index] > 0 {
            items.append(ScanItem(
                url: leftover.url, category: .appLeftovers, groupName: leftover.app, size: sizes[index],
                lastModified: dates[index], isDirectory: leftover.isDirectory
            ))
            report(sizes[index])
        }
        // These live outside the usual cache folders, so tell the safety check they were vetted.
        SafetyManager.shared.approveLeftovers(Set(items.map { $0.path }))
        return items
    }

    nonisolated private static func downloadsGroup(for url: URL, isDirectory: Bool, isPackage: Bool) -> String {
        if isPackage { return "Apps & packages" }
        if isDirectory { return "Folders" }
        switch url.pathExtension.lowercased() {
        case "dmg", "pkg", "mpkg", "iso": return "Installers & disk images"
        case "zip", "rar", "7z", "tar", "gz", "tgz", "xz", "bz2": return "Archives"
        case "mp4", "mov", "mkv", "avi", "webm", "m4v": return "Videos"
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff": return "Images"
        case "mp3", "wav", "flac", "m4a", "aac": return "Audio"
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf", "pages", "numbers", "key": return "Documents"
        default: return "Other files"
        }
    }

    /// Total size of a folder. Calls report(0) now and then so the watchdog knows it's still working.
    nonisolated private static func directorySize(_ url: URL, report: (Int64) -> Void) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        var counted = 0
        for case let file as URL in enumerator {
            counted += 1
            if counted % 1000 == 0 { report(0) }
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    nonisolated private static func hardLinkCount(_ path: String) -> Int {
        var info = stat()
        return lstat(path, &info) == 0 ? Int(info.st_nlink) : 1
    }
}

/// Tracks which categories are still scanning and when each last showed signs of life.
@MainActor
private final class ScanMonitor {
    private(set) var found: [CleanupCategory: [ScanItem]] = [:]
    private(set) var abandoned: [CleanupCategory] = []
    private(set) var isComplete = false
    var onComplete: (([CleanupCategory: [ScanItem]]) -> Void)?

    private var pending: Set<CleanupCategory>
    private var lastActivity: [CleanupCategory: Date] = [:]
    private let total: Int

    init(categories: [CleanupCategory]) {
        pending = Set(categories)
        total = categories.count
        let now = Date()
        for category in categories { lastActivity[category] = now }
    }

    var fractionDone: Double {
        total == 0 ? 1 : Double(total - pending.count) / Double(total)
    }

    var pendingNames: [String] {
        CleanupCategory.allCases.filter { pending.contains($0) }.map { $0.rawValue }
    }

    func touch(_ category: CleanupCategory) {
        lastActivity[category] = Date()
    }

    func finish(_ category: CleanupCategory, items: [ScanItem]) {
        guard pending.contains(category) else { return }   // already given up on: ignore late results
        pending.remove(category)
        found[category] = items
        completeIfDone()
    }

    func abandonStalled(after timeout: TimeInterval) {
        let now = Date()
        for category in pending where now.timeIntervalSince(lastActivity[category] ?? now) > timeout {
            pending.remove(category)
            abandoned.append(category)
        }
        completeIfDone()
    }

    func completeIfDone() {
        guard pending.isEmpty, !isComplete, let onComplete else { return }
        isComplete = true
        self.onComplete = nil
        onComplete(found)
    }
}
