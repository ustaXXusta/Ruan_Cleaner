import AppKit

/// Loads the images that ship with the app.
///
/// The old code loaded the logo from "/Users/mehmet/Desktop/...", a path that only exists on one Mac,
/// and used Image("city_wireframe"), which doesn't look inside the SwiftPM resource bundle.
/// This looks in the .app's Resources, then in the SwiftPM bundle (for `swift run`), and never crashes.
enum AppImages {
    private static let resourceBundleName = "MacCleanerPro_MacCleanerPro.bundle"

    private static let bundles: [Bundle] = {
        var result: [Bundle] = [Bundle.main]
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
            Bundle.main.bundleURL.appendingPathComponent(resourceBundleName),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(resourceBundleName)
        ]
        for case let url? in candidates {
            if let bundle = Bundle(url: url) { result.append(bundle) }
        }
        return result
    }()

    private static var cache: [String: NSImage] = [:]

    static func load(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                cache[name] = image
                return image
            }
        }
        return nil
    }
}
