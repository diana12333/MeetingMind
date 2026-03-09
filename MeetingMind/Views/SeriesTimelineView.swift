import SwiftUI

struct SeriesTimelineView: View {
    let meetings: [Meeting]

    private let dotSize: CGFloat = 12
    private let lineHeight: CGFloat = 2

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing16) {
                ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                    timelineDot(for: meeting, index: index)
                }
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing12)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func timelineDot(for meeting: Meeting, index: Int) -> some View {
        NavigationLink(value: meeting) {
            VStack(spacing: Theme.spacing6) {
                ZStack {
                    if index > 0 {
                        Rectangle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(width: Theme.spacing16 + dotSize, height: lineHeight)
                            .offset(x: -(Theme.spacing16 + dotSize) / 2)
                    }

                    Circle()
                        .fill(dotColor(for: meeting))
                        .frame(width: dotSize, height: dotSize)
                }
                .frame(width: dotSize, height: dotSize)

                Text(meeting.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(Theme.badgeFont)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func dotColor(for meeting: Meeting) -> Color {
        switch meeting.status {
        case .complete: return Theme.teal600
        case .recording, .transcribing, .diarizing, .analyzing:
            return Theme.orange500
        case .failed: return Theme.coral
        }
    }
}
