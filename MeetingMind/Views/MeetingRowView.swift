import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    private var dayNumber: String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: meeting.date))"
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: meeting.date)
    }

    var body: some View {
        HStack(spacing: Theme.cardPadding) {
            // Date badge with teal-tinted background
            VStack(spacing: 0) {
                Text(dayNumber)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.teal600)
                Text(monthAbbrev)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.teal600.opacity(0.7))
            }
            .frame(width: 46, height: 46)
            .background(Theme.surfaceTeal)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(meeting.title)
                    .font(Theme.headlineFont)
                    .lineLimit(2)

                HStack(spacing: Theme.spacing8) {
                    if let categoryName = meeting.categoryName {
                        Text(categoryName)
                            .font(Theme.badgeFont)
                            .padding(.horizontal, Theme.spacing8)
                            .padding(.vertical, Theme.spacing4)
                            .background(Theme.surfaceTeal)
                            .foregroundStyle(Theme.teal600)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Text(formatDuration(meeting.duration))
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: meeting.status)
        }
        .padding(.vertical, Theme.spacing6)
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
        HStack(spacing: Theme.spacing4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(status.label)
                .font(Theme.badgeFont)
        }
        .padding(.horizontal, Theme.spacing8)
        .padding(.vertical, Theme.spacing4)
        .background(status.color.opacity(Theme.badgeBackgroundOpacity))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

extension MeetingStatus {
    var label: String {
        switch self {
        case .recording: "Recording"
        case .transcribing: "Transcribing"
        case .diarizing: "Identifying Speakers"
        case .analyzing: "Analyzing"
        case .complete: "Complete"
        case .failed: "Failed"
        }
    }

    var color: Color {
        switch self {
        case .recording: Theme.statusRecording
        case .transcribing: Theme.statusTranscribing
        case .diarizing: Theme.statusDiarizing
        case .analyzing: Theme.statusAnalyzing
        case .complete: Theme.statusComplete
        case .failed: Theme.statusFailed
        }
    }
}
