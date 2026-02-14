import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let config = try AppConfig.load()
            let controller = AppController(
                config: config,
                recorder: AudioRecorder(),
                asrClient: VolcASRClient(config: config),
                inserter: TextInserter(),
                monitor: HotkeyMonitor(),
                statusBar: StatusBarController(),
                notifier: Notifier()
            )
            self.controller = controller
            controller.start()
        } catch {
            AppLogger.log.error("Startup failed: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }
    }
}

@main
struct AudioInputApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
