import Foundation
import SwiftUI
import Combine

enum ScanItemStatus {
    case ready
    case cleaning
    case deleted
    case error
    case skipped
}

final class ScanItem: Identifiable, ObservableObject, Hashable {
    /// Sent whenever any item's checkbox or status changes, so totals and group checkboxes refresh.
    static let changed = PassthroughSubject<Void, Never>()

    /// Set while updating many items at once (after a clean) so we send one change, not 100,000.
    static var muteChanges = false

    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let category: CleanupCategory
    /// Group shown in the results list (usually the app or folder the file belongs to).
    let groupName: String
    /// Bytes the file really occupies on disk (allocated size, not the logical size).
    let size: Int64
    let lastModified: Date
    let isDirectory: Bool

    @Published var isSelected: Bool = true {
        didSet { if oldValue != isSelected && !ScanItem.muteChanges { ScanItem.changed.send() } }
    }
    @Published var status: ScanItemStatus = .ready {
        didSet { if oldValue != status && !ScanItem.muteChanges { ScanItem.changed.send() } }
    }
    /// Why the item was skipped or failed. Shown as a tooltip.
    @Published var note: String?

    /// Still on disk (not deleted yet).
    var isActive: Bool { status != .deleted }

    init(url: URL, category: CleanupCategory, groupName: String, size: Int64, lastModified: Date, isDirectory: Bool = false) {
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.category = category
        self.groupName = groupName
        self.size = size
        self.lastModified = lastModified
        self.isDirectory = isDirectory
        self.isSelected = category.selectedByDefault
    }

    static func == (lhs: ScanItem, rhs: ScanItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class ScanGroup: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    /// Every file in this group, including the files of its subgroups.
    let items: [ScanItem]
    /// Only used by the "small folders" bucket, which holds several small groups.
    let subgroups: [ScanGroup]

    @Published var isExpanded: Bool = false

    // Cached totals. Worked out once per change by refreshStats(), so drawing a row is instant
    // (the old code re-added every file of every visible group on every redraw).
    private(set) var activeCount = 0
    private(set) var activeSize: Int64 = 0
    private(set) var isAllSelected = false

    init(name: String, items: [ScanItem], subgroups: [ScanGroup] = []) {
        self.name = name
        self.items = items
        self.subgroups = subgroups
        refreshStats()
    }

    var hasActiveItems: Bool { activeCount > 0 }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    func refreshStats() {
        var count = 0
        var size: Int64 = 0
        var allSelected = true
        for item in items where item.isActive {
            count += 1
            size += item.size
            if !item.isSelected { allSelected = false }
        }
        activeCount = count
        activeSize = size
        isAllSelected = count > 0 && allSelected
        for subgroup in subgroups { subgroup.refreshStats() }
    }

    func toggleSelection(_ isSelected: Bool) {
        ScanItem.muteChanges = true
        for item in items where item.isActive {
            item.isSelected = isSelected
        }
        ScanItem.muteChanges = false
        ScanItem.changed.send()
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let category: CleanupCategory
    var items: [ScanItem]
    var groups: [ScanGroup]

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    init(category: CleanupCategory, items: [ScanItem], groups: [ScanGroup]) {
        self.category = category
        self.items = items
        self.groups = groups
    }

    func setSelected(_ isSelected: Bool) {
        ScanItem.muteChanges = true
        for item in items where item.isActive {
            item.isSelected = isSelected
        }
        ScanItem.muteChanges = false
        ScanItem.changed.send()
    }
}

/// Totals for the whole scan, worked out in one pass whenever something changes.
struct ScanStats {
    struct CategoryStats {
        var activeCount = 0
        var activeSize: Int64 = 0
        var allSelected = false
    }

    var totalActiveSize: Int64 = 0
    var selectedSize: Int64 = 0
    var selectedCount = 0
    var categories: [CleanupCategory: CategoryStats] = [:]

    func category(_ category: CleanupCategory) -> CategoryStats {
        categories[category] ?? CategoryStats()
    }
}
