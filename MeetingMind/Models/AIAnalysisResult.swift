import Foundation

struct AIAnalysisResult: Codable {
    // Legacy fields (kept for backward compatibility with existing meetings)
    let summary: String
    let keyInsights: [AIKeyInsight]
    let actionItems: [AIActionItem]
    let suggestedTitle: String?
    let references: [AIReference]?

    // Executive brief fields (new)
    let tldr: String?
    let keyDecisions: [AIDecision]?
    let discussionPoints: [AIDiscussionPoint]?
    let openQuestions: [AIOpenQuestion]?
    let nextSteps: [AIActionItem]?

    init(
        summary: String,
        keyInsights: [AIKeyInsight],
        actionItems: [AIActionItem],
        suggestedTitle: String? = nil,
        references: [AIReference]? = nil,
        tldr: String? = nil,
        keyDecisions: [AIDecision]? = nil,
        discussionPoints: [AIDiscussionPoint]? = nil,
        openQuestions: [AIOpenQuestion]? = nil,
        nextSteps: [AIActionItem]? = nil
    ) {
        self.summary = summary
        self.keyInsights = keyInsights
        self.actionItems = actionItems
        self.suggestedTitle = suggestedTitle
        self.references = references
        self.tldr = tldr
        self.keyDecisions = keyDecisions
        self.discussionPoints = discussionPoints
        self.openQuestions = openQuestions
        self.nextSteps = nextSteps
    }

    var keyInsightStrings: [String] {
        keyInsights.map(\.text)
    }

    var effectiveTitle: String {
        if let suggestedTitle, !suggestedTitle.isEmpty {
            return suggestedTitle
        }
        let firstSentence = summary.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? summary
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 {
            return trimmed
        }
        return String(trimmed.prefix(47)) + "..."
    }

    /// The TL;DR if available, otherwise falls back to the first sentence of summary
    var effectiveTldr: String {
        if let tldr, !tldr.isEmpty { return tldr }
        let firstSentence = summary.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? summary
        return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AIDecision: Codable, Sendable {
    let text: String
    let citations: [Int]?
    let timestampSeconds: Int?
}

struct AIDiscussionPoint: Codable, Sendable {
    let topic: String
    let summary: String
    let citations: [Int]?
    let timestampSeconds: Int?
}

struct AIOpenQuestion: Codable, Sendable {
    let text: String
    let citations: [Int]?
    let timestampSeconds: Int?
}

struct AIKeyInsight: Codable, Sendable {
    let text: String
    let timestampSeconds: Int?

    init(text: String, timestampSeconds: Int? = nil) {
        self.text = text
        self.timestampSeconds = timestampSeconds
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let plainString = try? container.decode(String.self) {
            self.text = plainString
            self.timestampSeconds = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.text = try container.decode(String.self, forKey: .text)
            self.timestampSeconds = try container.decodeIfPresent(Int.self, forKey: .timestampSeconds)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case text, timestampSeconds
    }
}

struct AIReference: Codable, Sendable {
    let id: Int
    let passage: String
    let timestampSeconds: Int
    let speaker: String?

    init(id: Int, passage: String, timestampSeconds: Int, speaker: String? = nil) {
        self.id = id
        self.passage = passage
        self.timestampSeconds = timestampSeconds
        self.speaker = speaker
    }
}

struct AIActionItem: Codable {
    let title: String
    let type: String
    let suggestedDate: String?
    let assignee: String?
    let timestampSeconds: Int?

    var actionItemType: ActionItemType {
        ActionItemType(rawValue: type) ?? .task
    }

    var parsedDate: Date? {
        guard let suggestedDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: suggestedDate)
            ?? ISO8601DateFormatter().date(from: suggestedDate)
    }
}
