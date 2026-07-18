# Focus Forest Adventure - Phase 2 Development Plan

## Operating Principles

- Use the existing Xcode workspace only.
- Do not create a new project.
- Do not replace the existing architecture.
- Extend the current SwiftUI, MVVM, Clean Architecture, SwiftData codebase.
- Analyze before implementing.
- Implement one Phase 2 module at a time.
- Keep changes small, reviewable, and buildable.
- Build successfully after each implementation step.
- Ask for confirmation before moving from one Phase 2 module to the next.

## Current Project Status

**Updated July 2026 — Phases 2.1 through 2.8 are IMPLEMENTED.**
See "Implementation Status" at the end of this document for the full record,
deviations, extras delivered beyond the plan, and remaining work.

| Phase | Status |
|---|---|
| 2.1 AI Story Generator | ✅ Complete |
| 2.2 Bunny AI Assistant | ✅ Complete |
| 2.3 Parent Dashboard | ✅ Complete |
| 2.4 Teacher Mode | ✅ Complete |
| 2.5 AR Forest | ✅ Complete |
| 2.6 Hand Tracking | ✅ Complete (pinch + wave in gameplay; point/grab/palm classified, tested, awaiting more mini games) |
| 2.7 Engagement Estimation | ✅ Complete (camera-free by design — interaction signals only) |
| 2.8 Recommendation Engine | ✅ Complete (consumed end to end) |
| 2.9 Release Readiness | ⬜ Not started |

Current architecture includes:

- SwiftUI app entry point and root navigation.
- MVVM feature modules using `@Observable` view models.
- `AppDependencies` as the dependency composition root.
- SwiftData persistence through repository protocols.
- Use cases for mission start, mission completion, daily plan, and statistics.
- AI/game engines for mission generation, adaptive difficulty, learning recommendations, rewards, forest growth, and achievements.
- Reusable design system with forest theme tokens, reusable buttons, cards, progress, particles, animations, and accessibility-aware UI.
- Unit tests discovered in the active test plan.

Mission completion flow (Phase 2.1 integrated):
`Mission -> RewardCelebration -> StoryReader -> MovementBreak`.

## Step 1 - Existing Project Analysis

The analysis report should cover:

### Architecture

- Overall architecture.
- MVVM implementation.
- Navigation flow.
- Dependency Injection.
- SwiftData usage.
- Repository layer.
- Services.
- Utilities.
- Extensions.
- Design system.
- Reusable components.

### Folder Structure

Document the project tree and identify:

- Reusable views.
- Reusable view models.
- Managers.
- Services.
- Models.
- Animations.
- Assets.
- Theme.
- Localization.
- Testing.

### SwiftData Analysis

List every model and explain relationships.

Current SwiftData models:

- `ChildProfile`
- `MissionRecord`
- `ForestState`
- `DailyGoal`
- `SessionRecord`
- `AchievementRecord`

Likely Phase 2.1 addition:

- `StoryRecord`

### UI Analysis

Evaluate:

- Screens.
- Navigation.
- Animations.
- Accessibility.
- Consistency.
- Design quality.
- Performance risks.

### Code Quality

Evaluate:

- SOLID.
- Clean Architecture.
- MVVM.
- Naming.
- Concurrency.
- Memory management.
- Async/Await.
- Error handling.
- Dependency Injection.

### Testing

List:

- Existing unit tests.
- UI tests.
- Coverage.
- Missing tests.

Current test status:

- 32 enabled unit tests were discovered in the active test plan.
- App target builds successfully.
- Test execution is currently blocked by test target signing: `FocusForestAdventureTests` requires a development team.

## Step 2 - Phase 2 Roadmap

Before code generation, define:

- New folders.
- New services.
- New view models.
- New models.
- New repositories.
- New managers.
- Migration plan.
- Feature flags.
- Dependency graph.
- SwiftData migration.
- Navigation updates.
- Testing strategy.
- Performance considerations.
- Accessibility considerations.

## Step 3 - Incremental Implementation

Implementation rules:

- Implement one feature at a time.
- Compile successfully before moving to the next feature.
- Avoid generating thousands of lines at once.
- Use small reviewable commits.
- Preserve backward compatibility.
- Reuse existing components where possible.
- Never rewrite working code without a clear reason.

## Phase 2 Feature Order

### Phase 2.1 - AI Story Generator

Create:

- `StoryEngine`
- `StoryRepository`
- `StoryService`
- `StoryView`
- `StoryReader`
- `StoryHistory`
- `StoryCache`
- `StoryNarrator`

