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

    init(
        title: String,
        type: ActionItemType,
        dueDate: Date? = nil,
        isExported: Bool = false,
        exportedIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.dueDate = dueDate
        self.isExported = isExported
        self.exportedIdentifier = exportedIdentifier
    }
}
