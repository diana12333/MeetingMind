import Foundation
import SwiftData

@Model
final class MeetingCategory {
    var id: UUID
    var name: String
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
