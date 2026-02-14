import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @State private var searchText = ""
    @State private var showRecording = false

    var filteredMeetings: [Meeting] {
        if searchText.isEmpty { return meetings }
        return meetings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.transcriptText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredMeetings) { meeting in
                    NavigationLink(value: meeting) {
                        MeetingRowView(meeting: meeting)
                    }
                }
                .onDelete(perform: deleteMeetings)
            }
            .navigationTitle("MeetingMind")
            .searchable(text: $searchText, prompt: "Search meetings")
            .navigationDestination(for: Meeting.self) { meeting in
                MeetingDetailView(meeting: meeting)
            }
            .overlay {
                if meetings.isEmpty {
                    ContentUnavailableView(
                        "No Meetings",
                        systemImage: "mic.badge.plus",
                        description: Text("Tap + to record your first meeting.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showRecording = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView()
            }
        }
    }

    private func deleteMeetings(at offsets: IndexSet) {
        for index in offsets {
            let meeting = filteredMeetings[index]
            if let url = meeting.audioFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(meeting)
        }
    }
}
