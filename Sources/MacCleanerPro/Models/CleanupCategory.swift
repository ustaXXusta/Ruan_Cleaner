import Foundation
import SwiftUI

enum CleanupCategory: String, CaseIterable, Identifiable {
    case systemCaches = "System Caches"
    case applicationCaches = "Application Caches"
    case logs = "Logs & Crash Reports"
    case temporaryFiles = "Temporary Files"
    case oldDownloads = "Old Downloads"
    case browserData = "Browser Data"
    // Add more as needed
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .systemCaches: return "cpu"
        case .applicationCaches: return "app.badge"
        case .logs: return "doc.text"
        case .temporaryFiles: return "trash"
        case .oldDownloads: return "arrow.down.circle"
        case .browserData: return "globe"
        }
    }
    
    var description: String {
        switch self {
        case .systemCaches: return "System generated cache files that can be safely removed."
        case .applicationCaches: return "Caches created by applications to speed up loading."
        case .logs: return "System and application log files and crash reports."
        case .temporaryFiles: return "Temporary files that are no longer needed."
        case .oldDownloads: return "Downloads folder items older than 30 days."
        case .browserData: return "Cache files from web browsers like Chrome, Safari, and Firefox."
        }
    }
}
