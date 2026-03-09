import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var recorder = AudioRecorderService()
    @State private var meeting: Meeting?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing40) {
                Spacer()

                statusLabel
                timerDisplay

                WaveformView(levels: recorder.audioLevels)
                    .padding(.horizontal)

                Spacer()

                controlButtons

                Spacer()
            }
            .navigationTitle("Record Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelRecording() }
                }
            }
            .alert("Recording Error", isPresented: $showError) {
                Button("OK") { dismiss() }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private var statusLabel: some View {
        Text(statusText)
            .font(Theme.captionBoldFont)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(recorder.isRecording ? Theme.statusRecording : .secondary)
    }

    private var statusText: String {
        if recorder.isRecording && !recorder.isPaused {
            return "Recording"
        } else if recorder.isPaused {
            return "Paused"
        } else {
            return "Ready"
        }
    }

    private var timerDisplay: some View {
        Text(formatTime(recorder.elapsedTime))
            .font(Theme.timerMonoFont)
            .foregroundStyle(recorder.isRecording ? Theme.statusRecording : .primary)
    }

    private var controlButtons: some View {
        HStack(spacing: Theme.spacing40) {
            cancelButton
            recordButton
            stopButton
        }
    }

    private var cancelButton: some View {
        Button {
            cancelRecording()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inactiveControl)
        }
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording && !recorder.isPaused {
                recorder.pauseRecording()
            } else if recorder.isPaused {
                recorder.resumeRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.statusRecording)
                    .frame(width: 80, height: 80)

                if recorder.isRecording && !recorder.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                }
            }
            .scaleEffect(recorder.isRecording && !recorder.isPaused ? 1.06 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: recorder.isRecording && !recorder.isPaused
            )
        }
    }

    private var stopButton: some View {
        Button {
            stopRecording()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(recorder.isRecording ? Theme.statusRecording : Theme.inactiveControl)
        }
        .disabled(!recorder.isRecording)
    }

    // MARK: - Actions

    private func startRecording() {
        let newMeeting = Meeting(title: "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))")
        let fileName = "\(newMeeting.id.uuidString).m4a"
        newMeeting.audioFileName = fileName

        do {
            _ = try recorder.startRecording(fileName: fileName, title: newMeeting.title)
            meeting = newMeeting
            modelContext.insert(newMeeting)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() {
        let duration = recorder.stopRecording()
        meeting?.duration = duration
        meeting?.status = .transcribing
        dismiss()
    }

    private func cancelRecording() {
        if recorder.isRecording {
            _ = recorder.stopRecording()
            if let meeting {
                if let url = meeting.audioFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                modelContext.delete(meeting)
            }
        }
        dismiss()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
