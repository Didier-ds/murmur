# Murmur

A macOS menu bar app that types with your voice. Click the ring in the menu bar, speak, then press Esc or click again, and the text lands in whatever field you were typing in.

- **On-device:** Apple's `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26). Audio never leaves your Mac.
- **Inserts anywhere:** uses the Accessibility API, and falls back to pasting. If there's no text field to type into, the text stays on your clipboard so you can paste it with ⌘V.
- **Dark mirror UI:** a floating transcript capsule that never takes focus. The design mockup is in `prototype.html`.

## Build and run

Requires macOS 26 on Apple silicon and the Swift 6.2 toolchain (Command Line Tools are enough, Xcode isn't required).

```sh
./scripts/create-signing-cert.sh   # once: a local signing certificate so permissions survive rebuilds
./scripts/build-app.sh --run       # builds build/Murmur.app and launches it
```

On first launch, allow **Microphone** and **Speech Recognition**, then enable Murmur in **System Settings → Privacy & Security → Accessibility**. The right-click menu shows whether the voice model is ready.

Without the signing certificate the app is ad-hoc signed, and macOS forgets the Accessibility permission after every rebuild. If text starts landing on the clipboard instead of being typed, toggle Murmur off and on in Accessibility settings.

## Privacy & security

Murmur asks for powerful permissions, so here is exactly what it does with them. Everything below can be checked in the source.

| Permission | Why | Where |
|---|---|---|
| Microphone | Records only between your click and your Esc/click. macOS shows the orange mic indicator the whole time. | `SpeechSession.swift` |
| Speech Recognition | Transcribes with Apple's **on-device** model. No audio or text is sent anywhere. | `SpeechSession.swift` |
| Accessibility | Reads which text field is focused and types into it, or pastes with a simulated ⌘V. | `TextInsertion.swift` |
| Accessibility (keyboard) | While recording, and only then, checks each key press only to see whether it's a plain Esc, to finish dictation. Nothing is recorded, and every other key passes through unchanged. | `EscapeKeyMonitor.swift` |

- **No network access, analytics or accounts.** The only download is Apple's voice model, which macOS fetches itself.
- **Nothing is stored.** Transcripts live in memory until inserted. The last one is kept in memory for *Copy Last Dictation* and is gone when you quit. Logs record only lengths and outcomes, never what you said.
- **Safe to dictate into a terminal.** Line breaks and control characters are turned into spaces before inserting, so a transcript can never press Return and run a command.
- **Clipboard:** when Murmur pastes or copies, your dictation replaces the clipboard (it isn't restored, so you can paste it again). It's marked transient so clipboard-history apps don't save it, and it isn't synced to your other devices through Universal Clipboard.
- **Pasting only goes where you started.** If the app you were dictating into is no longer in front, Murmur copies instead of pasting into some other app.
- **Hardened Runtime** is enabled, with microphone access as the only entitlement.
- **No third-party dependencies** in the app: only Apple frameworks.

Found a vulnerability? See [SECURITY.md](SECURITY.md).

## Layout

| File | Role |
|---|---|
| `DictationCoordinator` | State machine: idle → recording → finalizing → insert |
| `StatusItemController` | Menu bar ring icon and menu |
| `SpeechSession` | Mic capture, format conversion, SpeechAnalyzer |
| `TextInsertion` | Focus capture, sanitizing, Accessibility insertion, paste fallback |
| `EscapeKeyMonitor` | Esc to finish, active only while recording |
| `HUDPanel` | Dark mirror transcript capsule and waveform |
| `Permissions` | Microphone, speech and Accessibility checks |

`promo/` holds the Remotion source for the launch video. It's development tooling only and isn't part of the app.
