import Foundation
import WatchConnectivity
import SwiftData

@MainActor
@Observable
final class WatchConnectivityService: NSObject {
    var isWatchReachable = false
    private var session: WCSession?
    private var modelContext: ModelContext?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    func sendMeetingList() {
        guard let session, session.isReachable, let modelContext else { return }

        let descriptor = FetchDescriptor<Meeting>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let meetings = try? modelContext.fetch(descriptor) else { return }

        let meetingDicts: [[String: Any]] = Array(meetings.prefix(10)).map { meeting in
            [
                "id": meeting.id.uuidString,
                "title": meeting.title,
                "date": meeting.date.timeIntervalSince1970,
                "status": meeting.status.rawValue,
            ]
        }

        session.sendMessage(["meetings": meetingDicts], replyHandler: nil, errorHandler: nil)
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        MainActor.assumeIsolated {
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        MainActor.assumeIsolated {
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        let duration = metadata["duration"] as? TimeInterval ?? 0
        let fileName = metadata["fileName"] as? String ?? "\(UUID().uuidString).m4a"

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)

            MainActor.assumeIsolated {
                self.createMeetingFromWatchRecording(fileName: fileName, duration: duration)
                session.sendMessage(["transferStatus": "completed"], replyHandler: nil, errorHandler: nil)
            }
        } catch {
            session.sendMessage(["transferStatus": "failed"], replyHandler: nil, errorHandler: nil)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "meetingList" {
            MainActor.assumeIsolated {
                guard let modelContext = self.modelContext else {
                    replyHandler(["meetings": []])
                    return
                }

                let descriptor = FetchDescriptor<Meeting>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let meetings = (try? modelContext.fetch(descriptor)) ?? []

                let meetingDicts: [[String: Any]] = Array(meetings.prefix(10)).map { meeting in
                    [
                        "id": meeting.id.uuidString,
                        "title": meeting.title,
                        "date": meeting.date.timeIntervalSince1970,
                        "status": meeting.status.rawValue,
                    ]
                }
                replyHandler(["meetings": meetingDicts])
            }
        }
    }
}

private extension WatchConnectivityService {
    func createMeetingFromWatchRecording(fileName: String, duration: TimeInterval) {
        guard let modelContext else { return }

        let title = "Watch Recording \(Date().formatted(date: .abbreviated, time: .shortened))"
        let meeting = Meeting(title: title, duration: duration, audioFileName: fileName, status: .transcribing)
        modelContext.insert(meeting)
    }
}
