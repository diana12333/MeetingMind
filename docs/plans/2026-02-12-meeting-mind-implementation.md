# MeetingMind Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native iOS app that records meetings, transcribes audio on-device, uses Claude AI to extract summaries and action items, and exports them to Apple Calendar/Reminders.

**Architecture:** Monolithic SwiftUI app using MVVM pattern. SwiftData for persistence with iCloud sync. AVFoundation for audio, Apple Speech for transcription, direct Claude API calls for AI analysis, EventKit for Calendar/Reminders integration.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, AVFoundation, Speech, EventKit, iOS 17+ minimum deployment target.

**Prerequisites:** Xcode 15+ installed on macOS. Apple Developer account (free tier works for simulator testing; paid $99/year needed for device testing and iCloud).

---

### Task 1: Create Xcode Project

**Files:**
- Create: `MeetingMind/MeetingMind.xcodeproj` (via Xcode)
- Create: `MeetingMind/MeetingMindApp.swift`
- Create: `MeetingMind/ContentView.swift`

**Step 1: Create the project**

Open Xcode > File > New > Project > iOS > App.
- Product Name: `MeetingMind`
- Organization Identifier: your reverse-domain (e.g. `com.yourname`)
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Uncheck "Include Tests" for now (we'll add manually)

Save the project into: `/Users/dianshen/Documents/Python_playground/claude_project/`

**Step 2: Configure project settings**

In Xcode project settings:
- Minimum Deployment Target: iOS 17.0
- Under "Signing & Capabilities", add:
  - iCloud (check CloudKit)
  - Background Modes (check "Audio, AirPlay, and Picture in Picture")

**Step 3: Add Info.plist privacy descriptions**

In the project's Info tab (or `Info.plist`), add these keys:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>MeetingMind needs microphone access to record your meetings.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>MeetingMind uses speech recognition to transcribe your meetings.</string>
<key>NSCalendarsUsageDescription</key>
<string>MeetingMind can add follow-up meetings to your calendar.</string>
<key>NSRemindersUsageDescription</key>
<string>MeetingMind can create reminders for your action items.</string>
```

**Step 4: Verify the project builds**

Run: `Cmd+B` in Xcode (or `xcodebuild -scheme MeetingMind -sdk iphonesimulator build`)
Expected: Build succeeds with default "Hello, World" SwiftUI app.

**Step 5: Commit**

```bash
cd /Users/dianshen/Documents/Python_playground/claude_project
git add MeetingMind/
git commit -m "feat: create MeetingMind Xcode project with SwiftData and permissions"
```

---

### Task 2: Define Data Models (SwiftData)

**Files:**
- Create: `MeetingMind/Models/Meeting.swift`
- Create: `MeetingMind/Models/ActionItem.swift`
- Create: `MeetingMind/Models/MeetingStatus.swift`
- Create: `MeetingMind/Models/ActionItemType.swift`

**Step 1: Create the MeetingStatus enum**

Create file `MeetingMind/Models/MeetingStatus.swift`:

```swift
import Foundation

enum MeetingStatus: String, Codable {
    case recording
    case transcribing
    case analyzing
    case complete
    case failed
}
```

**Step 2: Create the ActionItemType enum**

Create file `MeetingMind/Models/ActionItemType.swift`:

```swift
import Foundation

enum ActionItemType: String, Codable {
    case calendarEvent
    case reminder
    case task
}
```

**Step 3: Create the ActionItem model**

Create file `MeetingMind/Models/ActionItem.swift`:

```swift
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
```

**Step 4: Create the Meeting model**

Create file `MeetingMind/Models/Meeting.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var audioFileName: String?
    var transcriptText: String
    var status: MeetingStatus
    var summary: String?
    var keyInsights: [String]?

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.meeting)
    var actionItems: [ActionItem]

    init(
        title: String,
        date: Date = .now,
        duration: TimeInterval = 0,
        audioFileName: String? = nil,
        transcriptText: String = "",
        status: MeetingStatus = .recording
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.status = status
        self.actionItems = []
    }

    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(audioFileName)
    }
}
```

**Step 5: Update MeetingMindApp.swift to register models**

Modify `MeetingMind/MeetingMindApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct MeetingMindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Meeting.self, ActionItem.self])
    }
}
```

**Step 6: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds with no errors.

**Step 7: Commit**

```bash
git add MeetingMind/Models/ MeetingMind/MeetingMindApp.swift
git commit -m "feat: add SwiftData models for Meeting and ActionItem"
```

---

### Task 3: Build Keychain Helper for API Key Storage

**Files:**
- Create: `MeetingMind/Services/KeychainService.swift`

**Step 1: Create KeychainService**

Create file `MeetingMind/Services/KeychainService.swift`:

```swift
import Foundation
import Security

