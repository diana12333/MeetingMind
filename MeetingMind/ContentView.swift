import SwiftUI

struct ContentView: View {
    var body: some View {
        MeetingListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meeting.self, ActionItem.self, MeetingSeries.self, MeetingCategory.self], inMemory: true)
        .environment(SubscriptionService())
        .environment(AppState())
}
