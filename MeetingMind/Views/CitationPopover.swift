import SwiftUI

struct CitationPopover: View {
    let reference: AIReference
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Text("Reference [\(reference.id)]")
                    .font(Theme.subheadlineFont)
                    .fontWeight(.bold)
                Spacer()
                TimestampBadge(seconds: reference.timestampSeconds, onTap: onSeek)
            }

            if let speaker = reference.speaker {
                Text(speaker)
                    .font(Theme.captionBoldFont)
                    .foregroundStyle(.secondary)
            }

            Text(reference.passage)
                .font(Theme.bodyFont)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: 300)
    }
}
