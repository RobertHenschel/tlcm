import SwiftUI

struct AddConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var authType = "Password"
    @State private var authData = ""
    @State private var autoConnect = false

    private let editingId: UUID?
    var onSave: (Connection) -> Void

    init(editing connection: Connection? = nil, onSave: @escaping (Connection) -> Void) {
        self.editingId = connection?.id
        self.onSave = onSave
        if let c = connection {
            _name = State(initialValue: c.name)
            _server = State(initialValue: c.server)
            _username = State(initialValue: c.username)
            _authType = State(initialValue: c.authType)
            _authData = State(initialValue: c.authData)
            // Auto-connect is only valid with key auth; correct any legacy data silently.
            _autoConnect = State(initialValue: c.authType == "Password" ? false : c.autoConnect)
        }
    }

    private var isEditing: Bool { editingId != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Connection" : "Add Connection")
                .font(.headline)
                .padding()
            Form {
                TextField("Name", text: $name)
                TextField("Server", text: $server)
                TextField("Username", text: $username)
                Picker("Authentication", selection: $authType) {
                    Text("Password").tag("Password")
                    Text("Key").tag("Key")
                }
                .onChange(of: authType) { newType in
                    if newType == "Password" {
                        autoConnect = false
                        authData = ""
                    }
                }
                if authType == "Key" {
                    HStack {
                        TextField("Key path (optional)", text: $authData)
                        Button("Browse…") { browseForKey() }
                            .buttonStyle(.bordered)
                    }
                }
                Toggle("Connect automatically", isOn: $autoConnect)
                    .disabled(authType == "Password")
                if authType == "Password" {
                    Text("Auto-connect is not available with password authentication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || server.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 340, height: 380)
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Private Key"
        panel.message = "Choose your SSH private key file"
        panel.prompt = "Select"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            authData = url.path
        }
    }

    private func save() {
        let conn = Connection(
            id: editingId ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            server: server.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            authType: authType,
            authData: authType == "Password" ? "" : authData,
            autoConnect: authType == "Password" ? false : autoConnect
        )
        onSave(conn)
        dismiss()
    }
}

#if DEBUG
#Preview("Add") {
    AddConnectionSheet { _ in }
        .frame(width: 340, height: 380)
}

#Preview("Edit") {
    AddConnectionSheet(editing: Connection(name: "Demo", server: "demo.example.com", username: "user")) { _ in }
        .frame(width: 340, height: 380)
}
#endif
