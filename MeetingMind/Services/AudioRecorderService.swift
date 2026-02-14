import AVFoundation
import Foundation

@Observable
final class AudioRecorderService {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    var isRecording = false
    var isPaused = false
    var elapsedTime: TimeInterval = 0
    var audioLevels: [Float] = []

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    func startRecording(fileName: String) throws -> URL {
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
        startTimer()

        return audioURL
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        accumulatedTime = elapsedTime
        startTime = nil
        timer?.invalidate()
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTime = Date()
        startTimer()
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

        try? AVAudioSession.sharedInstance().setActive(false)
        return finalDuration
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
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
        }
    }
}
