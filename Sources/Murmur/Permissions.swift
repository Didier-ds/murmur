import AppKit
import ApplicationServices
import AVFoundation
import Speech

@MainActor
enum Permissions {
    static var microphoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    static var speechGranted: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static func requestSpeech() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await requestSpeechAuthorization() == .authorized
    }

    /// Nonisolated so the callback (delivered on a background queue) isn't assumed to be on the main actor.
    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    /// Needed both to write into other apps' text fields and to post ⌘V.
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func promptAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
