import Foundation

struct AppSettings: Codable, Equatable {
    var quitAfterConnect: Bool = false
    var lastConnectedId: UUID? = nil
}
