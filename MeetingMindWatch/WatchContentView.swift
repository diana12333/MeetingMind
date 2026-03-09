import SwiftUI

struct WatchContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchRecordingView()
                .tag(0)

            WatchMeetingListView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}
