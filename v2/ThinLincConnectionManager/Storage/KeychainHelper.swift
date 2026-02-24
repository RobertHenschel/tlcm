import Foundation

/// Manages passwords in the macOS login Keychain by shelling out to /usr/bin/security.
/// This ensures the entries are created by the security CLI itself, so the askpass
/// script (which also calls security) can retrieve them without ACL issues.
enum KeychainHelper {
    private static let service = "ThinLincConnectionManager"
    private static let securityPath = "/usr/bin/security"

    @discardableResult
    static func save(password: String, for id: UUID) -> Bool {
        // -U allows update if the entry already exists
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityPath)
        process.arguments = [
            "add-generic-password",
            "-s", service,
            "-a", id.uuidString,
            "-w", password,
            "-U",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func retrieve(for id: UUID) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityPath)
        process.arguments = [
            "find-generic-password",
            "-s", service,
            "-a", id.uuidString,
            "-w",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    static func hasPassword(for id: UUID) -> Bool {
        retrieve(for: id) != nil
    }

    @discardableResult
    static func delete(for id: UUID) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityPath)
        process.arguments = [
            "delete-generic-password",
            "-s", service,
            "-a", id.uuidString,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
