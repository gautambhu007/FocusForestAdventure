# Localization

All user-facing strings use `String(localized:)`, so Xcode's String Catalog
(`Localizable.xcstrings`) picks them up automatically:

1. In Xcode: File → New → File → String Catalog → name it `Localizable`.
2. Build once — Xcode extracts every `String(localized:)` key.
3. Add languages: English (base), Spanish, Hindi, French.
4. The Bunny's speech (`SpeechService`) automatically selects an
   `AVSpeechSynthesisVoice` matching the current locale.

Guideline: keep child-facing strings short (≤ 8 words), positive, and concrete.
Never translate to anything that could read as criticism ("wrong", "failed",
"bad") — use "almost!", "try again!", "so close!".
