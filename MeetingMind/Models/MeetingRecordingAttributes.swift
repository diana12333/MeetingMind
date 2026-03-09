import ActivityKit
import Foundation

struct MeetingRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isPaused: Bool
        var audioLevel: Float
    }

    var meetingTitle: String
}
