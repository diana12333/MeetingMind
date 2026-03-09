import ActivityKit
import SwiftUI
import WidgetKit

struct MeetingRecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetingRecordingAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        RecordingDot(isPaused: context.state.isPaused)
                        Text(context.state.isPaused ? "Paused" : "Recording")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedTime))
                        .font(.system(.body, design: .monospaced).monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.meetingTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        MiniWaveformView(level: context.state.audioLevel, barCount: 12)
                            .frame(height: 24)

                        Spacer()

                        Link(destination: URL(string: "meetingmind://recording?action=pause")!) {
                            Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 13/255, green: 148/255, blue: 136/255))
                        }

                        Link(destination: URL(string: "meetingmind://recording?action=stop")!) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    RecordingDot(isPaused: context.state.isPaused)
                        .frame(width: 8, height: 8)
                    Text(context.state.isPaused ? "Paused" : "Rec")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text(formatTime(context.state.elapsedTime))
                        .font(.caption.monospacedDigit())
                    MiniWaveformView(level: context.state.audioLevel, barCount: 4)
                        .frame(width: 20, height: 12)
                }
            } minimal: {
                RecordingDot(isPaused: context.state.isPaused)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<MeetingRecordingAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    RecordingDot(isPaused: context.state.isPaused)
                    Text(context.state.isPaused ? "Paused" : "Recording")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
                }

                Text(context.attributes.meetingTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                MiniWaveformView(level: context.state.audioLevel, barCount: 8)
                    .frame(height: 20)
            }

            Spacer()

            VStack(spacing: 12) {
                Text(formatTime(context.state.elapsedTime))
                    .font(.system(.title3, design: .monospaced).monospacedDigit())
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Link(destination: URL(string: "meetingmind://recording?action=pause")!) {
                        Text(context.state.isPaused ? "Resume" : "Pause")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 13/255, green: 148/255, blue: 136/255))
                    }

                    Link(destination: URL(string: "meetingmind://recording?action=stop")!) {
                        Text("Stop")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Dot

struct RecordingDot: View {
    let isPaused: Bool
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
            .frame(width: 8, height: 8)
            .opacity(isPaused ? 0.5 : (isAnimating ? 1.0 : 0.4))
            .animation(
                isPaused ? .default : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Mini Waveform View

struct MiniWaveformView: View {
    let level: Float
    let barCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
                    .frame(width: 3)
                    .scaleEffect(y: barHeight(for: index), anchor: .bottom)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        let variation = sin(Double(index) * 0.8 + Double(level) * 10) * 0.3 + 0.7
        let height = normalizedLevel * CGFloat(variation)
        return max(0.1, min(1.0, height))
    }
}
