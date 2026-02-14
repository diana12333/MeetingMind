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
            VStack(spacing: 40) {
                Spacer()

                Text(formatTime(recorder.elapsedTime))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(recorder.isRecording ? .red : .primary)

                WaveformView(levels: recorder.audioLevels)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 40) {
                    Button {
                        cancelRecording()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray)
                    }

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
                                .fill(Color.red)
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
                    }

                    Button {
                        stopRecording()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(recorder.isRecording ? .red : .gray)
                    }
                    .disabled(!recorder.isRecording)
                }

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

    private func startRecording() {
        let newMeeting = Meeting(title: "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))")
        let fileName = "\(newMeeting.id.uuidString).m4a"
        newMeeting.audioFileName = fileName

        do {
            _ = try recorder.startRecording(fileName: fileName)
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
