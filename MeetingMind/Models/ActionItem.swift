import Foundation
import SwiftData

@Model
final class ActionItem {
    var id: UUID
    var title: String
    var type: ActionItemType
    var dueDate: Date?
    var isExported: Bool
    var exportedIdentifier: String?
    var meeting: Meeting?

    // Completion tracking (optional → lightweight migration)
    var isCompleted: Bool
    var completedAt: Date?

    init(
        title: String,
        type: ActionItemType,
        dueDate: Date? = nil,
        isExported: Bool = false,
        exportedIdentifier: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.dueDate = dueDate
        self.isExported = isExported
        self.exportedIdentifier = exportedIdentifier
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
