import AppKit
import CoreGraphics

/// Catches a plain Esc press system-wide while dictation is active.
///
/// Murmur is never the active app, so Esc goes to whatever app the user is typing in.
/// An event tap lets us see it first and swallow it, so finishing dictation doesn't
/// also dismiss a dialog or clear a field in that app. Requires Accessibility permission;
/// without a tap we fall back to a global monitor, which sees Esc but can't swallow it.
@MainActor
final class EscapeKeyMonitor {
    private static let escapeKeyCode: Int64 = 53

    private let onEscape: () -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fallbackMonitor: Any?
    private var swallowingKeyUp = false

    init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    func start() {
        guard tap == nil, fallbackMonitor == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: escapeTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.tap = tap
            self.runLoopSource = source
        } else {
            fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard Int64(event.keyCode) == Self.escapeKeyCode, !Self.hasModifiers(event.modifierFlags) else { return }
                MainActor.assumeIsolated { self?.onEscape() }
            }
        }
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        runLoopSource = nil
        if let fallbackMonitor { NSEvent.removeMonitor(fallbackMonitor) }
        fallbackMonitor = nil
        swallowingKeyUp = false
    }

    /// Returns true if the event should be swallowed.
    fileprivate func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown:
            guard keyCode == Self.escapeKeyCode,
                  !Self.hasModifiers(NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))) else { return false }
            swallowingKeyUp = true
            // Finishing tears down this tap; don't do that from inside its own callback.
            Task { [weak self] in self?.onEscape() }
            return true
        case .keyUp:
            guard swallowingKeyUp, keyCode == Self.escapeKeyCode else { return false }
            swallowingKeyUp = false
            return true
        default:
            return false
        }
    }

    private static func hasModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.intersection([.command, .option, .control, .shift]).isEmpty
    }
}

/// C callback for the event tap. The tap's run loop source is on the main run loop,
/// so this always runs on the main thread.
private func escapeTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<EscapeKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    let swallow = MainActor.assumeIsolated { monitor.handle(type: type, keyCode: keyCode, flags: flags) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
