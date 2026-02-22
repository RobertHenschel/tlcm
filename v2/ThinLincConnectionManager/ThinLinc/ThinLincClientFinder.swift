import Foundation

enum ThinLincClientFinder {
    private static let appName = "ThinLinc Client.app"
    private static let paths: [URL] = [
        URL(fileURLWithPath: "/Applications/ThinLinc Client.app"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ThinLinc Client.app", isDirectory: true),
    ]

    /// Returns the ThinLinc Client.app bundle URL if installed, otherwise nil.
    static func findThinLincApp() -> URL? {
        for url in paths {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let binary = url.appendingPathComponent("Contents/MacOS/tlclient", isDirectory: false)
                if FileManager.default.fileExists(atPath: binary.path), FileManager.default.isReadableFile(atPath: binary.path) {
                    return url
                }
            }
        }
        return nil
    }

    /// Returns the path to the tlclient binary if available, otherwise nil.
    static func findThinLincBinary() -> URL? {
        guard let app = findThinLincApp() else { return nil }
        return app.appendingPathComponent("Contents/MacOS/tlclient", isDirectory: false)
    }

    /// Returns true if the ThinLinc client is installed and usable.
    static var isClientInstalled: Bool { findThinLincApp() != nil }
}
