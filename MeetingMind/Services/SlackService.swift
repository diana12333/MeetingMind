import Foundation
import SwiftData

enum SlackError: LocalizedError {
    case notConfigured
    case invalidWebhookURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Slack is not configured. Add your webhook URL in Settings."
        case .invalidWebhookURL:
            return "The Slack webhook URL is invalid. Check your URL in Settings."
        case .invalidResponse:
            return "Invalid response from Slack."
        case .apiError(let code, let message):
            return "Slack error (\(code)): \(message)"
        }
    }
}

@MainActor
@Observable
final class SlackService {
    var isExporting = false

    var isConfigured: Bool {
        let url = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        return !url.isEmpty
    }

    func exportMeeting(_ meeting: Meeting) async throws {
        isExporting = true
        defer { isExporting = false }

        guard isConfigured else { throw SlackError.notConfigured }

        let webhookURLString = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        guard let webhookURL = URL(string: webhookURLString) else {
            throw SlackError.invalidWebhookURL
        }

        let blocks = buildBlocks(from: meeting)
        let payload: [String: Any] = ["blocks": blocks]

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SlackError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SlackError.apiError(statusCode: httpResponse.statusCode, message: body)
        }
    }

    func testConnection() async throws {
        guard isConfigured else { throw SlackError.notConfigured }

        let webhookURLString = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        guard let webhookURL = URL(string: webhookURLString) else {
            throw SlackError.invalidWebhookURL
        }

        let payload: [String: Any] = [
            "blocks": [
                [
                    "type": "section",
                    "text": [
                        "type": "mrkdwn",
                        "text": "MeetingMind connection test successful!"
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SlackError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SlackError.apiError(statusCode: httpResponse.statusCode, message: body)
        }
    }

    // MARK: - Block Kit Formatting

    private func buildBlocks(from meeting: Meeting) -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        // Header
        blocks.append([
            "type": "header",
            "text": [
                "type": "plain_text",
                "text": meeting.title,
                "emoji": true
            ]
        ])

        // Meeting details context
        let dateStr = meeting.date.formatted(date: .long, time: .shortened)
        let durationMin = Int(meeting.duration / 60)
        blocks.append([
            "type": "context",
            "elements": [
                [
                    "type": "mrkdwn",
                    "text": ":calendar: \(dateStr)  |  :stopwatch: \(durationMin) min"
                ]
            ]
        ])

        blocks.append(["type": "divider"])

        // TL;DR / Summary
        if let summary = meeting.summary, !summary.isEmpty {
            let truncated = String(summary.prefix(2900))
            blocks.append([
                "type": "section",
                "text": [
                    "type": "mrkdwn",
                    "text": "*Summary*\n\(truncated)"
                ]
            ])
            blocks.append(["type": "divider"])
        }

        // Key Decisions (as fields)
        let insights = meeting.keyInsightsWithTimestamps
        if !insights.isEmpty {
            let decisionsText = insights.prefix(10).map { "• \($0.text)" }.joined(separator: "\n")
            blocks.append([
                "type": "section",
                "text": [
                    "type": "mrkdwn",
                    "text": "*Key Insights*\n\(String(decisionsText.prefix(2900)))"
                ]
            ])
        } else if let plainInsights = meeting.keyInsights, !plainInsights.isEmpty {
            let decisionsText = plainInsights.prefix(10).map { "• \($0)" }.joined(separator: "\n")
            blocks.append([
                "type": "section",
                "text": [
                    "type": "mrkdwn",
                    "text": "*Key Insights*\n\(String(decisionsText.prefix(2900)))"
                ]
            ])
        }

        // Action Items
        if !meeting.actionItems.isEmpty {
            var itemsText = "*Action Items*\n"
            for item in meeting.actionItems.prefix(15) {
                var line = "• \(item.title)"
                if let dueDate = item.dueDate {
                    line += " _(due: \(dueDate.formatted(date: .abbreviated, time: .omitted)))_"
                }
                itemsText += line + "\n"
            }
            blocks.append([
                "type": "section",
                "text": [
                    "type": "mrkdwn",
                    "text": String(itemsText.prefix(2900))
                ]
            ])
        }

        // Deep link button
        let deepLink = "meetingmind://meeting/\(meeting.id.uuidString)"
        blocks.append([
            "type": "actions",
            "elements": [
                [
                    "type": "button",
                    "text": [
                        "type": "plain_text",
                        "text": "Open in MeetingMind",
                        "emoji": true
                    ],
                    "url": deepLink
                ]
            ]
        ])

        return blocks
    }
}
