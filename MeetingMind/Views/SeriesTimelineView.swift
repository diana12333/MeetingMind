import SwiftUI
import SwiftData

struct SeriesTimelineView: View {
    let series: MeetingSeries

    private var sortedMeetings: [Meeting] {
        series.meetings.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            ForEach(sortedMeetings) { meeting in
                HStack(spacing: Theme.spacing8) {
                    Circle()
                        .fill(Theme.teal600)
                        .frame(width: 8, height: 8)
                    Text(meeting.title)
                        .font(Theme.captionFont)
                        .lineLimit(1)
                    Spacer()
                    Text(meeting.date.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
