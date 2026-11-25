import Foundation

/// Finds what deleted apps left behind in ~/Library.
///
/// Dragging an app to the Trash only removes the .app itself. Its settings, caches, containers,
/// saved state and login agents stay in ~/Library, which is why free space doesn't come back.
///
/// How it decides:
/// 1. Build a list of every app on this Mac: the Applications folders, Spotlight (apps anywhere
///    else, e.g. external drives) and apps that are running right now.
/// 2. Look through the folders where apps keep data. Anything named after an app that is NOT on
///    that list is a leftover. Apple's own folders are never touched.
/// 3. When unsure, it says "installed" — a missed leftover is better than deleting real data.
enum LeftoverFinder {
    typealias RunningApp = (bundleID: String?, name: String?)

    struct Leftover {
        let url: URL
        /// Name used to group everything one app left behind.
        let app: String
        let isDirectory: Bool
    }

    // MARK: - Find

    static func find(running: [RunningApp]) -> [Leftover] {
        let apps = installedApps(running: running)
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library").resolvingSymlinksInPath()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        var result: [Leftover] = []

        func entries(_ folder: String) -> [URL] {
            let urls = (try? fileManager.contentsOfDirectory(
                at: library.appendingPathComponent(folder),
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )) ?? []
            return urls.filter { (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true }
        }
        func isDirectory(_ url: URL) -> Bool {
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        }

        // 1. Application Support: folders named after an app ("Discord") or a bundle ID.
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86_400)
        for url in entries("Application Support") where isDirectory(url) {
            let name = url.lastPathComponent
            if isSystemName(name) { continue }
            let orphan: Bool
            if looksLikeBundleID(name) {
                orphan = !apps.knows(bundleID: name)
            } else {
                // All-lowercase names are often background services rather than apps,
                // so those also have to be untouched for two weeks.
                let lowercaseOnly = name == name.lowercased()
                orphan = !apps.knows(name: name) && (!lowercaseOnly || modified(url) < twoWeeksAgo)
            }
            if orphan {
                result.append(Leftover(url: url, app: displayName(for: name), isDirectory: true))
            }
        }

        // 2. Folders where entries are named by bundle ID (com.company.App).
        let bundleIDFolders: [(folder: String, suffix: String)] = [
            ("Containers", ""),
            ("Caches", ""),
            ("Logs", ""),
            ("HTTPStorages", ".binarycookies"),
            ("WebKit", ""),
            ("Saved Application State", ".savedState"),
            ("Preferences", ".plist")
        ]
        for (folder, suffix) in bundleIDFolders {
            for url in entries(folder) {
                var name = url.lastPathComponent
                if !suffix.isEmpty {
                    if name.hasSuffix(suffix) {
                        name = String(name.dropLast(suffix.count))
                    } else if folder == "Preferences" || folder == "Saved Application State" {
                        continue   // e.g. Preferences/ByHost
                    }
                }
                guard looksLikeBundleID(name), !isSystemName(name), !apps.knows(bundleID: name) else { continue }
                result.append(Leftover(url: url, app: displayName(for: name), isDirectory: isDirectory(url)))
            }
        }

        // 3. Login agents that start a program which no longer exists.
        for url in entries("LaunchAgents") where url.pathExtension == "plist" {
            let name = url.deletingPathExtension().lastPathComponent
            if isSystemName(name) { continue }
            guard let info = readPlist(url) else { continue }
            let program = (info["Program"] as? String) ?? (info["ProgramArguments"] as? [String])?.first
            guard let program, program.hasPrefix("/"), !fileManager.fileExists(atPath: program) else { continue }
            result.append(Leftover(url: url, app: displayName(for: name), isDirectory: false))
        }

        return result
    }

    // MARK: - Installed apps

    struct InstalledApps {
        private(set) var bundleIDs: Set<String> = []   // lowercased
        private(set) var tokens: Set<String> = []      // normalized names, letters and digits only

        mutating func add(bundleID: String?, names: [String?]) {
            if let id = bundleID?.lowercased(), !id.isEmpty {
                bundleIDs.insert(id)
                for part in id.split(separator: ".").dropFirst() {
                    let word = String(part)
                    if word.count >= 4 && !LeftoverFinder.genericWords.contains(word) {
                        tokens.insert(LeftoverFinder.normalize(word))
                    }
                }
            }
            for case let name? in names {
                let normalized = LeftoverFinder.normalize(name)
                if normalized.count >= 3 { tokens.insert(normalized) }
            }
        }

        func knows(bundleID raw: String) -> Bool {
            let id = raw.lowercased()
            if bundleIDs.contains(id) { return true }
            // Helpers and extensions: com.spotify.client.helper belongs to com.spotify.client.
            for installed in bundleIDs where installed.hasPrefix(id + ".") || id.hasPrefix(installed + ".") {
                return true
            }
            // Same company/app word as something installed (com.google.* while Chrome is installed).
            for part in id.split(separator: ".").dropFirst() {
                let word = String(part)
                if word.count >= 4 && !LeftoverFinder.genericWords.contains(word) && knows(name: word) {
                    return true
                }
            }
            return false
        }

