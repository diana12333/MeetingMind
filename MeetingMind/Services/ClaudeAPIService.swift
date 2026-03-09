import Foundation

enum Config {
    static let backendURL = "https://meetingmind-backend.dianshen.workers.dev"
    static let claudeAPIURL = "https://api.anthropic.com/v1/messages"
    static let claudeModel = "claude-sonnet-4-6"
    static let analysisSystemPrompt = """
        You are a meeting analysis assistant. Analyze the provided meeting transcript and return a JSON object with exactly this structure:
        {
          "summary": "2-3 paragraph summary of the meeting. Use inline citations like [1], [2] to reference specific transcript passages.",
          "suggestedTitle": "A short 3-6 word title for this meeting",
          "keyInsights": [
            { "text": "insight text", "timestampSeconds": 135 }
          ],
          "actionItems": [
            {
              "title": "action item description",
              "type": "calendarEvent" or "reminder" or "task",
              "suggestedDate": "ISO 8601 date string or null",
              "assignee": "person name or null",
              "timestampSeconds": 240
            }
          ],
          "references": [
            { "id": 1, "passage": "relevant quote from transcript", "timestampSeconds": 135 }
          ]
        }

        Rules:
        - suggestedTitle should be a concise, descriptive meeting title (e.g. "Q1 Planning Review", "Product Launch Sync")
        - Use "calendarEvent" for meetings, appointments, deadlines
        - Use "reminder" for follow-ups, check-ins
        - Use "task" for to-do items without specific dates
        - The transcript may have [MM:SS] timestamp prefixes on each chunk. Use these to determine timestampSeconds values.
        - timestampSeconds should be the number of seconds from the start of the recording where the relevant content was discussed
        - In the summary, use [1], [2], etc. to cite specific transcript passages. Each citation number must match a "references" entry.
        - Each reference should include the id, a short verbatim or near-verbatim passage, and the timestampSeconds from the [MM:SS] prefix.
        - If no timestamps are available in the transcript, omit timestampSeconds fields and references array.
        - Return ONLY valid JSON, no markdown, no explanation
        """

    static let crossMeetingSystemPrompt = """
        You are a meeting series analyst. Given summaries from previous meetings in a recurring series and the current meeting's transcript, generate a "Previously On..." brief and track progress.

        Return a JSON object with exactly this structure:
        {
          "previouslyOn": "2-3 sentence recap of key unresolved items and decisions from prior meetings",
          "carriedForwardItems": [
            { "title": "action item still open", "originMeeting": "meeting title or date" }
          ],
          "progressUpdate": "1-2 sentence summary of progress made since the last meeting",
          "decisionLog": [
            { "text": "key decision", "meetingDate": "when it was decided" }
          ]
        }

        Rules:
        - previouslyOn: Focus on what's most relevant for the current meeting — unresolved items, pending decisions
        - carriedForwardItems: Only include items that appear unresolved across meetings
        - progressUpdate: Compare what was planned vs. what was accomplished
        - decisionLog: Aggregate key decisions across all meetings in the series
        - Return ONLY valid JSON, no markdown, no explanation
        """

    static let diarizationSystemPrompt = """
        You are a speaker diarization assistant. Analyze the provided meeting transcript and identify distinct speakers based on conversational cues (e.g., "I think...", "You mentioned...", changes in topic or perspective, question-answer patterns).

        Return a JSON object with exactly this structure:
        {
          "speakers": ["Speaker 1", "Speaker 2"],
          "segments": [
            { "speaker": "Speaker 1", "startSeconds": 0, "endSeconds": 45, "text": "the text spoken in this segment" },
            { "speaker": "Speaker 2", "startSeconds": 45, "endSeconds": 92, "text": "the text spoken in this segment" }
          ]
        }

        Rules:
        - If you can infer actual names from the conversation (e.g., "Thanks, Sarah"), use those names
        - Otherwise use "Speaker 1", "Speaker 2", etc.
        - The transcript has [MM:SS] timestamp prefixes. Use these to determine startSeconds and endSeconds
        - startSeconds of each segment should match the [MM:SS] prefix of the first line in that segment
        - endSeconds should match the startSeconds of the next segment (or the end of the recording)
        - Merge consecutive lines by the same speaker into one segment
        - Every line of the transcript must be assigned to a speaker
        - Return ONLY valid JSON, no markdown, no explanation
        """

