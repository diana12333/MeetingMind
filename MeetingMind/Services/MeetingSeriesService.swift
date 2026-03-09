import Foundation
import SwiftData
import EventKit

@MainActor
@Observable
final class MeetingSeriesService {
    private let eventStore = EKEventStore()

    // MARK: - Series Management

    func createSeries(
        name: String,
        calendarEventIdentifier: String? = nil,
        in context: ModelContext
    ) -> MeetingSeries {
        let series = MeetingSeries(name: name, calendarEventIdentifier: calendarEventIdentifier)
        context.insert(series)
        return series
    }

    func addMeeting(_ meeting: Meeting, to series: MeetingSeries) {
        let nextOrder = (Array(series.meetings).map { $0.seriesOrder ?? 0 }.max() ?? -1) + 1
        meeting.series = series
        meeting.seriesOrder = nextOrder
    }

    func removeMeeting(_ meeting: Meeting) {
        meeting.series = nil
        meeting.seriesOrder = nil
    }

    // MARK: - Auto-Detection via EventKit

    func detectRecurringSeries(
        for meeting: Meeting,
        allSeries: [MeetingSeries]
    ) -> MeetingSeries? {
        guard !meeting.title.isEmpty else { return nil }

        for series in allSeries {
            let seriesTitle = series.name.lowercased()
            let meetingTitle = meeting.title.lowercased()
            if seriesTitle == meetingTitle || meetingTitle.contains(seriesTitle) || seriesTitle.contains(meetingTitle) {
                return series
            }
        }
        return nil
    }

    func fetchRecurringEventIdentifier(for title: String) async -> String? {
        let granted = await requestCalendarAccess()
        guard granted else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let predicate = eventStore.predicateForEvents(
            withStart: threeMonthsAgo,
            end: now,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)

        for event in events {
            guard let eventTitle = event.title else { continue }
            if eventTitle.lowercased().contains(title.lowercased()) && event.hasRecurrenceRules {
                return event.eventIdentifier
            }
        }
        return nil
    }

    // MARK: - Carry-Forward Action Items

    func openActionItems(in series: MeetingSeries) -> [ActionItem] {
        Array(series.meetings)
            .sorted { $0.date < $1.date }
            .flatMap { Array($0.actionItems) }
            .filter { !$0.isCompleted }
    }

    func previousMeetingSummaries(for meeting: Meeting, in series: MeetingSeries) -> [String] {
        Array(series.meetings)
            .sorted { $0.date < $1.date }
            .filter { $0.date < meeting.date }
            .compactMap { m in
                guard let summary = m.summary else { return nil }
                let brief = m.executiveBrief
                let tldr = brief?.effectiveTldr ?? String(summary.prefix(200))
                return "[\(m.title) - \(m.date.formatted(date: .abbreviated, time: .omitted))]: \(tldr)"
            }
    }

    // MARK: - Private

    private func requestCalendarAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }
}
