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
