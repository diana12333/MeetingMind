import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var audioFileName: String?
    var transcriptText: String
    var status: MeetingStatus
    var summary: String?
    var keyInsights: [String]?

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.meeting)
    var actionItems: [ActionItem]

    init(
        title: String,
        date: Date = .now,
        duration: TimeInterval = 0,
        audioFileName: String? = nil,
        transcriptText: String = "",
        status: MeetingStatus = .recording
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.status = status
        self.actionItems = []
    }

    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(audioFileName)
    }
}
