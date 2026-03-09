import Foundation
import SwiftData

struct NotionExportResult: Sendable {
    let pageId: String
    let pageUrl: String
}

enum NotionError: LocalizedError {
    case notConfigured
    case unauthorized
    case parentNotFound
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Notion is not configured. Add your API token and parent page ID in Settings."
        case .unauthorized:
            return "Notion API token is invalid or the integration doesn't have access to the page. Check your token in Settings."
        case .parentNotFound:
            return "Parent page not found. Verify the page ID in Settings and ensure your integration has access."
        case .invalidResponse:
            return "Invalid response from Notion API."
        case .apiError(let code, let message):
            return "Notion error (\(code)): \(message)"
        }
    }
}

@MainActor
@Observable
final class NotionService {
    var isExporting = false

    private let notionAPIBase = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"
    private let blockLimit = 100
    private let richTextCharLimit = 2000

    var isConfigured: Bool {
        let token = UserDefaults.standard.string(forKey: "notionAPIToken") ?? ""
        let pageId = UserDefaults.standard.string(forKey: "notionParentPageId") ?? ""
        return !token.isEmpty && !pageId.isEmpty
    }

    func exportMeeting(_ meeting: Meeting) async throws -> NotionExportResult {
        isExporting = true
        defer { isExporting = false }

        guard isConfigured else { throw NotionError.notConfigured }

        let token = UserDefaults.standard.string(forKey: "notionAPIToken") ?? ""
        let parentPageId = UserDefaults.standard.string(forKey: "notionParentPageId") ?? ""

        let blocks = buildBlocks(from: meeting)

        // Create the page with the first 100 blocks
        let firstBatch = Array(blocks.prefix(blockLimit))
        let result = try await createPage(
            title: meeting.title,
            parentPageId: parentPageId,
            children: firstBatch,
            token: token
        )

        // Append remaining blocks in 100-block chunks
        if blocks.count > blockLimit {
            let remaining = Array(blocks.dropFirst(blockLimit))
            for chunk in remaining.chunked(into: blockLimit) {
                try await appendBlocks(to: result.pageId, children: chunk, token: token)
            }
        }

        return result
    }

    // MARK: - Block Building

    private func buildBlocks(from meeting: Meeting) -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        // 1. Meeting Details
        blocks.append(heading2("Meeting Details"))
        let dateStr = meeting.date.formatted(date: .long, time: .shortened)
        let durationMin = Int(meeting.duration / 60)
        var detailLines = [
            "Date: \(dateStr)",
            "Duration: \(durationMin) minutes"
        ]
        if let category = meeting.categoryName {
            detailLines.append("Category: \(category)")
        }
        blocks.append(paragraph(detailLines.joined(separator: "\n")))
        blocks.append(divider())

        // 2. Summary
        if let summary = meeting.summary, !summary.isEmpty {
            blocks.append(heading2("Summary"))
            blocks.append(contentsOf: paragraphBlocks(summary))
            blocks.append(divider())
        }

        // 3. Key Insights
        let insights = meeting.keyInsightsWithTimestamps
        if !insights.isEmpty {
            blocks.append(heading2("Key Insights"))
            for insight in insights {
                var text = insight.text
                if let ts = insight.timestampSeconds {
                    let m = ts / 60
                    let s = ts % 60
                    text += " [\(String(format: "%02d:%02d", m, s))]"
                }
                blocks.append(bulletedListItem(text))
            }
            blocks.append(divider())
        } else if let plainInsights = meeting.keyInsights, !plainInsights.isEmpty {
            blocks.append(heading2("Key Insights"))
            for insight in plainInsights {
                blocks.append(bulletedListItem(insight))
            }
            blocks.append(divider())
        }

        // 4. Action Items
        if !meeting.actionItems.isEmpty {
            blocks.append(heading2("Action Items"))
            for item in meeting.actionItems {
                var text = item.title
                if let dueDate = item.dueDate {
                    text += " (due: \(dueDate.formatted(date: .abbreviated, time: .omitted)))"
                }
                blocks.append(toDo(text, checked: item.isExported))
            }
            blocks.append(divider())
        }

