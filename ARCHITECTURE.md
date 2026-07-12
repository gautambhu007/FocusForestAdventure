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