        func knows(name raw: String) -> Bool {
            let name = LeftoverFinder.normalize(raw)
            if name.count < 3 { return true }   // too short to judge: leave it alone
            if tokens.contains(name) { return true }
            for token in tokens where token.count >= 4 {
                if token.contains(name) || (name.count >= 4 && name.contains(token)) { return true }
            }
            return false
        }
    }

    static func installedApps(running: [RunningApp]) -> InstalledApps {
        var apps = InstalledApps()
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var seen = Set<String>()

        let roots = ["/Applications", "/System/Applications", "/System/Library/CoreServices", home + "/Applications"]
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    if seen.insert(url.path).inserted { addApp(at: url, to: &apps) }
                    enumerator.skipDescendants()
                } else if enumerator.level >= 4 {
                    enumerator.skipDescendants()
                }
            }
        }

        // Apps anywhere else Spotlight knows about (external drives, Downloads, Steam, Setapp...).
        for path in spotlightApps() where !path.contains("/.Trash/") && seen.insert(path).inserted {
            addApp(at: URL(fileURLWithPath: path), to: &apps)
        }

        for app in running {
            apps.add(bundleID: app.bundleID, names: [app.name])
        }
        return apps
    }

    private static func addApp(at url: URL, to apps: inout InstalledApps) {
        var names: [String?] = [url.deletingPathExtension().lastPathComponent]
        var bundleID: String?
        if let info = readPlist(url.appendingPathComponent("Contents/Info.plist")) {
            bundleID = info["CFBundleIdentifier"] as? String
            names.append(info["CFBundleName"] as? String)
            names.append(info["CFBundleDisplayName"] as? String)
            names.append(info["CFBundleExecutable"] as? String)
        }
        apps.add(bundleID: bundleID, names: names)
    }

    private static func spotlightApps() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return []
        }
        // Spotlight can hang while it's indexing. Give it 8 seconds, then go on without it.
        var data = Data()
        let reading = DispatchGroup()
        reading.enter()
        DispatchQueue.global(qos: .utility).async {
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }
        if reading.wait(timeout: .now() + 8) == .timedOut {
            process.terminate()
            return []
        }
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
    }

    // MARK: - Helpers

    static let genericWords: Set<String> = [
        "com", "org", "net", "io", "app", "apps", "co", "www", "mac", "macos", "osx", "desktop",
        "client", "helper", "agent", "launcher", "inc", "ltd", "llc", "the", "free", "pro", "lite",
        "beta", "plus", "edu", "dev", "github", "mas", "application", "service", "services",
        "extension", "widget", "widgets", "daemon", "update", "updater", "installer", "plugin", "plugins"
    ]

    /// Folders in Application Support that belong to macOS itself.
    private static let systemFolderNames: Set<String> = [
        "addressbook", "animoji", "callhistorydb", "callhistorytransactions", "clouddocs", "cloudkit",
        "crashreporter", "diskimages", "dock", "fileprovider", "icloud", "icdd", "knowledge",
        "mobilesync", "syncservices", "quick look", "networkserviceproxy", "coreparsec",
        "differentialprivacy", "accessibility", "accessibilitybundles", "controlcenter", "caches",
        "default.store", "familycircle", "facetime", "homeenergyd", "videosubscriptionsd",
        "locationaccessstored", "notificationcenter", "spotlight", "siri", "stickers", "wallpaper",
        "photos", "mail", "messages", "safari", "maps", "music", "tv", "podcasts", "books", "news"
    ]

    static func isSystemName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix(".")
            || lower.hasPrefix("com.apple")
            || lower.hasPrefix("group.com.apple")
            || lower.contains("apple")
            || systemFolderNames.contains(lower)
    }

    /// com.company.App style: 3+ parts, short lowercase first part, no spaces.
    static func looksLikeBundleID(_ name: String) -> Bool {
        guard !name.contains(" ") else { return false }
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        let first = parts[0]
        return (2...5).contains(first.count) && first.allSatisfy { $0.isLowercase && $0.isLetter }
    }

    /// "com.hnc.Discord" -> "Discord", "discord" -> "Discord", so one app's leftovers group together.
    static func displayName(for name: String) -> String {
        var base = name
        if looksLikeBundleID(name) {
            let parts = name.split(separator: ".").map(String.init)
            if let part = parts.dropFirst().reversed().first(where: { !genericWords.contains($0.lowercased()) }) {
                base = part
            }
        }
        guard let first = base.first else { return name }
        return first.uppercased() + base.dropFirst()
    }

    static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    static func readPlist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
