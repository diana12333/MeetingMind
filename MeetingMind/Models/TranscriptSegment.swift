import Foundation

struct TranscriptSegment: Codable, Sendable {
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
}

struct TranscriptionResult: Sendable {
    let fullText: String
    let segments: [TranscriptSegment]
}
