import AppKit
import Foundation

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")

    private let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ",")
    private let selfCheckItem = NSMenuItem(title: "Self Check", action: #selector(handleSelfCheck), keyEquivalent: "")

    var onQuit: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onSelfCheck: (() -> Void)?

    override init() {
        super.init()

        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        settingsItem.target = self
        selfCheckItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(selfCheckItem)
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

    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }

    @objc private func handleSelfCheck() {
        onSelfCheck?()
    }

    @objc private func handleQuit() {
        onQuit?()
    }
}