        // 5. References
        let references = meeting.references
        if !references.isEmpty {
            blocks.append(heading2("References"))
            for ref in references {
                let m = ref.timestampSeconds / 60
                let s = ref.timestampSeconds % 60
                let text = "[\(ref.id)] \"\(ref.passage)\" [\(String(format: "%02d:%02d", m, s))]"
                blocks.append(bulletedListItem(text))
            }
            blocks.append(divider())
        }

        // 6. Transcript
        if !meeting.transcriptText.isEmpty {
            blocks.append(heading2("Transcript"))
            blocks.append(contentsOf: paragraphBlocks(meeting.transcriptText))
        }

        return blocks
    }

    // MARK: - Block Helpers

    private func heading2(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "heading_2",
            "heading_2": [
                "rich_text": richText(text)
            ]
        ]
    }

    private func paragraph(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": richText(text)
            ]
        ]
    }

    private func paragraphBlocks(_ text: String) -> [[String: Any]] {
        let chunks = splitText(text, limit: richTextCharLimit)
        return chunks.map { paragraph($0) }
    }

    private func bulletedListItem(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": [
                "rich_text": richText(text)
            ]
        ]
    }

    private func toDo(_ text: String, checked: Bool) -> [String: Any] {
        [
            "object": "block",
            "type": "to_do",
            "to_do": [
                "rich_text": richText(text),
                "checked": checked
            ]
        ]
    }

    private func divider() -> [String: Any] {
        [
            "object": "block",
            "type": "divider",
            "divider": [String: Any]()
        ]
    }

    private func richText(_ text: String) -> [[String: Any]] {
        let chunks = splitText(text, limit: richTextCharLimit)
        return chunks.map { chunk in
            [
                "type": "text",
                "text": ["content": chunk]
            ]
        }
    }

    private func splitText(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }

        var chunks: [String] = []
        var remaining = text

        while !remaining.isEmpty {
            if remaining.count <= limit {
                chunks.append(remaining)
                break
            }

            let endIndex = remaining.index(remaining.startIndex, offsetBy: limit)
            let searchRange = remaining.startIndex..<endIndex

            // Try to split at a natural break point (newline, then period+space, then space)
            var splitAt: String.Index?
            if let newlineRange = remaining.range(of: "\n", options: .backwards, range: searchRange) {
                splitAt = newlineRange.upperBound
            } else if let periodRange = remaining.range(of: ". ", options: .backwards, range: searchRange) {
                splitAt = periodRange.upperBound
            } else if let spaceRange = remaining.range(of: " ", options: .backwards, range: searchRange) {
                splitAt = spaceRange.upperBound
            } else {
                splitAt = endIndex
            }

            let chunk = String(remaining[remaining.startIndex..<splitAt!])
            chunks.append(chunk)
            remaining = String(remaining[splitAt!...])
        }

        return chunks
    }

    // MARK: - API Calls

    private func createPage(
        title: String,
        parentPageId: String,
        children: [[String: Any]],
        token: String
    ) async throws -> NotionExportResult {
        let url = URL(string: "\(notionAPIBase)/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "parent": ["page_id": parentPageId],
            "properties": [
                "title": [
                    [
                        "text": ["content": title]
                    ]
                ]
            ],
            "children": children
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pageId = json["id"] as? String,
                  let pageUrl = json["url"] as? String else {
                throw NotionError.invalidResponse
            }
            return NotionExportResult(pageId: pageId, pageUrl: pageUrl)
        case 401:
            throw NotionError.unauthorized
        case 404:
            throw NotionError.parentNotFound
        default:
            let errorBody = parseNotionError(data: data)
            throw NotionError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }

    private func appendBlocks(
        to pageId: String,
        children: [[String: Any]],
        token: String
    ) async throws {
        let url = URL(string: "\(notionAPIBase)/blocks/\(pageId)/children")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["children": children]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = parseNotionError(data: data)
            throw NotionError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }

    private nonisolated func parseNotionError(data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
