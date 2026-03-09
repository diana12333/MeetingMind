import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let onStay: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.successCheck)

            Text(message)
                .font(Theme.subheadlineFont)

            Spacer()

            Button("Stay") {
                onStay()
            }
            .font(Theme.captionFont)
            .foregroundStyle(Theme.teal600)
        }
        .padding(Theme.cardPadding)
        .background(Theme.surfaceTeal)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .padding(.horizontal, Theme.spacing16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
