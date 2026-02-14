import Foundation

struct AIAnalysisResult: Codable {
    let summary: String
    let keyInsights: [String]
    let actionItems: [AIActionItem]
}

struct AIActionItem: Codable {
    let title: String
    let type: String
    let suggestedDate: String?
    let assignee: String?

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
