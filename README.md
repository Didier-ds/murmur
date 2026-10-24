# Murmur

A macOS menu bar app that types with your voice. Click the ring in the menu bar, speak, click again, and the text lands in whatever field you were typing in.

- **On-device:** Apple's `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26). Audio never leaves your Mac.
- **Inserts anywhere:** uses the Accessibility API, and falls back to pasting (your clipboard is restored).
- **Dark mirror UI:** a floating transcript capsule that never takes focus. The design mockup is in `prototype.html`.

## Build and run

Requires macOS 26 and the Swift 6.2 toolchain (Command Line Tools are enough, Xcode isn't required).

```sh
./scripts/build-app.sh --run   # builds build/Murmur.app and launches it
```

On first launch, allow **Microphone** and **Speech Recognition**, then enable Murmur in **System Settings → Privacy & Security → Accessibility**. The right-click menu shows whether the voice model is ready.

The app is ad-hoc signed, so macOS may forget the Accessibility permission after a rebuild. If text starts landing on the clipboard instead of being typed, toggle Murmur off and on in Accessibility settings.

## Layout

| File | Role |
|---|---|
| `DictationCoordinator` | State machine: idle → recording → finalizing → insert |
| `StatusItemController` | Menu bar ring icon and menu |
| `SpeechSession` | Mic capture, format conversion, SpeechAnalyzer |
| `TextInsertion` | Focus capture, Accessibility insertion, paste fallback |
| `HUDPanel` | Dark mirror transcript capsule and waveform |
| `Permissions` | Microphone, speech and Accessibility checks |
