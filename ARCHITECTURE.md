# Architecture Decision Record — Focus Forest Adventure

## 1. Layering (Clean Architecture, MVVM at the edge)

Presentation → ViewModel → UseCase → Repository → SwiftData

- **Views** are dumb: they render `@Observable` ViewModel state and forward intents.
- **ViewModels** (`@Observable @MainActor`) own screen state and call use cases.
  No SwiftData imports in views; no SwiftUI imports in use cases/engines.
- **UseCases** orchestrate repositories + engines; one verb each
  (`StartMissionUseCase`, `CompleteMissionUseCase`, …).
- **Engines** are pure `Sendable` structs (difficulty, recommendation, generator,
  reward, growth) — trivially unit-testable, no I/O.
- **Repositories** are protocols; SwiftData implementations are swapped for
  in-memory fakes in tests.

## 2. Dependency injection

`AppDependencies` is the single composition root, created in `@main` and pushed
through the SwiftUI Environment. ViewModels receive it by initializer. There are
no singletons; the only process-wide state is what the graph itself owns
(sound engine, speech synthesizer, haptic engine — inherently single instances,
but still injected, never accessed statically).

## 3. Concurrency model (Swift 6, strict)

- Everything UI-adjacent is `@MainActor` (ViewModels, services touching AVFoundation/CoreHaptics, SwiftData mainContext repositories).
- Engines are `Sendable` value types usable from any actor.
- Timers use structured `Task.sleep` loops owned by the ViewModel and cancelled
  in `onDisappear` — no `Timer`/RunLoop, no detached tasks.
- StoreKit transaction listener is a long-lived `Task` owned by `PremiumStore`
  and cancelled on deinit.

## 4. Child-psychology-driven game rules (encoded in engines)

| Rule | Implementation |
|---|---|
| Never punish | `RewardEngine` floors stars at 1; retry copy is "Almost!" |
| Never jump difficulty | `AdaptiveDifficultyEngine` moves ±1 max, promotion needs 2 strong missions in a row |
| End before frustration | `MissionPlan.maxDuration` (3–5 min) + `frustrationMissLimit` (3 consecutive misses) → graceful celebratory exit |
| ~80% success target | difficulty thresholds tuned to keep accuracy near the flow channel |
| Movement after focus | mandatory 30s `MovementBreakView` between missions |
| Effort > outcome | seeds scale with questions attempted, not accuracy |

## 4a. Post-mission story flow (Phase 2.1)

Mission completion runs `Mission → Reward → StoryReader → MovementBreak`, all as
phases inside `MissionContainerView` (single navigation destination — see the
`MissionPhase` note about NavigationStack stability). After
`CompleteMissionUseCase` succeeds, `MissionViewModel` asks `StoryService` to
generate and persist a `StoryRecord` from local progress signals only (nickname,
forest level, trees, unlocked animals, achievements, favorite activity). Story
generation is offline and deterministic (`StoryEngine`); failure is silent — the
flow simply skips to the movement break. `.story` is a marker phase because
SwiftData models aren't `Equatable`; the record travels in
`MissionViewModel.pendingStory`. Past stories are listed in `StoryHistory` and
narrated by `StoryNarrator` through the shared speech service.

## 4b. Bunny assistant (Phase 2.2)

Conversation is fully offline and fully curated. `IntentDetector` (pure,
keyword-based) maps an utterance to a coarse `BunnyIntent`; `ConversationEngine`
(pure) picks a reply from hand-written, age-appropriate catalogs — there is no
open-ended generation, so Bunny can never say something unreviewed. Safety
ordering: distress keywords ("sad", "scared"…) outrank every other intent and
answer with comfort plus a gentle "tell a grown-up" nudge; unknown input gets a
friendly redirect, never a made-up answer.

Voice input (`VoiceManager`) is tap-to-talk, requires explicit permission, and
uses **on-device recognition only** (`requiresOnDeviceRecognition = true`); if
the device/language can't do on-device, the mic is hidden and tap-to-ask chips
carry the whole interaction. Conversations (`ConversationHistory`) are
session-only and in-memory — never persisted — which is the data-minimization
guarantee for the child's chats. Replies are spoken through the existing
`SpeechService`, so the parent's "Bunny speaks" setting is honored.

## 4c. Phase 2.3–2.8 additions

