import AppKit
import ApplicationServices

/// Where the user was typing when dictation started.
struct FocusTarget {
    let app: NSRunningApplication?
    let element: AXUIElement?

    var appName: String { app?.localizedName ?? "the focused app" }

    /// Clicking a menu bar item doesn't activate our app, so the frontmost app
    /// and its focused element are still the ones the user was typing into.
    @MainActor
    static func capture() -> FocusTarget {
        let app = NSWorkspace.shared.frontmostApplication
        var element: AXUIElement?
        if let app {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, "AXFocusedUIElement" as CFString, &value) == .success,
               let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                element = (value as! AXUIElement)
            }
        }
        return FocusTarget(app: app, element: element)
    }
}

/// Inserts text at the cursor: Accessibility first, then ⌘V. Whenever insertion
/// can't be confirmed, the text is left on the clipboard so it's never lost.
@MainActor
final class InsertionService {
    enum Outcome: Equatable {
        /// Written straight into the field and confirmed.
        case typed
        /// Pasted with ⌘V; also left on the clipboard in case nothing took it.
        case pasted
        /// Focus wasn't on a text input, so we only copied it.
        case copiedNoField
        /// Without Accessibility we can't type or paste, so we only copied it.
        case copiedNoPermission
    }

    func insert(_ raw: String, into target: FocusTarget) async -> Outcome? {
        let text = Self.sanitize(raw)
        guard !text.isEmpty else { return nil }

        // Without Accessibility, macOS silently drops both AX writes and the simulated ⌘V.
        guard Permissions.accessibilityGranted else {
            copy(text)
            return .copiedNoPermission
        }

        // If the user switched apps mid-dictation, go back to where they started.
        if let app = target.app, !isFrontmost(app) {
            app.activate()
            try? await Task.sleep(for: .milliseconds(200))
        }

        if let element = target.element {
            if insertViaAccessibility(text, into: element) { return .typed }
            if isClearlyNotTextInput(element) {
                copy(text)
                return .copiedNoField
            }
        }
        // A simulated ⌘V goes to whichever app is frontmost. If that isn't the app the user was
        // dictating into (it quit, or focus moved), don't paste anywhere: just copy.
        if let app = target.app, !isFrontmost(app) {
            copy(text)
            return .copiedNoField
        }
        // No element (browsers and Electron often hide it) or an unconfirmed write: paste,
        // and keep the text on the clipboard either way.
        await paste(text)
        return .pasted
    }

    private func isFrontmost(_ app: NSRunningApplication) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }

    /// Makes a transcript safe to type into any app.
    /// Line breaks and other control characters become spaces, so text pasted into a terminal
    /// can never press Return and run a command. Bidirectional override characters are removed,
    /// since they can make text display differently from what it actually contains.
    nonisolated static func sanitize(_ raw: String) -> String {
        let bidiControls: [ClosedRange<UInt32>] = [0x202A...0x202E, 0x2066...0x2069]
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            if bidiControls.contains(where: { $0.contains(scalar.value) }) { continue }
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) {
                scalars.append(" ")
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    // MARK: Accessibility

    /// Many apps (browsers, Electron) report success without inserting anything,
    /// so we read the value back to confirm before trusting it.
    private func insertViaAccessibility(_ text: String, into element: AXUIElement) -> Bool {
        guard let before = stringValue(element, "AXValue") else { return false }

        var insertion = text
        if let range = selectedRange(element), range.location > 0, range.location <= (before as NSString).length {
            let previous = (before as NSString).substring(with: NSRange(location: range.location - 1, length: 1))
            if previous.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { insertion = " " + insertion }
        }

        guard AXUIElementSetAttributeValue(element, "AXSelectedText" as CFString, insertion as CFString) == .success else {
            return false
        }
        guard let after = stringValue(element, "AXValue") else { return false }
        return after != before
    }

    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    /// Roles that can hold an editable web field we can't see into; never treat these as "no field".
    private static let ambiguousRoles: Set<String> = ["AXWebArea", "AXGroup", "AXUnknown"]

    /// True only when we're confident focus is on something you can't type into
    /// (a list, button, Finder window...). When unsure, we prefer to try pasting.
    private func isClearlyNotTextInput(_ element: AXUIElement) -> Bool {
        let role = stringValue(element, "AXRole") ?? "AXUnknown"
        if Self.textRoles.contains(role) || Self.ambiguousRoles.contains(role) { return false }
        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(element, "AXSelectedText" as CFString, &settable) == .success, settable.boolValue {
            return false
        }
        return true
    }

    private func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func selectedRange(_ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSelectedTextRange" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    // MARK: Paste fallback

    /// Puts text on the clipboard without Universal Clipboard syncing it to other devices,
    /// and marks it transient (nspasteboard.org convention) so clipboard-history apps skip it.
    /// It stays pasteable with ⌘V as usual.
    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"))
        pasteboard.writeObjects([item])
    }

    private func paste(_ text: String) async {
        copy(text)
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        // Let the target app read the clipboard before anything else touches it.
        try? await Task.sleep(for: .milliseconds(150))
    }
}
