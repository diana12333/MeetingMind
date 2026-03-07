import SwiftUI

struct TimelineBarView: View {
    let segments: [SpeakerSegment]
    let duration: TimeInterval
    let currentTime: TimeInterval
    let speakerNames: [String]
    let onTap: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: Theme.spacing4) {
            // Speaker legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacing8) {
                    ForEach(Array(speakerNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: Theme.spacing4) {
                            Circle()
                                .fill(Theme.speakerColor(for: index))
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Timeline bar
            GeometryReader { geo in
                let totalWidth = geo.size.width

                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 24)

                    // Speaker segments
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        let speakerIndex = speakerNames.firstIndex(of: segment.speaker) ?? 0
                        let startFraction = duration > 0 ? segment.startSeconds / duration : 0
                        let endFraction = duration > 0 ? segment.endSeconds / duration : 0
                        let segWidth = max((endFraction - startFraction) * totalWidth, 2)
                        let xOffset = startFraction * totalWidth

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.speakerColor(for: speakerIndex))
                            .frame(width: segWidth, height: 24)
                            .offset(x: xOffset)
                            .onTapGesture {
                                onTap(segment.startSeconds)
                            }
                    }

                    // Playback scrubber
                    if duration > 0 {
                        let scrubberX = (currentTime / duration) * totalWidth
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 2, height: 32)
                            .offset(x: scrubberX)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 24)
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.spacing8)
    }
}