struct KeychainService {
    private static let serviceName = "com.meetingmind.apikey"
    private static let accountName = "claude-api-key"

    static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
```

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/Services/KeychainService.swift
git commit -m "feat: add KeychainService for secure API key storage"
```

---

### Task 4: Build Audio Recording Service

**Files:**
- Create: `MeetingMind/Services/AudioRecorderService.swift`

**Step 1: Create AudioRecorderService**

Create file `MeetingMind/Services/AudioRecorderService.swift`:

```swift
import AVFoundation
import Foundation

@Observable
final class AudioRecorderService {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    var isRecording = false
    var isPaused = false
    var elapsedTime: TimeInterval = 0
    var audioLevels: [Float] = [] // For waveform visualization

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    func startRecording(fileName: String) throws -> URL {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        isPaused = false
        startTime = Date()
        accumulatedTime = 0
        startTimer()

        return audioURL
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        accumulatedTime = elapsedTime
        startTime = nil
        timer?.invalidate()
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTime = Date()
        startTimer()
    }

    func stopRecording() -> TimeInterval {
        audioRecorder?.stop()
        timer?.invalidate()

        let finalDuration = elapsedTime
        isRecording = false
        isPaused = false
        elapsedTime = 0
        accumulatedTime = 0
        startTime = nil
        audioLevels = []

        try? AVAudioSession.sharedInstance().setActive(false)
        return finalDuration
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let startTime = self.startTime {
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(startTime)
            }
            self.audioRecorder?.updateMeters()
            if let level = self.audioRecorder?.averagePower(forChannel: 0) {
                let normalizedLevel = max(0, (level + 60) / 60) // Normalize -60...0 to 0...1
                self.audioLevels.append(normalizedLevel)
                if self.audioLevels.count > 100 {
                    self.audioLevels.removeFirst()
                }
            }
        }
    }
}
```

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/Services/AudioRecorderService.swift
git commit -m "feat: add AudioRecorderService with recording, pause, and waveform metering"
```

---

### Task 5: Build Audio Playback Service

**Files:**
- Create: `MeetingMind/Services/AudioPlayerService.swift`

**Step 1: Create AudioPlayerService**

Create file `MeetingMind/Services/AudioPlayerService.swift`:

```swift
import AVFoundation
import Foundation

@Observable
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    private var timer: Timer?

    func loadAudio(url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer?.rate = playbackRate
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            audioPlayer?.rate = rate
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentTime = self?.audioPlayer?.currentTime ?? 0
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        timer?.invalidate()
        currentTime = 0
    }
}
```

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/Services/AudioPlayerService.swift
git commit -m "feat: add AudioPlayerService with playback rate and seek support"
```

---

### Task 6: Build Transcription Service

**Files:**
- Create: `MeetingMind/Services/TranscriptionService.swift`

**Step 1: Create TranscriptionService**

Create file `MeetingMind/Services/TranscriptionService.swift`:

```swift
import Speech
import Foundation

@Observable
final class TranscriptionService {
    var isTranscribing = false
    var transcriptText = ""
    var progress: Double = 0

    private var recognizer: SFSpeechRecognizer?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribeAudioFile(url: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        isTranscribing = true
        progress = 0
        transcriptText = ""

        defer {
            isTranscribing = false
            progress = 1.0
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        // Use on-device recognition if available
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else { return }

                self?.transcriptText = result.bestTranscription.formattedString

                if result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .notAuthorized:
            return "Speech recognition permission was not granted."
        }
    }
}
```

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/Services/TranscriptionService.swift
git commit -m "feat: add TranscriptionService with on-device speech recognition"
```

---

### Task 7: Build Claude AI Service

**Files:**
- Create: `MeetingMind/Services/ClaudeAPIService.swift`
- Create: `MeetingMind/Models/AIAnalysisResult.swift`

**Step 1: Create the AIAnalysisResult model**

Create file `MeetingMind/Models/AIAnalysisResult.swift`:

```swift
import Foundation

struct AIAnalysisResult: Codable {
    let summary: String
    let keyInsights: [String]
    let actionItems: [AIActionItem]
}

