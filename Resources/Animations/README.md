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

Status: 9 of 12 are BUNDLED — programmatically authored flat-style
animations (python-lottie): bunny_wave, bunny_cheer, bunny_dance,
bunny_thinking, tree_grow, butterfly, confetti_big, bird_fly, rainbow.
Still placeholders (SF-symbol fallback): river_flow, castle_sparkle,
chest_open. Replace any file with same-named artwork to upgrade it.

Sound assets (`Resources/Assets`): forest_piano_ambience.m4a plus the short
effects listed in `SoundEffect` (tap_pop, correct_chime, gentle_try_again,
star_earned, chest_open, forest_grow, card_flip, and 6 animal sounds).
All effects should be mastered quiet (≤ -12 LUFS) — no loud sounds.
