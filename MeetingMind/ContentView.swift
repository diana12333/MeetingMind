import SwiftUI

struct ContentView: View {
    var body: some View {
        MeetingListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meeting.self, ActionItem.self], inMemory: true)
}