**Parent dashboard & reports (2.3/2.4).** `DashboardInsights` is a pure
aggregator (streaks, week-over-week trend) computed from the 14-day focus map.
Teacher Mode is three pieces: `ReportBuilder` (pure summary → `ProgressReport`),
`ReportCSVEncoder` (stable column contract, RFC-4180 escaping), and
`ReportExporter` (`UIGraphicsPDFRenderer` → temp files shared via `ShareLink`,
which covers AirDrop, Mail, print, and Files). Reports carry first name +
aggregates only.

**AR Forest (2.5).** `ARForestSession` (@MainActor) owns the RealityKit scene:
tap-to-plant procedural entities (no bundled 3D assets), tap-to-water growth
stages, periodic collectible stars. Persistence = `ARWorldMap` for
relocalization + a JSON sidecar (`ARForestSceneState`, pure & tested) that
re-creates entities on load — deliberately no `ARSessionDelegate`, keeping
Swift 6 isolation trivial. Device support is gated (`isSupported`) with a
friendly non-AR fallback.

**Hand tracking (2.6).** Split by testability: `GestureEngine` + `WaveDetector`
are pure classifiers over normalized landmarks (no Vision import);
`HandTrackingService` runs AVCapture + `VNDetectHumanHandPoseRequest` on a
plain serial GCD queue (same iOS 18 forced-sync rule as VoiceManager, see 4b),
throttled to ~12 fps, publishing only gesture + pointer to @MainActor. Frames
are processed in memory and discarded. The Star Catch mini-game treats hand
tracking as an optional layer — every star is also tappable.

**Engagement estimation (2.7 — camera-free by design).** `EngagementEngine`
scores engagement 0…1 from interaction signals only (answer speed, slowing
trend, consecutive misses, idle time) and maps it to pacing advice
(keepGoing / encourage / windDown). Consent-gated: off by default, explicit
parent opt-in in Settings, and the mission flow only ever uses it to cheer or
end early on a celebratory note — identical mechanics to the frustration guard.

**Daily recommendations (2.8).** `makeDailyRecommendations` extends the
recommendation engine to one explainable bundle: today's mission + difficulty,
story theme, reward emphasis, movement-break style, favorite activity, and a
gentle session schedule — with plain-language `parentExplanations` surfaced on
the dashboard ("What adapts next"). Cold start degrades to discovery framing.
The bundle is consumed end to end: `StoryService` feeds the recommended
`StoryTheme` into `StoryEngine` (one themed page per story, persisted on
`StoryRecord`), and `MissionViewModel` uses the recommended movement break and
passes `RewardEmphasis` to the celebration screen, which spotlights that
reward. All recommendation failures degrade silently to the previous defaults.

Gap-closing addenda: the AR forest also places procedural forest friends
(fox), and `HandTrackingService` runs `WaveDetector` so waving at Bunny in
Star Catch earns a wave-back and bonus stars.

## 4d. Age-based content

`AppSettings.childAge` (Settings → Learning, default 4) switches content
style. At age 5 the ABC adventure becomes word reading: `MissionType.findWord`
questions show 4 word options (3–4 letters, uppercase) drawn from `WordBank`
— 350+ curated, kid-safe words. Targets never repeat: attempted words are
recorded on `ChildProfile.usedWordsRaw` at mission completion and excluded
from future draws until the whole bank has been seen once (then a new lap
starts). Distractors may repeat; only targets are tracked. Other adventures
are age-independent for now — the switch point is centralized in
`MissionGeneratorEngine.generateMission(age:usedWords:)` so future ages only
touch the engine.

At age 6 the Numbers adventure opens a chooser with four graded addition
sections (`AdditionSection`: Easy 1–9, Medium 5–14, Hard large-addend,
Challenge mixed — all sums ≤ 20). `AdditionEngine` generates 20 unique
problems per section, sorted easy→hard (Challenge stays mixed), with four
answer choices in-app.

## 4e. Puzzle Quest (visual reasoning, ages 4–8)

A second game loop beside missions, for the reasoning skills the adventures
don't touch: pattern completion, symmetry, rotation, matrices, rule discovery.

