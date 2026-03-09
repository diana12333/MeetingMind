import ActivityKit
import AVFoundation
import Foundation

@MainActor
@Observable
final class AudioRecorderService {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var liveActivity: Activity<MeetingRecordingAttributes>?
    private var lastActivityUpdate: Date = .distantPast

    var isRecording = false
    var isPaused = false
    var elapsedTime: TimeInterval = 0
    var audioLevels: [Float] = []

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var meetingTitle: String = ""

    func startRecording(fileName: String, title: String = "Meeting") throws -> URL {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        isPaused = false
        startTime = Date()
        accumulatedTime = 0
        meetingTitle = title
        startTimer()
        startLiveActivity()

        return audioURL
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        accumulatedTime = elapsedTime
        startTime = nil
        timer?.invalidate()
        updateLiveActivity()
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTime = Date()
        startTimer()
        updateLiveActivity()
    }

    func stopRecording() -> TimeInterval {
        audioRecorder?.stop()
        timer?.invalidate()

        let finalDuration = elapsedTime
        isRecording = false
        isPaused = false
        elapsedTime = 0
        accumulatedTime = 0
        startTime = nil
        audioLevels = []

        endLiveActivity()

        try? AVAudioSession.sharedInstance().setActive(false)
        return finalDuration
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let startTime = self.startTime {
                    self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(startTime)
                }
                self.audioRecorder?.updateMeters()
                if let level = self.audioRecorder?.averagePower(forChannel: 0) {
                    let normalizedLevel = max(0, (level + 60) / 60)
                    self.audioLevels.append(normalizedLevel)
                    if self.audioLevels.count > 100 {
                        self.audioLevels.removeFirst()
                    }
                }

                // Update Live Activity at ~1 Hz
                let now = Date()
                if now.timeIntervalSince(self.lastActivityUpdate) >= 1.0 {
                    self.lastActivityUpdate = now
                    self.updateLiveActivity()
                }
            }
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MeetingRecordingAttributes(meetingTitle: meetingTitle)
        let initialState = MeetingRecordingAttributes.ContentState(
            elapsedTime: 0,
            isPaused: false,
            audioLevel: 0
        )
        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(5))

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }

        let currentLevel: Float
        if let level = audioRecorder?.averagePower(forChannel: 0) {
            currentLevel = max(0, (level + 60) / 60)
        } else {
            currentLevel = 0
        }

        let updatedState = MeetingRecordingAttributes.ContentState(
            elapsedTime: elapsedTime,
            isPaused: isPaused,
            audioLevel: currentLevel
        )
        let content = ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(5))

        Task {
            await liveActivity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }

        let finalState = MeetingRecordingAttributes.ContentState(
            elapsedTime: elapsedTime,
            isPaused: false,
            audioLevel: 0
        )
        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await liveActivity.end(content, dismissalPolicy: .default)
        }
        self.liveActivity = nil
    }
}
