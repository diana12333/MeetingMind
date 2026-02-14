import AVFoundation
import Foundation

@Observable
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    private var timer: Timer?

    func loadAudio(url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
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
            self?.currentTime = self?.audioPlayer?.currentTime ?? 0
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        timer?.invalidate()
        currentTime = 0
    }
}
