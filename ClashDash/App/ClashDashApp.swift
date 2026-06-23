import SwiftUI

@main
struct ClashDashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { DebugServer.shared.start() }
        }
    }
}
