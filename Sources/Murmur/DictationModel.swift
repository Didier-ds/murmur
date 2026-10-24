import Foundation
import Observation

/// Live state shared by the menu bar icon and the HUD capsule.
@MainActor
@Observable
final class DictationModel {
    var finalized = ""
    var volatile = ""
    var label = "Listening"
    var targetName = ""
    /// Replaces the footer hint after dictation, e.g. when text was only copied.
    var notice: String?
    var startedAt = Date()
    /// Smoothed microphone level, 0...1.
    var level: Float = 0

    func reset(targetName: String) {
        finalized = ""
        volatile = ""
        label = "Listening"
        notice = nil
        self.targetName = targetName
        startedAt = Date()
        level = 0
    }

    func push(level raw: Float) {
        // Fast attack, slow release, so the waveform feels alive but not jittery.
        let k: Float = raw > level ? 0.5 : 0.12
        level += (raw - level) * k
    }
}
