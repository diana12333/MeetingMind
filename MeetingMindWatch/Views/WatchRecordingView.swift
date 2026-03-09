import SwiftUI

struct WatchRecordingView: View {
    @Environment(WatchSessionService.self) private var sessionService
    @State private var recorder = WatchAudioRecorderService()
    @State private var showError = false
    @State private var errorMessage = ""

    private let tealAccent = Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)
    private let coral = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)

    var body: some View {
        VStack(spacing: 8) {
            statusText

            timerDisplay

            audioLevelBars

            recordButton

            if let progress = sessionService.transferProgress {
                transferProgressView(progress)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Subviews

    private var statusText: some View {
        Text(recorder.isRecording ? "RECORDING" : "READY")
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(recorder.isRecording ? coral : .secondary)
    }

    private var timerDisplay: some View {
        Text(formatTime(recorder.elapsedTime))
            .font(.system(size: 32, weight: .thin, design: .monospaced))
            .foregroundStyle(recorder.isRecording ? coral : .primary)
    }

    private var audioLevelBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let threshold = Float(index) / 5.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(recorder.audioLevel > threshold ? tealAccent : tealAccent.opacity(0.2))
                    .frame(width: 6, height: barHeight(for: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.1), value: recorder.audioLevel)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 10, 14, 10, 6]
        return heights[index]
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(coral)
                    .frame(width: 60, height: 60)

                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func transferProgressView(_ progress: Double) -> some View {
        VStack(spacing: 2) {
            ProgressView(value: progress)
                .tint(tealAccent)
            Text("Sending to iPhone...")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        do {
            _ = try recorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() {
        let (url, duration) = recorder.stopRecording()
        if let url {
            sessionService.transferRecording(fileURL: url, duration: duration)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
