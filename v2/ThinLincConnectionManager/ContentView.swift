import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ConnectionsStore
    @State private var showingAddSheet = false
    @State private var editingConnection: Connection?
    @State private var deletingConnection: Connection?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            connectionList
        }
        .sheet(isPresented: $showingAddSheet) {
            AddConnectionSheet { connection in
                store.add(connection)
            }
        }
        .sheet(item: $editingConnection) { conn in
            AddConnectionSheet(editing: conn) { updated in
                store.update(updated)
                editingConnection = nil
            }
        }
        .confirmationDialog(
            "Delete \"\(deletingConnection?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingConnection != nil },
                set: { if !$0 { deletingConnection = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let conn = deletingConnection,
                   let idx = store.connections.firstIndex(where: { $0.id == conn.id }) {
                    store.remove(at: IndexSet(integer: idx))
                }
                deletingConnection = nil
            }
            Button("Cancel", role: .cancel) { deletingConnection = nil }
        } message: {
            Text("This connection will be permanently removed.")
        }
    }

    private var toolbar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Connections")
                    .font(.headline)
                if store.usingDropbox {
                    Text("Synced via Dropbox")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            Spacer()
            Toggle("Quit after connect", isOn: Binding(
                get: { store.settings.quitAfterConnect },
                set: { store.settings.quitAfterConnect = $0; store.saveSettings() }
            ))
            .toggleStyle(.checkbox)
            .font(.subheadline)
            .help("Quit ThinLinc Connection Manager automatically after the client is launched")
            Divider()
                .frame(height: 18)
                .padding(.horizontal, 4)
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                Text("Add Connection")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var connectionList: some View {
        Group {
            if store.connections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.connections) { conn in
                        ConnectionRow(
                            connection: conn,
                            iconURL: store.iconURL(for: conn),
                            onConnect: {
                                let shouldQuit = store.settings.quitAfterConnect
                                ThinLincClientLauncher.launch(connection: conn) { _ in
                                    if shouldQuit {
                                        NSApplication.shared.terminate(nil)
                                    }
                                }
                            },
                            onEdit: { editingConnection = conn },
                            onDelete: { deletingConnection = conn },
                            onRemoveIcon: { store.deleteIcon(for: conn) }
                        )
                    }
                    .onDelete(perform: store.remove(at:))
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No connections yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Click \"Add Connection\" to add your first ThinLinc server.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConnectionRow: View {
    let connection: Connection
    let iconURL: URL
    var onConnect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onRemoveIcon: () -> Void

    @State private var loadedIcon: NSImage? = nil
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            ConnectionIconView(iconURL: iconURL, loadedIcon: $loadedIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name.isEmpty ? "Unnamed" : connection.name)
                    .font(.headline)
                Text(connection.server)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.bordered)
            Button("Connect") {
                onConnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        )
        .contentShape(Rectangle())
        .onDoubleClick { onConnect() }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleImageDrop)
        .contextMenu {
            Button("Connect") { onConnect() }
            Button("Edit") { onEdit() }
            Divider()
            Button("Remove Custom Icon", role: .destructive) {
                onRemoveIcon()
                loadedIcon = nil
            }
            Button("Delete Connection", role: .destructive) { onDelete() }
        }
    }

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var fileURL: URL?
            if let data = item as? Data {
                fileURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                fileURL = url
            } else if let str = item as? String {
                fileURL = URL(string: str)
            }

            guard let url = fileURL else { return }
            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif"].contains(ext) else { return }

            if let saved = saveConnectionIcon(from: url, to: iconURL) {
                DispatchQueue.main.async { loadedIcon = saved }
            }
        }
        return true
    }
}

// Double-click gesture for rows
struct DoubleClickGesture: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.gesture(
            TapGesture(count: 2).onEnded { _ in action() }
        )
    }
}
extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        modifier(DoubleClickGesture(action: action))
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(ConnectionsStore())
        .frame(width: 420, height: 320)
}

#Preview("Row") {
    ConnectionRow(
        connection: Connection(name: "Demo", server: "demo.example.com", username: "user"),
        iconURL: URL(fileURLWithPath: "/tmp/demo-icon.png"),
        onConnect: {}, onEdit: {}, onDelete: {}, onRemoveIcon: {}
    )
    .frame(width: 380)
}
#endif
