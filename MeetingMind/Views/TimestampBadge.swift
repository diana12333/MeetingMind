import SwiftUI

struct TimestampBadge: View {
    let seconds: Int
    let onTap: (TimeInterval) -> Void

    var body: some View {
        Button {
            onTap(TimeInterval(seconds))
        } label: {
            HStack(spacing: Theme.spacing4) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .semibold))
                Text(formatTimestamp(seconds))
                    .font(.caption2.monospaced())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.spacing6)
            .padding(.vertical, Theme.spacing4)
            .background(Color.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formatTimestamp(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
