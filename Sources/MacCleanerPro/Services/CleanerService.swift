import Foundation

@MainActor
class CleanerService: ObservableObject {
    @Published var isCleaning: Bool = false
    @Published var progress: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var filesProcessed: Int = 0
    @Published var totalFiles: Int = 0
    @Published var currentFileName: String = ""
    
    private var cleaningTask: Task<Void, Never>?
    
    func clean(results: [ScanResult]) async -> Int64 {
        // Cancel any existing cleaning task
        cleaningTask?.cancel()
        
        isCleaning = true
        progress = 0.0
        filesProcessed = 0
        
        var totalCleaned: Int64 = 0
        
        // Collect all items to process (selected ones)
        var allItems: [ScanItem] = []
        for result in results {
            let itemsToProcess = result.items.filter { $0.isSelected && $0.status != .deleted }
            allItems.append(contentsOf: itemsToProcess)
        }
        
        // SORT BY SIZE DESCENDING: Delete biggest files first
        allItems.sort { $0.size > $1.size }
        
        totalFiles = allItems.count
        let startTime = Date()
        
        // ADAPTIVE IO CONFIGURATION
        let targetLatency: TimeInterval = 0.01 // 10ms target per file
        var currentSleepInterval: UInt64 = 0 // Nanoseconds
        let maxSleepInterval: UInt64 = 100_000_000 // 100ms max sleep
        
        // Batching for UI
        let batchSize = 10
        
        // Create background task for deletion
        cleaningTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            var batchCleaned: Int64 = 0
            var batchProcessedItems: [ScanItem] = []
            var batchStatusUpdates: [ScanItem: ScanItemStatus] = [:]
            
            var batchStartTime = Date()
            
            for (index, item) in allItems.enumerated() {
                // Check for cancellation
                if Task.isCancelled { break }
                
                let opStartTime = Date()
                var itemStatus: ScanItemStatus = .ready
                
                // 1. Safety Check & Deletion
                // We use a linear flow here: Check -> Delete -> Update. 
                // No 'return' or 'continue' that skips the batching logic at the bottom.
                
                if !SafetyManager.shared.isSafeToDelete(url: item.url) {
                    itemStatus = .skipped
                } else {
                    // Safe to delete - perform IO inside autoreleasepool
                    autoreleasepool {
                        do {
                            if SafetyManager.shared.isDryRun {
                                // Dry run
                                batchCleaned += item.size
                                itemStatus = .deleted
                            } else {
                                // Real deletion
                                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                                batchCleaned += item.size
                                itemStatus = .deleted
                            }
                        } catch {
                            print("⚠️ Failed to delete \(item.path): \(error.localizedDescription)")
                            itemStatus = .error
                        }
                    }
                }
                
                // 2. Update Batch State
                batchStatusUpdates[item] = itemStatus
                batchProcessedItems.append(item)
                
                // 3. Adaptive Throttling Logic (only throttle if we actually did IO)
                if itemStatus == .deleted || itemStatus == .error {
                    let opDuration = Date().timeIntervalSince(opStartTime)
                    
                    // If operation was too slow, increase sleep
                    if opDuration > targetLatency {
                        currentSleepInterval = min(currentSleepInterval + 1_000_000, maxSleepInterval) // +1ms
                    } else if opDuration < targetLatency / 2 && currentSleepInterval > 0 {
                        // If operation was very fast, decrease sleep
                        currentSleepInterval = max(currentSleepInterval - 500_000, 0) // -0.5ms
                    }
                    
                    // Apply throttle if needed
                    if currentSleepInterval > 0 {
                        try? await Task.sleep(nanoseconds: currentSleepInterval)
                    }
                }
                
                // 4. Batched UI Updates
                // This block MUST be reached for every item to ensure progress updates
                let isLastItem = (index == allItems.count - 1)
                let shouldUpdate = ((index + 1) % batchSize == 0) || isLastItem
                
                if shouldUpdate {
                    let currentIndex = index + 1
                    let currentBatchCleaned = batchCleaned
                    let currentBatchUpdates = batchStatusUpdates
                    let currentBatchItems = batchProcessedItems
                    
                    // Update UI on main thread
                    await MainActor.run {
                        totalCleaned += currentBatchCleaned
                        self.filesProcessed = currentIndex
                        self.progress = Double(currentIndex) / Double(self.totalFiles)
                        
                        // Apply status updates
                        for (item, status) in currentBatchUpdates {
                            item.status = status
                        }
                        
                        // Calculate ETA
                        let elapsed = Date().timeIntervalSince(startTime)
                        if self.filesProcessed > 0 {
                            let avgTimePerFile = elapsed / Double(self.filesProcessed)
                            let filesRemaining = Double(self.totalFiles - self.filesProcessed)
                            self.estimatedTimeRemaining = avgTimePerFile * filesRemaining
                        }
                        
                        // Update current file name
                        if let lastItem = currentBatchItems.last {
                            self.currentFileName = lastItem.name
                        }
                    }
                    
                    // Reset batch
                    batchCleaned = 0
                    batchProcessedItems.removeAll()
                    batchStatusUpdates.removeAll()
                    batchStartTime = Date()
                }
            }
            
            // 5. Verification & Retry Loop
            // User requested: "check mechanism that runs the cleaning algorithm till all files deleted and recusively check"
            
            let maxRetries = 3
            var retryCount = 0
            var itemsToVerify = allItems.filter { $0.status == .deleted }
            
            while retryCount < maxRetries && !itemsToVerify.isEmpty {
                retryCount += 1
                
                await MainActor.run {
                    self.currentFileName = "Verifying deletion (Attempt \(retryCount)/\(maxRetries))..."
                }
                
                var stillExistingItems: [ScanItem] = []
                
                for item in itemsToVerify {
                    if Task.isCancelled { break }
                    
                    // Check if file still exists
                    if fileManager.fileExists(atPath: item.path) {
                        // Try to delete again
                        autoreleasepool {
                            do {
                                print("🔄 Retry deleting: \(item.path)")
                                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                            } catch {
                                print("⚠️ Retry failed for \(item.path): \(error.localizedDescription)")
                            }
                        }
                        
                        // Check again immediately
                        if fileManager.fileExists(atPath: item.path) {
                            stillExistingItems.append(item)
                        }
                    }
                }
                
                itemsToVerify = stillExistingItems
                
                // Small delay between retries if needed
                if !itemsToVerify.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                }
            }
            
            // Mark any remaining items as error
            if !itemsToVerify.isEmpty {
                await MainActor.run {
                    for item in itemsToVerify {
                        item.status = .error
                    }
                }
            }
            
            // Final cleanup
            await MainActor.run {
                self.isCleaning = false
                self.progress = 1.0
                self.estimatedTimeRemaining = 0
                self.currentFileName = ""
            }
        }
        
        await cleaningTask?.value
        
        return totalCleaned
    }
    
    func cancelCleaning() {
        cleaningTask?.cancel()
        isCleaning = false
    }
    
    func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}
