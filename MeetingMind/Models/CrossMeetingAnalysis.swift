import Foundation

struct CrossMeetingAnalysis: Codable {
    let previouslyDiscussed: [String]
    let openActionItems: [String]
    let progressSummary: String

    static let empty = CrossMeetingAnalysis(
        previouslyDiscussed: [],
        openActionItems: [],
        progressSummary: ""
    )
}
