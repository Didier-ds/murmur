@preconcurrency import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable
    case unsupportedLocale
    case noAudioFormat

    var errorDescription: String? {
        switch self {
        case .unavailable: "On-device speech isn't available on this Mac."
        case .unsupportedLocale: "Your language isn't supported by the on-device model."
        case .noAudioFormat: "Couldn't find a compatible audio format."
        }
    }
}

enum SpeechSetup {
    /// Picks the closest supported locale to the user's own, falling back to US English.
    static func resolveLocale() async throws -> Locale {
        guard SpeechTranscriber.isAvailable else { throw SpeechError.unavailable }
        if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) { return locale }
        if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) { return locale }
        throw SpeechError.unsupportedLocale
    }

    /// Downloads the on-device model the first time. No-op once installed.
    static func ensureAssets(for locale: Locale) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
}

/// One dictation: microphone → format conversion → SpeechAnalyzer → text.
/// Not actor-isolated on purpose: the audio tap runs on a realtime audio thread.
final class SpeechSession: @unchecked Sendable {
    typealias UpdateHandler = @Sendable (_ finalized: String, _ volatile: String) -> Void
    typealias LevelHandler = @Sendable (Float) -> Void

    private let engine = AVAudioEngine()
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let results: Task<String, Error>

    private init(analyzer: SpeechAnalyzer, input: AsyncStream<AnalyzerInput>.Continuation, results: Task<String, Error>) {
        self.analyzer = analyzer
        self.input = input
        self.results = results
    }

    static func start(locale: Locale, onUpdate: @escaping UpdateHandler, onLevel: @escaping LevelHandler) async throws -> SpeechSession {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechError.noAudioFormat
        }

        let results = Task<String, Error> {
            var finalized = ""
            var volatile = ""
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    finalized += text
                    volatile = ""
                } else {
                    volatile = text
                }
                onUpdate(finalized, volatile)
            }
            return finalized + volatile
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let session = SpeechSession(analyzer: analyzer, input: continuation, results: results)
        try await analyzer.start(inputSequence: stream)
        do {
            try session.startMicrophone(converting: format, onLevel: onLevel)
        } catch {
            await session.cancel()
            throw error
        }
        return session
    }

    private func startMicrophone(converting outFormat: AVAudioFormat, onLevel: @escaping LevelHandler) throws {
        let node = engine.inputNode
        let inFormat = node.outputFormat(forBus: 0)
        let converter = Converter(from: inFormat, to: outFormat)
        let input = self.input

        node.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { buffer, _ in
            onLevel(Self.level(of: buffer))
            if let converted = converter.convert(buffer) {
                input.yield(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
    }

    /// Stops listening and waits for the model to finalize the last words.
    func finish() async throws -> String {
        stopMicrophone()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await results.value
    }

    func cancel() async {
        stopMicrophone()
        await analyzer.cancelAndFinishNow()
        results.cancel()
    }

    private func stopMicrophone() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        input.finish()
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // Map roughly -50 dB...-10 dB onto 0...1.
        let db = 20 * log10(max(rms, 1e-6))
        return min(max((db + 50) / 40, 0), 1)
    }
}

/// Wraps AVAudioConverter for use from the audio thread.
private final class Converter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let outFormat: AVAudioFormat
    private let ratio: Double

    init(from inFormat: AVAudioFormat, to outFormat: AVAudioFormat) {
        self.outFormat = outFormat
        self.ratio = outFormat.sampleRate / inFormat.sampleRate
        self.converter = inFormat == outFormat ? nil : AVAudioConverter(from: inFormat, to: outFormat)
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return nil }
        // The input block runs synchronously inside convert(), so these are never shared across threads.
        nonisolated(unsafe) var consumed = false
        nonisolated(unsafe) let buffer = buffer
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}
