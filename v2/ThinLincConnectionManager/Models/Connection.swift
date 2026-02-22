import Foundation

struct Connection: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var server: String
    var username: String
    var authType: String
    var authData: String
    var autoConnect: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        server: String = "",
        username: String = "",
        authType: String = "Password",
        authData: String = "",
        autoConnect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.username = username
        self.authType = authType
        self.authData = authData
        self.autoConnect = autoConnect
    }

    enum CodingKeys: String, CodingKey {
        case id, name, server, username, autoConnect
        case authType = "auth_type"
        case authData = "auth_data"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        server = try c.decode(String.self, forKey: .server)
        username = try c.decode(String.self, forKey: .username)
        authType = try c.decodeIfPresent(String.self, forKey: .authType) ?? "Password"
        authData = try c.decodeIfPresent(String.self, forKey: .authData) ?? ""
        autoConnect = try c.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? false
    }
}