**Difficulty is cognitive, not quantitative.** `PuzzleSkill` is an eight-rung
ladder (match colors → complete pattern → mirror → rotate → multi-rule →
memory+logic → hidden pattern → mixed IQ); the grid bound grows *with* the
rung rather than being the difficulty itself. `PuzzleWorld` (Forest, Jungle,
Castle, Space, Lab, Dragon) is the themed progression on top, unlocked by age
**or** by earning it through the previous world — a locked world always shows
the child how to open it.

**Puzzles are generated, not authored.** `PuzzleGeneratorEngine` turns a
`PuzzleSpec` (the JSON contract: grid size, theme, rule, missing tiles,
options, time limit, reward) into a `Puzzle`, seeded so a board is
reproducible. Eighteen `PuzzleKind` recipes cover the spec's puzzle families;
two invariants hold for all of them and are tested property-style across every
kind × rung × world × seed: exactly one answer satisfies the stated rule, and
no two answer chips are visually identical. Distractors are built to break
*one* half of a rule (right shape/wrong color) so a wrong tap is informative
rather than random.

**One renderer.** Every kind draws through `PuzzleGridView` +
`PuzzleOptionsView` (+ an optional legend), with `PuzzleAnswerMode` choosing
between tapping a chip and tapping a board tile. Adding a recipe never needs
a view.

**Same psychology rules as missions.** Stars floor at 1; the time limit only
*adds* the speed star and never ends a puzzle; a wrong tap costs nothing but a
shake; the hint is one tap away; after three misses Bunny fills the answer in
and moves on, so a child can be stuck but never stopped.
`PuzzleProgressionEngine` moves the rung ±1 at most, promoting only after two
strong runs and demoting immediately after a bad one.

Persistence is deliberately small: `PuzzleProgress` (per child × world:
level, rung, stars, and a 5-run accuracy history — attempts themselves are
never stored) and `PuzzleSkillStat` (per child × skill), plus coins and badges
on `ChildProfile`. The compact history is what lets the adaptive rung survive
a relaunch without persisting every tap.

## 4f. Puzzle Adventure World — the campaign layer

**Story is data.** `BrainlandStory` is the whole script: prologue, nine
worlds, their casts, and a `StoryChapter` list per world. A chapter joins a
story name to a generator rule ("Hidden Acorns" → `.hiddenObject`), so adding
a level is a data edit. Nothing about the narrative is generated — same rule
as the Bunny assistant (4b): a child can never be told unreviewed prose.

**Worlds are earned, difficulty is separate.** `PuzzleWorld` decides what a
puzzle is *about*; `PuzzleSkill`'s eight rungs decide how hard. A world opens
when the previous world's crystal is won — or, for a child old enough who is
already five levels in, early, so a stuck boss can never end the campaign.
The Rainbow Kingdom needs all seven story crystals. Each world is its
chapters plus one boss; the boss is longer, harder, pays double, and awards
the crystal.

**Theming lives in the vocabulary.** `PuzzleMotif` is either a tintable shape
or a story picture. Worlds draw their boards from their own cast, *except*
where the rule is about color (`PuzzleKind.needsTintableShapes`) — "the red
one" has to mean something, and a picture's color isn't ours to change.

**Six answer modes, one renderer.** `.options` (tap a chip), `.tapTile`
(tap the odd one), `.tapMany` (find them all), `.tapPath` (walk a route),
`.assemble` (pick a piece, then tap where it goes), and `.rotateTiles` (turn
things until they line up). `Puzzle.correctIDs` is a set so correctness is
one containment check in every mode. `peekDuration`
drives the memory puzzles: the board is shown, then covered, and the clock
for that puzzle only starts once it goes down — looking isn't answering.

**Mazes.** `PuzzleTileRole` marks start/goal/hazard/key; `MazeRules` holds
the walking rules as pure functions (`canStep`, `isComplete`,
`hasRouteRemaining`) so they're tested without a view. The generator carves
the safe route *first* and only ever places hazards off it, so an unsolvable
board is impossible by construction — there is no retry loop. Reaching for a
non-adjacent square is treated as a mis-tap (a shake, uncounted), not a wrong
answer; only walking into a hazard counts. Stepping onto the previous cell is
an undo, "Step Back" is always available, and `hasRouteRemaining` lets the
app spot a dead end and say so kindly rather than leaving a child stuck.