    static let executiveBriefSystemPrompt = """
        You are a meeting analysis assistant. Analyze the provided speaker-labeled meeting transcript and return a structured executive brief as JSON with exactly this structure:
        {
          "summary": "2-3 paragraph summary with inline citations like [1], [2]",
          "tldr": "1-2 sentence overview of the entire meeting",
          "suggestedTitle": "A short 3-6 word title for this meeting",
          "keyDecisions": [
            { "text": "decision description", "citations": [1, 2], "timestampSeconds": 135 }
          ],
          "discussionPoints": [
            { "topic": "Topic Name", "summary": "what was discussed", "citations": [3], "timestampSeconds": 200 }
          ],
          "openQuestions": [
            { "text": "unresolved question", "citations": [5], "timestampSeconds": 400 }
          ],
          "keyInsights": [
            { "text": "insight text", "timestampSeconds": 135 }
          ],
          "actionItems": [
            {
              "title": "action item description",
              "type": "calendarEvent" or "reminder" or "task",
              "suggestedDate": "ISO 8601 date string or null",
              "assignee": "person name or null",
              "timestampSeconds": 240
            }
          ],
          "nextSteps": [
            {
              "title": "next step description",
              "type": "task",
              "assignee": "person name or null",
              "suggestedDate": "ISO 8601 date or null",
              "timestampSeconds": 500
            }
          ],
          "references": [
            { "id": 1, "passage": "relevant quote from transcript", "speaker": "Speaker Name", "timestampSeconds": 135 }
          ]
        }

        Rules:
        - suggestedTitle: concise, descriptive (e.g. "Q1 Planning Review")
        - tldr: the single most important takeaway in 1-2 sentences
        - keyDecisions: only firm decisions that were agreed upon, not suggestions
        - discussionPoints: main topics discussed, each with a short summary paragraph
        - openQuestions: items explicitly left unresolved or needing follow-up
        - actionItems: use "calendarEvent" for meetings/deadlines, "reminder" for follow-ups, "task" for to-dos
        - nextSteps: concrete next actions with assignees where possible
        - references: each must include the speaker who said the quoted passage
        - The transcript has [Speaker Name] labels and [MM:SS] timestamps. Use these for speaker and timestampSeconds
        - citations [1], [2] in summary, keyDecisions, discussionPoints must match reference IDs
        - If no timestamps are available, omit timestampSeconds fields
        - Return ONLY valid JSON, no markdown, no explanation
        """
}

@Observable
final class ClaudeAPIService {
    @MainActor var isAnalyzing = false

    private let subscriptionService: SubscriptionService

