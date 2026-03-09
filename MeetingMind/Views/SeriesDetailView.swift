import SwiftUI
import SwiftData

struct SeriesDetailView: View {
    @Bindable var series: MeetingSeries

    private var sortedMeetings: [Meeting] {
        series.meetings.sorted { ($0.seriesOrder ?? 0) < ($1.seriesOrder ?? 0) }
    }

    var body: some View {
        List {
            Section("Meetings") {
                ForEach(sortedMeetings) { meeting in
                    NavigationLink(value: meeting) {
                        VStack(alignment: .leading, spacing: Theme.spacing4) {
                            Text(meeting.title)
                                .font(Theme.headlineFont)
                            Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(series.name)
    }
}
