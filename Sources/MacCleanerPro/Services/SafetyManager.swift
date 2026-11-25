import Foundation
import Darwin

/// Last line of defence: every file is checked here right before it is deleted.
///
/// This is an allow-list. A file can only be deleted if it lives in one of the places
/// Ruan Cleaner is meant to clean. Anything else is refused, whatever the scanner found.
final class SafetyManager {
    static let shared = SafetyManager()

    private init() {}

    /// Folder names that hold rebuildable cache data. Used by the scanner and by the checks below.
    static let cacheFolderNames: Set<String> = [
        "cache", "caches", "code cache", "gpucache", "cacheddata", "shadercache",
        "grshadercache", "dawncache", "dawngraphitecache"
    ]

    private let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path

    private let tempRoot: String = {
        var path = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath().path
        while path.hasSuffix("/") && path.count > 1 { path.removeLast() }
        return path
    }()

    // MARK: - Never touched

    private let criticalSystemPaths: [String] = [
        "/System", "/usr", "/bin", "/sbin", "/etc", "/private/etc",
        "/var/db", "/private/var/db", "/Library", "/Applications", "/opt"
    ]

    /// Personal data inside the home folder. Never cleaned, even if a scan path points inside.
    private let protectedHomeFolders: [String] = [
        "Documents", "Desktop", "Pictures", "Movies", "Music", "Public", "Applications",
        "Library/Mobile Documents",            // iCloud Drive
        "Library/CloudStorage",                // Dropbox, Google Drive, OneDrive
        "Library/Mail", "Library/Messages", "Library/Keychains", "Library/Preferences",
        "Library/Photos", "Library/Safari", "Library/Cookies", "Library/Accounts",
        "Library/Calendars", "Library/Group Containers",
        "Library/Application Support/MobileSync",   // iPhone backups
        "Library/Application Support/AddressBook",
        ".ssh", ".gnupg", ".config"
    ]

    private let criticalExtensions: Set<String> = [
        "dylib", "framework", "kext", "bundle", "prefpane", "plugin", "app", "pkg", "keychain"
    ]

    /// Personal data that is refused even for vetted app leftovers.
    private let personalFolders: [String] = [
        "Documents", "Desktop", "Pictures", "Movies", "Music", "Public",
        "Library/Mobile Documents", "Library/CloudStorage", "Library/Mail", "Library/Messages",
        "Library/Keychains", "Library/Group Containers", "Library/Application Support/MobileSync"
    ]

    // MARK: - Approved app leftovers

    /// Exact paths the leftover scan found (folders/files of deleted apps). These live outside
    /// the usual cache folders, so they are allowed only if they are on this list.
    private var approvedLeftovers: Set<String> = []

    func approveLeftovers(_ paths: Set<String>) {
        cacheLock.lock()
        approvedLeftovers = paths
        cacheLock.unlock()
    }

    private func isApprovedLeftover(_ path: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return approvedLeftovers.contains(path)
    }

    // MARK: - Check

    /// Returns nil when the file may be deleted, otherwise the reason it is refused.
    func check(_ url: URL) -> String? {
        // Resolve the parent folder (not the file itself, so a symlink is judged as the link).
        let path = resolvedParent(of: url) + "/" + url.lastPathComponent
        let library = home + "/Library"
        let downloads = home + "/Downloads"

        for critical in criticalSystemPaths where isInside(path, critical) {
            return "System location"
        }

        if isApprovedLeftover(path) {
            for folder in personalFolders where isInside(path, home + "/" + folder) {
                return "Personal data folder"
            }
            var info = stat()
            guard lstat(path, &info) == 0 else { return "File no longer exists" }
            if info.st_uid != getuid() { return "Owned by another user" }
            if (info.st_flags & (UInt32(UF_IMMUTABLE) | UInt32(SF_IMMUTABLE))) != 0 { return "Locked file" }
            return nil
        }

        for folder in protectedHomeFolders where isInside(path, home + "/" + folder) {
            return "Personal data folder"
        }

        if isInside(path, library + "/Caches") || isInside(path, library + "/Logs") || isInside(path, tempRoot) {
            // Cache, log and temp folders: fine.
        } else if isInside(path, library + "/Application Support") {
            // Only cache folders inside app data, never the app data itself.
            let parts = relative(path, to: library + "/Application Support")
                .split(separator: "/").map { $0.lowercased() }
            let insideCacheFolder = parts.dropLast().contains { SafetyManager.cacheFolderNames.contains($0) }
            if !(insideCacheFolder || parts.first == "crashreporter") {
                return "App data (not a cache folder)"
            }
        } else if isInside(path, library + "/Containers") {
            if !path.contains("/Data/Library/Caches/") {
                return "App container data (not a cache folder)"
            }
        } else if isInside(path, downloads) {
            // Old downloads: allowed, they go to the Trash.
        } else {
            return "Outside the folders Ruan Cleaner cleans"
        }

        if !isInside(path, downloads), criticalExtensions.contains(url.pathExtension.lowercased()) {
            return "Protected file type"
        }

        var info = stat()
        guard lstat(path, &info) == 0 else { return "File no longer exists" }
        if info.st_uid != getuid() { return "Owned by another user" }
        if (info.st_flags & (UInt32(UF_IMMUTABLE) | UInt32(SF_IMMUTABLE))) != 0 { return "Locked file" }
        if !FileManager.default.isDeletableFile(atPath: path) { return "No permission to delete" }

        return nil
    }

    func isSafeToDelete(url: URL) -> Bool {
        check(url) == nil
    }

    func validateDeletion(for items: [ScanItem]) -> [ScanItem] {
        items.filter { isSafeToDelete(url: $0.url) }
    }

    // MARK: - Helpers

    // Resolving a folder path costs several system calls. Thousands of files share the same
    // folder, so remember the answer. Locked because cleaning runs on several threads.
    private let cacheLock = NSLock()
    private var resolvedParents: [String: String] = [:]

    private func resolvedParent(of url: URL) -> String {
        let parent = url.deletingLastPathComponent().path
        cacheLock.lock()
        if let cached = resolvedParents[parent] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let resolved = URL(fileURLWithPath: parent).resolvingSymlinksInPath().path
        cacheLock.lock()
        resolvedParents[parent] = resolved
        cacheLock.unlock()
        return resolved
    }

    /// True if `path` is `folder` itself or something inside it (not just a name that starts the same).
    private func isInside(_ path: String, _ folder: String) -> Bool {
        path == folder || path.hasPrefix(folder + "/")
    }

    private func relative(_ path: String, to folder: String) -> String {
        guard path.hasPrefix(folder + "/") else { return "" }
        return String(path.dropFirst(folder.count + 1))
    }
}
