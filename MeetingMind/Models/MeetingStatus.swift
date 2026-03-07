import Foundation

enum MeetingStatus: String, Codable {
    case recording
    case transcribing
    case diarizing
    case analyzing
    case complete
    case failed
}
