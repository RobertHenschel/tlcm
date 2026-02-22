import Foundation

enum DropboxLocator {
    /// Filename in the root of the Dropbox folder holding all connection data.
    static let connectionsFileName = "tlcm-connections.json"

    /// Returns the Dropbox root directory URL if Dropbox appears to be installed, otherwise nil.
    /// Checks ~/Dropbox and ~/Library/CloudStorage/Dropbox (macOS Cloud Storage location).
    static var dropboxRoot: URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Dropbox", isDirectory: true),
            home.appendingPathComponent("Library/CloudStorage/Dropbox", isDirectory: true),
        ]
        for url in candidates {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return nil
    }

    /// URL for the shared connections file in Dropbox root, or nil if Dropbox is not available.
    static var dropboxConnectionsFile: URL? {
        dropboxRoot?.appendingPathComponent(connectionsFileName, isDirectory: false)
    }
}
