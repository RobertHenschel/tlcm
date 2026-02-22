import Foundation

/// Top-level structure of the JSON file. Wraps both connections and app-wide settings
/// so everything lives in one file (and syncs via Dropbox as a unit).
private struct AppData: Codable {
    var connections: [Connection]
    var settings: AppSettings
}

final class ConnectionsStore: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var settings: AppSettings = AppSettings()

    /// When true, connections are stored in Dropbox root for syncing across devices.
    @Published private(set) var usingDropbox: Bool = false

    private let fileURL: URL = {
        if let dropboxURL = DropboxLocator.dropboxConnectionsFile {
            return dropboxURL
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ThinLincConnectionManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("connections.json")
    }()

    init() {
        usingDropbox = (DropboxLocator.dropboxRoot != nil)
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            connections = []
            return
        }

        // Try new envelope format first.
        if let appData = try? JSONDecoder().decode(AppData.self, from: data) {
            connections = appData.connections
            settings = appData.settings
            return
        }

        // Migrate from old bare-array format (v1 / early v2).
        if let bare = try? JSONDecoder().decode([Connection].self, from: data) {
            connections = bare
            settings = AppSettings()
            save()   // rewrite in new format immediately
        }
    }

    func save() {
        let appData = AppData(connections: connections, settings: settings)
        guard let data = try? JSONEncoder().encode(appData) else { return }
        try? data.write(to: fileURL)
    }

    func add(_ connection: Connection) {
        connections.append(connection)
        save()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets {
            deleteIcon(for: connections[i])
        }
        connections.remove(atOffsets: offsets)
        save()
    }

    func update(_ connection: Connection) {
        if let i = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[i] = connection
            save()
        }
    }

    func saveSettings() {
        save()
    }

    // MARK: - Icon management

    /// URL for the icon file for a given connection.
    /// Named after the JSON file's stem: e.g. `tlcm-connections-<uuid>.png`
    /// so all files share the same location and sort together.
    func iconURL(for connection: Connection) -> URL {
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let dir  = fileURL.deletingLastPathComponent()
        return dir.appendingPathComponent("\(stem)-\(connection.id.uuidString).png")
    }

    func deleteIcon(for connection: Connection) {
        let url = iconURL(for: connection)
        try? FileManager.default.removeItem(at: url)
    }
}
