import AppKit
import os

/// The only piece that knows about everything else: idle → starting → recording → finalizing → idle.
@MainActor
final class DictationCoordinator {
    enum State { case idle, starting, recording, finalizing }
    enum Setup: Equatable { case checking, downloading, ready, failed(String) }

    private let log = Logger(subsystem: "dev.murmur.Murmur", category: "dictation")
    private let model = DictationModel()
    private let inserter = InsertionService()
    private lazy var hud = HUDController(model: model)
    private lazy var statusItem = StatusItemController(
        onToggle: { [weak self] in self?.toggle() },
        makeMenu: { [weak self] in self?.makeMenu() ?? NSMenu() },
        level: { [weak self] in self?.model.level ?? 0 }
    )
    // Esc finishes dictation and inserts the text, like clicking the ring again.
    private lazy var escapeMonitor = EscapeKeyMonitor(onEscape: { [weak self] in self?.toggle() })

    private var state = State.idle
    private var setup = Setup.checking
    private var locale: Locale?
    private var session: SpeechSession?
    private var target: FocusTarget?
    private var lastMessage: String?
    private var lastTranscript: String?
    /// Esc or a click arrived while the microphone was still starting up.
    private var stopRequested = false

    private var playSounds: Bool {
        get { UserDefaults.standard.object(forKey: "playSounds") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "playSounds") }
    }

    // MARK: Launch

    func bootstrap() async {
        _ = statusItem
        log.notice("Accessibility trusted: \(Permissions.accessibilityGranted, privacy: .public)")
        // Download the voice model while the user answers the permission prompts.
        async let model: Void = prepareModel()
        _ = await Permissions.requestMicrophone()
        _ = await Permissions.requestSpeech()
        if !Permissions.accessibilityGranted { Permissions.promptAccessibility() }
        await model
    }

    private func prepareModel() async {
        do {
            setup = .checking
            let locale = try await SpeechSetup.resolveLocale()
            self.locale = locale
            setup = .downloading
            try await SpeechSetup.ensureAssets(for: locale)
            setup = .ready
            log.info("Speech model ready for \(locale.identifier, privacy: .public)")
        } catch {
            setup = .failed(error.localizedDescription)
            log.error("Model setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Toggle

    func toggle() {
        switch state {
        case .idle: Task { await start() }
        case .recording: Task { await stop() }
        case .starting: stopRequested = true // finish as soon as recording has started
        case .finalizing: break
        }
    }

    private func start() async {
        guard setup == .ready, let locale else {
            flashError(setupMessage)
            return
        }
        guard await Permissions.requestMicrophone() else {
            flashError("Microphone access is off. Enable it in System Settings → Privacy & Security.")
            Permissions.openSettings("Privacy_Microphone")
            return
        }

        state = .starting
        stopRequested = false
        let target = FocusTarget.capture()
        self.target = target
        model.reset(targetName: target.appName)

        // Listen for Esc right away, so a quick Esc during startup isn't sent to the focused app.
        let escMode = escapeMonitor.start()
        log.notice("Esc listener: \(escMode.rawValue, privacy: .public), secure input: \(EscapeKeyMonitor.secureInputActive, privacy: .public)")
        switch escMode {
        case .unavailable: model.notice = "Esc needs Accessibility access · click ◎ to finish"
        case .intercepting, .observing:
            if EscapeKeyMonitor.secureInputActive { model.notice = "Esc is blocked by a secure input field · click ◎ to finish" }
        }

        do {
            let model = self.model
            session = try await SpeechSession.start(
                locale: locale,
                onUpdate: { finalized, volatile in
                    Task { @MainActor in
                        model.finalized = finalized
                        model.volatile = volatile
                    }
                },
                onLevel: { level in
                    Task { @MainActor in model.push(level: level) }
                }
            )
            state = .recording
            statusItem.look = .recording
            hud.show(below: statusItem.button)
            if playSounds { NSSound(named: "Tink")?.play() }
            if stopRequested { await stop() }
        } catch {
            escapeMonitor.stop()
            state = .idle
            flashError("Couldn't start listening: \(error.localizedDescription)")
        }
    }

    private func stop() async {
        guard let session, let target else { return }
        escapeMonitor.stop()
        state = .finalizing
        statusItem.look = .busy
        model.label = "Sealing"

        let text: String
        do {
            text = try await session.finish()
        } catch {
            log.error("Finalize failed: \(error.localizedDescription, privacy: .public)")
            text = model.finalized + model.volatile
        }
        self.session = nil
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lastTranscript = text }

        let outcome = await inserter.insert(text, into: target)
        log.info("Dictation of \(text.count) chars: \(String(describing: outcome), privacy: .public)")
        state = .idle

        switch outcome {
        case .copiedNoField:
            // Nothing to type into: keep the capsule up briefly so the user knows where the text went.
            lastMessage = nil
            statusItem.look = .idle
            showNotice("No text field focused — copied. Click a field and press ⌘V.")
        case .copiedNoPermission:
            showNotice("Copied — press ⌘V. Murmur needs Accessibility to type for you.")
            flashError("Copied to clipboard — press ⌘V. Murmur needs Accessibility access to type for you.")
            Permissions.promptAccessibility()
        case .typed, .pasted, nil:
            hud.hide()
            lastMessage = nil
            if playSounds && outcome != nil { NSSound(named: "Pop")?.play() }
            statusItem.look = .idle
        }
    }

    private func showNotice(_ notice: String) {
        model.label = "Copied"
        model.notice = notice
        if playSounds { NSSound(named: "Pop")?.play() }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if state == .idle { hud.hide() }
        }
    }

    /// Throw the dictation away without inserting anything (menu → Cancel Dictation).
    func cancel() {
        guard state == .recording, let session else { return }
        escapeMonitor.stop()
        self.session = nil
        target = nil
        state = .idle
        statusItem.look = .idle
        hud.hide()
        log.info("Dictation cancelled")
        Task { await session.cancel() }
    }

    private func flashError(_ message: String) {
        lastMessage = message
        log.error("\(message, privacy: .public)")
        NSSound.beep()
        statusItem.look = .error
        Task {
            try? await Task.sleep(for: .seconds(2))
            if state == .idle { statusItem.look = .idle }
        }
    }

    // MARK: Menu

    private var setupMessage: String {
        switch setup {
        case .checking: "Preparing the voice model…"
        case .downloading: "Downloading the on-device voice model…"
        case .ready: "Ready · \(locale.map { Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier } ?? "")"
        case .failed(let reason): "Voice model unavailable: \(reason)"
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(disabled(setupMessage))
        if let lastMessage { menu.addItem(disabled(lastMessage)) }
        menu.addItem(.separator())

        menu.addItem(action(state == .recording ? "Stop Dictation" : "Start Dictation") { [weak self] in self?.toggle() })
        if state == .recording {
            menu.addItem(action("Cancel Dictation") { [weak self] in self?.cancel() })
        }
        if let lastTranscript {
            menu.addItem(action("Copy Last Dictation") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lastTranscript, forType: .string)
            })
        }

        if !Permissions.microphoneGranted {
            menu.addItem(action("Grant Microphone Access…") { Permissions.openSettings("Privacy_Microphone") })
        }
        if !Permissions.accessibilityGranted {
            menu.addItem(action("Grant Accessibility Access…") {
                Permissions.promptAccessibility()
                Permissions.openSettings("Privacy_Accessibility")
            })
        }
        if case .failed = setup {
            menu.addItem(action("Retry Voice Model Download") { [weak self] in Task { await self?.prepareModel() } })
        }

        menu.addItem(.separator())
        let sounds = action("Play Sounds") { [weak self] in self?.playSounds.toggle() }
        sounds.state = playSounds ? .on : .off
        menu.addItem(sounds)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Murmur", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ handler: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuAction.run), keyEquivalent: "")
        let target = MenuAction(handler)
        item.target = target
        item.representedObject = target // keep it alive as long as the item
        return item
    }
}

@MainActor
private final class MenuAction: NSObject {
    let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }
    @objc func run() { handler() }
}
