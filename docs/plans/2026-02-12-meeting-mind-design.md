# MeetingMind — Product Requirements Document

## 1. Overview

**MeetingMind** is a native iOS app that records meetings, automatically transcribes audio using on-device speech recognition, and leverages cloud AI (Claude API) to generate summaries, key insights, and actionable follow-ups. Users can export action items directly to Apple Calendar and Reminders with one tap.

## 2. Goals

- Enable users to record meetings with a simple, distraction-free interface
- Automatically transcribe recordings using Apple's on-device Speech framework (free, offline-capable)
- Use Claude API to generate intelligent meeting summaries, insights, and structured action items
- Allow one-tap export of action items to Apple Calendar and Reminders
- Sync all data across Apple devices via iCloud

## 3. Target User

Professionals who attend frequent meetings and need to capture decisions, follow-ups, and action items without manual note-taking.

## 4. Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Swift + SwiftUI | Native iOS, best access to Apple APIs |
| Architecture | Monolithic single-app | Simplest path to MVP, no backend to maintain |
| Transcription | Apple Speech (on-device) | Free, offline-capable, good English accuracy |
| AI Analysis | Claude API (cloud) | High-quality summaries and structured extraction |
| Action Items | Direct Apple integration (EventKit) | Seamless Calendar & Reminders integration |
| Storage | SwiftData + iCloud (CloudKit) | Modern persistence with automatic cross-device sync |
| API Key Storage | iOS Keychain | Encrypted, secure enclave backed |

## 5. Architecture

```
┌─────────────────────────────────────────────────┐
│                  MeetingMind App                 │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌───────────┐   ┌──────────────┐               │
│  │ Recording  │──▶│ Transcription │              │
│  │ (AVFound.) │   │ (Apple Speech)│              │
│  └───────────┘   └──────┬───────┘               │
│                         │                        │
│                         ▼                        │
│               ┌──────────────────┐               │
│               │  AI Analysis     │               │
│               │  (Claude API)    │               │
│               └────────┬─────────┘               │
│                        │                         │
│            ┌───────────┼───────────┐             │
│            ▼           ▼           ▼             │
│     ┌──────────┐ ┌──────────┐ ┌─────────┐       │
│     │ Summary  │ │ Calendar │ │Reminders│       │
│     │ & Notes  │ │(EventKit)│ │(EventKit)│      │
│     └──────────┘ └──────────┘ └─────────┘       │
│                                                  │
│  ┌──────────────────────────────────────┐        │
│  │  Storage: SwiftData + CloudKit/iCloud │       │
│  └──────────────────────────────────────┘        │
└─────────────────────────────────────────────────┘
```

### Core Flow

1. User taps "Record" — audio captured via `AVFoundation`
2. Real-time or post-recording transcription via Apple `Speech` framework
3. Transcript sent to Claude API for analysis
4. AI returns: summary, key insights, and extracted action items
5. User reviews and taps to create Calendar events or Reminders
6. Everything persisted locally via `SwiftData` with iCloud sync

## 6. Data Model

```
Meeting
├── id: UUID
├── title: String
├── date: Date
├── duration: TimeInterval
├── audioFileURL: URL (local file reference)
├── transcriptText: String
├── status: enum (recording, transcribing, analyzing, complete)
│
├── summary: String? (AI-generated)
├── keyInsights: [String]? (AI-generated)
│
└── actionItems: [ActionItem]
      ├── id: UUID
      ├── title: String
      ├── type: enum (calendarEvent, reminder, task)
      ├── dueDate: Date?
      ├── isExported: Bool (sent to Calendar/Reminders?)
      └── exportedIdentifier: String? (EventKit ID for reference)
```

All models use `SwiftData` `@Model` macros with iCloud sync via `ModelConfiguration`.

## 7. Screens

### 7.1 Home / Meeting List
- Displays all recorded meetings sorted by date (newest first)
- Each row shows: title, date, duration, status badge (recording/transcribing/complete)
- Search bar for filtering meetings by title or transcript content
- Floating "+" button to start a new recording

### 7.2 Recording Screen
- Large, prominent record/stop button
- Live audio waveform visualization
- Running timer display
- Optional live transcript preview (scrolling text as speech is recognized)
- Pause/resume support

### 7.3 Meeting Detail
- **Header:** Title (editable), date, duration
- **Audio Player:** Play/pause, scrub bar, playback speed control
- **Transcript Tab:** Full scrollable transcript text
- **Summary Tab:** AI-generated summary (2-3 paragraphs)
- **Insights Tab:** Bullet-pointed key decisions and insights
- **Action Items Tab:** List of extracted action items with export buttons
- "Analyze" button to trigger/re-trigger AI analysis

