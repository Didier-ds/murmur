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

/// Inserts text at the cursor: Accessibility first, clipboard + ⌘V as fallback.
@MainActor
final class InsertionService {
    enum Method: String { case accessibility, paste }

    func insert(_ raw: String, into target: FocusTarget) async -> Method? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // If the user switched apps mid-dictation, go back to where they started.
        if let app = target.app, NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
            app.activate()
            try? await Task.sleep(for: .milliseconds(200))
        }

        if let element = target.element, insertViaAccessibility(text, into: element) {
            return .accessibility
        }
        await paste(text)
        return .paste
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

    private func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let saved: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChange = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        // Give the target app time to read the clipboard, then put the user's back.
        try? await Task.sleep(for: .milliseconds(450))
        guard pasteboard.changeCount == ourChange else { return }
        pasteboard.clearContents()
        let items = saved.map { entries in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
