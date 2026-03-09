import Foundation
import WatchConnectivity

@MainActor
@Observable
final class WatchSessionService: NSObject {
    var isReachable = false
    var transferProgress: Double?
    var recentMeetings: [WatchMeetingInfo] = []

    private var session: WCSession?
    private var activeTransfer: WCSessionFileTransfer?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func transferRecording(fileURL: URL, duration: TimeInterval) {
        guard let session, session.isReachable else {
            transferProgress = nil
            return
        }

        let metadata: [String: Any] = [
            "duration": duration,
            "date": Date().timeIntervalSince1970,
            "fileName": fileURL.lastPathComponent,
        ]

        transferProgress = 0
        activeTransfer = session.transferFile(fileURL, metadata: metadata)
    }

    func requestMeetingList() {
        guard let session, session.isReachable else { return }
        session.sendMessage(["request": "meetingList"], replyHandler: { [weak self] reply in
            MainActor.assumeIsolated {
                if let meetingsData = reply["meetings"] as? [[String: Any]] {
                    self?.recentMeetings = meetingsData.compactMap { WatchMeetingInfo(from: $0) }
                }
            }
        }, errorHandler: nil)
    }
}

extension WatchSessionService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        MainActor.assumeIsolated {
            isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        MainActor.assumeIsolated {
            isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        MainActor.assumeIsolated {
            if let status = message["transferStatus"] as? String {
                if status == "completed" {
                    transferProgress = nil
                }
            }
        }
    }
}

struct WatchMeetingInfo: Identifiable {
    let id: String
    let title: String
    let date: Date
    let status: String

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let dateInterval = dict["date"] as? TimeInterval,
              let status = dict["status"] as? String else { return nil }
        self.id = id
        self.title = title
        self.date = Date(timeIntervalSince1970: dateInterval)
        self.status = status
    }
}
