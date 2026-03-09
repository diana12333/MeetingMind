import SwiftUI

@main
struct MeetingMindWatchApp: App {
    @State private var sessionService = WatchSessionService()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(sessionService)
        }
    }
}
