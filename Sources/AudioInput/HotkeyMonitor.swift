import ApplicationServices
import Foundation
import IOKit.hid

final class HotkeyMonitor {
    var onRightCommandDown: (() -> Void)?
    var onRightCommandUp: (() -> Void)?
    var onEscDown: (() -> Void)?

    private var hidManager: IOHIDManager?
    private var isCommandDown = false
    private var activeUsage: UInt32?

    private(set) var hotkeySide: HotkeySide = .right

    private static let keyboardUsagePage: UInt32 = 0x07
    private static let escapeUsage: UInt32 = 0x29
    private static let leftCommandUsage: UInt32 = 0xE3
    private static let rightCommandUsage: UInt32 = 0xE7

    func setHotkeySide(_ side: HotkeySide) {
        hotkeySide = side
        isCommandDown = false
        activeUsage = nil
        fputs("[AudioInput] Hotkey side set to: \(side.rawValue)\n", stderr)
    }

    @discardableResult
    func start() -> Bool {
        guard hidManager == nil else { return true }

        guard PermissionHelper.hasInputMonitoringAccess() else {
            AppLogger.log.error("Input Monitoring permission is required for keyboard HID events.")
            return false
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard,
        ] as CFDictionary

        IOHIDManagerSetDeviceMatching(manager, matching)

        let callback: IOHIDValueCallback = { context, _, _, value in
            guard let context else { return }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handle(value: value)
        }
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterInputValueCallback(manager, callback, selfPtr)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            AppLogger.log.error("Failed to open IOHIDManager: \(result)")
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return false
        }

        hidManager = manager
        return true
    }

    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        hidManager = nil
        isCommandDown = false
        activeUsage = nil
    }

    private func handle(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        guard usagePage == Self.keyboardUsagePage else { return }

        let usage = IOHIDElementGetUsage(element)
        let isPressed = IOHIDValueGetIntegerValue(value) != 0

        if usage == Self.escapeUsage && isPressed {
            fputs("[AudioInput] Hotkey: ESC down\n", stderr)
            onEscDown?()
            return
        }

        guard isAllowedCommandUsage(usage) else { return }

        let keyName = usage == Self.rightCommandUsage ? "Right" : "Left"
        if isPressed && !isCommandDown {
            isCommandDown = true
            activeUsage = usage
            fputs("[AudioInput] Hotkey: \(keyName) Command down\n", stderr)
            onRightCommandDown?()
        } else if !isPressed && isCommandDown && activeUsage == usage {
            isCommandDown = false
            activeUsage = nil
            fputs("[AudioInput] Hotkey: \(keyName) Command up\n", stderr)
            onRightCommandUp?()
        }
    }

    private func isAllowedCommandUsage(_ usage: UInt32) -> Bool {
        switch hotkeySide {
        case .right:
            return usage == Self.rightCommandUsage
        case .left:
            return usage == Self.leftCommandUsage
        case .both:
            return usage == Self.rightCommandUsage || usage == Self.leftCommandUsage
        }
    }
}
