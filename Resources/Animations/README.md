# Lottie Animations

Place Lottie JSON files here (added to the app target). Required set,
matching `ForestAnimation` in `DesignSystem/LottieView.swift`:

| File | Used for |
|---|---|
| bunny_wave.json | Splash, home greeting |
| bunny_cheer.json | Correct answers, reward screen |
| bunny_dance.json | Movement breaks |
| bunny_thinking.json | During questions |
| tree_grow.json | Forest level-up |
| butterfly.json | Forest ambience |
| bird_fly.json | Forest ambience |
| river_flow.json | River unlock |
| rainbow.json | Rainbow unlock |
| castle_sparkle.json | Castle unlock |
| chest_open.json | Magic chest |
| confetti_big.json | Mission complete |

Until the JSON files are added, `LottieView` renders a friendly SF Symbol
placeholder, so the app runs end-to-end without assets.

Sound assets (`Resources/Assets`): forest_piano_ambience.m4a plus the short
effects listed in `SoundEffect` (tap_pop, correct_chime, gentle_try_again,
star_earned, chest_open, forest_grow, card_flip, and 6 animal sounds).
All effects should be mastered quiet (≤ -12 LUFS) — no loud sounds.
