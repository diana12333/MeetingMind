import Foundation
import SwiftData

enum TeamsError: LocalizedError {
    case notConfigured
    case invalidWebhookURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Microsoft Teams is not configured. Add your webhook URL in Settings."
        case .invalidWebhookURL:
            return "The Teams webhook URL is invalid. Check your URL in Settings."
        case .invalidResponse:
            return "Invalid response from Microsoft Teams."
        case .apiError(let code, let message):
            return "Teams error (\(code)): \(message)"
        }
    }
}

@MainActor
@Observable
final class TeamsService {
    var isExporting = false

    var isConfigured: Bool {
        let url = UserDefaults.standard.string(forKey: "teamsWebhookURL") ?? ""
        return !url.isEmpty
    }

    func exportMeeting(_ meeting: Meeting) async throws {
        isExporting = true
        defer { isExporting = false }

        guard isConfigured else { throw TeamsError.notConfigured }

        let webhookURLString = UserDefaults.standard.string(forKey: "teamsWebhookURL") ?? ""
        guard let webhookURL = URL(string: webhookURLString) else {
            throw TeamsError.invalidWebhookURL
        }

        let card = buildAdaptiveCard(from: meeting)

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: card)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeamsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TeamsError.apiError(statusCode: httpResponse.statusCode, message: body)
        }
    }

    func testConnection() async throws {
        guard isConfigured else { throw TeamsError.notConfigured }

        let webhookURLString = UserDefaults.standard.string(forKey: "teamsWebhookURL") ?? ""
        guard let webhookURL = URL(string: webhookURLString) else {
            throw TeamsError.invalidWebhookURL
        }

        let card: [String: Any] = [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": [
                        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                        "type": "AdaptiveCard",
                        "version": "1.4",
                        "body": [
                            [
                                "type": "TextBlock",
                                "text": "MeetingMind connection test successful!",
                                "weight": "bolder"
                            ]
                        ]
                    ] as [String: Any]
                ]
            ]
        ]

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: card)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeamsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TeamsError.apiError(statusCode: httpResponse.statusCode, message: body)
        }
    }

    // MARK: - Adaptive Card Formatting

    private func buildAdaptiveCard(from meeting: Meeting) -> [String: Any] {
        var body: [[String: Any]] = []

        // Title
        body.append([
            "type": "TextBlock",
            "text": meeting.title,
            "size": "large",
            "weight": "bolder",
            "wrap": true
        ])

        // Meeting details
        let dateStr = meeting.date.formatted(date: .long, time: .shortened)
        let durationMin = Int(meeting.duration / 60)
        body.append([
            "type": "TextBlock",
            "text": "\(dateStr) | \(durationMin) min",
            "isSubtle": true,
            "spacing": "none"
        ])

        // Summary
        if let summary = meeting.summary, !summary.isEmpty {
            body.append([
                "type": "TextBlock",
                "text": "**Summary**",
                "weight": "bolder",
                "spacing": "large"
            ])
            body.append([
                "type": "TextBlock",
                "text": String(summary.prefix(2900)),
                "wrap": true
            ])
        }

        // Key Insights
        let insights = meeting.keyInsightsWithTimestamps
        if !insights.isEmpty {
            body.append([
                "type": "TextBlock",
                "text": "**Key Insights**",
                "weight": "bolder",
                "spacing": "large"
            ])
            let insightItems: [[String: Any]] = insights.prefix(10).map { insight in
                [
                    "type": "TextBlock",
                    "text": "- \(insight.text)",
                    "wrap": true,
                    "spacing": "none"
                ]
            }
            body.append(contentsOf: insightItems)
        } else if let plainInsights = meeting.keyInsights, !plainInsights.isEmpty {
            body.append([
                "type": "TextBlock",
                "text": "**Key Insights**",
                "weight": "bolder",
                "spacing": "large"
            ])
            let insightItems: [[String: Any]] = plainInsights.prefix(10).map { insight in
                [
                    "type": "TextBlock",
                    "text": "- \(insight)",
                    "wrap": true,
                    "spacing": "none"
                ]
            }
            body.append(contentsOf: insightItems)
        }

        // Action Items
        if !meeting.actionItems.isEmpty {
            body.append([
                "type": "TextBlock",
                "text": "**Action Items**",
                "weight": "bolder",
                "spacing": "large"
            ])
            for item in meeting.actionItems.prefix(15) {
                var text = "- \(item.title)"
                if let dueDate = item.dueDate {
                    text += " *(due: \(dueDate.formatted(date: .abbreviated, time: .omitted)))*"
                }
                body.append([
                    "type": "TextBlock",
                    "text": text,
                    "wrap": true,
                    "spacing": "none"
                ])
            }
        }

        // Deep link action
        let deepLink = "meetingmind://meeting/\(meeting.id.uuidString)"
        let actions: [[String: Any]] = [
            [
                "type": "Action.OpenUrl",
                "title": "Open in MeetingMind",
                "url": deepLink
            ]
        ]

        let cardContent: [String: Any] = [
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": body,
            "actions": actions
        ]

        return [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": cardContent
                ]
            ]
        ]
    }
}
