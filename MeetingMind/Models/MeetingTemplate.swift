import Foundation

struct MeetingTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let systemPrompt: String
    let isBuiltIn: Bool

    static let general = MeetingTemplate(
        id: "general",
        name: "General",
        icon: "text.bubble",
        systemPrompt: Config.analysisSystemPrompt,
        isBuiltIn: true
    )

    static let standup = MeetingTemplate(
        id: "standup",
        name: "Standup",
        icon: "arrow.clockwise.circle",
        systemPrompt: """
            You are a standup meeting analysis assistant. Analyze the provided meeting transcript focusing on daily standup patterns. Return a JSON object with exactly this structure:
            {
              "summary": "2-3 paragraph summary focusing on team progress and blockers. Use inline citations like [1], [2].",
              "suggestedTitle": "A short 3-6 word title (e.g. 'Daily Standup Mar 9')",
              "keyInsights": [
                { "text": "insight about blockers, progress, or team dynamics", "timestampSeconds": 135 }
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

            Focus areas:
            - Extract what each person accomplished since last standup
            - Identify blockers and impediments clearly
            - Capture commitments for today/next period
            - Flag any risks or dependencies mentioned
            - Note any requests for help or collaboration
            - Return ONLY valid JSON, no markdown, no explanation
            """,
        isBuiltIn: true
    )

    static let oneOnOne = MeetingTemplate(
        id: "one-on-one",
        name: "1:1",
        icon: "person.2",
        systemPrompt: """
            You are a 1:1 meeting analysis assistant. Analyze the provided meeting transcript focusing on manager-report dynamics. Return a JSON object with exactly this structure:
            {
              "summary": "2-3 paragraph summary focusing on feedback, growth, and relationship building. Use inline citations like [1], [2].",
              "suggestedTitle": "A short 3-6 word title (e.g. '1:1 with Sarah')",
              "keyInsights": [
                { "text": "insight about career development, feedback, or morale", "timestampSeconds": 135 }
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

            Focus areas:
            - Capture feedback given and received
            - Identify career growth discussions and goals
            - Note any concerns or morale indicators
            - Extract personal action items and follow-ups
            - Highlight coaching moments and advice
            - Return ONLY valid JSON, no markdown, no explanation
            """,
        isBuiltIn: true
    )

    static let brainstorm = MeetingTemplate(
        id: "brainstorm",
        name: "Brainstorm",
        icon: "lightbulb",
        systemPrompt: """
            You are a brainstorming session analysis assistant. Analyze the provided meeting transcript focusing on idea generation and creative exploration. Return a JSON object with exactly this structure:
            {
              "summary": "2-3 paragraph summary highlighting the most promising ideas and creative directions. Use inline citations like [1], [2].",
              "suggestedTitle": "A short 3-6 word title (e.g. 'Product Ideas Brainstorm')",
              "keyInsights": [
                { "text": "a generated idea or creative insight, ranked by feasibility", "timestampSeconds": 135 }
              ],
              "actionItems": [
                {
                  "title": "action item to explore or prototype an idea",
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

            Focus areas:
            - Capture ALL ideas mentioned, even brief ones
            - Rank ideas by feasibility and potential impact in keyInsights
            - Group related ideas into themes
            - Note which ideas had the most group energy or consensus
            - Identify next steps to validate or prototype top ideas
            - Return ONLY valid JSON, no markdown, no explanation
            """,
        isBuiltIn: true
    )

    static let clientCall = MeetingTemplate(
        id: "client-call",
        name: "Client Call",
        icon: "briefcase",
        systemPrompt: """
            You are a client meeting analysis assistant. Analyze the provided meeting transcript focusing on client relationship and requirements. Return a JSON object with exactly this structure:
            {
              "summary": "2-3 paragraph summary focusing on client needs, commitments made, and relationship dynamics. Use inline citations like [1], [2].",
              "suggestedTitle": "A short 3-6 word title (e.g. 'Acme Client Review')",
              "keyInsights": [
                { "text": "insight about client requirements, sentiment, or business opportunity", "timestampSeconds": 135 }
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

            Focus areas:
            - Extract specific client requirements and feature requests
            - Identify objections, concerns, or pain points raised
            - Capture all commitments and promises made to the client
            - Note follow-up items with clear owners and deadlines
            - Assess overall client sentiment (positive, neutral, concerned)
            - Return ONLY valid JSON, no markdown, no explanation
            """,
        isBuiltIn: true
    )

    static let interview = MeetingTemplate(
        id: "interview",
        name: "Interview",
        icon: "person.badge.plus",
        systemPrompt: """
            You are an interview analysis assistant. Analyze the provided meeting transcript focusing on candidate evaluation. Return a JSON object with exactly this structure:
            {
              "summary": "2-3 paragraph summary evaluating the candidate's performance, strengths, and areas of concern. Use inline citations like [1], [2].",
              "suggestedTitle": "A short 3-6 word title (e.g. 'Interview: Jane Doe')",
              "keyInsights": [
                { "text": "insight about candidate strengths, concerns, or notable responses", "timestampSeconds": 135 }
              ],
              "actionItems": [
                {
                  "title": "follow-up action (e.g. reference check, next round scheduling)",
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

            Focus areas:
            - Evaluate technical or domain competency demonstrated
            - Identify communication skills and clarity of thought
            - Note cultural fit signals (positive and negative)
            - Capture specific strengths with evidence
            - Flag any concerns or red flags with evidence
            - Provide an overall hire/no-hire signal in the summary
            - Return ONLY valid JSON, no markdown, no explanation
            """,
        isBuiltIn: true
    )

    static let builtInTemplates: [MeetingTemplate] = [
        .general, .standup, .oneOnOne, .brainstorm, .clientCall, .interview
    ]
}
