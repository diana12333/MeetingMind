import SwiftUI
import SwiftData

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MeetingCategory.createdAt) private var categories: [MeetingCategory]

    @State private var selectedTab = 0
    @State private var claudeService: ClaudeAPIService?
    @State private var transcriptionService = TranscriptionService()
    @State private var eventKitService = EventKitService()
    @State private var playerService = AudioPlayerService()
    @State private var coordinator = NavigationCoordinator()

    @AppStorage("autoAnalyze") private var autoAnalyze = false
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = Locale.current.language.languageCode?.identifier ?? "en"

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSubscriptionPaywall = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showNewCategory = false
    @State private var newCategoryName = ""
    @State private var notionService = NotionService()
    @State private var showNotionSuccess = false
    @State private var notionExportURL: String?

    private var isProcessing: Bool {
        transcriptionService.isTranscribing || claudeService?.isAnalyzing == true || notionService.isExporting
    }

    private var shareText: String {
        var parts: [String] = ["# \(meeting.title)"]
        parts.append("Date: \(meeting.date.formatted(date: .long, time: .shortened))")
        if !meeting.transcriptText.isEmpty {
            parts.append("\n## Transcript\n\(meeting.transcriptText)")
        }
        if let summary = meeting.summary, !summary.isEmpty {
            parts.append("\n## Summary\n\(summary)")
        }
        if let insights = meeting.keyInsights, !insights.isEmpty {
            parts.append("\n## Key Insights\n" + insights.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !meeting.actionItems.isEmpty {
            parts.append("\n## Action Items\n" + meeting.actionItems.map { "- \($0.title)" }.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n")
    }

    private var tabItems: [(label: String, icon: String, tag: Int)] {
        [
            ("Transcript", "text.bubble", 0),
            ("Summary", "doc.text", 1),
            ("Insights", "lightbulb", 2),
            ("Actions", "checklist", 3),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            if meeting.audioFileURL != nil {
                AudioPlayerBar(player: playerService)
                    .padding(Theme.cardPadding)
                    .background(Theme.surfaceTeal)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .padding(.horizontal)
                    .padding(.top, Theme.spacing8)
            }

            if !meeting.speakerSegments.isEmpty {
                TimelineBarView(
                    segments: meeting.speakerSegments,
                    duration: playerService.duration,
                    currentTime: coordinator.currentTimestamp,
                    speakerNames: meeting.speakerNames,
                    onTap: { coordinator.seekTo($0) }
                )
            }

            // Show a prominent action button when no transcript exists
            if meeting.transcriptText.isEmpty && !transcriptionService.isTranscribing && meeting.audioFileURL != nil {
                Button {
                    transcribeAndAnalyze()
                } label: {
                    Label("Transcribe & Analyze", systemImage: "waveform.and.sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }

            // Show processing status
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(transcriptionService.isTranscribing ? "Transcribing..." :
                         meeting.status == .diarizing ? "Identifying speakers..." :
                         "Analyzing with AI...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Pill tab buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabItems, id: \.tag) { item in
                        PillTabButton(
                            label: item.label,
                            icon: item.icon,
                            isSelected: selectedTab == item.tag
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = item.tag
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            contentTabView
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        transcribeAudio()
                    } label: {
                        Label("Transcribe", systemImage: "waveform")
                    }
                    .disabled(meeting.audioFileURL == nil || transcriptionService.isTranscribing)

                    Button {
                        analyzeTranscript()
                    } label: {
                        Label("Analyze with AI", systemImage: "sparkles")
                    }
                    .disabled(meeting.transcriptText.isEmpty || claudeService?.isAnalyzing == true)

                    Button {
                        exportToNotion()
                    } label: {
                        if notionService.isExporting {
                            Label("Exporting...", systemImage: "arrow.up.circle")
                        } else {
                            Label(
                                meeting.isExportedToNotion ? "Re-export to Notion" : "Export to Notion",
                                systemImage: "arrow.up.doc"
                            )
                        }
                    }
                    .disabled(meeting.summary == nil || !notionService.isConfigured || notionService.isExporting)

                    Divider()

                    Button {
                        editedTitle = meeting.title
                        isEditingTitle = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Menu("Category") {
                        Button {
                            meeting.categoryName = nil
                        } label: {
                            HStack {
                                Text("None")
                                if meeting.categoryName == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        ForEach(categories) { category in
                            Button {
                                meeting.categoryName = category.name
                            } label: {
                                HStack {
                                    Text(category.name)
                                    if meeting.categoryName == category.name {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            showNewCategory = true
                        } label: {
                            Label("New Category...", systemImage: "plus")
                        }
                    }
                } label: {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(meeting.transcriptText.isEmpty && meeting.summary == nil)
            }
        }
        .alert("Rename Meeting", isPresented: $isEditingTitle) {
            TextField("Meeting title", text: $editedTitle)
            Button("Save") {
                if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    meeting.title = editedTitle
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Category", isPresented: $showNewCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                if !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                    let cat = MeetingCategory(name: trimmed)
                    modelContext.insert(cat)
                }
                meeting.categoryName = trimmed
                newCategoryName = ""
            }
            Button("Cancel", role: .cancel) { newCategoryName = "" }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Exported to Notion", isPresented: $showNotionSuccess) {
            if let url = notionExportURL, let link = URL(string: url) {
                Link("Open in Notion", destination: link)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your meeting notes have been exported to Notion.")
        }
        .sheet(isPresented: $showSubscriptionPaywall) {
            NavigationStack {
                SubscriptionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSubscriptionPaywall = false }
                        }
                    }
            }
        }
        .onAppear {
            if claudeService == nil {
                claudeService = ClaudeAPIService(subscriptionService: subscriptionService)
            }
            coordinator.attach(player: playerService)
            loadAudio()
            if meeting.status == .transcribing {
                transcribeAudio()
            }
        }
        .onChange(of: playerService.currentTime) { _, newTime in
            coordinator.updatePlaybackPosition(newTime)
        }
    }

    private var hasAudio: Bool { meeting.audioFileURL != nil }

    private var contentTabView: some View {
        let seekHandler: ((TimeInterval) -> Void)? = hasAudio ? { coordinator.seekTo($0) } : nil
        return TabView(selection: $selectedTab) {
            TranscriptTabView(
                transcriptText: meeting.transcriptText,
                isTranscribing: transcriptionService.isTranscribing,
                partialText: transcriptionService.transcriptText,
                segments: meeting.transcriptSegments,
                speakerSegments: meeting.speakerSegments,
                speakerNames: meeting.speakerNames,
                onSeek: seekHandler,
                scrollToTimestamp: coordinator.scrollToTimestamp,
                currentTimestamp: coordinator.currentTimestamp
            )
            .tag(0)

            SummaryTabView(
                summary: meeting.summary,
                references: meeting.references,
                executiveBrief: meeting.executiveBrief,
                onSeek: seekHandler
            )
            .tag(1)

            InsightsTabView(
                insights: meeting.keyInsights,
                insightsWithTimestamps: meeting.keyInsightsWithTimestamps,
                onSeek: seekHandler
            )
            .tag(2)

            ActionItemsTabView(
                meeting: meeting,
                eventKitService: eventKitService,
                errorMessage: $errorMessage,
                showError: $showError,
                onSeek: seekHandler
            )
            .tag(3)
        }
    }

    private func loadAudio() {
        guard let url = meeting.audioFileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Audio file not found. The recording may have been lost."
            showError = true
            return
        }
        do {
            try playerService.loadAudio(url: url)
        } catch {
            // Audio playback failed, but transcription may still work
            errorMessage = error.localizedDescription
            showError = true
        }
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

        let langId = meeting.transcriptionLanguage ?? transcriptionLanguage
        transcriptionService.setLocale(Locale(identifier: langId))

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
                let result = try await transcriptionService.transcribeAudioFile(url: url)
                var text = result.fullText
                // Fallback: use partial transcript if final result is empty
                if text.isEmpty, !transcriptionService.transcriptText.isEmpty {
                    text = transcriptionService.transcriptText
                }
                if text.isEmpty {
                    errorMessage = "Transcription returned empty text. The recording may be too short or silent."
                    showError = true
                    meeting.status = .complete
                } else {
                    meeting.transcriptText = text
                    meeting.transcriptSegments = result.segments
                    meeting.status = .complete
                    if autoAnalyze {
                        analyzeTranscript()
                    }
                }
            } catch {
                // Fallback: if partial transcript was captured, use it despite the error
                if !transcriptionService.transcriptText.isEmpty {
                    meeting.transcriptText = transcriptionService.transcriptText
                    meeting.status = .complete
                    if autoAnalyze {
                        analyzeTranscript()
                    }
                } else {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    showError = true
                    meeting.status = .failed
                }
            }
        }
    }

    private func transcribeAndAnalyze() {
        guard let url = meeting.audioFileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Audio file not found."
            showError = true
            return
        }

        let langId = meeting.transcriptionLanguage ?? transcriptionLanguage
        transcriptionService.setLocale(Locale(identifier: langId))

        meeting.status = .transcribing
        Task { @MainActor in
            let authorized = await transcriptionService.requestAuthorization()
            guard authorized else {
                errorMessage = "Speech recognition permission not granted."
                showError = true
                meeting.status = .failed
                return
            }
            do {
                let result = try await transcriptionService.transcribeAudioFile(url: url)
                var text = result.fullText
                if text.isEmpty, !transcriptionService.transcriptText.isEmpty {
                    text = transcriptionService.transcriptText
                }
                guard !text.isEmpty else {
                    errorMessage = "Transcription returned empty text."
                    showError = true
                    meeting.status = .complete
                    return
                }
                meeting.transcriptText = text
                meeting.transcriptSegments = result.segments
                meeting.status = .complete
                // Chain directly into analysis
                analyzeTranscript()
            } catch {
                if !transcriptionService.transcriptText.isEmpty {
                    meeting.transcriptText = transcriptionService.transcriptText
                    meeting.status = .complete
                    analyzeTranscript()
                } else {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    showError = true
                    meeting.status = .failed
                }
            }
        }
    }

    private func analyzeTranscript() {
        #if !DEBUG
        guard subscriptionService.isSubscribed else {
            showSubscriptionPaywall = true
            return
        }
        #endif

        Task { @MainActor in
            do {
                guard let claudeService else {
                    errorMessage = "Analysis service not ready. Please try again."
                    showError = true
                    return
                }

                // Build timestamped transcript from segments if available
                let segments = meeting.transcriptSegments
                var timestampedTranscript: String? = nil
                if !segments.isEmpty {
                    let chunks = TranscriptionService.chunkSegments(segments)
                    timestampedTranscript = chunks.map { chunk in
                        let m = Int(chunk.timestamp) / 60
                        let s = Int(chunk.timestamp) % 60
                        return "[\(String(format: "%02d:%02d", m, s))] \(chunk.text)"
                    }.joined(separator: "\n\n")
                }

                // Pass 1: Speaker Diarization
                if let tsTranscript = timestampedTranscript {
                    meeting.status = .diarizing
                    let diarization = try await claudeService.diarizeTranscript(tsTranscript)
                    meeting.speakerSegments = diarization.segments
                }

                // Build speaker-labeled transcript for Pass 2
                let speakerSegments = meeting.speakerSegments
                let analysisTranscript: String
                if !speakerSegments.isEmpty {
                    analysisTranscript = speakerSegments.map { seg in
                        let m = Int(seg.startSeconds) / 60
                        let s = Int(seg.startSeconds) % 60
                        return "[\(String(format: "%02d:%02d", m, s))] [\(seg.speaker)] \(seg.text)"
                    }.joined(separator: "\n\n")
                } else {
                    analysisTranscript = timestampedTranscript ?? meeting.transcriptText
                }

                // Pass 2: Executive Brief Analysis
                meeting.status = .analyzing
                let result = try await claudeService.analyzeWithExecutiveBrief(analysisTranscript)
                meeting.summary = result.summary
                meeting.keyInsights = result.keyInsightStrings
                meeting.keyInsightsWithTimestamps = result.keyInsights
                meeting.title = result.effectiveTitle
                meeting.executiveBrief = result

                if let refs = result.references {
                    meeting.references = refs
                }

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
            } catch let apiError as ClaudeAPIError {
                switch apiError {
                case .noSubscription, .subscriptionExpired, .noReceipt:
                    showSubscriptionPaywall = true
                default:
                    errorMessage = apiError.localizedDescription
                    showError = true
                }
                meeting.status = .complete
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                meeting.status = .complete
            }
        }
    }

    private func exportToNotion() {
        Task { @MainActor in
            do {
                let result = try await notionService.exportMeeting(meeting)
                meeting.notionPageId = result.pageId
                meeting.notionPageUrl = result.pageUrl
                notionExportURL = result.pageUrl
                showNotionSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
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
    var segments: [TranscriptSegment] = []
    var speakerSegments: [SpeakerSegment] = []
    var speakerNames: [String] = []
    var onSeek: ((TimeInterval) -> Void)?
    var scrollToTimestamp: TimeInterval?
    var currentTimestamp: TimeInterval = 0

    var body: some View {
        ScrollViewReader { proxy in
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
                        description: Text("Tap the \u{22EF} menu and select Transcribe, or tap the waveform button in the toolbar.")
                    )
                } else if !speakerSegments.isEmpty, let onSeek {
                    // Speaker-labeled transcript
                    LazyVStack(alignment: .leading, spacing: Theme.spacing12) {
                        ForEach(Array(speakerSegments.enumerated()), id: \.offset) { index, segment in
                            let speakerIndex = speakerNames.firstIndex(of: segment.speaker) ?? 0
                            let isHighlighted = isSegmentActive(segment)

                            VStack(alignment: .leading, spacing: Theme.spacing4) {
                                HStack(spacing: Theme.spacing8) {
                                    Text(segment.speaker)
                                        .font(Theme.captionBoldFont)
                                        .foregroundStyle(Theme.speakerColor(for: speakerIndex))
                                    TimestampBadge(seconds: Int(segment.startSeconds), onTap: onSeek)
                                }

                                Text(segment.text)
                                    .font(Theme.bodyFont)
                                    .textSelection(.enabled)
                            }
                            .padding(Theme.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isHighlighted ? Theme.subtleAccent : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: Theme.accentBarCornerRadius)
                                    .fill(Theme.speakerColor(for: speakerIndex))
                                    .frame(width: Theme.accentBarWidth)
                                    .padding(.vertical, Theme.spacing4)
                            }
                            .id(index)
                        }
                    }
                    .padding()
                } else if !segments.isEmpty, let onSeek {
                    // Chunked transcript with timestamp headers (fallback)
                    LazyVStack(alignment: .leading, spacing: 16) {
                        let chunks = TranscriptionService.chunkSegments(segments)
                        ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                            VStack(alignment: .leading, spacing: 4) {
                                TimestampBadge(seconds: Int(chunk.timestamp), onTap: onSeek)
                                Text(chunk.text)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding()
                } else {
                    Text(transcriptText)
                        .padding()
                        .textSelection(.enabled)
                }
            }
            .onChange(of: scrollToTimestamp) { _, newValue in
                guard let target = newValue else { return }
                let targetIndex = speakerSegments.firstIndex { seg in
                    target >= seg.startSeconds && target < seg.endSeconds
                } ?? speakerSegments.firstIndex { seg in
                    seg.startSeconds >= target
                }
                if let idx = targetIndex {
                    withAnimation {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }

    private func isSegmentActive(_ segment: SpeakerSegment) -> Bool {
        currentTimestamp >= segment.startSeconds && currentTimestamp < segment.endSeconds
    }
}

struct SummaryTabView: View {
    let summary: String?
    var references: [AIReference] = []
    var executiveBrief: AIAnalysisResult?
    var onSeek: ((TimeInterval) -> Void)?

    var body: some View {
        ScrollView {
            if let brief = executiveBrief {
                LazyVStack(alignment: .leading, spacing: Theme.spacing16) {
                    // TL;DR Card
                    BriefCard(title: "TL;DR", icon: "text.quote", surface: Theme.surfaceTeal) {
                        Text(brief.effectiveTldr)
                            .font(Theme.bodyFont)
                    }

                    // Key Decisions Card
                    if let decisions = brief.keyDecisions, !decisions.isEmpty {
                        BriefCard(title: "Key Decisions", icon: "checkmark.seal", surface: Theme.surfaceOrange) {
                            ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                                HStack(alignment: .top, spacing: Theme.spacing8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.orange500)
                                        .font(.caption)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                                        citedText(decision.text, citations: decision.citations, references: references, onSeek: onSeek)
                                        if let ts = decision.timestampSeconds, let onSeek {
                                            TimestampBadge(seconds: ts, onTap: onSeek)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Discussion Points Card
                    if let points = brief.discussionPoints, !points.isEmpty {
                        BriefCard(title: "Discussion Points", icon: "bubble.left.and.bubble.right", surface: Theme.surfaceDefault) {
                            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                                VStack(alignment: .leading, spacing: Theme.spacing4) {
                                    Text(point.topic)
                                        .font(Theme.subheadlineFont)
                                        .fontWeight(.semibold)
                                    citedText(point.summary, citations: point.citations, references: references, onSeek: onSeek)
                                    if let ts = point.timestampSeconds, let onSeek {
                                        TimestampBadge(seconds: ts, onTap: onSeek)
                                    }
                                }
                                if point.topic != points.last?.topic {
                                    Divider()
                                }
                            }
                        }
                    }

                    // Open Questions Card
                    if let questions = brief.openQuestions, !questions.isEmpty {
                        BriefCard(title: "Open Questions", icon: "questionmark.circle", surface: Theme.surfacePurple) {
                            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                                HStack(alignment: .top, spacing: Theme.spacing8) {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundStyle(Theme.actionTask)
                                        .font(.caption)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                                        citedText(question.text, citations: question.citations, references: references, onSeek: onSeek)
                                        if let ts = question.timestampSeconds, let onSeek {
                                            TimestampBadge(seconds: ts, onTap: onSeek)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Next Steps Card
                    if let steps = brief.nextSteps, !steps.isEmpty {
                        BriefCard(title: "Next Steps", icon: "arrow.right.circle", surface: Theme.surfaceTeal) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                                HStack(alignment: .top, spacing: Theme.spacing8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(Theme.teal600)
                                        .font(.caption)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                                        Text(step.title)
                                            .font(Theme.subheadlineFont)
                                        if let assignee = step.assignee {
                                            Text(assignee)
                                                .font(Theme.captionFont)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let ts = step.timestampSeconds, let onSeek {
                                            TimestampBadge(seconds: ts, onTap: onSeek)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Sources section
                    if !references.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacing8) {
                            SectionHeaderLabel(title: "Sources", icon: "quote.opening")

                            ForEach(references) { ref in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("[\(ref.id)]")
                                        .font(.caption.bold().monospaced())
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 28, alignment: .leading)

                                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                                        if let speaker = ref.speaker {
                                            Text(speaker)
                                                .font(Theme.captionBoldFont)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(ref.passage)
                                            .font(Theme.subheadlineFont)
                                            .italic()
                                            .foregroundStyle(.secondary)
                                        if let onSeek {
                                            TimestampBadge(seconds: ref.timestampSeconds, onTap: onSeek)
                                        }
                                    }
                                }
                                .padding(Theme.cardPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surfaceDefault)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                            }
                        }
                    }
                }
                .padding()
            } else if let summary, !summary.isEmpty {
                // Fallback: legacy plain summary for old meetings
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        SectionHeaderLabel(title: "Meeting Summary", icon: "doc.text")
                        VStack(alignment: .leading, spacing: Theme.spacing12) {
                            if !references.isEmpty, let onSeek {
                                RichSummaryText(summary: summary, references: references, onSeek: onSeek)
                            } else {
                                Text(summary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(Theme.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surfaceTeal)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "No Summary",
                    systemImage: "sparkles",
                    description: Text("Tap Analyze to generate a summary.")
                )
            }
        }
    }

    @ViewBuilder
    private func citedText(_ text: String, citations: [Int]?, references: [AIReference], onSeek: ((TimeInterval) -> Void)?) -> some View {
        if let onSeek, !references.isEmpty {
            RichSummaryText(summary: text, references: references, onSeek: onSeek)
        } else {
            Text(text)
                .font(Theme.bodyFont)
        }
    }
}

struct BriefCard<Content: View>: View {
    let title: String
    let icon: String
    let surface: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionHeaderLabel(title: title, icon: icon)

            VStack(alignment: .leading, spacing: Theme.spacing12) {
                content
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }
}

struct InsightsTabView: View {
    let insights: [String]?
    var insightsWithTimestamps: [AIKeyInsight] = []
    var onSeek: ((TimeInterval) -> Void)?

    var body: some View {
        ScrollView {
            let displayInsights = !insightsWithTimestamps.isEmpty
                ? insightsWithTimestamps
                : (insights ?? []).map { AIKeyInsight(text: $0) }

            if !displayInsights.isEmpty {
                LazyVStack(alignment: .leading, spacing: Theme.spacing16) {
                    SectionHeaderLabel(title: "\(displayInsights.count) Key Insights", icon: "lightbulb")

                    ForEach(Array(displayInsights.enumerated()), id: \.offset) { index, insight in
                        HStack(alignment: .top, spacing: Theme.spacing12) {
                            // Numbered circle
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.insightBadge)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: Theme.spacing6) {
                                Text(insight.text)
                                    .font(Theme.subheadlineFont)

                                if let ts = insight.timestampSeconds, let onSeek {
                                    TimestampBadge(seconds: ts, onTap: onSeek)
                                }
                            }
                        }
                        .padding(Theme.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surfaceOrange)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Theme.accentBarCornerRadius)
                                .fill(Theme.insightBadge)
                                .frame(width: Theme.accentBarWidth)
                                .padding(.vertical, Theme.spacing8)
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
    var onSeek: ((TimeInterval) -> Void)?

    @State private var itemToExport: ActionItem?

    var body: some View {
        ScrollView {
            if meeting.actionItems.isEmpty {
                ContentUnavailableView(
                    "No Action Items",
                    systemImage: "checklist",
                    description: Text("Tap Analyze to extract action items.")
                )
            } else {
                LazyVStack(spacing: Theme.spacing12) {
                    SectionHeaderLabel(title: "\(meeting.actionItems.count) Action Items", icon: "checklist")
                        .padding(.horizontal)

                    ForEach(meeting.actionItems) { item in
                        ActionItemRowView(item: item, onSeek: onSeek) {
                            itemToExport = item
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .sheet(item: $itemToExport) { item in
            NavigationStack {
                ExportReviewSheet(item: item, eventKitService: eventKitService) { result in
                    itemToExport = nil
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Export Review Sheet

struct ExportReviewSheet: View {
    @Bindable var item: ActionItem
    let eventKitService: EventKitService
    let onComplete: (Result<Void, Error>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String = ""
    @State private var editedType: ActionItemType = .task
    @State private var editedDate: Date = Date().addingTimeInterval(86400)
    @State private var hasDate: Bool = false
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $editedTitle)

                Picker("Type", selection: $editedType) {
                    Label("Calendar Event", systemImage: "calendar")
                        .tag(ActionItemType.calendarEvent)
                    Label("Reminder", systemImage: "bell")
                        .tag(ActionItemType.reminder)
                    Label("Task", systemImage: "checklist")
                        .tag(ActionItemType.task)
                }
            }

            Section("Date & Time") {
                Toggle("Set date", isOn: $hasDate)

                if hasDate {
                    DatePicker(
                        editedType == .calendarEvent ? "Start" : "Due",
                        selection: $editedDate,
                        in: Date()...
                    )

                    if editedType == .calendarEvent {
                        Text("Duration: 1 hour")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text(exportDestinationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Export To")
            }
        }
        .navigationTitle("Review Action Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveAndExport()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Add")
                            .bold()
                    }
                }
                .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .onAppear {
            editedTitle = item.title
            editedType = item.type
            hasDate = item.dueDate != nil
            editedDate = item.dueDate ?? Date().addingTimeInterval(86400)
        }
    }

    private var exportDestinationDescription: String {
        switch editedType {
        case .calendarEvent:
            return "Will be added to your default Calendar."
        case .reminder:
            return "Will be added to your default Reminders list."
        case .task:
            return "Will be added to your default Reminders list as a task."
        }
    }

    private func saveAndExport() {
        isSaving = true
        // Update the item with edited values
        item.title = editedTitle.trimmingCharacters(in: .whitespaces)
        item.type = editedType
        item.dueDate = hasDate ? editedDate : nil

        Task { @MainActor in
            do {
                switch editedType {
                case .calendarEvent:
                    let granted = await eventKitService.requestCalendarAccess()
                    guard granted else {
                        isSaving = false
                        onComplete(.failure(ExportError.permissionDenied("Calendar access required. Enable it in Settings > Privacy > Calendars.")))
                        return
                    }
                    let id = try eventKitService.createCalendarEvent(
                        title: item.title,
                        startDate: hasDate ? editedDate : Date().addingTimeInterval(86400),
                        notes: nil
                    )
                    item.exportedIdentifier = id
                    item.isExported = true

                case .reminder, .task:
                    let granted = await eventKitService.requestRemindersAccess()
                    guard granted else {
                        isSaving = false
                        onComplete(.failure(ExportError.permissionDenied("Reminders access required. Enable it in Settings > Privacy > Reminders.")))
                        return
                    }
                    let id = try eventKitService.createReminder(
                        title: item.title,
                        dueDate: hasDate ? editedDate : nil,
                        notes: nil
                    )
                    item.exportedIdentifier = id
                    item.isExported = true
                }
                isSaving = false
                onComplete(.success(()))
            } catch {
                isSaving = false
                onComplete(.failure(error))
            }
        }
    }
}

private enum ExportError: LocalizedError {
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return message
        }
    }
}

// MARK: - Pill Tab Button

struct PillTabButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(Theme.subheadlineFont)
                .padding(.horizontal, Theme.cardPadding)
                .padding(.vertical, Theme.spacing8)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header Label

struct SectionHeaderLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: Theme.spacing8) {
            RoundedRectangle(cornerRadius: Theme.accentBarCornerRadius)
                .fill(Theme.teal600)
                .frame(width: Theme.accentBarWidth, height: 16)

            Image(systemName: icon)
                .font(Theme.captionBoldFont)
                .foregroundStyle(Theme.teal600)

            Text(title)
                .font(Theme.sectionHeaderFont)
                .foregroundStyle(.primary)
        }
    }
}
