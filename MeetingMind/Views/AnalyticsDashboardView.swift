import SwiftUI
import Charts
import SwiftData

struct AnalyticsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var service = AnalyticsService()

    var body: some View {
        Group {
            if service.totalMeetings < 2 {
                emptyState
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            service.configure(modelContext: modelContext)
            service.refresh()
        }
        .onChange(of: service.dateRange) {
            service.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Not Enough Data",
            systemImage: "chart.bar.xaxis.ascending",
            description: Text("Record more meetings to see trends. You need at least 2 completed meetings.")
        )
        .onAppear {
            service.configure(modelContext: modelContext)
            service.refresh()
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: Theme.spacing16) {
                dateRangePicker

                summaryStats

                meetingHoursTrendChart

                categoryChart

                actionItemGauge
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.bottom, Theme.spacing32)
        }
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        Picker("Date Range", selection: $service.dateRange) {
            ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing12) {
            StatCardView(
                icon: "calendar",
                value: "\(service.totalMeetings)",
                label: "Meetings"
            )

            StatCardView(
                icon: "clock",
                value: String(format: "%.1fh", service.totalHours),
                label: "Total Hours",
                color: Theme.teal500
            )

            StatCardView(
                icon: "timer",
                value: formatDuration(service.averageDuration),
                label: "Avg Duration",
                color: Theme.orange500
            )

            StatCardView(
                icon: "checklist",
                value: "\(service.totalActionItems)",
                label: "Action Items",
                color: Theme.actionTask
            )
        }
    }

    // MARK: - Meeting Hours Trend

    private var meetingHoursTrendChart: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Meeting Hours")
                .font(Theme.sectionHeaderFont)

            if service.meetingHoursTrend.isEmpty {
                Text("No data for this period")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(service.meetingHoursTrend) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(Theme.teal600)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.teal500.opacity(0.3), Theme.teal500.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(Theme.teal600)
                    .symbolSize(30)
                }
                .chartYAxisLabel("Hours")
                .frame(height: 200)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Category Distribution

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("By Category")
                .font(Theme.sectionHeaderFont)

            if service.categoryDistribution.isEmpty {
                Text("No data for this period")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(service.categoryDistribution) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Category", item.name)
                    )
                    .foregroundStyle(Theme.teal500.gradient)
                    .cornerRadius(4)
                }
                .frame(height: max(CGFloat(service.categoryDistribution.count) * 40, 100))
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Action Item Gauge

    private var actionItemGauge: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Action Items Exported")
                .font(Theme.sectionHeaderFont)

            let fraction = service.totalActionItems > 0
                ? Double(service.exportedActionItems) / Double(service.totalActionItems)
                : 0

            HStack(spacing: Theme.spacing16) {
                Gauge(value: fraction) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(fraction * 100))%")
                        .font(Theme.headlineFont)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Theme.teal600)
                .scaleEffect(1.4)
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: Theme.spacing4) {
                    Text("\(service.exportedActionItems) of \(service.totalActionItems) exported")
                        .font(Theme.subheadlineFont)
                    Text("to Calendar or Reminders")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.spacing8)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
