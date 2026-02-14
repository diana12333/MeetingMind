import Foundation

enum MeetingStatus: String, Codable {
    case recording
    case transcribing
    case analyzing
    case complete
    case failed
}
