import SwiftUI

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.waveformRecordingColor)
                    .frame(width: 3, height: max(2, CGFloat(level) * 60))
            }
        }
        .frame(height: 60)
    }
}
