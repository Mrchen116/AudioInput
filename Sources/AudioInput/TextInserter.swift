import AppKit
import ApplicationServices
import Foundation

final class TextInserter {
    func paste(_ text: String, keepClipboard: Bool) {
        let pasteboard = NSPasteboard.general
        let oldValue = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        if !keepClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pasteboard.clearContents()
                if let oldValue {
                    pasteboard.setString(oldValue, forType: .string)
                }
            }
        }
    }
}
