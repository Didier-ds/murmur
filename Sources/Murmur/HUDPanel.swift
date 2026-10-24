import AppKit
import SwiftUI

/// Floating "dark mirror" capsule under the menu bar icon.
/// Non-activating and click-through, so it never steals focus from the text field.
@MainActor
final class HUDController {
    private static let size = NSSize(width: 400, height: 210)
    private let panel: NSPanel

    init(model: DictationModel) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(model: model).environment(\.colorScheme, .dark))
    }

    func show(below button: NSStatusBarButton?) {
        if let buttonFrame = button?.window?.frame, let screen = button?.window?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            var x = buttonFrame.midX - Self.size.width / 2
            x = min(max(x, visible.minX + 8), visible.maxX - Self.size.width - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: buttonFrame.minY - Self.size.height - 2))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }
}

// MARK: - Views

private let ember = Color(red: 1, green: 0.353, blue: 0.235)
private let ice = Color(red: 0.81, green: 0.9, blue: 1)

struct HUDView: View {
    let model: DictationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            WaveformView(model: model)
                .frame(height: 40)
            transcript
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 360, alignment: .leading)
        .background(DarkMirror(cornerRadius: 26))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 14)
        .frame(width: 400, height: 210, alignment: .top)
        .padding(.top, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ember)
                .frame(width: 7, height: 7)
                .shadow(color: ember, radius: 4)
                .phaseAnimator([1.0, 0.35]) { dot, opacity in dot.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.7) }
            Text(model.label.uppercased())
                .tracking(1.5)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(context.date.timeIntervalSince(model.startedAt)))
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .monospacedDigit()
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.45))
    }

    private var transcript: some View {
        let silver = LinearGradient(colors: [.white, Color(white: 0.74)], startPoint: .top, endPoint: .bottom)
        let finalized = Text(model.finalized).foregroundStyle(silver)
        let volatile = Text(model.volatile).foregroundStyle(.white.opacity(0.32))
        let placeholder = Text("Start speaking…").foregroundStyle(.white.opacity(0.25))
        return Group {
            if model.finalized.isEmpty && model.volatile.isEmpty { placeholder } else { Text("\(finalized)\(volatile)") }
        }
        .font(.system(size: 14.5))
        .lineSpacing(2)
        .lineLimit(4)
        .truncationMode(.head) // keep the newest words visible
        .frame(maxWidth: .infinity, minHeight: 21, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text("→ \(model.targetName)")
            Spacer()
            Text("esc to cancel · click ◎ to finish")
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.38))
        .padding(.top, 6)
    }
}

/// Black glass with a chrome rim and a slow specular sweep.
struct DarkMirror: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(LinearGradient(colors: [Color(white: 0.11).opacity(0.78), Color(white: 0.03).opacity(0.9)], startPoint: .top, endPoint: .bottom))
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 7) / 7
                let x = t < 0.6 ? -1.0 : -1.0 + (t - 0.6) / 0.4 * 3.0 // rest, then sweep
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.07), location: 0.45), .init(color: .clear, location: 0.55)],
                    startPoint: UnitPoint(x: x, y: 0),
                    endPoint: UnitPoint(x: x + 1, y: 1)
                )
            }
            .clipShape(shape)
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.38), location: 0),
                        .init(color: .white.opacity(0.05), location: 0.35),
                        .init(color: .white.opacity(0.02), location: 0.65),
                        .init(color: .white.opacity(0.18), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
    }
}

/// Liquid-mercury waveform: three glowing sine layers driven by the mic level.
struct WaveformView: View {
    let model: DictationModel

    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 3.6
            let level = CGFloat(model.level)
            Canvas { gc, size in
                let layers: [(amp: CGFloat, freq: CGFloat, color: Color, width: CGFloat)] = [
                    (0.9, 1.0, .white.opacity(0.95), 2.0),
                    (0.6, 1.7, ice.opacity(0.45), 1.5),
                    (0.4, 2.6, ember.opacity(0.55), 1.3),
                ]
                let mid = size.height / 2
                for layer in layers {
                    var path = Path()
                    for step in 0...90 {
                        let n = CGFloat(step) / 90
                        let envelope = pow(sin(.pi * n), 2)
                        let y = mid
                            + sin(n * .pi * 4 * layer.freq + phase * layer.freq) * envelope * layer.amp * max(level, 0.04) * size.height * 0.45
                            + sin(n * 40 + phase * 3) * level * 1.5
                        let point = CGPoint(x: n * size.width, y: y)
                        step == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                    let fade = Gradient(stops: [.init(color: .clear, location: 0), .init(color: layer.color, location: 0.5), .init(color: .clear, location: 1)])
                    var glow = gc
                    glow.addFilter(.shadow(color: layer.color, radius: 4))
                    glow.stroke(path, with: .linearGradient(fade, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: layer.width)
                }
            }
        }
    }
}
