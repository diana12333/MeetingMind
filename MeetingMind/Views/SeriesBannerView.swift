import SwiftUI
import SwiftData

struct SeriesBannerView: View {
    let series: MeetingSeries
    let meeting: Meeting

    var body: some View {
        NavigationLink(value: series) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "link")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.teal600)
                VStack(alignment: .leading, spacing: 2) {
                    Text(series.name)
                        .font(Theme.captionBoldFont)
                        .foregroundStyle(Theme.teal600)
                    Text("\(series.meetings.count) meetings in series")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.spacing12)
            .background(Theme.surfaceTeal)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
