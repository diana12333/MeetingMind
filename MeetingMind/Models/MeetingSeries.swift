import Foundation
import SwiftData

@Model
final class MeetingSeries {
    var id: UUID
    var name: String
    var calendarEventIdentifier: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Meeting.series)
    var meetings: [Meeting]

    init(
        name: String,
        calendarEventIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.calendarEventIdentifier = calendarEventIdentifier
        self.createdAt = .now
        self.meetings = []
    }

    var sortedMeetings: [Meeting] {
        Array(meetings).sorted { ($0.seriesOrder ?? 0) < ($1.seriesOrder ?? 0) }
    }

    var meetingCount: Int { meetings.count }

    var dateRange: String {
        let sorted = Array(meetings).sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        if first.id == last.id {
            return formatter.string(from: first.date)
        }
        return "\(formatter.string(from: first.date)) \u{2013} \(formatter.string(from: last.date))"
    }

    var openActionItems: [ActionItem] {
        Array(meetings).flatMap { Array($0.actionItems) }.filter { !$0.isCompleted }
    }
}
