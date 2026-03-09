import SwiftUI

struct WatchMeetingListView: View {
    @Environment(WatchSessionService.self) private var sessionService

    private let tealAccent = Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)

    var body: some View {
        List {
            if sessionService.recentMeetings.isEmpty {
                Text("No recent meetings")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sessionService.recentMeetings) { meeting in
                    meetingRow(meeting)
                }
            }
        }
        .navigationTitle("Meetings")
        .onAppear {
            sessionService.requestMeetingList()
        }
    }

    private func meetingRow(_ meeting: WatchMeetingInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .lineLimit(2)

            HStack(spacing: 6) {
                statusIndicator(meeting.status)
                Text(meeting.date, style: .relative)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(_ status: String) -> some View {
        let (color, label) = statusInfo(status)
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func statusInfo(_ status: String) -> (Color, String) {
        switch status {
        case "complete":
            return (Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255), "Done")
        case "transcribing":
            return (Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255), "Transcribing")
        case "analyzing":
            return (tealAccent, "Analyzing")
        case "failed":
            return (Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255), "Failed")
        default:
            return (.secondary, status.capitalized)
        }
    }
}
