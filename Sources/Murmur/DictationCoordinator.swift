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

    private var state = State.idle
    private var setup = Setup.checking
    private var locale: Locale?
    private var session: SpeechSession?
    private var target: FocusTarget?
    private var lastMessage: String?

    private var playSounds: Bool {
        get { UserDefaults.standard.object(forKey: "playSounds") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "playSounds") }
    }

    // MARK: Launch

    func bootstrap() async {
        _ = statusItem
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
        case .starting, .finalizing: break
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
        let target = FocusTarget.capture()
        self.target = target
        model.reset(targetName: target.appName)

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
        } catch {
            state = .idle
            flashError("Couldn't start listening: \(error.localizedDescription)")
        }
    }

    private func stop() async {
        guard let session, let target else { return }
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
        hud.hide()

        let method = await inserter.insert(text, into: target)
        log.info("Inserted \(text.count) chars via \(method?.rawValue ?? "nothing", privacy: .public)")
        if method == .paste && !Permissions.accessibilityGranted {
            lastMessage = "Text is on your clipboard. Grant Accessibility so Murmur can type it for you."
        } else {
            lastMessage = nil
        }
        if playSounds && method != nil { NSSound(named: "Pop")?.play() }

        state = .idle
        statusItem.look = .idle
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
