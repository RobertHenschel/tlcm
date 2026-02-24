import SwiftUI

struct AddConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var authType = "Password"
    @State private var authData = ""
    @State private var autoConnect = false
    @State private var password = ""
    @State private var savePassword = false
    @State private var hadKeychainEntry = false
    @State private var showPassword = false

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
            _autoConnect = State(initialValue: c.autoConnect)
            if c.authType == "Password" {
                let exists = KeychainHelper.hasPassword(for: c.id)
                _hadKeychainEntry = State(initialValue: exists)
                _savePassword = State(initialValue: exists)
            }
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
                        authData = ""
                    } else {
                        password = ""
                        savePassword = false
                        hadKeychainEntry = false
                        showPassword = false
                    }
                }
                if authType == "Key" {
                    HStack {
                        TextField("Key path (optional)", text: $authData)
                        Button("Browse…") { browseForKey() }
                            .buttonStyle(.bordered)
                    }
                    Toggle("Connect automatically", isOn: $autoConnect)
                }
                if authType == "Password" {
                    Toggle("Save to macOS Keychain", isOn: $savePassword)
                        .onChange(of: savePassword) { on in
                            if !on {
                                password = ""
                                showPassword = false
                            }
                        }
                    HStack {
                        if showPassword {
                            TextField(hadKeychainEntry ? "Password (leave blank to keep)" : "Password",
                                      text: $password)
                        } else {
                            SecureField(hadKeychainEntry ? "Password (leave blank to keep)" : "Password",
                                        text: $password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .disabled(!savePassword)
                    Text(savePassword
                         ? "Saved passwords are used to log in automatically."
                         : "Without a saved password, the ThinLinc client will prompt you.")
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
        .frame(width: 425, height: 420)
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
        let id = editingId ?? UUID()

        if authType == "Password" {
            if savePassword && !password.isEmpty {
                KeychainHelper.save(password: password, for: id)
            } else if !savePassword {
                KeychainHelper.delete(for: id)
            }
        } else {
            if let eid = editingId { KeychainHelper.delete(for: eid) }
        }

        let effectiveAutoConnect: Bool
        if authType == "Password" {
            effectiveAutoConnect = savePassword || hadKeychainEntry
        } else {
            effectiveAutoConnect = autoConnect
        }

        let conn = Connection(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            server: server.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            authType: authType,
            authData: authType == "Password" ? "" : authData,
            autoConnect: effectiveAutoConnect
        )
        onSave(conn)
        dismiss()
    }
}

#if DEBUG
#Preview("Add") {
    AddConnectionSheet { _ in }
        .frame(width: 425, height: 420)
}

#Preview("Edit") {
    AddConnectionSheet(editing: Connection(name: "Demo", server: "demo.example.com", username: "user")) { _ in }
        .frame(width: 425, height: 420)
}
#endif
