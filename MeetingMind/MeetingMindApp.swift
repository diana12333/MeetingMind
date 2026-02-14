import SwiftUI
import SwiftData

@main
struct MeetingMindApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Meeting.self, ActionItem.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
