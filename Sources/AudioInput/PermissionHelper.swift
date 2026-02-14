import AVFoundation
import ApplicationServices
import Foundation

enum PermissionHelper {
    static func requestAccessibilityTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func hasAccessibilityTrust() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                AppLogger.log.info("Microphone permission granted")
            } else {
                AppLogger.log.error("Microphone permission denied")
            }
        }
    }
}
