import Foundation

struct SpeakerSegment: Codable, Sendable {
    let speaker: String
    let startSeconds: TimeInterval
    let endSeconds: TimeInterval
    let text: String
}

struct DiarizationResult: Codable, Sendable {
    let speakers: [String]
    let segments: [SpeakerSegment]
}
