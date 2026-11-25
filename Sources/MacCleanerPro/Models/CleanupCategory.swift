import Foundation
import SwiftUI

enum CleanupCategory: String, CaseIterable, Identifiable {
    case systemCaches = "System Caches"
    case applicationCaches = "Application Caches"
    case logs = "Logs & Crash Reports"
    case temporaryFiles = "Temporary Files"
    case oldDownloads = "Old Downloads"
    case browserData = "Browser Data"
    case appLeftovers = "App Leftovers"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .systemCaches: return "cpu"
        case .applicationCaches: return "app.badge"
        case .logs: return "doc.text"
        case .temporaryFiles: return "trash"
        case .oldDownloads: return "arrow.down.circle"
        case .browserData: return "globe"
        case .appLeftovers: return "shippingbox"
        }
    }

    var description: String {
        switch self {
        case .systemCaches: return "Cache files in ~/Library/Caches. Apps rebuild them when needed."
        case .applicationCaches: return "Only folders named Cache, Code Cache, GPUCache and similar inside app data. Settings, saves and documents are never touched."
        case .logs: return "Log files and crash reports older than one day."
        case .temporaryFiles: return "Temporary files older than two days."
        case .oldDownloads: return "Items that landed in Downloads 30+ days ago. Not selected by default, and moved to the Trash instead of deleted."
        case .browserData: return "Browser cache files only. Logins, history and bookmarks are not touched."
        case .appLeftovers: return "Settings, caches and data left behind by apps you deleted. Not selected by default: check the apps you recognize. Moved to the Trash, so empty it to get the space back."
        }
    }

    /// When the same file is found by more than one scan, the first category in this list keeps it.
    /// This stops one file from showing up twice (and being deleted from a list where you unchecked it).
    static let claimOrder: [CleanupCategory] = [
        .appLeftovers, .browserData, .temporaryFiles, .logs, .applicationCaches, .systemCaches, .oldDownloads
    ]

    /// Junk is preselected. Personal files have to be picked by hand.
    var selectedByDefault: Bool { self != .oldDownloads && self != .appLeftovers }

    /// Junk is deleted for real so the space comes back right away.
    /// Downloads and app leftovers go to the Trash so they can still be restored.
    var deletesPermanently: Bool { self != .oldDownloads && self != .appLeftovers }
}