    init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
    }

    @MainActor
    func analyzeTranscript(_ transcript: String, timestampedTranscript: String? = nil, template: MeetingTemplate? = nil) async throws -> AIAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let systemPrompt = template?.systemPrompt ?? Config.analysisSystemPrompt

        #if DEBUG
        // In DEBUG mode, try direct API first if key is available
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        if !apiKey.isEmpty {
            let transcriptToAnalyze = timestampedTranscript ?? transcript
            return try await callClaude(
                systemPrompt: systemPrompt,
                userMessage: "Please analyze this meeting transcript:\n\n\(transcriptToAnalyze)",
                apiKey: apiKey
            )
        }
        // Fall back to mock analysis for testing without API key
        if UserDefaults.standard.bool(forKey: "useMockAnalysis") {
            return mockAnalysis(for: transcript)
        }
        // Fall back to backend with debug auth
        return try await analyzeViaBackend(transcript: transcript)
        #else
        return try await analyzeViaBackend(transcript: transcript)
        #endif
    }

    // MARK: - Mock analysis for testing

    private func mockAnalysis(for transcript: String) -> AIAnalysisResult {
        let wordCount = transcript.split(separator: " ").count
        return AIAnalysisResult(
            summary: "This meeting covered several important topics [1]. The discussion lasted approximately \(wordCount) words and included key decisions about project direction, team assignments, and upcoming deadlines [2].\n\nThe team agreed on clear next steps with specific ownership and timelines for each action item.",
            keyInsights: [
                AIKeyInsight(text: "The team has clear alignment on project priorities", timestampSeconds: 30),
                AIKeyInsight(text: "Deadlines are aggressive but achievable with current resources", timestampSeconds: 120),
                AIKeyInsight(text: "Budget allocation reflects engineering-first approach", timestampSeconds: 240),
                AIKeyInsight(text: "Hiring is a critical dependency for Q1 goals", timestampSeconds: 360)
            ],
            actionItems: [
                AIActionItem(title: "Finalize mobile app wireframes", type: "task", suggestedDate: nil, assignee: "Sarah", timestampSeconds: 60),
                AIActionItem(title: "Set up staging environment", type: "task", suggestedDate: nil, assignee: "John", timestampSeconds: 180),
                AIActionItem(title: "Post engineering job listings", type: "reminder", suggestedDate: nil, assignee: "HR", timestampSeconds: 300),
                AIActionItem(title: "Q1 progress review meeting", type: "calendarEvent", suggestedDate: nil, assignee: nil, timestampSeconds: nil)
            ],
            suggestedTitle: "Q1 Planning Review",
            references: [
                AIReference(id: 1, passage: "We need to cover the important topics first", timestampSeconds: 15),
                AIReference(id: 2, passage: "The key decisions are about direction and deadlines", timestampSeconds: 90)
            ]
        )
    }

    // MARK: - Generic Claude API call helper

    @MainActor
    private func callClaude<T: Decodable>(systemPrompt: String, userMessage: String, apiKey: String) async throws -> T {
        let url = URL(string: Config.claudeAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": Config.claudeModel,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw ClaudeAPIError.apiError(statusCode: 401, message: "Invalid API key. Check your Claude API key in Settings.")
            }
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let claudeResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = claudeResponse?["content"] as? [[String: Any]],
              let textContent = content.first?["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        var jsonString = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```") {
            if let firstNewline = jsonString.firstIndex(of: "\n") {
                jsonString = String(jsonString[jsonString.index(after: firstNewline)...])
            }
            if jsonString.hasSuffix("```") {
                jsonString = String(jsonString.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    // MARK: - Diarization (two-pass pipeline, pass 1)

    @MainActor
    func diarizeTranscript(_ timestampedTranscript: String) async throws -> DiarizationResult {
        #if DEBUG
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        if !apiKey.isEmpty {
            return try await callClaude(
                systemPrompt: Config.diarizationSystemPrompt,
                userMessage: "Please identify the speakers in this meeting transcript:\n\n\(timestampedTranscript)",
                apiKey: apiKey
            )
        }
        // Mock diarization for testing
        return DiarizationResult(speakers: ["Speaker 1", "Speaker 2"], segments: [
            SpeakerSegment(speaker: "Speaker 1", startSeconds: 0, endSeconds: 60, text: "Mock speaker 1 text"),
            SpeakerSegment(speaker: "Speaker 2", startSeconds: 60, endSeconds: 120, text: "Mock speaker 2 text"),
        ])
        #else
        throw ClaudeAPIError.invalidResponse // Backend support to be added
        #endif
    }

    // MARK: - Executive brief analysis (two-pass pipeline, pass 2)

    @MainActor
    func analyzeWithExecutiveBrief(_ speakerLabeledTranscript: String, template: MeetingTemplate? = nil) async throws -> AIAnalysisResult {
        #if DEBUG
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        if !apiKey.isEmpty {
            let briefPrompt = template?.systemPrompt ?? Config.executiveBriefSystemPrompt
            return try await callClaude(
                systemPrompt: briefPrompt,
                userMessage: "Please analyze this speaker-labeled meeting transcript:\n\n\(speakerLabeledTranscript)",
                apiKey: apiKey
            )
        }
        if UserDefaults.standard.bool(forKey: "useMockAnalysis") {
            return mockAnalysis(for: speakerLabeledTranscript)
        }
        return try await analyzeViaBackend(transcript: speakerLabeledTranscript)
        #else
        return try await analyzeViaBackend(transcript: speakerLabeledTranscript)
        #endif
    }

    // MARK: - Cross-Meeting Analysis

    @MainActor
    func analyzeCrossMeeting(
        previousSummaries: [String],
        currentTranscript: String
    ) async throws -> CrossMeetingAnalysis {
        #if DEBUG
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        if !apiKey.isEmpty {
            let context = previousSummaries.joined(separator: "\n\n")
            let userMessage = """
                Previous meetings in this series:
                \(context)

                Current meeting transcript:
                \(currentTranscript)
                """
            return try await callClaude(
                systemPrompt: Config.crossMeetingSystemPrompt,
                userMessage: userMessage,
                apiKey: apiKey
            )
        }
        return CrossMeetingAnalysis.empty
        #else
        return CrossMeetingAnalysis.empty
        #endif
    }

    // MARK: - Chat with Meeting

    @MainActor
    func chatWithMeeting(transcript: String, history: [ChatMessage], userMessage: String) async throws -> String {
        #if DEBUG
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            return "Chat requires a Claude API key. Add one in Settings."
        }

        let systemPrompt = """
            You are a helpful meeting assistant. You have access to the following meeting transcript. \
            Answer the user's questions based on the transcript content. Be specific, cite relevant parts \
            of the discussion, and provide helpful context. If the user asks you to draft something \
            (like an email or summary), use the meeting content as the basis.

            Meeting Transcript:
            \(transcript)
            """

        var messages: [[String: String]] = []
        for msg in history {
            messages.append(["role": msg.role, "content": msg.content])
        }
        messages.append(["role": "user", "content": userMessage])

        return try await callClaudeChat(systemPrompt: systemPrompt, messages: messages, apiKey: apiKey)
        #else
        throw ClaudeAPIError.invalidResponse
        #endif
    }

    @MainActor
    private func callClaudeChat(systemPrompt: String, messages: [[String: String]], apiKey: String) async throws -> String {
        let url = URL(string: Config.claudeAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": Config.claudeModel,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw ClaudeAPIError.apiError(statusCode: 401, message: "Invalid API key. Check your Claude API key in Settings.")
            }
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let claudeResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = claudeResponse?["content"] as? [[String: Any]],
              let textContent = content.first?["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        return textContent
    }

    // MARK: - Backend proxy

    @MainActor
    private func analyzeViaBackend(transcript: String) async throws -> AIAnalysisResult {
        let url = URL(string: "\(Config.backendURL)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        request.setValue("Bearer debug-test", forHTTPHeaderField: "Authorization")
        request.setValue("debug", forHTTPHeaderField: "X-Receipt-Data")
        #else
        guard subscriptionService.isSubscribed else {
            throw ClaudeAPIError.noSubscription
        }
        guard let transactionId = await subscriptionService.getOriginalTransactionId() else {
            throw ClaudeAPIError.noSubscription
        }
        guard let receiptData = subscriptionService.getReceiptData() else {
            throw ClaudeAPIError.noReceipt
        }
        request.setValue("Bearer \(transactionId)", forHTTPHeaderField: "Authorization")
        request.setValue(receiptData, forHTTPHeaderField: "X-Receipt-Data")
        #endif

        let body = ["transcript": transcript]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(AIAnalysisResult.self, from: data)
        case 401:
            throw ClaudeAPIError.noSubscription
        case 403:
            throw ClaudeAPIError.subscriptionExpired
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }
}

enum ClaudeAPIError: LocalizedError {
    case noSubscription
    case subscriptionExpired
    case noReceipt
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noSubscription:
            return "Active subscription required. Subscribe in Settings to unlock AI analysis."
        case .subscriptionExpired:
            return "Your subscription has expired. Renew in Settings to continue using AI analysis."
        case .noReceipt:
            return "Could not verify subscription. Try restoring purchases in Settings."
        case .invalidResponse:
            return "Invalid response from analysis service."
        case .apiError(let code, let message):
            return "Analysis error (\(code)): \(message)"
        }
    }
}
