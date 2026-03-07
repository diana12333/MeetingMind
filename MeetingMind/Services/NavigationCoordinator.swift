import Foundation
import SwiftUI

@Observable
@MainActor
final class NavigationCoordinator {
    var currentTimestamp: TimeInterval = 0
    var highlightedSegmentIndex: Int? = nil
    var isFollowingPlayback: Bool = true
    var scrollToTimestamp: TimeInterval? = nil

    private var playerService: AudioPlayerService?

    func attach(player: AudioPlayerService) {
        self.playerService = player
    }

    func seekTo(_ timestamp: TimeInterval) {
        currentTimestamp = timestamp
        scrollToTimestamp = timestamp
        playerService?.seek(to: timestamp)
        playerService?.play()

        // Reset highlight, will be set by views observing scrollToTimestamp
        highlightedSegmentIndex = nil
    }

    func updatePlaybackPosition(_ time: TimeInterval) {
        currentTimestamp = time
        if isFollowingPlayback {
            scrollToTimestamp = time
        }
    }

    func clearScrollTarget() {
        scrollToTimestamp = nil
    }
}
