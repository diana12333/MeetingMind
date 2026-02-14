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
