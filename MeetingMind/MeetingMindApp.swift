import SwiftUI
import SwiftData
import UIKit

/// Shared state for propagating quick-record shortcut activation from the app delegate to the UI.
@MainActor
@Observable
final class AppState {
    var shouldStartRecording = false
    var deepLinkMeetingId: UUID?
}

/// Global app state instance, accessible from delegates and views.
@MainActor
let appState = AppState()

/// App delegate that handles home screen quick action shortcuts.
final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {
    static let quickRecordActionType = "com.meetingmind.app.quick-record"

    /// Called when the app is launched via a shortcut item (cold launch).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem,
           shortcutItem.type == Self.quickRecordActionType {
            Task { @MainActor in
                appState.shouldStartRecording = true
            }
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Scene delegate that handles shortcut items when the app is already running (warm launch).
final class SceneDelegate: NSObject, UIWindowSceneDelegate, @unchecked Sendable {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let actionType = shortcutItem.type
        Task { @MainActor in
            if actionType == AppDelegate.quickRecordActionType {
                appState.shouldStartRecording = true
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
}

@main
struct MeetingMindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Meeting.self, ActionItem.self, MeetingSeries.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(container)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "meetingmind",
              url.host == "meeting",
              let idString = url.pathComponents.dropFirst().first,
              let meetingId = UUID(uuidString: idString) else {
            return
        }
        appState.deepLinkMeetingId = meetingId
    }
}