Requirements:

- Generate a new story after every completed mission.
- Use unlocked animals.
- Use forest level.
- Use trees planted.
- Use achievements.
- Use child nickname.
- Use favorite activities.
- Support offline mode.
- Support voice narration.
- Persist stories with SwiftData.
- Support animated page transitions.

Recommended implementation slices:

1. Add story domain values and `StoryRecord` SwiftData model.
2. Add `StoryRepository` protocol and SwiftData implementation.
3. Add `StoryEngine` for deterministic offline story generation.
4. Add `StoryService` to orchestrate story generation and persistence.
5. Add `StoryNarrator` using the existing speech infrastructure.
6. Add `StoryCache` for offline and repeat-read support.
7. Add `StoryReader` and `StoryHistory` views.
8. Add navigation route and mission completion integration.
9. Add unit tests for story generation, persistence, narration state, and offline fallback.
10. Build and verify.

### Phase 2.2 - Bunny AI Assistant

Create:

- `ConversationEngine`
- `VoiceManager`
- `IntentDetector`
- `ConversationHistory`
- `BunnyAssistant`

Features:

- Voice input.
- Speech synthesis.
- Safe responses.
- Age-appropriate language.
- Offline fallback.
- Positive reinforcement only.

### Phase 2.3 - Parent Dashboard

Create or expand:

- Dashboard.
- Analytics.
- Charts.
- Reports.
- Daily progress.
- Weekly progress.
- Recommendations.
- Achievements.
- Focus duration.
- Learning statistics.

### Phase 2.4 - Teacher Mode

Support:

- PDF reports.
- CSV export.
- Print.
- Share Sheet.
- AirDrop.
- Weekly summaries.

### Phase 2.5 - AR Forest

Create:

- RealityKit scene.
- AR forest.
- Tree planting.
- Growing flowers.
- Collecting stars.
- Animals.
- Watering.
- World map saving.
- Saved forest loading.

### Phase 2.6 - Hand Tracking

Support:

- Pinch.
- Grab.
- Wave.
- Point.
- Open palm.
- Mini games.

### Phase 2.7 - Engagement Estimation

Requirements:

- Estimate engagement on-device with parental consent.
- Never identify the child.
- Never store images.
- Never send camera data to a server.
- Use engagement only to adjust pacing, difficulty, and encouragement.

### Phase 2.8 - Recommendation Engine

Recommend:

- Today's mission.
- Difficulty.
- Story.
- Rewards.
- Movement break.
- Favorite activities.
- Learning schedule.

## Phase 2 Story Documentation Plan

This section documents the work as product and engineering stories. Each phase should be treated as a small epic with clear acceptance criteria before implementation starts.

### Phase 2.1 Story Documentation - AI Story Generator

Epic:

- As a child, I want Bunny to tell me a short magical story after I finish a mission so that my learning feels connected to my growing forest.
- As a parent, I want stories to be safe, offline-capable, and based on progress so that the experience stays private and age appropriate.

Primary stories:

- As a child, I receive a new story after each completed mission.
- As a child, I can listen to Bunny narrate the story aloud.
- As a child, I can turn pages with animated transitions.
- As a child, I see familiar forest friends, unlocked animals, achievements, and forest progress reflected in the story.
- As a parent, stories are persisted locally and available later in story history.
- As a parent, stories still work offline without any network dependency.

Documentation deliverables:

- Story generation architecture note.
- SwiftData model note for `StoryRecord`.
- Repository/service dependency graph.
- Mission completion flow update: `Mission -> Reward -> StoryReader -> MovementBreak`.
- Offline fallback behavior note.
- Privacy note explaining that story generation uses local app data only.

Acceptance criteria:

- A story is generated and saved after mission completion.
- Story content uses child nickname, forest level, unlocked animals, achievements, and favorite activity signals where available.
- Story narration can start, stop, and respect speech settings.
- Story history can display previously generated stories.
- The app builds after each implementation slice.

Testing notes:

- Unit test deterministic story generation.
- Unit test empty-data fallback story.
- Unit test persistence and fetch ordering.
- Unit test narration state if `StoryNarrator` owns state.
- UI test basic story reader page navigation when UI tests are configured.

### Phase 2.2 Story Documentation - Bunny AI Assistant

Epic:

- As a child, I want to talk to Bunny so I can ask for encouragement, help, or playful guidance.
- As a parent, I want Bunny to respond safely and positively so the child never receives inappropriate or discouraging language.

Primary stories:

- As a child, I can tap Bunny and speak a simple question.
- As a child, Bunny answers with short, age-appropriate language.
- As a child, Bunny can help me choose what to do next.
- As a parent, Bunny has an offline fallback for common intents.
- As a parent, Bunny does not produce negative, shaming, or unsafe responses.

Documentation deliverables:

- Conversation safety policy.
- Intent detection map.
- Voice input and speech synthesis flow.
- Conversation persistence policy.
- Offline fallback phrase catalog.
- Privacy note for microphone usage and consent.

Acceptance criteria:

- Voice input requires explicit user action and system permission.
- Assistant responses are short, positive, and child-safe.
- Common intents work offline.
- Conversation history avoids storing sensitive personal data.
- Speech synthesis respects the existing speech setting.

Testing notes:

- Unit test intent detection.
- Unit test safe fallback responses.
- Unit test blocked/unknown intent behavior.
- Accessibility test assistant controls and labels.

### Phase 2.3 Story Documentation - Parent Dashboard Expansion

Epic:

- As a parent, I want a clear dashboard of my child's learning and focus progress so I can understand trends without interrupting play.

Primary stories:

- As a parent, I can see daily and weekly progress.
- As a parent, I can see focus duration, missions completed, achievements, and learning statistics.
- As a parent, I can see recommendations that explain what the app will adapt next.
- As a parent, dashboard data remains PIN protected.

Documentation deliverables:

- Dashboard information architecture.
- Analytics metric definitions.
- Chart data model note.
- Parent recommendation explanation.
- Privacy note for local analytics.

Acceptance criteria:

- Dashboard presents daily progress and weekly progress.
- Dashboard shows focus duration, achievements, and subject performance.
- Recommendations are explainable and positive.
- Existing parent gate remains required.
- Empty states are clear when there is little data.

Testing notes:

- Unit test dashboard aggregation.
- Unit test recommendation text for edge cases.
- UI test parent gate to dashboard route when signing is configured.
- Accessibility test chart summaries and VoiceOver labels.

### Phase 2.4 Story Documentation - Teacher Mode

Epic:

- As a parent or teacher, I want exportable progress summaries so I can share learning updates outside the app.

Primary stories:

- As a parent, I can generate a weekly summary.
- As a parent, I can export a PDF report.
- As a parent, I can export CSV data.
- As a parent, I can print or share reports through the system share sheet.

Documentation deliverables:

- Report template specification.
- PDF export architecture note.
- CSV schema documentation.
- Share Sheet and print flow note.
- Data minimization and privacy note.

Acceptance criteria:

- PDF report includes weekly summary, focus duration, missions, achievements, and recommendations.
- CSV export uses stable column names.
- Sharing uses system share APIs.
- Exports avoid unnecessary personal data.

Testing notes:

- Unit test CSV formatting.
- Unit test report summary generation.
- Snapshot or golden-file test for report content where practical.
- Manual test print and share flows.

### Phase 2.5 Story Documentation - AR Forest

Epic:

- As a child, I want to see my forest in the real world so that planted trees, flowers, stars, and animals feel magical and tangible.

Primary stories:

- As a child, I can place my forest in AR.
- As a child, I can plant trees and grow flowers.
- As a child, I can collect stars and interact with animals.
- As a child, I can water parts of the forest.
- As a parent, the AR world can be saved and loaded later.

Documentation deliverables:

- RealityKit scene architecture.
- AR session lifecycle note.
- World map save/load strategy.
- Asset and entity catalog.
- Device capability and fallback policy.
- Privacy note for camera usage.

Acceptance criteria:

- AR feature checks device support before launch.
- AR session asks for camera permission only when needed.
- Forest placement and core interactions work smoothly.
- Saved world maps can be restored where supported.
- Non-AR fallback is available for unsupported devices.

Testing notes:

- Unit test AR state models independent of ARKit.
- Manual device testing for placement, save, and load.
- Performance test frame pacing and memory.
- Accessibility/fallback test for non-camera use.

### Phase 2.6 Story Documentation - Hand Tracking

Epic:

- As a child, I want to use gestures like pinch, wave, grab, point, and open palm to play mini games more naturally.

Primary stories:

- As a child, I can pinch to collect stars.
- As a child, I can wave to greet Bunny.
- As a child, I can point or grab in supported mini games.
- As a parent, gesture features respect device support and privacy.

Documentation deliverables:

- Gesture vocabulary specification.
- Hand tracking capability matrix.
- Mini-game integration plan.
- Privacy and consent note.
- Fallback touch-control plan.

