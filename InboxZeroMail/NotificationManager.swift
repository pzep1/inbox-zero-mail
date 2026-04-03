import AppKit
import MailCore
import MailFeatures
import UserNotifications

/// Manages macOS notifications for new mail and dock badge count.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var isAuthorized = false
    private var knownUnreadThreadIDs: Set<MailThreadID> = []
    private var hasPrimedUnreadBaseline = false

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
            }
        }
    }

    func handleReload(reason: MailReloadReason, threads: [MailThread]) {
        let unreadThreads = threads.filter(\.hasUnread)
        let unreadIDs = Set(unreadThreads.map(\.id))
        updateBadge(count: unreadThreads.count)

        guard hasPrimedUnreadBaseline else {
            knownUnreadThreadIDs = unreadIDs
            hasPrimedUnreadBaseline = true
            return
        }

        let newUnread = unreadThreads.filter { knownUnreadThreadIDs.contains($0.id) == false }
        knownUnreadThreadIDs = unreadIDs

        guard reason == .workspaceChange, isAuthorized else { return }

        for thread in newUnread.prefix(3) {
            scheduleNotification(for: thread)
        }
    }

    /// Update dock badge to reflect current unread count.
    func updateBadge(count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    // MARK: - Private

    private func scheduleNotification(for thread: MailThread) {
        let content = UNMutableNotificationContent()
        content.title = thread.participantSummary
        content.subtitle = thread.subject
        content.body = thread.snippet
        content.sound = .default
        content.userInfo = ["threadID": thread.id.rawValue]

        let request = UNNotificationRequest(
            identifier: "newmail-\(thread.id.rawValue)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification click — posted as a Notification so the app can open the thread.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let threadID = response.notification.request.content.userInfo["threadID"] as? String
        if let threadID {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .openThreadFromNotification,
                    object: nil,
                    userInfo: ["threadID": threadID]
                )
            }
        }
        completionHandler()
    }

    /// Show notifications even when app is in foreground (banner style).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let openThreadFromNotification = Notification.Name("openThreadFromNotification")
}