struct AIActionItem: Codable {
    let title: String
    let type: String // "calendarEvent", "reminder", "task"
    let suggestedDate: String?
    let assignee: String?

    var actionItemType: ActionItemType {
        ActionItemType(rawValue: type) ?? .task
    }

    var parsedDate: Date? {
        guard let suggestedDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: suggestedDate)
            ?? ISO8601DateFormatter().date(from: suggestedDate)
    }
}
```

**Step 2: Create ClaudeAPIService**

Create file `MeetingMind/Services/ClaudeAPIService.swift`:

```swift
import Foundation

@Observable
final class ClaudeAPIService {
    var isAnalyzing = false

    func analyzeTranscript(_ transcript: String) async throws -> AIAnalysisResult {
        guard let apiKey = KeychainService.getAPIKey(), !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemPrompt = """
        You are a meeting analysis assistant. Analyze the provided meeting transcript and return a JSON object with exactly this structure:
        {
          "summary": "2-3 paragraph summary of the meeting",
          "keyInsights": ["insight 1", "insight 2", ...],
          "actionItems": [
            {
              "title": "action item description",
              "type": "calendarEvent" or "reminder" or "task",
              "suggestedDate": "ISO 8601 date string or null",
              "assignee": "person name or null"
            }
          ]
        }

        Rules:
        - Use "calendarEvent" for meetings, appointments, deadlines
        - Use "reminder" for follow-ups, check-ins
        - Use "task" for to-do items without specific dates
        - Return ONLY valid JSON, no markdown, no explanation
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Please analyze this meeting transcript:\n\n\(transcript)"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw ClaudeAPIError.invalidAPIKey
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse Claude API response to extract the text content
        let apiResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textContent = apiResponse.content.first?.text else {
            throw ClaudeAPIError.noContent
        }

        // Parse the JSON from Claude's text response
        guard let jsonData = textContent.data(using: .utf8) else {
            throw ClaudeAPIError.invalidJSON
        }

        return try JSONDecoder().decode(AIAnalysisResult.self, from: jsonData)
    }
}

// Claude API response structures
private struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

private struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidResponse
    case noContent
    case invalidJSON
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Claude API key in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .noContent:
            return "No content in Claude API response."
        case .invalidJSON:
            return "Could not parse AI analysis results."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}
```

**Step 3: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add MeetingMind/Services/ClaudeAPIService.swift MeetingMind/Models/AIAnalysisResult.swift
git commit -m "feat: add ClaudeAPIService for meeting transcript analysis"
```

---

### Task 8: Build EventKit Service (Calendar & Reminders)

**Files:**
- Create: `MeetingMind/Services/EventKitService.swift`

**Step 1: Create EventKitService**

Create file `MeetingMind/Services/EventKitService.swift`:

```swift
import EventKit
import Foundation

final class EventKitService {
    private let eventStore = EKEventStore()

    func requestCalendarAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func createCalendarEvent(
        title: String,
        startDate: Date,
        notes: String? = nil
    ) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(3600) // Default 1 hour
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    func createReminder(
        title: String,
        dueDate: Date? = nil,
        notes: String? = nil
    ) throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
}
```

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/Services/EventKitService.swift
git commit -m "feat: add EventKitService for Calendar and Reminders integration"
```

---

### Task 9: Build Meeting List Screen (Home)

**Files:**
- Create: `MeetingMind/Views/MeetingListView.swift`
- Create: `MeetingMind/Views/MeetingRowView.swift`
- Modify: `MeetingMind/ContentView.swift`

**Step 1: Create MeetingRowView**

Create file `MeetingMind/Views/MeetingRowView.swift`:

```swift
import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)

                Text(meeting.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: meeting.status)

                Text(formatDuration(meeting.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

extension MeetingStatus {
    var label: String {
        switch self {
        case .recording: "Recording"
        case .transcribing: "Transcribing"
        case .analyzing: "Analyzing"
        case .complete: "Complete"
        case .failed: "Failed"
        }
    }

    var color: Color {
        switch self {
        case .recording: .red
        case .transcribing: .orange
        case .analyzing: .blue
        case .complete: .green
        case .failed: .red
        }
    }
}
```

**Step 2: Create MeetingListView**

Create file `MeetingMind/Views/MeetingListView.swift`:

```swift
import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @State private var searchText = ""
    @State private var showRecording = false

    var filteredMeetings: [Meeting] {
        if searchText.isEmpty { return meetings }
        return meetings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.transcriptText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredMeetings) { meeting in
                    NavigationLink(value: meeting) {
                        MeetingRowView(meeting: meeting)
                    }
                }
                .onDelete(perform: deleteMeetings)
            }
            .navigationTitle("MeetingMind")
            .searchable(text: $searchText, prompt: "Search meetings")
            .navigationDestination(for: Meeting.self) { meeting in
                MeetingDetailView(meeting: meeting)
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
            .toolbar {
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
        }
    }

    private func deleteMeetings(at offsets: IndexSet) {
        for index in offsets {
            let meeting = filteredMeetings[index]
            // Delete audio file
            if let url = meeting.audioFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(meeting)
        }
    }
}
```

**Step 3: Update ContentView**

Replace contents of `MeetingMind/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        MeetingListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meeting.self, ActionItem.self], inMemory: true)
}
```

**Step 4: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Will fail because `MeetingDetailView` and `RecordingView` don't exist yet. That's expected — we'll create stubs.

**Step 5: Create placeholder views**

Create file `MeetingMind/Views/MeetingDetailView.swift`:

```swift
import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting

    var body: some View {
        Text("Meeting Detail — coming soon")
            .navigationTitle(meeting.title)
    }
}
```

Create file `MeetingMind/Views/RecordingView.swift`:

```swift
import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Recording — coming soon")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
```

**Step 6: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 7: Commit**

```bash
git add MeetingMind/Views/ MeetingMind/ContentView.swift
git commit -m "feat: add MeetingListView with search, delete, and navigation"
```

---

### Task 10: Build Recording Screen

**Files:**
- Modify: `MeetingMind/Views/RecordingView.swift`
- Create: `MeetingMind/Views/WaveformView.swift`

**Step 1: Create WaveformView**

Create file `MeetingMind/Views/WaveformView.swift`:

```swift
import SwiftUI

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 3, height: max(2, CGFloat(level) * 60))
            }
        }
        .frame(height: 60)
    }
}
```

**Step 2: Replace RecordingView with full implementation**

Replace contents of `MeetingMind/Views/RecordingView.swift`:

```swift
import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var recorder = AudioRecorderService()
    @State private var meeting: Meeting?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Timer
                Text(formatTime(recorder.elapsedTime))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(recorder.isRecording ? .red : .primary)

                // Waveform
                WaveformView(levels: recorder.audioLevels)
                    .padding(.horizontal)

                Spacer()

                // Controls
                HStack(spacing: 40) {
                    // Cancel
                    Button {
                        cancelRecording()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray)
                    }

                    // Record / Pause
                    Button {
                        if recorder.isRecording && !recorder.isPaused {
                            recorder.pauseRecording()
                        } else if recorder.isPaused {
                            recorder.resumeRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)

                            if recorder.isRecording && !recorder.isPaused {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }

                    // Stop (only when recording)
                    Button {
                        stopRecording()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(recorder.isRecording ? .red : .gray)
                    }
                    .disabled(!recorder.isRecording)
                }

                Spacer()
            }
            .navigationTitle("Record Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelRecording() }
                }
            }
            .alert("Recording Error", isPresented: $showError) {
                Button("OK") { dismiss() }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func startRecording() {
        let newMeeting = Meeting(title: "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))")
        let fileName = "\(newMeeting.id.uuidString).m4a"
        newMeeting.audioFileName = fileName

        do {
            _ = try recorder.startRecording(fileName: fileName)
            meeting = newMeeting
            modelContext.insert(newMeeting)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() {
        let duration = recorder.stopRecording()
        meeting?.duration = duration
        meeting?.status = .transcribing
        dismiss()
    }

    private func cancelRecording() {
        if recorder.isRecording {
            _ = recorder.stopRecording()
            if let meeting {
                if let url = meeting.audioFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                modelContext.delete(meeting)
            }
        }
        dismiss()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
```

**Step 3: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add MeetingMind/Views/RecordingView.swift MeetingMind/Views/WaveformView.swift
git commit -m "feat: add RecordingView with waveform, pause/resume, and timer"
```

---

### Task 11: Build Meeting Detail Screen

**Files:**
- Modify: `MeetingMind/Views/MeetingDetailView.swift`
- Create: `MeetingMind/Views/ActionItemRowView.swift`

**Step 1: Create ActionItemRowView**

Create file `MeetingMind/Views/ActionItemRowView.swift`:

```swift
import SwiftUI

struct ActionItemRowView: View {
    let item: ActionItem
    let onExport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: item.type.iconName)
                .foregroundStyle(item.type.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)

                if let dueDate = item.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.isExported {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Export", action: onExport)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

extension ActionItemType {
    var iconName: String {
        switch self {
        case .calendarEvent: "calendar"
        case .reminder: "bell"
        case .task: "checklist"
        }
    }

    var iconColor: Color {
        switch self {
        case .calendarEvent: .blue
        case .reminder: .orange
        case .task: .purple
        }
    }
}
```

**Step 2: Replace MeetingDetailView with full implementation**

Replace contents of `MeetingMind/Views/MeetingDetailView.swift`:

```swift
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
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            // Audio player bar
            if meeting.audioFileURL != nil {
                AudioPlayerBar(player: playerService, meeting: meeting)
                    .padding()
                Divider()
            }

            // Tab picker
            Picker("Section", selection: $selectedTab) {
                Text("Transcript").tag(0)
                Text("Summary").tag(1)
                Text("Insights").tag(2)
                Text("Actions").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $selectedTab) {
                TranscriptTabView(
                    meeting: meeting,
                    transcriptionService: transcriptionService
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
        guard let url = meeting.audioFileURL else { return }
        Task {
            let authorized = await transcriptionService.requestAuthorization()
            guard authorized else {
                errorMessage = "Speech recognition permission required."
                showError = true
                return
            }
            do {
                let text = try await transcriptionService.transcribeAudioFile(url: url)
                meeting.transcriptText = text
                meeting.status = .complete
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                meeting.status = .failed
            }
        }
    }

    private func analyzeTranscript() {
        Task {
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
                selectedTab = 1 // Jump to summary tab
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
    @Bindable var player: AudioPlayerService
    let meeting: Meeting

    var body: some View {
        VStack(spacing: 8) {
            // Progress slider
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

                // Playback controls
                Button {
                    if player.isPlaying { player.pause() } else { player.play() }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }

                Spacer()

                // Speed picker
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
    let meeting: Meeting
    let transcriptionService: TranscriptionService

    var body: some View {
        ScrollView {
            if transcriptionService.isTranscribing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Transcribing...")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            } else if meeting.transcriptText.isEmpty {
                ContentUnavailableView(
                    "No Transcript",
                    systemImage: "text.bubble",
                    description: Text("Transcript will appear after recording completes.")
                )
            } else {
                Text(meeting.transcriptText)
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
        Task {
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
```

**Step 3: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add MeetingMind/Views/MeetingDetailView.swift MeetingMind/Views/ActionItemRowView.swift
git commit -m "feat: add MeetingDetailView with transcript, summary, insights, and action items tabs"
```

---

### Task 12: Build Settings Screen

**Files:**
- Create: `MeetingMind/Views/SettingsView.swift`
- Modify: `MeetingMind/Views/MeetingListView.swift` (add settings navigation)

**Step 1: Create SettingsView**

Create file `MeetingMind/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isSaved = false

    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("autoAnalyze") private var autoAnalyze = false

    var body: some View {
        Form {
            Section("Claude API Key") {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("sk-ant-...", text: $apiKey)
                    }

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                }

                Button("Save API Key") {
                    if KeychainService.saveAPIKey(apiKey) {
                        isSaved = true
                    }
                }
                .disabled(apiKey.isEmpty)

                if isSaved {
                    Text("API key saved securely in Keychain")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("Recording") {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Standard").tag("standard")
                    Text("High").tag("high")
                }
            }

            Section("AI Analysis") {
                Toggle("Auto-analyze after transcription", isOn: $autoAnalyze)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("AI Provider")
                    Spacer()
                    Text("Claude (Anthropic)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKey = KeychainService.getAPIKey() ?? ""
        }
    }
}
```

**Step 2: Add settings button to MeetingListView**

In `MeetingMind/Views/MeetingListView.swift`, add a toolbar item inside the existing `.toolbar` block:

```swift
ToolbarItem(placement: .navigationBarLeading) {
    NavigationLink {
        SettingsView()
    } label: {
        Image(systemName: "gear")
    }
}
```

Add this as a second `ToolbarItem` inside the existing `.toolbar { }` modifier, alongside the existing `+` button.

**Step 3: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add MeetingMind/Views/SettingsView.swift MeetingMind/Views/MeetingListView.swift
git commit -m "feat: add SettingsView with API key management and recording preferences"
```

---

### Task 13: Wire Up Auto-Transcription After Recording

**Files:**
- Modify: `MeetingMind/Views/MeetingListView.swift`

**Step 1: Add auto-transcription trigger**

When a meeting's status is `.transcribing`, the `MeetingDetailView` already kicks off transcription in `onAppear`. The flow is:

1. `RecordingView.stopRecording()` sets `meeting.status = .transcribing`
2. User is dismissed back to `MeetingListView`
3. User taps the meeting to open `MeetingDetailView`
4. `MeetingDetailView.onAppear` detects `.transcribing` status and calls `transcribeAudio()`

This works as-is. No changes needed — the wiring is already in place from Tasks 10 and 11.

**Step 2: Verify the end-to-end flow**

Run the app on an iPhone Simulator:
1. Tap `+` to start recording
2. Speak for 10-15 seconds
3. Tap Stop
4. Tap the new meeting in the list
5. Wait for transcription to complete
6. Tap the sparkles button to analyze

Expected: Transcript appears, then AI summary/insights/actions after analysis.

**Step 3: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: wire up end-to-end recording and transcription flow"
```

---

### Task 14: Add iCloud Sync Configuration

**Files:**
- Modify: `MeetingMind/MeetingMindApp.swift`

**Step 1: Update ModelContainer for iCloud sync**

Replace `MeetingMindApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct MeetingMindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Meeting.self, ActionItem.self], isAutosaveEnabled: true)
    }
}
```

Note: For full iCloud sync with CloudKit, you need:
1. An Apple Developer account (paid, $99/year)
2. The iCloud capability added in Xcode (done in Task 1)
3. A CloudKit container configured in the Apple Developer portal

For local development and simulator testing, SwiftData works locally without CloudKit. iCloud sync activates automatically when deployed to a real device with a signed Apple Developer account.

**Step 2: Build and verify**

Run: `Cmd+B` in Xcode
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add MeetingMind/MeetingMindApp.swift
git commit -m "feat: configure SwiftData ModelContainer with autosave for iCloud readiness"
```

---

### Task 15: Polish and Final Integration Testing

**Files:**
- All views (minor adjustments as needed)

**Step 1: Run the full app on Simulator**

Test each flow end-to-end:
- [ ] Launch app, see empty state
- [ ] Tap +, record 15 seconds, stop
- [ ] Meeting appears in list with "Transcribing" badge
- [ ] Open meeting, transcript populates
- [ ] Tap Analyze (sparkles button), wait for AI response
- [ ] Summary tab shows summary
- [ ] Insights tab shows bullet points
- [ ] Actions tab shows extracted items
- [ ] Tap Export on a calendar item, verify Calendar app has event
- [ ] Tap Export on a reminder, verify Reminders app has it
- [ ] Swipe to delete a meeting
- [ ] Settings: save API key, change quality setting

**Step 2: Fix any issues found during testing**

Address bugs found in the integration test above.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete MeetingMind v1 MVP with all features integrated"
```

---

## Summary of Tasks

| Task | Description | Estimated Complexity |
|------|-------------|---------------------|
| 1 | Create Xcode project | Setup |
| 2 | Define SwiftData models | Low |
| 3 | Keychain helper | Low |
| 4 | Audio recording service | Medium |
| 5 | Audio playback service | Low |
| 6 | Transcription service | Medium |
| 7 | Claude AI service | Medium |
| 8 | EventKit service | Low |
| 9 | Meeting list screen | Medium |
| 10 | Recording screen | Medium |
| 11 | Meeting detail screen | High |
| 12 | Settings screen | Low |
| 13 | Auto-transcription wiring | Low |
| 14 | iCloud sync config | Low |
| 15 | Polish & integration test | Medium |

## Dependencies

```
Task 1 (project setup)
├── Task 2 (models)
│   ├── Task 3 (keychain)
│   │   └── Task 7 (Claude API) ──┐
│   ├── Task 4 (recorder) ────────┤
│   ├── Task 5 (player) ──────────┤
│   ├── Task 6 (transcription) ───┤
│   └── Task 8 (EventKit) ────────┤
│                                  ▼
├── Task 9 (list view) ──→ Task 10 (recording view)
│                                  │
│                          Task 11 (detail view)
│                                  │
├── Task 12 (settings) ───────────┤
├── Task 13 (wiring) ─────────────┤
├── Task 14 (iCloud) ─────────────┤
└── Task 15 (integration test) ◄──┘
```
