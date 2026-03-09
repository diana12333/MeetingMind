import SwiftUI

struct SeriesBannerView: View {
    let series: MeetingSeries
    let meeting: Meeting

    private var meetingPosition: Int {
        let sorted = series.sortedMeetings
        return (sorted.firstIndex(where: { $0.id == meeting.id }) ?? 0) + 1
    }

    var body: some View {
        NavigationLink(value: series) {
            HStack(spacing: Theme.spacing8) {
                RoundedRectangle(cornerRadius: Theme.accentBarCornerRadius)
                    .fill(Theme.teal600)
                    .frame(width: Theme.accentBarWidth)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Part of: \(series.name)")
                        .font(Theme.captionBoldFont)
                        .foregroundStyle(Theme.teal600)
                    Text("Meeting \(meetingPosition) of \(series.meetingCount)")
                        .font(Theme.badgeFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.spacing12)
            .background(Theme.surfaceTeal)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
