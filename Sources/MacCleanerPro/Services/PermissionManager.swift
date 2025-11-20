import Foundation
import AppKit

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var hasFullDiskAccess: Bool = false
    
    private let permissionKey = "HasRequestedFullDiskAccess"
    
    private init() {
        _ = checkFullDiskAccess()
    }
    
    func checkFullDiskAccess() -> Bool {
        // Check if we can access a protected directory
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        
        let canAccess = FileManager.default.isReadableFile(atPath: testPath.path)
        
        DispatchQueue.main.async {
            self.hasFullDiskAccess = canAccess
        }
        
        return canAccess
    }
    
    func requestFullDiskAccessIfNeeded() {
        // Check if we've already requested
        let hasRequested = UserDefaults.standard.bool(forKey: permissionKey)
        
        if !hasRequested && !hasFullDiskAccess {
            showPermissionAlert()
            UserDefaults.standard.set(true, forKey: permissionKey)
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "Mac Cleaner Pro needs Full Disk Access to scan and clean your system effectively.\n\n1. Open System Settings\n2. Go to Privacy & Security → Full Disk Access\n3. Enable access for Mac Cleaner Pro\n4. Restart the app"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