**Mental rotation.** `PuzzlePattern` is a little block of filled cells with
`rotated()`, `mirrored()`, and `isRotation(of:)`. Block-rotation puzzles are
fair because of two guards: the shown block is chosen to have four *different*
orientations (`hasDistinctRotations` — a symmetric block would have several
right answers), and every distractor is checked against all four turns of the
original, so a decoy can never be accidentally correct. A mirror image is the
best distractor precisely because it is never a rotation.

**Assembly.** `.slot` tiles carry the glyph they want and draw it as a faint
silhouette; the piece bank is the options row. Correctness is a glyph
comparison at drop time, so no separate slot→piece map is needed. Picking a
piece up is free (tap another to swap, tap the held one to put it back) and a
piece dropped in the wrong place bounces back to the bank rather than being
consumed. From rung 4 a spare piece appears, so the bank has to be read
rather than just emptied.

**Pipes.** `PipeConnections` is an `OptionSet` of open sides with `rotated()`
and `opposite`; `PipeRules` holds the flow rules (`rotating`, `flooded`,
`isConnected`) as pure functions. Water crosses only when *both* neighbours
open onto each other — one arm facing a closed side is a leak, not a join.
Built like the maze: the working pipeline is laid down first and then every
tile is turned, so solvability is guaranteed and the only thing the generator
has to check afterwards is that the scramble didn't leave the board already
solved (straight pipes look identical after a half turn, so a "turned" tile
isn't always a changed one). Turning a pipe is never a *miss* — there is no
wrong tap, only a board that isn't joined up yet — and the flooded set drives
both the blue "water" colouring and a "3 of 9 pipes joined" progress line.

**Murals.** `MuralCatalog` gives each world a nine-tile picture. A 🧩 piece is
spent to reveal one tile, by choice rather than automatically — a reward you
*do* something with lands harder than a number going up on its own — and
finishing a picture pays a one-time gem bonus (`muralBonusPaid` guards it).

**Two currencies, two feelings.** 💎 gems are earned every level and spent
freely in `CollectibleCatalog` (cosmetic only — a locked item is never a
disadvantage); 🧩 pieces accumulate slowly. Crystals gate the best items, so
the story stays the real prize.

**The daily layer is deliberately gentle.** `PuzzleDailyEngine` owns the
seeded daily puzzle, the day-seeded mystery chest (relaunching can't reroll
it), the seven-day streak ladder, and the weekend challenge. A missed day
costs the streak *multiplier*, never anything already owned, and there are no
countdown timers. Daily and weekend runs carry `PuzzleRunMode` values whose
`advancesStory` is false and whose level is 0, so they pay gems and practise
skills without ever skipping a chapter.

Persistence stays small: `PuzzleProgress` (per child × world: level, rung,
stars, crystal, and a 5-run accuracy history — attempts are never stored),
`PuzzleSkillStat` (per child × skill), plus gems, pieces, badges,
collectibles, and the aggregate speed/hint signals on `ChildProfile`.
Day-scoped flags (today's puzzle done, chest opened) live in `UserDefaults`
via `DailyPuzzleLog`, not in the synced store — a chest opened on the iPad
shouldn't vanish when the iPhone syncs.

**Parent reporting** is in cognitive terms, not engine terms:
`PuzzleSkill.cognitiveSkills` maps rungs onto the seven `CognitiveSkill`
rows, and concentration and processing speed come from *how* the child plays
(hint rate, time against the limit). A row with fewer than five samples shows
"not enough play yet" rather than a made-up rating.

## 5. Persistence & sync

Single SwiftData store, CloudKit private database (`.private` ModelConfiguration).
CloudKit constraints honored: defaults on all attributes, optional relationships,
no `@Attribute(.unique)`. Widget data crosses the process boundary via an App
Group `UserDefaults` snapshot (`ForestWidgetSnapshot`), not the database.

## 6. Error philosophy

Child-facing surfaces never show errors. Repository failures degrade to safe
defaults (empty forest, default goal) with `assertionFailure` in debug. The only
fatal path is ModelContainer creation after the local-storage fallback also fails.

## 7. Testing strategy

- **Engines**: exhaustive pure unit tests (property-style loops for generators).
- **UseCases**: in-memory `ModelContainer`, real repositories — fast integration.
- **Snapshots**: design-system components, incl. Dynamic Type XXL + dark mode.
- **UI**: happy path, parent-gate enforcement, `performAccessibilityAudit`.
- **Performance**: XCTApplicationLaunchMetric; Canvas-based particles keep the
  render loop allocation-free.