### 7.4 Action Item Review
- List of AI-extracted action items
- Each item shows: title, type icon (calendar/reminder), suggested date
- One-tap buttons: "Add to Calendar", "Add to Reminders"
- Checkmark indicator for already-exported items
- Edit capability before exporting (adjust title, date, etc.)

### 7.5 Settings
- Claude API key input (stored in Keychain)
- iCloud sync toggle
- Audio quality preference (standard / high)
- Default transcription language
- About / version info

## 8. Apple Framework Usage

| Feature | Framework | Details |
|---|---|---|
| Audio recording | `AVFoundation` (`AVAudioRecorder`) | Record to `.m4a`, configurable sample rate and quality |
| Audio playback | `AVFoundation` (`AVAudioPlayer`) | Playback with speed control |
| Transcription | `Speech` (`SFSpeechRecognizer`) | On-device recognition, supports 50+ languages |
| Calendar events | `EventKit` (`EKEventStore`, `EKEvent`) | Request permission, create events with title/date/notes |
| Reminders/Tasks | `EventKit` (`EKEventStore`, `EKReminder`) | Create reminders with due dates and notes |
| Local storage | `SwiftData` | `@Model` macros, `ModelContainer`, `@Query` |
| iCloud sync | `CloudKit` via SwiftData | Automatic sync through `ModelConfiguration` |
| Notifications | `UserNotifications` | Alert when transcription or AI analysis completes |
| Secure storage | `Security` (Keychain) | Store API key encrypted in iOS Keychain |

## 9. AI Integration

### Provider
Claude API (Anthropic) via direct HTTPS calls from the app.

### Trigger
After transcription completes, user taps "Analyze" or auto-analyze is enabled in settings.

### Prompt Strategy
Send the full transcript with a structured system prompt requesting:
- **Meeting summary:** 2-3 concise paragraphs
- **Key insights:** Bullet points of decisions made, important topics discussed
- **Action items:** Structured list with fields: title, type (calendarEvent/reminder), suggested date, assignee (if mentioned)

### Response Format
Request JSON output from Claude API for reliable parsing:

```json
{
  "summary": "...",
  "keyInsights": ["...", "..."],
  "actionItems": [
    {
      "title": "Follow up with design team",
      "type": "calendarEvent",
      "suggestedDate": "2026-02-20T14:00:00Z",
      "assignee": "John"
    }
  ]
}
```

Parse response into `ActionItem` SwiftData models.

### Error Handling
- Network failure: Show retry button, keep transcript intact
- API key invalid: Prompt user to check Settings
- Rate limiting: Queue requests, show status to user

## 10. Permissions Required

| Permission | When Requested | `Info.plist` Key |
|---|---|---|
| Microphone | First recording | `NSMicrophoneUsageDescription` |
| Speech Recognition | First transcription | `NSSpeechRecognitionUsageDescription` |
| Calendar | First calendar export | `NSCalendarsUsageDescription` |
| Reminders | First reminder export | `NSRemindersUsageDescription` |

Permissions are requested lazily — only when the user first triggers the relevant feature.

## 11. Security & Privacy

- **API key:** Stored in iOS Keychain (encrypted, hardware-backed on devices with Secure Enclave)
- **Audio files:** Stored in app sandbox, optionally synced via iCloud
- **Transcripts:** Stored locally in SwiftData, synced via iCloud if enabled
- **Network:** All API calls over HTTPS
- **No analytics or tracking** in v1
- **No third-party SDKs** beyond Anthropic API calls

## 12. Out of Scope (v1)

- Multi-user / shared meetings
- Web or Mac companion app
- Speaker diarization (who said what)
- Real-time collaboration
- Custom backend / user accounts
- Export to third-party tools (Notion, Slack, etc.)
- In-app subscription or payment

## 13. Success Criteria

- User can record a meeting and see a transcript within 30 seconds of stopping
- AI analysis returns summary and action items within 15 seconds
- One-tap export creates valid Calendar events and Reminders
- Data persists across app launches and syncs via iCloud
- App handles recordings of at least 60 minutes

## 14. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| API key exposed on device | Store in Keychain; note in Settings that key is stored securely. Consider lightweight backend proxy in v2. |
| Apple Speech accuracy varies | Allow user to edit transcript before AI analysis |
| Long recordings may hit API token limits | Chunk long transcripts into segments, summarize each, then merge |
| iCloud sync conflicts | SwiftData/CloudKit handles merge automatically; last-write-wins for simple fields |
| Apple Speech rate limits (1 min real-time max for on-device) | Use file-based recognition for post-recording transcription (no real-time limit) |
