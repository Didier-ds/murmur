import AppKit

/// The ring-and-bars logo in the menu bar. Left click toggles dictation, right click opens the menu.
@MainActor
final class StatusItemController: NSObject {
    enum Look { case idle, recording, busy, error }

    static let ember = NSColor(srgbRed: 1, green: 0.353, blue: 0.235, alpha: 1)

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onToggle: () -> Void
    private let makeMenu: () -> NSMenu
    private let level: () -> Float
    private var timer: Timer?
    private var phase: CGFloat = 0

    var button: NSStatusBarButton? { item.button }

    var look: Look = .idle {
        didSet { lookChanged() }
    }

    init(onToggle: @escaping () -> Void, makeMenu: @escaping () -> NSMenu, level: @escaping () -> Float) {
        self.onToggle = onToggle
        self.makeMenu = makeMenu
        self.level = level
        super.init()
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Murmur — click to dictate"
        redraw()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            item.menu = makeMenu()
            item.button?.performClick(nil) // opens the menu and blocks until it closes
            item.menu = nil
        } else {
            onToggle()
        }
    }

    private func lookChanged() {
        timer?.invalidate()
        timer = nil
        if look == .recording || look == .busy {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.phase += 0.35
                    self.redraw()
                }
            }
        }
        redraw()
    }

    private func redraw() {
        item.button?.image = Self.icon(look: look, level: CGFloat(level()), phase: phase)
    }

    private static func icon(look: Look, level: CGFloat, phase: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let color: NSColor = switch look {
            case .recording: ember
            case .error: .systemOrange
            default: .black
            }
            color.setStroke()
            color.setFill()

            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.6
            let ring = NSBezierPath()
            ring.lineWidth = 1.6
            if look == .busy {
                // A short arc chasing around the ring while we finalize.
                let start = -phase * 40
                ring.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start + 110)
            } else {
                ring.appendOval(in: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            ring.stroke()

            // Three bars; while recording they follow the microphone level.
            let base: [CGFloat] = [4.5, 8.5, 4.5]
            for (i, h) in base.enumerated() {
                var height = h
                if look == .recording {
                    let wobble = 0.75 + 0.25 * sin(phase * (1.3 + CGFloat(i) * 0.7))
                    height = max(2.2, h * (0.35 + level * 1.1) * wobble)
                }
                let x = center.x - 4 + CGFloat(i) * 3.2
                NSBezierPath(roundedRect: NSRect(x: x, y: center.y - height / 2, width: 1.8, height: height), xRadius: 0.9, yRadius: 0.9).fill()
            }
            return true
        }
        // Template images adapt to light/dark menu bars; the recording state keeps its ember color.
        image.isTemplate = look != .recording && look != .error
        return image
    }
}
