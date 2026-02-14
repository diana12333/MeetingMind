import AVFoundation
import Foundation

@MainActor
@Observable
final class AudioPlayerService {
    private var audioPlayer: AVAudioPlayer?
    private var delegate: PlayerDelegate?

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    private var timer: Timer?

    func loadAudio(url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.enableRate = true
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0

        let del = PlayerDelegate { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                self?.timer?.invalidate()
                self?.currentTime = 0
            }
        }
        delegate = del
        audioPlayer?.delegate = del
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer?.rate = playbackRate
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            audioPlayer?.rate = rate
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentTime = self?.audioPlayer?.currentTime ?? 0
            }
        }
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    let onFinish: @Sendable () -> Void

    init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
