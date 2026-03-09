# MeetingMind

A native iOS app that records meetings, transcribes audio on-device, and uses AI to generate summaries, action items, and executive briefs.

## Features

- **One-tap recording** with live waveform visualization and pause/resume
- **On-device transcription** via Apple Speech framework (50+ languages)
- **AI-powered analysis** using Claude API — summaries, key decisions, open questions
- **Speaker diarization** — identifies distinct speakers with a two-pass AI pipeline
- **Action item extraction** — automatically surfaces tasks, calendar events, and reminders
- **Timeline bar** — visual speaker segments with seek-to-timestamp
- **Audio playback** — custom player with scrubber, skip controls, and speed adjustment
- **Notion export** — send complete meeting notes to your Notion workspace
- **iCloud sync** — automatic cross-device sync via CloudKit
- **Subscription model** — monthly Pro tier for AI analysis features

## Requirements

- iOS 17.0+
- Xcode 16+

## Architecture

```
Record Audio → Transcribe (Apple Speech)
  → Diarize & Analyze (Claude API, 2-pass)
  → Extract Action Items
  → Export to Calendar / Reminders / Notion
```

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI + `@Observable` |
| Persistence | SwiftData + CloudKit |
| Audio | AVFoundation |
| Transcription | Apple Speech Framework |
| AI | Claude API (Sonnet) |
| Payments | StoreKit 2 |
| Secrets | iOS Keychain |

## Project Structure

```
MeetingMind/
├── Models/          # SwiftData models (Meeting, ActionItem, TranscriptSegment, …)
├── Views/           # SwiftUI screens and components
├── Services/        # Audio, transcription, Claude API, Notion, EventKit, …
└── Resources/       # Info.plist and assets
```

## Getting Started

1. Clone the repo and open `MeetingMind.xcodeproj` in Xcode.
2. Set your development team under **Signing & Capabilities**.
3. Build and run on a device or simulator (iOS 17+).
4. On first launch, grant microphone and speech recognition permissions when prompted.
5. To enable AI analysis, add your Claude API key in **Settings**.

## License

All rights reserved.
