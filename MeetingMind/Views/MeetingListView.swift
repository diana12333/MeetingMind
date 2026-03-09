import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(AppState.self) private var appState
    @Query private var meetings: [Meeting]
    @State private var searchText = ""
    @State private var showRecording = false
    @State private var navigationPath = NavigationPath()

    @AppStorage("meetingSortOrder") private var sortOrder = MeetingSortOrder.dateNewest.rawValue
    @AppStorage("meetingGroupMode") private var groupMode = MeetingGroupMode.none.rawValue

    private var currentSort: MeetingSortOrder {
        MeetingSortOrder(rawValue: sortOrder) ?? .dateNewest
    }

    private var currentGroup: MeetingGroupMode {
        MeetingGroupMode(rawValue: groupMode) ?? .none
    }

    private var sortedMeetings: [Meeting] {
        let filtered = searchText.isEmpty ? meetings : meetings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.transcriptText.localizedCaseInsensitiveContains(searchText)
        }
        switch currentSort {
        case .dateNewest: return filtered.sorted { $0.date > $1.date }
        case .dateOldest: return filtered.sorted { $0.date < $1.date }
        case .nameAZ: return filtered.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .nameZA: return filtered.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        }
    }

    private var groupedMeetings: [(key: String, meetings: [Meeting])] {
        switch currentGroup {
        case .none:
            return [(key: "", meetings: sortedMeetings)]
        case .category:
            let grouped = Dictionary(grouping: sortedMeetings) { $0.categoryName ?? "Uncategorized" }
            return grouped.map { (key: $0.key, meetings: $0.value) }.sorted { $0.key < $1.key }
        case .series:
            let withSeries = sortedMeetings.filter { $0.series != nil }
            let withoutSeries = sortedMeetings.filter { $0.series == nil }
            var groups: [(key: String, meetings: [Meeting])] = []
            let seriesGrouped = Dictionary(grouping: withSeries) { $0.series?.name ?? "" }
            groups += seriesGrouped.map { (key: $0.key, meetings: $0.value) }.sorted { $0.key < $1.key }
            if !withoutSeries.isEmpty {
                groups.append((key: "Ungrouped", meetings: withoutSeries))
            }
            return groups
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(groupedMeetings, id: \.key) { group in
                        Section {
                            ForEach(group.meetings) { meeting in
                                NavigationLink(value: meeting) {
                                    MeetingRowView(meeting: meeting)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteMeeting(meeting)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if meeting.status == .failed || (meeting.status == .recording && meeting.duration == 0) {
                                        if meeting.audioFileURL != nil {
                                            Button {
                                                meeting.status = .transcribing
                                            } label: {
                                                Label("Retry", systemImage: "arrow.clockwise")
                                            }
                                            .tint(Theme.statusTranscribing)
                                        }
                                    }
                                }
                            }
                        } header: {
                            if currentGroup != .none {
                                Text(group.key)
                            }
                        }
                        .headerProminence(.increased)
                    }
                }
                .overlay {
                    if meetings.isEmpty {
                        ContentUnavailableView(
                            "No Meetings",
                            systemImage: "mic.badge.plus",
                            description: Text("Tap + to record your first meeting.")
                        )
                    }
                }

                floatingRecordButton
            }
            .navigationTitle("MeetingMind")
            .searchable(text: $searchText, prompt: "Search meetings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AnalyticsDashboardView()
                    } label: {
                        Image(systemName: "chart.bar.xaxis.ascending")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort By") {
                            ForEach(MeetingSortOrder.allCases, id: \.self) { option in
                                Button {
                                    sortOrder = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if currentSort == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        Section("Group By") {
                            ForEach(MeetingGroupMode.allCases, id: \.self) { option in
                                Button {
                                    groupMode = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if currentGroup == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showRecording = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView()
            }
            .navigationDestination(for: Meeting.self) { meeting in
                MeetingDetailView(meeting: meeting)
            }
            .navigationDestination(for: MeetingSeries.self) { series in
                SeriesDetailView(series: series)
            }
            .onChange(of: showRecording) { _, isShowing in
                if !isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let newest = meetings.first(where: { $0.status == .transcribing }) {
                            navigationPath.append(newest)
                        }
                    }
                }
            }
            .onAppear {
                recoverStuckMeetings()
                handleQuickRecordShortcut()
            }
            .onChange(of: appState.shouldStartRecording) { _, shouldStart in
                if shouldStart {
                    showRecording = true
                    appState.shouldStartRecording = false
                }
            }
        }
    }

    // MARK: - Subviews

    private var floatingRecordButton: some View {
        Button {
            showRecording = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.teal600)
                .clipShape(Circle())
                .shadow(color: Theme.teal600.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.bottom, Theme.spacing32)
        .accessibilityLabel("Record new meeting")
        .accessibilityHint("Double tap to start recording a new meeting")
    }

    // MARK: - Actions

    private func handleQuickRecordShortcut() {
        if appState.shouldStartRecording {
            showRecording = true
            appState.shouldStartRecording = false
        }
    }

    private func recoverStuckMeetings() {
        for meeting in meetings {
            if meeting.status == .recording {
                if let url = meeting.audioFileURL,
                   FileManager.default.fileExists(atPath: url.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? UInt64, size > 0 {
                    meeting.status = .complete
                } else {
                    meeting.status = .failed
                }
            }
            if meeting.status == .analyzing || meeting.status == .diarizing {
                meeting.status = meeting.transcriptText.isEmpty ? .failed : .complete
            }
        }
    }

    private func deleteMeeting(_ meeting: Meeting) {
        if let url = meeting.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(meeting)
    }
}
