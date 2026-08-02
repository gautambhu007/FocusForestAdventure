# Local-Only Math Practice Platform — Product Spec (Ages 4–7)

## 1. Premise

KooBits is cloud-backed: questions come from a server-side bank, videos stream
from CDN, progress syncs to a backend. This spec adapts its 6 core features
into an **entirely on-device, no-account, no-network** product for a younger
band (4–7, vs. KooBits' 5–12/K1–P6) — matching the privacy-first philosophy
already used in this repo (Focus Forest Adventure: "no accounts, no
analytics, no data collection", `README.md`).

**Recommendation**: build this as an expansion of Focus Forest Adventure's
existing `Numbers` adventure rather than a new app from scratch. It already
has the exact architecture this spec needs — `AdaptiveDifficultyEngine`,
`AdditionEngine`, `MissionGeneratorEngine`, a PIN-gated parent dashboard with
Swift Charts, and a Clean Architecture layering that's proven across 7
adventures and a full Hindi learning platform. Reusing it is weeks faster
than starting over. If a fully separate app is actually wanted, everything
below still applies — just duplicate the architectural pattern into a new
project instead of a new module.

## 2. Feature-by-feature: cloud feature → local equivalent

| KooBits feature | Why it can't port as-is | Local-only equivalent |
|---|---|---|
| 10 personalized daily questions | Server picks from a live bank tuned by a backend model | An on-device `AdaptiveDifficultyEngine` (already exists) picks the day's topic + difficulty from local performance history; a local generator produces the 10 questions at that difficulty. No network round-trip needed — this is strictly easier offline. |
| 1,000+ animated tutorial videos | Real video assets at that scale = gigabytes, impossible to bundle, impossible to author for one dev | A **parameterized animation library**: ~40–60 reusable Lottie/SwiftUI animation *templates* (one per concept: counting, more/less, shapes, grouping, simple addition, patterns, sorting, size comparison...) each driven by data (numbers, colors, objects) so one template covers dozens of question variants. This is exactly the pattern already used for `BreakMusicEngine` and the procedurally-authored Lottie set in this repo — synthesize once, parameterize forever. Paired with on-device TTS narration (`SpeechService` already exists) instead of recorded voiceover. |
| 100,000+ question bank | A literal static bank that size can't be hand-authored or fully bundled | **Procedural question generation**, not a static bank. `AdditionEngine`-style generators produce unlimited unique questions per topic/difficulty on demand (already the pattern for Numbers/Shapes/Colors in this repo). "100,000 questions" becomes "20 topics × 5 difficulty tiers × a generator with enough parameter space to never visibly repeat" — functionally unlimited, zero storage cost. |
| Instant auto-marking + step-by-step explanations | Same challenge server-side or on-device — this one's actually *easier* offline (no round-trip latency) | Trivial: compare the tapped answer to the generated correct answer locally. Step-by-step explanation = a **template string** built from the question's own operands (e.g. "6 + 2 → start at 6, count up 2 more: 7, 8 → answer is 8"), same spirit as the existing `additionChoiceQuestion` spoken-prompt pattern (`MissionGeneratorEngine.swift`). |
| Top-school exam papers + solutions | Irrelevant to this age band anyway (that's a P1–P6/exam-prep concept) and requires licensing real exam content | Replace with **milestone practice sets**: bundled, locally-authored question sets aligned to common early-years outcomes (count to 20, shape recognition, sort by size/color, addition within 10, simple patterns) with full local walkthroughs — same value (structured, gradeable checkpoints) without needing real exam papers or an age group this app doesn't serve. |
| Parent app for tracking progress / gaps | KooBits syncs to a companion app over the internet | **Already solved in this codebase**: SwiftData-backed `PerformanceSummary`, `DashboardInsights` (streaks, week-over-week trend), and a PIN-gated `ParentDashboardView` with Swift Charts — all on-device, zero network. Reuse verbatim. |

## 3. Age-band adaptation (4–7 vs. KooBits' 5–12)

- Drop anything exam/curriculum-branded (P1–P6 syllabus alignment, past
  papers) — not meaningful before age 7 and risks miscalibrating tone.
- Cap session length hard (this repo's `frustrationMissLimit` +
  `maxDuration` pattern) — 4–7 year olds need 3–5 minute missions, not
  30-minute practice sets.
- Replace "10 questions, graded and scored" framing with the existing
  celebratory model (`RewardEngine`: stars floor at 1, effort > accuracy) —
  scored exam-style feedback is developmentally wrong for this age.
- Topics for 4–7, roughly by age:
  - **4**: counting to 10, shape/color recognition, bigger/smaller, sorting.
  - **5**: counting to 20, simple patterns, more/less, basic shapes combined.
  - **6–7**: addition/subtraction within 20 (the existing `AdditionSection`
    Easy/Medium/Hard/Challenge tiers already cover this), number bonds,
    simple word problems using concrete objects/emoji.

## 4. Content authoring strategy (how "1,000 videos" and "100k questions" become feasible offline)

The trap is treating these as literal asset counts. Reframe as **generators,
not libraries**:

1. **Animation templates** (~40–60): each is a Lottie/SwiftUI animation with
   parameters (count, color, object emoji, shape). A single "counting"
   template rendering 1–20 objects covers what would otherwise be 20
   separate videos.
2. **Question generators** (~15–20, one per topic): pure `Sendable` structs
   like the existing `AdditionEngine`, each producing effectively unlimited
   unique questions within a difficulty band. No storage, no authoring at
   scale — just good generator design once per topic.
3. **Step-by-step explanation templates**: derived from the question's own
   generated operands, not hand-written per question.

This mirrors exactly how this repo already reached its own "40 categories /
games" Hindi platform and "1000+ word Listening Corner" — data-driven
templates + generators, not one-off authored content per item.

## 5. Suggested build order

1. Extend `AdditionSection`-style graded tiers to the 4–7 topic list above
   (counting, shapes, patterns, sorting) as new `MissionType`/generator
   pairs — smallest possible first slice, reuses everything.
2. Build the animation-template library for the 5–6 most-used concepts
   first (counting, shapes, more/less); expand later.
3. Wire step-by-step explanations into the existing reward/celebration flow
   (`RewardCelebrationView` equivalent) so a wrong answer shows the
   worked-through steps before the gentle retry.
4. Add a "Weak Topics" card to the existing parent dashboard (subject
   accuracy already tracked in `PerformanceSummary.perSubject` — just
   surface the lowest-accuracy subject explicitly).
5. Milestone practice sets last — they're content-authoring work, not
   architecture work, and easiest to expand incrementally once the engine
   exists.

## 6. What's explicitly out of scope (and why)

- **Any server component** — contradicts the local-only requirement and
  this repo's existing privacy stance.
- **Real licensed exam papers** — legal/licensing risk, wrong age band.
- **Literal 1,000-video or 100,000-question assets** — physically
  unbundleable; the generator/template approach above delivers the same
  perceived variety at near-zero storage cost.
- **Cross-device progress sync** — optional stretch via iCloud key-value
  store (already used for Hindi platform scores in this repo), not a
  requirement for the core product.
