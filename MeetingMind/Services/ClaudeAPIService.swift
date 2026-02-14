import Foundation

@MainActor
@Observable
final class ClaudeAPIService {
    var isAnalyzing = false

    func analyzeTranscript(_ transcript: String) async throws -> AIAnalysisResult {
        guard let apiKey = KeychainService.getAPIKey(), !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemPrompt = """
        You are a meeting analysis assistant. Analyze the provided meeting transcript and return a JSON object with exactly this structure:
        {
          "summary": "2-3 paragraph summary of the meeting",
          "keyInsights": ["insight 1", "insight 2", ...],
          "actionItems": [
            {
              "title": "action item description",
              "type": "calendarEvent" or "reminder" or "task",
              "suggestedDate": "ISO 8601 date string or null",
              "assignee": "person name or null"
            }
          ]
        }

        Rules:
        - Use "calendarEvent" for meetings, appointments, deadlines
        - Use "reminder" for follow-ups, check-ins
        - Use "task" for to-do items without specific dates
        - Return ONLY valid JSON, no markdown, no explanation
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Please analyze this meeting transcript:\n\n\(transcript)"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw ClaudeAPIError.invalidAPIKey
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let apiResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textContent = apiResponse.content.first?.text else {
            throw ClaudeAPIError.noContent
        }

        guard let jsonData = textContent.data(using: .utf8) else {
            throw ClaudeAPIError.invalidJSON
        }

        return try JSONDecoder().decode(AIAnalysisResult.self, from: jsonData)
    }
}

private struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

private struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidResponse
    case noContent
    case invalidJSON
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Claude API key in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .noContent:
            return "No content in Claude API response."
        case .invalidJSON:
            return "Could not parse AI analysis results."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}
