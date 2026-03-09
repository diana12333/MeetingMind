import Foundation

enum MeetingSortOrder: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case nameAZ = "Name (A-Z)"
    case nameZA = "Name (Z-A)"
}

enum MeetingGroupMode: String, CaseIterable {
    case none = "No Grouping"
    case category = "By Category"
}
