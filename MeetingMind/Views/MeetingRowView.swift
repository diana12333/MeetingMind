import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)

                Text(meeting.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: meeting.status)

                Text(formatDuration(meeting.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

extension MeetingStatus {
    var label: String {
        switch self {
        case .recording: "Recording"
        case .transcribing: "Transcribing"
        case .analyzing: "Analyzing"
        case .complete: "Complete"
        case .failed: "Failed"
        }
    }

    var color: Color {
        switch self {
        case .recording: .red
        case .transcribing: .orange
        case .analyzing: .blue
        case .complete: .green
        case .failed: .red
        }
    }
}
