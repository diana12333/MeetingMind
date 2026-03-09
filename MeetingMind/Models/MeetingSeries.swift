import Foundation
import SwiftData

@Model
final class MeetingSeries {
    var id: UUID
    var name: String
    var calendarEventIdentifier: String?
    var createdAt: Date

    @Relationship(inverse: \Meeting.series)
    var meetings: [Meeting]

    init(name: String, calendarEventIdentifier: String? = nil) {
        self.id = UUID()
        self.name = name
        self.calendarEventIdentifier = calendarEventIdentifier
        self.createdAt = .now
        self.meetings = []
    }
}
