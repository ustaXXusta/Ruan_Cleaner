import Foundation
import SwiftUI

class AppModel: ObservableObject {
    @Published var scanResults: [ScanResult] = []
    @Published var totalJunkSize: Int64 = 0
    @Published var lastScanDate: Date?
    
    @ObservedObject var scannerService = ScannerService()
    @ObservedObject var cleanerService = CleanerService()
    
    var isScanning: Bool { scannerService.isScanning }
    var isCleaning: Bool { cleanerService.isCleaning }
    
    func startScan() async {
        // Reset results
        DispatchQueue.main.async {
            self.scanResults = []
            self.totalJunkSize = 0
        }
        
        let results = await scannerService.scan(categories: CleanupCategory.allCases)
        
        DispatchQueue.main.async {
            self.scanResults = results
            self.totalJunkSize = results.reduce(0) { $0 + $1.totalSize }
            self.lastScanDate = Date()
        }
    }
    
    func performCleanup() async {
        let cleanedSize = await cleanerService.clean(results: scanResults)
        
        DispatchQueue.main.async {
            self.totalJunkSize -= cleanedSize
            if self.totalJunkSize < 0 { self.totalJunkSize = 0 }
            
            // Don't clear results, just let the view hide deleted items
            // This allows unchecked items to remain visible
        }
    }
    
    func performRealCleanup() async {
        // Disable dry-run mode for real cleanup
        SafetyManager.shared.isDryRun = false
        
        let cleanedSize = await cleanerService.clean(results: scanResults)
        
        DispatchQueue.main.async {
            self.totalJunkSize -= cleanedSize
            if self.totalJunkSize < 0 { self.totalJunkSize = 0 }
            
            // Don't clear results, just let the view hide deleted items
        }
        
        // Re-enable dry-run mode for safety
        SafetyManager.shared.isDryRun = true
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
