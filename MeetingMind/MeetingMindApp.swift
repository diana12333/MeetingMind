import SwiftUI
import SwiftData

@main
struct MeetingMindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Meeting.self, ActionItem.self], isAutosaveEnabled: true)
    }
}
