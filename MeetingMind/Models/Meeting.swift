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
    var transcriptionLanguage: String?
    var categoryName: String?

    // Timeline mapping & transcript references (optional → lightweight migration)
    var timestampedSegmentsJSON: String?
    var referencesJSON: String?
    var keyInsightsJSON: String?
    var speakerSegmentsJSON: String?
    var executiveBriefJSON: String?

    // Notion export (optional → lightweight migration)
    var notionPageId: String?
    var notionPageUrl: String?

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

    var isExportedToNotion: Bool { notionPageId != nil }

    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(audioFileName)
    }

    // MARK: - Computed wrappers for JSON-encoded fields

    var transcriptSegments: [TranscriptSegment] {
        get {
            guard let json = timestampedSegmentsJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([TranscriptSegment].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                timestampedSegmentsJSON = nil
                return
            }
            timestampedSegmentsJSON = String(data: data, encoding: .utf8)
        }
    }

    var references: [AIReference] {
        get {
            guard let json = referencesJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([AIReference].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                referencesJSON = nil
                return
            }
            referencesJSON = String(data: data, encoding: .utf8)
        }
    }

    var keyInsightsWithTimestamps: [AIKeyInsight] {
        get {
            guard let json = keyInsightsJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([AIKeyInsight].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                keyInsightsJSON = nil
                return
            }
            keyInsightsJSON = String(data: data, encoding: .utf8)
        }
    }

    var speakerSegments: [SpeakerSegment] {
        get {
            guard let json = speakerSegmentsJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([SpeakerSegment].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                speakerSegmentsJSON = nil
                return
            }
            speakerSegmentsJSON = String(data: data, encoding: .utf8)
        }
    }

    var speakerNames: [String] {
        Array(Set(speakerSegments.map(\.speaker))).sorted()
    }

    var executiveBrief: AIAnalysisResult? {
        get {
            guard let json = executiveBriefJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AIAnalysisResult.self, from: data)
        }
        set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value) else {
                executiveBriefJSON = nil
                return
            }
            executiveBriefJSON = String(data: data, encoding: .utf8)
        }
    }
}
