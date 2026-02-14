import Foundation
import UserNotifications

final class Notifier {
    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    func requestAuthorization() {
        guard canUseUserNotifications else {
            emit("Notifications disabled: not running from an app bundle")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String) {
        if !canUseUserNotifications {
            emit("\(title): \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func emit(_ message: String) {
        AppLogger.log.info("\(message)")
        fputs("[AudioInput] \(message)\n", stderr)
    }
}
