import Foundation

@MainActor
class ScannerService: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentStatus: String = ""
    @Published var currentScannedSize: Int64 = 0
    
    func scan(categories: [CleanupCategory]) async -> [ScanResult] {
        isScanning = true
        progress = 0.0
        currentScannedSize = 0
        currentStatus = "Scanning..."
        
        var results: [ScanResult] = []
        let totalCategories = Double(categories.count)
        var completedCategories = 0
        
        // OPTIMIZATION: Parallel scanning using TaskGroup
        await withTaskGroup(of: ScanResult?.self) { group in
            for category in categories {
                group.addTask {
                    // Update status (on main actor)
                    await MainActor.run {
                        self.currentStatus = "Scanning \(category.rawValue)..."
                    }
                    
                    // Pass progress callback for real-time updates
                    let items = await self.scanCategory(category, progressCallback: { [weak self] itemCount, currentSize in
                        guard let self = self else { return }
                        Task { @MainActor in
                            // We don't update status text here to avoid flickering from multiple threads
                            // self.currentStatus = "Scanning \(category.rawValue)... (\(itemCount) items)"
                            self.currentScannedSize += currentSize
                        }
                    })
                    
                    if !items.isEmpty {
                        // Group items
                        let groups = self.groupItems(items, category: category)
                        return ScanResult(category: category, items: items, groups: groups)
                    }
                    return nil
                }
            }
            
            // Collect results
            for await result in group {
                if let result = result {
                    results.append(result)
                }
                
                // Update progress
                await MainActor.run {
                    completedCategories += 1
                    self.progress = Double(completedCategories) / totalCategories
                }
            }
        }
        
        // Sort results to maintain consistent order (optional, but good for UI)
        results.sort { $0.category.rawValue < $1.category.rawValue }
        
        isScanning = false
        currentStatus = "Scan Complete"
        
        return results
    }
    
    // ... (groupItems and getGroupName methods remain unchanged) ...
    
    nonisolated private func groupItems(_ items: [ScanItem], category: CleanupCategory) -> [ScanGroup] {
        var groups: [String: [ScanItem]] = [:]
        
        for item in items {
            let groupName = getGroupName(for: item, category: category)
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.append(item)
        }
        
        return groups.map { name, groupItems in
            // Sort items within the group by size (descending)
            let sortedItems = groupItems.sorted { $0.size > $1.size }
            return ScanGroup(name: name, items: sortedItems)
        }
        .sorted { $0.totalSize > $1.totalSize }
    }
    
    nonisolated private func getGroupName(for item: ScanItem, category: CleanupCategory) -> String {
        let path = item.path
        
        switch category {
        case .applicationCaches, .logs:
            // Try to find application name in path
            if let appName = extractAppName(from: path) {
                return appName
            }
            return "System / Other"
            
        case .oldDownloads:
            return "Downloads"
            
        default:
            // For system caches etc, try to group by parent folder
            let components = path.components(separatedBy: "/")
            if let index = components.firstIndex(of: "Caches"), index + 1 < components.count {
                return components[index + 1]
            }
            if let index = components.firstIndex(of: "Containers"), index + 1 < components.count {
                return components[index + 1]
            }
            return "Miscellaneous"
        }
    }
    
    nonisolated private func extractAppName(from path: String) -> String? {
        // Common patterns:
        // .../Application Support/Google/Chrome/... -> Google Chrome
        // .../Containers/com.apple.Safari/... -> Safari
        // .../Logs/Zoom/... -> Zoom
        
        let components = path.components(separatedBy: "/")
        
        // Check for Application Support
        if let index = components.firstIndex(of: "Application Support"), index + 1 < components.count {
            let appName = components[index + 1]
            // Check if next component is also part of name (e.g. Google/Chrome)
            if index + 2 < components.count && (appName == "Google" || appName == "Microsoft" || appName == "Adobe") {
                return "\(appName) \(components[index + 2])"
            }
            return appName
        }
        
        // Check for Containers (usually bundle IDs)
        if let index = components.firstIndex(of: "Containers"), index + 1 < components.count {
            let bundleId = components[index + 1]
            // Convert bundle ID to readable name (simplified)
            let parts = bundleId.components(separatedBy: ".")
            if let last = parts.last {
                return last.capitalized
            }
            return bundleId
        }
        
        // Check for Logs
        if let index = components.firstIndex(of: "Logs"), index + 1 < components.count {
            return components[index + 1]
        }
        
        return nil
    }
    
    nonisolated private func scanCategory(_ category: CleanupCategory, progressCallback: @escaping (Int, Int64) -> Void) async -> [ScanItem] {
        var items: [ScanItem] = []
        let fileManager = FileManager.default
        
        let paths: [URL] = getPaths(for: category)
        
        for path in paths {
            // Deep scan - no limits
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            // Use different strategies based on category
            if category == .systemCaches || category == .applicationCaches {
                items.append(contentsOf: await scanCachesDeep(at: path, fileManager: fileManager, progressCallback: progressCallback))
            } else if category == .logs {
                items.append(contentsOf: await scanLogsDeep(at: path, fileManager: fileManager, progressCallback: progressCallback))
            } else if category == .temporaryFiles {
                items.append(contentsOf: await scanTempDeep(at: path, fileManager: fileManager, progressCallback: progressCallback))
            } else if category == .browserData {
                // Browser data is just cache files, so we can use the deep cache scanner
                items.append(contentsOf: await scanCachesDeep(at: path, fileManager: fileManager, progressCallback: progressCallback))
            } else {
                items.append(contentsOf: await scanStandard(at: path, category: category, fileManager: fileManager, progressCallback: progressCallback))
            }
        }
        
        return items
    }
    
    nonisolated private func scanCachesDeep(at path: URL, fileManager: FileManager, progressCallback: @escaping (Int, Int64) -> Void) async -> [ScanItem] {
        var items: [ScanItem] = []
        var itemCount = 0
        var batchSize: Int64 = 0
        let updateInterval = 100 // Update progress every 100 items
        
        // Define browser paths to exclude if we are NOT scanning browser data
        // This prevents duplication if we scan System Caches (which includes ~/Library/Caches)
        let browserPathsToExclude: Set<String> = [
            "Google/Chrome",
            "com.apple.Safari",
            "Mozilla/Firefox",
            "Microsoft Edge",
            "BraveSoftware",
            "com.operasoftware.Opera",
            "com.operasoftware.OperaGX"
        ]
        
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: []
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                // Check exclusion logic
                let pathString = fileURL.path
                var shouldExclude = false
                
                // If this is a generic cache scan (not specifically browser data), check exclusions
                // We can identify if we are in a browser path by checking if the file path contains any of the browser cache folders
                // BUT, we only want to exclude them if we are scanning the parent folder (e.g. ~/Library/Caches)
                // If 'path' passed to this function IS one of the browser paths, we shouldn't exclude it.
                
                let isScanningParentCache = path.path.hasSuffix("/Library/Caches")
                
                if isScanningParentCache {
                    for browserPath in browserPathsToExclude {
                        // Check if the path contains the browser identifier
                        // We use case insensitive check just in case
                        if pathString.localizedCaseInsensitiveContains("/\(browserPath)") {
                            shouldExclude = true
                            break
                        }
                    }
                }
                
                if !shouldExclude,
                   let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                   let size = attributes.fileSize,
                   let date = attributes.contentModificationDate,
                   let isDir = attributes.isDirectory,
                   !isDir,
                   size > 0 {
                    items.append(ScanItem(url: fileURL, size: Int64(size), lastModified: date))
                    itemCount += 1
                    batchSize += Int64(size)
                    
                    // OPTIMIZATION: Batch progress updates
                    if itemCount % updateInterval == 0 {
                        progressCallback(itemCount, batchSize)
                        batchSize = 0
                    }
                }
            }
        }
        
        // Final update
        if itemCount % updateInterval != 0 {
            progressCallback(itemCount, batchSize)
        }
        
        return items
    }
    
    nonisolated private func scanLogsDeep(at path: URL, fileManager: FileManager, progressCallback: @escaping (Int, Int64) -> Void) async -> [ScanItem] {
        var items: [ScanItem] = []
        var itemCount = 0
        var batchSize: Int64 = 0
        let updateInterval = 100
        
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: []
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                   let size = attributes.fileSize,
                   let date = attributes.contentModificationDate,
                   let isDir = attributes.isDirectory,
                   !isDir,
                   size > 0 {
                    
                    // Include all log files
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "log" || ext == "crash" || ext == "diag" || ext.isEmpty {
                        items.append(ScanItem(url: fileURL, size: Int64(size), lastModified: date))
                        itemCount += 1
                        batchSize += Int64(size)
                        
                        if itemCount % updateInterval == 0 {
                            progressCallback(itemCount, batchSize)
                            batchSize = 0
                        }
                    }
                }
            }
        }
        
        if itemCount % updateInterval != 0 {
            progressCallback(itemCount, batchSize)
        }
        
        return items
    }
    
    nonisolated private func scanTempDeep(at path: URL, fileManager: FileManager, progressCallback: @escaping (Int, Int64) -> Void) async -> [ScanItem] {
        var items: [ScanItem] = []
        var itemCount = 0
        var batchSize: Int64 = 0
        let updateInterval = 100
        
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: []
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                   let size = attributes.fileSize,
                   let date = attributes.contentModificationDate,
                   let isDir = attributes.isDirectory,
                   !isDir,
                   size > 0 {
                    items.append(ScanItem(url: fileURL, size: Int64(size), lastModified: date))
                    itemCount += 1
                    batchSize += Int64(size)
                    
                    if itemCount % updateInterval == 0 {
                        progressCallback(itemCount, batchSize)
                        batchSize = 0
                    }
                }
            }
        }
        
        if itemCount % updateInterval != 0 {
            progressCallback(itemCount, batchSize)
        }
        
        return items
    }
    
    nonisolated private func scanStandard(at path: URL, category: CleanupCategory, fileManager: FileManager, progressCallback: @escaping (Int, Int64) -> Void) async -> [ScanItem] {
        var items: [ScanItem] = []
        var itemCount = 0
        var batchSize: Int64 = 0
        let updateInterval = 100
        
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: []
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                   let size = attributes.fileSize,
                   let date = attributes.contentModificationDate,
                   let isDir = attributes.isDirectory,
                   !isDir,
                   size > 0 {
                    
                    // Filter logic for old downloads
                    if category == .oldDownloads {
                        let thirtyDaysAgo = Date().addingTimeInterval(-30*24*60*60)
                        if date > thirtyDaysAgo { return }
                    }
                    
                    items.append(ScanItem(url: fileURL, size: Int64(size), lastModified: date))
                    itemCount += 1
                    batchSize += Int64(size)
                    
                    if itemCount % updateInterval == 0 {
                        progressCallback(itemCount, batchSize)
                        batchSize = 0
                    }
                }
            }
        }
        
        if itemCount % updateInterval != 0 {
            progressCallback(itemCount, batchSize)
        }
        
        return items
    }
    
    nonisolated private func getPaths(for category: CleanupCategory) -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        switch category {
        case .systemCaches:
            return [
                home.appendingPathComponent("Library/Caches"),
                home.appendingPathComponent("Library/Application Support/CachedData"),
                home.appendingPathComponent("Library/Safari/LocalStorage"),
                home.appendingPathComponent("Library/Safari/Databases")
            ]
        case .applicationCaches:
            return [
                home.appendingPathComponent("Library/Application Support"),
                home.appendingPathComponent("Library/Containers")
            ].filter { fileManager.fileExists(atPath: $0.path) }
        case .logs:
            return [
                home.appendingPathComponent("Library/Logs"),
                home.appendingPathComponent("Library/Application Support/CrashReporter")
            ]
        case .temporaryFiles:
            return [
                URL(fileURLWithPath: NSTemporaryDirectory()),
                home.appendingPathComponent("Library/Caches/TemporaryItems")
            ]
        case .oldDownloads:
            return [home.appendingPathComponent("Downloads")]
        case .browserData:
            return [
                home.appendingPathComponent("Library/Caches/Google/Chrome"),
                home.appendingPathComponent("Library/Caches/com.apple.Safari"),
                home.appendingPathComponent("Library/Caches/Mozilla/Firefox"),
                home.appendingPathComponent("Library/Caches/Microsoft Edge"),
                home.appendingPathComponent("Library/Caches/BraveSoftware"),
                home.appendingPathComponent("Library/Caches/com.operasoftware.Opera"),
                home.appendingPathComponent("Library/Caches/com.operasoftware.OperaGX")
            ].filter { fileManager.fileExists(atPath: $0.path) }
        }
    }
}
