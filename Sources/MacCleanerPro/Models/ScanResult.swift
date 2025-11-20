import Foundation
import SwiftUI

enum ScanItemStatus {
    case ready
    case cleaning
    case deleted
    case error
    case skipped
}

class ScanItem: Identifiable, ObservableObject, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let size: Int64
    let lastModified: Date
    
    @Published var isSelected: Bool = true
    @Published var status: ScanItemStatus = .ready
    
    init(url: URL, size: Int64, lastModified: Date) {
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.size = size
        self.lastModified = lastModified
    }
    
    static func == (lhs: ScanItem, rhs: ScanItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class ScanGroup: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let items: [ScanItem]
    
    @Published var isExpanded: Bool = false
    
    init(name: String, items: [ScanItem]) {
        self.name = name
        self.items = items
    }
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    // Helper to toggle all items
    func toggleSelection(_ isSelected: Bool) {
        for item in items {
            item.isSelected = isSelected
        }
        objectWillChange.send()
    }
    
    var isAllSelected: Bool {
        items.allSatisfy { $0.isSelected }
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let category: CleanupCategory
    var items: [ScanItem] // Keep flat list for easy access if needed
    var groups: [ScanGroup] // Grouped items for UI
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    init(category: CleanupCategory, items: [ScanItem], groups: [ScanGroup]) {
        self.category = category
        self.items = items
        self.groups = groups
    }
}
