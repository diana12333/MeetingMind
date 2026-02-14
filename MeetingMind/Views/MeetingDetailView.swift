import SwiftUI

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting

    @State private var selectedTab = 0
    @State private var claudeService = ClaudeAPIService()
    @State private var transcriptionService = TranscriptionService()
    @State private var eventKitService = EventKitService()
    @State private var playerService = AudioPlayerService()

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            if meeting.audioFileURL != nil {
                AudioPlayerBar(player: playerService)
                    .padding()
                Divider()
            }

            Picker("Section", selection: $selectedTab) {
                Text("Transcript").tag(0)
                Text("Summary").tag(1)
                Text("Insights").tag(2)
                Text("Actions").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                TranscriptTabView(
                    transcriptText: meeting.transcriptText,
                    isTranscribing: transcriptionService.isTranscribing,
                    partialText: transcriptionService.transcriptText
                )
                .tag(0)

                SummaryTabView(summary: meeting.summary)
                    .tag(1)

                InsightsTabView(insights: meeting.keyInsights)
                    .tag(2)

                ActionItemsTabView(
                    meeting: meeting,
                    eventKitService: eventKitService,
                    errorMessage: $errorMessage,
                    showError: $showError
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    transcribeAudio()
                } label: {
                    if transcriptionService.isTranscribing {
                        ProgressView()
                    } else {
                        Label("Transcribe", systemImage: "waveform")
                    }
                }
                .disabled(meeting.audioFileURL == nil || transcriptionService.isTranscribing)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    analyzeTranscript()
                } label: {
                    if claudeService.isAnalyzing {
                        ProgressView()
                    } else {
                        Label("Analyze", systemImage: "sparkles")
                    }
                }
                .disabled(meeting.transcriptText.isEmpty || claudeService.isAnalyzing)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadAudio()
            if meeting.status == .transcribing {
                transcribeAudio()
            }
        }
    }

    private func loadAudio() {
        guard let url = meeting.audioFileURL else { return }
        try? playerService.loadAudio(url: url)
    }

    private func transcribeAudio() {
        guard let url = meeting.audioFileURL else {
            errorMessage = "No audio file found for this meeting."
            showError = true
            return
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Audio file does not exist at: \(url.lastPathComponent)"
            showError = true
            return
        }

        meeting.status = .transcribing
        Task { @MainActor in
            let authorized = await transcriptionService.requestAuthorization()
            guard authorized else {
                errorMessage = "Speech recognition permission not granted. Go to Settings > Privacy > Speech Recognition and enable it for MeetingMind."
                showError = true
                meeting.status = .failed
                return
            }
            do {
                let text = try await transcriptionService.transcribeAudioFile(url: url)
                if text.isEmpty {
                    errorMessage = "Transcription returned empty text. The recording may be too short or silent."
                    showError = true
                    meeting.status = .complete
                } else {
                    meeting.transcriptText = text
                    meeting.status = .complete
                }
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                showError = true
                meeting.status = .failed
            }
        }
    }

    private func analyzeTranscript() {
        Task { @MainActor in
            meeting.status = .analyzing
            do {
                let result = try await claudeService.analyzeTranscript(meeting.transcriptText)
                meeting.summary = result.summary
                meeting.keyInsights = result.keyInsights
                for aiItem in result.actionItems {
                    let actionItem = ActionItem(
                        title: aiItem.title,
                        type: aiItem.actionItemType,
                        dueDate: aiItem.parsedDate
                    )
                    meeting.actionItems.append(actionItem)
                }
                meeting.status = .complete
                selectedTab = 1
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                meeting.status = .complete
            }
        }
    }
}

// MARK: - Audio Player Bar

struct AudioPlayerBar: View {
    var player: AudioPlayerService

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )

            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption2)
                    .monospacedDigit()

                Spacer()

                Button {
                    if player.isPlaying { player.pause() } else { player.play() }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }

                Spacer()

                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button("\(rate, specifier: "%.2g")x") {
                            player.setRate(Float(rate))
                        }
                    }
                } label: {
                    Text("\(player.playbackRate, specifier: "%.2g")x")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill)
                        .clipShape(Capsule())
                }

                Text(formatTime(player.duration))
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Tab Views

struct TranscriptTabView: View {
    let transcriptText: String
    let isTranscribing: Bool
    let partialText: String

    var body: some View {
        ScrollView {
            if isTranscribing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Transcribing...")
                        .foregroundStyle(.secondary)
                    if !partialText.isEmpty {
                        Text(partialText)
                            .padding()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 40)
            } else if transcriptText.isEmpty {
                ContentUnavailableView(
                    "No Transcript",
                    systemImage: "text.bubble",
                    description: Text("Tap the ⋯ menu and select Transcribe, or tap the waveform button in the toolbar.")
                )
            } else {
                Text(transcriptText)
                    .padding()
                    .textSelection(.enabled)
            }
        }
    }
}

struct SummaryTabView: View {
    let summary: String?

    var body: some View {
        ScrollView {
            if let summary, !summary.isEmpty {
                Text(summary)
                    .padding()
                    .textSelection(.enabled)
            } else {
                ContentUnavailableView(
                    "No Summary",
                    systemImage: "sparkles",
                    description: Text("Tap Analyze to generate a summary.")
                )
            }
        }
    }
}

struct InsightsTabView: View {
    let insights: [String]?

    var body: some View {
        ScrollView {
            if let insights, !insights.isEmpty {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 20)
                            Text(insight)
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "No Insights",
                    systemImage: "lightbulb",
                    description: Text("Tap Analyze to extract key insights.")
                )
            }
        }
    }
}

struct ActionItemsTabView: View {
    @Bindable var meeting: Meeting
    let eventKitService: EventKitService
    @Binding var errorMessage: String
    @Binding var showError: Bool

    var body: some View {
        ScrollView {
            if meeting.actionItems.isEmpty {
                ContentUnavailableView(
                    "No Action Items",
                    systemImage: "checklist",
                    description: Text("Tap Analyze to extract action items.")
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(meeting.actionItems) { item in
                        ActionItemRowView(item: item) {
                            exportActionItem(item)
                        }
                        .padding(.horizontal)
                        Divider()
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private func exportActionItem(_ item: ActionItem) {
        Task { @MainActor in
            do {
                switch item.type {
                case .calendarEvent:
                    let granted = await eventKitService.requestCalendarAccess()
                    guard granted else {
                        errorMessage = "Calendar access required."
                        showError = true
                        return
                    }
                    let id = try eventKitService.createCalendarEvent(
                        title: item.title,
                        startDate: item.dueDate ?? Date().addingTimeInterval(86400)
                    )
                    item.exportedIdentifier = id
                    item.isExported = true

                case .reminder, .task:
                    let granted = await eventKitService.requestRemindersAccess()
                    guard granted else {
                        errorMessage = "Reminders access required."
                        showError = true
                        return
                    }
                    let id = try eventKitService.createReminder(
                        title: item.title,
                        dueDate: item.dueDate
                    )
                    item.exportedIdentifier = id
                    item.isExported = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
