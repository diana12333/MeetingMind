import AVFoundation
import Foundation
import WatchKit

@MainActor
@Observable
final class WatchAudioRecorderService {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var audioLevel: Float = 0

    private var startTime: Date?
    private(set) var recordingURL: URL?

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000,
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        startTime = Date()
        recordingURL = fileURL
        startTimer()

        WKInterfaceDevice.current().play(.start)

        return fileURL
    }

    func stopRecording() -> (URL?, TimeInterval) {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil

        let finalDuration = elapsedTime
        let url = recordingURL

        isRecording = false
        elapsedTime = 0
        audioLevel = 0
        startTime = nil
        recordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false)

        WKInterfaceDevice.current().play(.stop)

        return (url, finalDuration)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
                self.audioRecorder?.updateMeters()
                if let level = self.audioRecorder?.averagePower(forChannel: 0) {
                    self.audioLevel = max(0, (level + 60) / 60)
                }
            }
        }
    }
}