Acceptance criteria:

- Gesture mini games work only on supported hardware and OS versions.
- Every gesture interaction has a touch fallback.
- No camera frames are stored or transmitted.
- Gesture recognition is used only for immediate gameplay.

Testing notes:

- Unit test gesture state transitions with mocked inputs.
- Manual device test each gesture.
- Performance test recognition loop.
- Accessibility test fallback controls.

### Phase 2.7 Story Documentation - Engagement Estimation

Epic:

- As a parent, I want optional on-device engagement estimation so the app can adapt pacing while preserving privacy.

Primary stories:

- As a parent, I can explicitly consent before engagement estimation is enabled.
- As a child, the app can slow down, simplify, or encourage me when engagement appears low.
- As a parent, no images are stored, identified, or sent to any server.

Documentation deliverables:

- Consent UX specification.
- On-device processing architecture.
- Data retention policy.
- Engagement signal definition.
- Pacing adaptation rules.
- Privacy threat model.

Acceptance criteria:

- Feature is off by default.
- Parent consent is required.
- No face identity is created.
- No images or camera frames are persisted.
- No camera data leaves the device.
- Engagement signal only affects pacing, difficulty, and encouragement.

Testing notes:

- Unit test pacing adaptation from synthetic engagement values.
- Unit test consent gating.
- Manual privacy audit.
- Accessibility test consent flow.

### Phase 2.8 Story Documentation - Recommendation Engine Expansion

Epic:

- As a child, I want today's adventure, story, rewards, movement breaks, and activities to feel personalized.
- As a parent, I want recommendations to be explainable and based on local learning progress.

Primary stories:

- As a child, I receive a recommended mission for today.
- As a child, I receive a recommended difficulty that changes gently.
- As a child, stories and rewards reflect my interests and progress.
- As a child, movement breaks fit my recent focus pattern.
- As a parent, the app can recommend favorite activities and a learning schedule.

Documentation deliverables:

- Recommendation signal map.
- Scoring formula documentation.
- Explainability note for parent dashboard.
- Feature flag rollout note.
- Privacy and local-only data note.

Acceptance criteria:

- Recommendation engine can recommend mission, difficulty, story theme, reward type, movement break, favorite activity, and learning schedule.
- Recommendations degrade gracefully with little or no history.
- Parent-facing explanations are plain-language and non-judgmental.
- Difficulty changes remain gentle.

Testing notes:

- Unit test each recommendation output.
- Unit test cold-start behavior.
- Unit test struggling and high-mastery profiles.
- Regression test existing recommendation behavior.

### Phase 2.9 - Release Readiness, Privacy, Testing, and Polish

Focus areas:

- Privacy review.
- Accessibility audit.
- Performance profiling.
- Battery impact review.
- Regression testing.
- UI testing.
- Snapshot testing.
- Documentation updates.
- App Store readiness.

## Engineering Standards

Follow:

- Swift API Design Guidelines.
- Apple Human Interface Guidelines.
- Accessibility best practices.
- SOLID.
- Clean Architecture.
- Swift Concurrency.
- Dependency Injection.
- Modular code.
- Reusable components.
- No duplicated code.

## Performance Targets

Maintain:

- 60 FPS where practical.
- Low memory usage.
- Fast launch.
- Smooth animations.
- Battery efficiency.
- Offline-first behavior where practical.

## Security and Privacy

Use:

- SwiftData.
- CloudKit where appropriate.
- Local encryption where appropriate.
- Parental controls.
- PIN-protected parent area.
- Privacy by Design.
- No personal data collection without consent.

## Testing Expectations

For implemented features, add or update:

- Unit tests.
- UI tests where practical.
- Snapshot tests where practical.
- Performance tests for high-risk areas.
- Accessibility tests.
- Regression tests.

## Documentation Expectations

For every implemented feature, document:

- Why it was implemented this way.
- Modified files.
- New files.
- Architecture notes or diagrams when appropriate.
- README updates when necessary.

---

## Implementation Status (July 2026)

### Phase 2.1 — AI Story Generator ✅

All eight components exist (`StoryEngine`, `StoryRepository`, `StoryService`,
`StoryView`, `StoryReader`, `StoryHistory`, `StoryCache`, `StoryNarrator`).
Stories are deterministic, offline, persisted via `StoryRecord`, narrated
through the shared speech service, and generated after every completed
mission. Flow: `Mission -> Reward -> StoryReader -> MovementBreak`.
Unit tests cover generation, fallback, persistence ordering, and narration.

