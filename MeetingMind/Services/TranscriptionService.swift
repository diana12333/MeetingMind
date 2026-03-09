import Speech
import Foundation

@MainActor
@Observable
final class TranscriptionService {
    var isTranscribing = false
    var transcriptText = ""
    var progress: Double = 0

    private var recognizer: SFSpeechRecognizer?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func setLocale(_ locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    static func chunkSegments(_ segments: [TranscriptSegment], maxChunkDuration: TimeInterval = 30) -> [TranscriptSegment] {
        guard !segments.isEmpty else { return [] }
        var chunks: [TranscriptSegment] = []
        var currentText = ""
        var chunkStart = segments[0].timestamp
        var chunkDuration: TimeInterval = 0

        for segment in segments {
            if chunkDuration + segment.duration > maxChunkDuration && !currentText.isEmpty {
                chunks.append(TranscriptSegment(text: currentText.trimmingCharacters(in: .whitespaces), timestamp: chunkStart, duration: chunkDuration))
                currentText = ""
                chunkStart = segment.timestamp
                chunkDuration = 0
            }
            currentText += " " + segment.text
            chunkDuration += segment.duration
        }

        if !currentText.isEmpty {
            chunks.append(TranscriptSegment(text: currentText.trimmingCharacters(in: .whitespaces), timestamp: chunkStart, duration: chunkDuration))
        }

        return chunks
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribeAudioFile(url: URL) async throws -> TranscriptionResult {
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

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error, !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else { return }

                self?.transcriptText = result.bestTranscription.formattedString

                if result.isFinal, !hasResumed {
                    hasResumed = true
                    let transcription = result.bestTranscription
                    let segments = transcription.segments.map { seg in
                        TranscriptSegment(
                            text: seg.substring,
                            timestamp: seg.timestamp,
                            duration: seg.duration
                        )
                    }
                    continuation.resume(returning: TranscriptionResult(
                        fullText: transcription.formattedString,
                        segments: segments
                    ))
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
