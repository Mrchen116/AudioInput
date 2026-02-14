import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static func apply(enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            AppLogger.log.info("Launch at login requires macOS 13+")
            return
        }

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            AppLogger.log.error("Launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
