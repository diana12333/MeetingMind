import SwiftUI

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = Theme.teal600

    var body: some View {
        VStack(spacing: Theme.spacing6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(Theme.headlineFont)
                .foregroundStyle(.primary)

            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
