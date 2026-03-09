import SwiftUI
import SwiftData

struct SeriesDetailView: View {
    @Bindable var series: MeetingSeries
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    private var sortedMeetings: [Meeting] {
        series.sortedMeetings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing16) {
                seriesHeader
                SeriesTimelineView(meetings: sortedMeetings)
                previouslyOnCard
                openActionItemsSection
                decisionLogSection
            }
            .padding(Theme.spacing16)
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    editedTitle = series.name
                    isEditingTitle = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
        }
        .alert("Rename Series", isPresented: $isEditingTitle) {
            TextField("Series name", text: $editedTitle)
            Button("Save") {
                if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    series.name = editedTitle
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Subviews

    private var seriesHeader: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            Text(series.name)
                .font(Theme.titleFont)
            Text("\(series.meetingCount) meetings \u{00B7} \(series.dateRange)")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var previouslyOnCard: some View {
        if let lastMeeting = sortedMeetings.last, let summary = lastMeeting.summary {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text("Previously On\u{2026}")
                    .font(Theme.sectionHeaderFont)
                let displayText = summary.count > 200 ? String(summary.prefix(200)) + "\u{2026}" : summary
                Text(displayText)
                    .font(Theme.bodyFont)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceTeal)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }

    @ViewBuilder
    private var openActionItemsSection: some View {
        let items = series.openActionItems
        if !items.isEmpty {
            DisclosureGroup {
                ForEach(items) { item in
                    actionItemRow(item)
                }
            } label: {
                sectionLabel(title: "Open Action Items", count: items.count)
            }
        }
    }

    private func actionItemRow(_ item: ActionItem) -> some View {
        HStack(spacing: Theme.spacing8) {
            Button {
                item.isCompleted = true
                item.completedAt = .now
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(Theme.teal600)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.bodyFont)
                if let meetingTitle = item.meeting?.title {
                    Text(meetingTitle)
                        .font(Theme.badgeFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.pillPaddingH)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceTeal)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, Theme.spacing4)
    }

    @ViewBuilder
    private var decisionLogSection: some View {
        let decisions = collectDecisions()
        if !decisions.isEmpty {
            DisclosureGroup {
                ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                    HStack(spacing: Theme.spacing8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.statusComplete)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(decision.text)
                                .font(Theme.bodyFont)
                            Text(decision.date)
                                .font(Theme.badgeFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Theme.spacing4)
                }
            } label: {
                sectionLabel(title: "Decision Log", count: decisions.count)
            }
        }
    }

    private func collectDecisions() -> [(text: String, date: String)] {
        sortedMeetings.compactMap { meeting -> [(text: String, date: String)]? in
            guard let brief = meeting.executiveBrief,
                  let keyDecisions = brief.keyDecisions, !keyDecisions.isEmpty else { return nil }
            let dateStr = meeting.date.formatted(date: .abbreviated, time: .omitted)
            return keyDecisions.map { (text: $0.text, date: dateStr) }
        }.flatMap { $0 }
    }

    private func sectionLabel(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Theme.sectionHeaderFont)
            Spacer()
            Text("\(count)")
                .font(Theme.badgeFont)
                .foregroundStyle(Theme.teal600)
                .padding(.horizontal, Theme.pillPaddingH)
                .padding(.vertical, Theme.pillPaddingV)
                .background(Theme.teal600.opacity(Theme.badgeBackgroundOpacity))
                .clipShape(Capsule())
        }
    }
}
