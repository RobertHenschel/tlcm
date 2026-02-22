import SwiftUI

@main
struct ThinLincConnectionManagerApp: App {
    @StateObject private var store = ConnectionsStore()
    private let thinLincAvailable = ThinLincClientFinder.isClientInstalled

    var body: some Scene {
        WindowGroup {
            if thinLincAvailable {
                ContentView()
                    .environmentObject(store)
                    .frame(minWidth: 360, minHeight: 280)
            } else {
                ThinLincNotFoundView()
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 320)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
