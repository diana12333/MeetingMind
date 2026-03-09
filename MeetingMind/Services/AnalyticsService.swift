import Foundation
import SwiftData

enum AnalyticsDateRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case all = "All"
}

struct CategoryCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DailyMeetingHours: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
}

@Observable
@MainActor
final class AnalyticsService {
    var dateRange: AnalyticsDateRange = .month

    var totalMeetings: Int = 0
    var totalHours: Double = 0
    var averageDuration: TimeInterval = 0
    var totalActionItems: Int = 0
    var exportedActionItems: Int = 0
    var meetingHoursTrend: [DailyMeetingHours] = []
    var categoryDistribution: [CategoryCount] = []

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        guard let modelContext else { return }

        let startDate = startDate(for: dateRange)

        let completeStatus = MeetingStatus.complete
        let descriptor = FetchDescriptor<Meeting>(
            predicate: #Predicate<Meeting> { meeting in
                meeting.status == completeStatus
            },
            sortBy: [SortDescriptor(\.date)]
        )

        guard let allComplete = try? modelContext.fetch(descriptor) else { return }

        let meetings: [Meeting]
        if let startDate {
            meetings = allComplete.filter { $0.date >= startDate }
        } else {
            meetings = allComplete
        }

        totalMeetings = meetings.count
        totalHours = meetings.reduce(0) { $0 + $1.duration } / 3600.0
        averageDuration = meetings.isEmpty ? 0 : meetings.reduce(0) { $0 + $1.duration } / Double(meetings.count)

        // Action items
        let actionDescriptor = FetchDescriptor<ActionItem>()
        let allItems = (try? modelContext.fetch(actionDescriptor)) ?? []
        let filteredItems: [ActionItem]
        if let startDate {
            filteredItems = allItems.filter { item in
                guard let meeting = item.meeting else { return false }
                return meeting.date >= startDate && meeting.status == .complete
            }
        } else {
            filteredItems = allItems.filter { $0.meeting?.status == .complete }
        }
        totalActionItems = filteredItems.count
        exportedActionItems = filteredItems.filter(\.isExported).count

        // Category distribution
        let grouped = Dictionary(grouping: meetings) { $0.categoryName ?? "Uncategorized" }
        categoryDistribution = grouped.map { CategoryCount(name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Daily meeting hours trend
        let calendar = Calendar.current
        let dailyGrouped = Dictionary(grouping: meetings) { meeting in
            calendar.startOfDay(for: meeting.date)
        }
        meetingHoursTrend = dailyGrouped.map { date, dayMeetings in
            DailyMeetingHours(date: date, hours: dayMeetings.reduce(0) { $0 + $1.duration } / 3600.0)
        }.sorted { $0.date < $1.date }
    }

    private func startDate(for range: AnalyticsDateRange) -> Date? {
        let calendar = Calendar.current
        switch range {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: .now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: .now)
        case .all:
            return nil
        }
    }
}
