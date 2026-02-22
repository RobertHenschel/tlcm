import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: ConnectionsStore
    @State private var showingAddSheet = false
    @State private var editingConnection: Connection?

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
                            onConnect: {
                                let shouldQuit = store.settings.quitAfterConnect
                                ThinLincClientLauncher.launch(connection: conn) { _ in
                                    if shouldQuit {
                                        NSApplication.shared.terminate(nil)
                                    }
                                }
                            },
                            onEdit: { editingConnection = conn }
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
    var onConnect: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)
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
        .contentShape(Rectangle())
        .onDoubleClick { onConnect() }
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
    ConnectionRow(connection: Connection(name: "Demo", server: "demo.example.com", username: "user"), onConnect: {}, onEdit: {})
        .frame(width: 380)
}
#endif
