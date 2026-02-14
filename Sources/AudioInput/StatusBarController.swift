import AppKit
import Foundation

final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")

    var onQuit: (() -> Void)?

    init() {
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = "AI"
    }

    func update(state: InputState) {
        let stateLabel: String
        switch state {
        case .idle:
            stateItem.title = "Status: Idle"
            statusItem.button?.title = "AI"
            stateLabel = "Idle"
        case .recording:
            stateItem.title = "Status: Recording"
            statusItem.button?.title = "REC"
            stateLabel = "Recording"
        case .transcribing:
            stateItem.title = "Status: Transcribing"
            statusItem.button?.title = "ASR"
            stateLabel = "Transcribing"
        case .inserting:
            stateItem.title = "Status: Inserting"
            statusItem.button?.title = "PUT"
            stateLabel = "Inserting"
        case .error(let message):
            stateItem.title = "Status: Error (\(message))"
            statusItem.button?.title = "ERR"
            stateLabel = "Error(\(message))"
        }
        fputs("[AudioInput] State: \(stateLabel)\n", stderr)
    }

    @objc private func handleQuit() {
        onQuit?()
    }
}