### Phase 2.2 — Bunny AI Assistant ✅

`IntentDetector` (keyword, offline, distress-first priority) +
`ConversationEngine` (curated catalogs only — no open-ended generation) +
`VoiceManager` (tap-to-talk, ON-DEVICE-ONLY recognition, silence auto-stop) +
session-only in-memory `ConversationHistory` + chat UI with tap-to-ask chips.
Hard-won lesson now encoded in ARCHITECTURE.md: on iOS 18, ALL
SFSpeech/AVFoundation work must run on plain GCD queues — driving it from
Swift Concurrency contexts aborts with `_dispatch_assert_queue_fail`.

### Phase 2.3 — Parent Dashboard ✅

Charts, daily focus, subject strengths, achievements, plus `DashboardInsights`
(week-over-week trend, play streak) and a "What adapts next" section fed by
Phase 2.8 with plain-language explanations.

### Phase 2.4 — Teacher Mode ✅

`ReportBuilder` -> `ProgressReport`, `ReportCSVEncoder` (stable column
contract), `ReportExporter` (A4 PDF). Shared via ShareLink (covers AirDrop,
Mail, print, Files). Data minimization: first name + aggregates only.

### Phase 2.5 — AR Forest ✅

RealityKit scene: tap-to-plant procedural trees/flowers/animal friends (fox),
watering growth stages, collectible stars, `ARWorldMap` + JSON sidecar
save/load, device-support gate with non-AR fallback, camera usage description.
No bundled 3D assets — entities are procedural.

### Phase 2.6 — Hand Tracking ✅

Pure `GestureEngine` (pinch / point / grab / open palm) + `WaveDetector`,
all unit-tested with synthetic landmarks. `HandTrackingService` runs Vision
hand pose on a plain GCD queue at ~12 fps; frames are processed in memory and
discarded. Star Catch mini-game: pinch to collect, wave for a Bunny wave-back
and bonus stars; every interaction has a touch fallback. Point/grab/palm are
classified and tested but not yet used by a game.

### Phase 2.7 — Engagement Estimation ✅ (deviation, deliberate)

Implemented CAMERA-FREE: `EngagementEngine` scores engagement from
interaction signals only (answer speed, slowing trend, consecutive misses,
idle time). Identical benefit (pacing, encouragement, graceful wind-down)
with a categorically stronger privacy story — no image pipeline exists at
all. Consent toggle in Settings, off by default. All original acceptance
criteria met or exceeded.

### Phase 2.8 — Recommendation Engine ✅

`makeDailyRecommendations`: mission, difficulty, story theme, reward
emphasis, movement break, favorite activity, learning schedule — with parent
explanations and cold-start degradation. Consumed end to end: story theme
flows into `StoryEngine` (persisted on `StoryRecord`), the recommended
movement break replaces the random one, reward emphasis is spotlighted on
the celebration screen.

### Delivered beyond the plan

- **Age-based content**: Settings age picker (4/5/6). Age 5 turns ABC into
  word reading — 4 options per question, 356-word curated `WordBank`,
  non-repeating targets tracked per child, picture (emoji) + spoken reveal
  on success. Age 6 adds four graded addition sections to Numbers
  (Easy/Medium/Hard/Challenge, 20 unique questions, sums ≤ 20, symbol
  display "6 + 2 = ?" with spoken "What is 6 plus 2?").
- **Night mode**: full adaptive palette (day pastels -> dusk forest);
  game color swatches deliberately fixed so color-learning stays truthful.
- **2-minute exercise movement break**: 8 shuffled kid exercises with
  emoji flip-book animation, per-exercise narration, progress leaves,
  early-exit button, and procedurally synthesized background music
  (`BreakMusicEngine` — no audio assets required).
- **App identity**: bunny forest app icon, display name "Adventure",
  sky-colored launch screen (light/dark) replacing the white flash.
- **CloudKit sync hygiene**: remote-notification background mode +
  aps-environment entitlement.
- **Settings hydration at launch** (fixed latent sync bug).

### Remaining work

- **Phase 2.9 — Release readiness**: privacy review, accessibility audit,
  performance/battery profiling, regression + UI + snapshot test expansion,
  App Store metadata. Largely human-on-device work.
- **Real assets**: Lottie animation JSONs (12 files listed in
  Resources/Animations/README.md) and sound effects/ambience are still
  placeholders; the app runs fully without them by design.
- **Test target signing** for running the suite on device.
- **Gesture mini games** for point/grab/open-palm (engine ready).
