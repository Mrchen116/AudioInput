import ApplicationServices
import Foundation

final class HotkeyMonitor {
    var onRightCommandDown: (() -> Void)?
    var onRightCommandUp: (() -> Void)?
    var onEscDown: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRightCmdDown = false

    private static let rightCommandKeyCode: CGKeyCode = 54
    private static let escapeKeyCode: CGKeyCode = 53

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let events = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handle(eventType: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(events),
            callback: callback,
            userInfo: selfPtr
        ) else {
            AppLogger.log.error("Failed to create CGEvent tap. Enable Accessibility/Input Monitoring permissions.")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        guard let tap = eventTap, let source = runLoopSource else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        eventTap = nil
        runLoopSource = nil
        isRightCmdDown = false
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        if eventType == .flagsChanged {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            guard keyCode == Self.rightCommandKeyCode else { return }

            let currentlyDown = event.flags.contains(.maskCommand)

            if currentlyDown && !isRightCmdDown {
                isRightCmdDown = true
                fputs("[AudioInput] Hotkey: Right Command down\n", stderr)
                onRightCommandDown?()
            } else if !currentlyDown && isRightCmdDown {
                isRightCmdDown = false
                fputs("[AudioInput] Hotkey: Right Command up\n", stderr)
                onRightCommandUp?()
            }
        }

        if eventType == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == Self.escapeKeyCode {
                fputs("[AudioInput] Hotkey: ESC down\n", stderr)
                onEscDown?()
            }
        }
    }
}
