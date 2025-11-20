import SwiftUI
import AppKit

@main
struct MacCleanerProApp: App {
    @StateObject var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                DashboardView()
                MatrixRainView()
            }
            .environmentObject(appModel)
            .onAppear {
                // Set window to 85% of screen size
                if let screen = NSScreen.main {
                    let screenSize = screen.visibleFrame.size
                    let windowWidth = screenSize.width * 0.85
                    let windowHeight = screenSize.height * 0.85
                    
                    if let window = NSApplication.shared.windows.first {
                        window.setFrame(
                            NSRect(
                                x: (screenSize.width - windowWidth) / 2,
                                y: (screenSize.height - windowHeight) / 2,
                                width: windowWidth,
                                height: windowHeight
                            ),
                            display: true
                        )
                    }
                }
            }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
