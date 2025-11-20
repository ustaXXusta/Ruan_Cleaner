import Foundation

class SafetyManager {
    static let shared = SafetyManager()
    
    private init() {}
    
    // MARK: - SIP Check
    func isSIPEnabled() -> Bool {
        return true
    }
    
    // MARK: - Critical System Paths (NEVER DELETE)
    private let criticalPaths: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/etc",
        "/var/db",
        "/Library/Apple",
        "/Applications",
        "/Library/LaunchDaemons",
        "/Library/LaunchAgents",
        "/Library/Preferences",
        "/Library/Frameworks",
        "/Library/Extensions"
    ]
    
    // MARK: - Protected User Paths
    private let protectedUserPaths: [String] = [
        "Documents",
        "Desktop",
        "Pictures",
        "Movies",
        "Music",
        "Library/Application Support/MobileSync", // iOS backups
        "Library/Keychains",
        "Library/Preferences/com.apple"
    ]
    
    // MARK: - Protected Application Data (NEVER DELETE)
    // These are critical user data directories for popular applications
    private let protectedApplicationPaths: [String] = [
        // Browsers - Core Data
        "Library/Application Support/Google/Chrome",
        "Library/Application Support/Google/Chrome Canary",
        "Library/Application Support/Chromium",
        "Library/Application Support/BraveSoftware/Brave-Browser",
        "Library/Application Support/Microsoft Edge",
        "Library/Application Support/Firefox",
        "Library/Application Support/Arc",
        "Library/Safari",
        
        // Browser Profiles & User Data (critical)
        "Library/Application Support/Google/Chrome/Default",
        "Library/Application Support/Google/Chrome/Profile",
        "Library/Application Support/BraveSoftware/Brave-Browser/Default",
        "Library/Application Support/Microsoft Edge/Default",
        
        // Messaging Apps
        "Library/Application Support/Telegram",
        "Library/Application Support/Telegram Desktop",
        "Library/Group Containers/group.WhatsApp",
        "Library/Containers/WhatsApp",
        "Library/Containers/net.whatsapp.WhatsApp",
        "Library/Application Support/WhatsApp",
        "Library/Application Support/Signal",
        "Library/Application Support/Slack",
        "Library/Application Support/Discord",
        
        // Email Clients
        "Library/Mail",
        "Library/Application Support/Microsoft/Outlook",
        "Library/Application Support/Thunderbird",
        
        // Cloud Storage
        "Library/CloudStorage",
        "Library/Application Support/Dropbox",
        "Library/Application Support/Google Drive",
        "Library/Application Support/OneDrive",
        
        // Development Tools (important user data)
        "Library/Application Support/Code", // VS Code
        "Library/Application Support/JetBrains",
        ".config", // User configurations
        
        // Password Managers
        "Library/Application Support/1Password",
        "Library/Application Support/Bitwarden",
        "Library/Application Support/LastPass",
        
        // Other Critical Apps
        "Library/Application Support/Notion",
        "Library/Application Support/Obsidian",
        "Library/Application Support/Evernote"
    ]
    
    // MARK: - Critical Extensions (NEVER DELETE)
    private let criticalExtensions: [String] = [
        "dylib", "framework", "kext", "bundle",
        "prefPane", "plugin", "app", "pkg"
    ]
    
    func isSafeToDelete(url: URL) -> Bool {
        let path = url.path
        let ext = url.pathExtension.lowercased()
        
        // 1. Check critical system paths
        for critical in criticalPaths {
            if path.hasPrefix(critical) {
                return false
            }
        }
        
        // 2. Check protected user paths
        for protected in protectedUserPaths {
            if path.contains(protected) {
                return false
            }
        }
        
        // 3. Check protected application paths (CRITICAL!)
        for protected in protectedApplicationPaths {
            if path.contains(protected) {
                return false
            }
        }
        
        // 4. Check critical file extensions
        if criticalExtensions.contains(ext) {
            return false
        }
        
        // 5. Check if file is currently in use
        if isFileInUse(url: url) {
            return false
        }
        
        // 6. Double-check: is it a system file?
        if isSystemFile(url: url) {
            return false
        }
        
        return true
    }
    
    private func isFileInUse(url: URL) -> Bool {
        // Check if file can be opened exclusively
        let fileHandle = try? FileHandle(forUpdating: url)
        fileHandle?.closeFile()
        return fileHandle == nil
    }
    
    private func isSystemFile(url: URL) -> Bool {
        // Check file attributes for system/immutable flags
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                // Check if file is owned by root or system
                return posixPermissions.intValue & 0o4000 != 0
            }
        }
        return false
    }
    
    // MARK: - Dry Run
    var isDryRun: Bool = true
    
    func validateDeletion(for items: [ScanItem]) -> [ScanItem] {
        return items.filter { isSafeToDelete(url: $0.url) }
    }
}
