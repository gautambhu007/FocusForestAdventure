# Word Search — feasibility study

Studied: `Flora_40_Word_Search_Master_Prompt.md`, `template-forest-fox.png` (Forest / fox),
`template-garden-solveit.png` (Garden / girl + rabbit), and the codebase as of `3addbb3` on
`feature/puzzle-quest`. Written 2026-09-12 without any product decisions taken —
where a choice is needed it is named, with a recommendation.

## Status — 2026-09-12

**Every engineering slice has landed on `main`** — the five from this study
(`97956d8` … `e8d674e`) plus the art-track foundation (`8ca14d5`). `main` is
fast-forwarded from `feature/puzzle-quest`. What holds each one:

| Slice | Landed | Held by |
|---|---|---|
| 1 Word table + uniqueness | `78df0e5` | `WordSearchWordBankTests` — collisions (dup / stem / substring), stage tables, 40 sheets |
| 2 Generator + stage rules | `78df0e5` | `WordSearchEngineTests` — 40 sheets × 60 seeds: sizes, directions, intersections, backwards cap, every target once, no blocked filler, every stage direction appears (this is the fallback guard) |
| 3 Play screen | `a6a0ebc` | `WordSearchPlayViewModelTests` — 11 finger-style tests (drag, snap, hints, stars, finish, replay, crossing colour) |
| 4 Progress + dashboard | `6c905cb` | `WordSearchSnapshotTests`, `WordSearchRepositoryTests` — per-child `WordSearchRecord` rows, read-back through a fresh context |
| 5 iPad layout | `e8d674e` | Rendered at iPad landscape/portrait and iPhone via a throwaway test; no permanent snapshot (the snapshot target has no recorded references) |
| 7 Code-painted scenes | `a452c28` | `testEverySheetHasAPaintedSceneFromOneSourceOrTheOther` — 21 forest + 19 painted, exactly one source per sheet, every family used; all twelve rendered and three sheets checked on screen |
| 6 Art contract | `8ca14d5` | `WordSearchArtTests` — names unique and catalog-safe across all 609 assets, missing asset is nil, 21 painted places; `testTheMascotFollowsPlay` |

**START HERE for the next session:** every sheet now stands on a painted
scene — 21 in the forest's places, 19 in `WordSearchPaintedScene`'s twelve
code-painted families (ocean, farm, prehistoric, city, beach, winter,
tropical, savanna, arctic, robot, construction, railway). What remains:
1. **Scenes** — 40 `WS_ENV_nn` images, each generated as its own full-size
   image (≥1024 wide, portrait, no label) from `Prompts.md`. Two deliveries
   so far were the same labelled contact grid cropped into 171px tiles and
   were rejected; a "corrected" mascot batch was the grid cropped off-cell
   and was also rejected (the mascots already landed are the good cut).
   **One prompt → one image → one file**, three scenes first for a check.
   Mascots are done. Word pictures are optional (emoji does the job) and
   must use names from the `Prompts.md` table — a pasted grid of 24 had
   only 9 words that exist in the game.
2. **The 10×10 touch size on phones** — a decision from watching a child play
   sheet 31+.
Move this pointer when one of them lands.

**Measured, not planned:** 249 target words (the brief's "~320" was 8 × 40; the
stage-1 sheets legitimately carry 4). Grid sizes are the smallest stage size
under 70% target letters — 20 sheets sit one size above the minimum. Phone
cells on a 10×10 are ~31pt.

**Defects found by measuring before landing** (all fixed, all now guarded):
two 3-letter words on stage-4 sheets; four sheets stuck in the rows-only
fallback because a target contained a blocked word (S**HELL**, GR**ASS**…); letters
from *different* words lining up into DIE; three sheets never laying a
diagonal at 86% density; and the test file's own run counter dividing by two,
which would have hidden the fallback defect.

**Art track — the contract is in place, the art is not.** `WordSearchArt`
(`Features/WordSearch/WordSearchArt.swift`) resolves three layers per sheet —
mascot pose (`WS_CHAR_nn_State`, eight states from §13), scene (`WS_ENV_nn`) and
word picture (`WS_WORD_WORD`) — from the asset catalog, falling back to the
emoji mascot moved per state, a painted scene (21 sheets stand in a forest
place, 19 in a code-painted family — `WordSearchScenes.swift`), and the emoji. The mascot's state is
derived from play (`mascotState`), so a rigged character replaces the layer
and inherits the behaviour. `docs/WordSearch/ArtContract.md` is the brief an
artist works from: names, sizes, and the 40-sheet and 249-word tables. Held
by `WordSearchArtTests` and `testTheMascotFollowsPlay`.

**First art through the contract (2026-09-12):** ten CC0 image sets from
Kenney's Animal and Fish packs — 4 idle mascots (sheets 1, 6, 10, 40) and 6
word pictures (HIPPO, MONKEY, PIG, SNAKE, BUNNY, FISH); provenance in
`ThirdPartyArt.md`. That is the whole overlap between those packs and the
word bank. A generator script for the OpenAI Images API exists at
`tools/wordhunt_art.py` (untracked) for when an API key is in the profile.

**Open — not engineering:**
- **The art itself** — **40 of 40 idle mascots** (generated 2026-09-12, one pose
  each; the other 7 states are optional), 0 of 40 painted `WS_ENV` scenes (all
  40 have a code-painted one; a first generated batch was rejected — cut from
  a labelled grid at 171px with the filename baked in — scenes must be one
  full-size image per prompt), 6 of 249 word pictures. Drop image sets in per
  the contract; nothing else changes.
- **Touch size on 10×10 phones** — the spec wants 48pt, the phone gives ~31pt
  with drag-to-line snapping. Decide after watching a child play sheet 31+.
- **Stars earned before `6c905cb`** lived in `UserDefaults` and were not migrated
  (the feature had not shipped).

The rest of this document is the study as written before any code landed.

## Verdict

**Feasible, and most of it is cheap.** The prompt is written for Unity, but every
layer it names has a direct SwiftUI equivalent that already exists in this app.
The engineering is one new engine, one new screen, one SwiftData row and their
tests — comparable in size to the maze or pipe puzzle kinds already shipped.

**The real cost is content and art, not code**, and it splits three ways:

| Part | Feasibility | Why |
|---|---|---|
| Puzzle generator, difficulty stages, uniqueness validation | **High** — 2–3 days | Pure `Sendable` engine + property tests, same shape as `PuzzleGeneratorEngine`; the four §5 stage tables are data |
| Play screen (drag-select grid, word list, reactions) | **High** — 3–4 days | `DotConnectView` already does drag-across-cells; `PuzzleGridView` already does aspect-ratio boards; reward/haptic/sound plumbing is shared |
| 320-word database with zero repeats | **Medium** — 1–2 days | Achievable, but the 40 themes overlap heavily (see risk 1); needs a test, not a promise |
| Per-word illustrations (§9) | **Medium** — emoji today, art later | `WordBank` already maps ~300 words → emoji; a themed illustration for every word is the single largest asset line in the spec |
| 40 art-directed pages with mascot + environment per theme (§10–§14, §18) | **Low as specified** | The app has 1 painted scene family (`ForestSceneBackground`, 8 places), 4 bunny Lotties, and a fox/bird/deer/owl set in the *template* only. 40 unique characters × 8 animation states = ~320 animation assets that do not exist |

So: **build the game now on the assets that exist; treat the 40-page art system as
a separate, budgeted track.** The prompt's own §25 asset separation makes this
safe — the grid, word list and character are independent layers, so pages can
gain art without the puzzle changing.

## What already exists that this reuses

- **Architecture fits without bending.** `ARCHITECTURE.md` §1: pure engines in
  `AI/`, `@Observable @MainActor` view models, protocol repositories. A
  `WordSearchEngine` slots in beside `PuzzleGeneratorEngine`; a
  `WordSearchProgress` row beside `PuzzleProgress` (`SwiftData/Models.swift:341`).
- **Drag-across-cells is solved.** `Features/MiniGames/DotConnectView.swift:690`
  uses `DragGesture(minimumDistance: 0)` with normalised coordinates and a
  view-model `dragBegan/dragMoved/dragEnded` triple. A word search is the same
  gesture snapped to a straight line of cells.
- **Board sizing is solved as of today.** `PuzzleGridView`
  (`Features/Puzzles/PuzzleBoardViews.swift:320`) sizes by aspect ratio with a
  tile cap; the prompt's 48–56pt touch target is a parameter, not a redesign.
- **Word vocabulary and pictures exist.** `AI/WordBank.swift` holds 350+ concrete
  3–4-letter words with an emoji map and a "targets never repeat" draw. It
  covers stage 1–2 word lengths outright; stages 3–4 (up to 8–10 letters) need
  new entries.
- **Never-punish rules are encoded.** `RewardEngine` floors stars; retry copy is
  "Almost!". The prompt's ENCOURAGE state is that rule's animation.
- **Reactions are plumbed.** `soundEngine` (`tap_pop`, `correct_chime`,
  `star_earned`, `confetti_big` Lottie), haptics, `Particles.swift`. The §15
  word-found sequence composes from these; nothing new is needed for a first cut.
- **Routing.** `AppRoute` (`App/AppDependencies.swift:212`) — one new case, one
  `RootView` branch, same as `.puzzleRun`.
- **Seeded determinism** is the house style (`PuzzleSpec` is `Codable`, stories
  regenerate from seeds), so a grid can be reproduced from `(worksheet, seed)`
  and never stored.

## What does not exist

1. **A word-search generator.** Placement with direction constraints,
   intersection caps, filler letters that do not accidentally spell target
   words, and a solvability check. ~300 lines plus tests.
2. **A word database for 40 fixed themes.** `WordBank` is organised by
   *category* (animals, food, home…), not by the prompt's 40 *themes*, and has
   no words over 4 letters.
3. **iPad layout.** `horizontalSizeClass` is used **nowhere** in the app
   (grep count 0). The prompt's iPad-landscape "grid left, words right" is new
   ground for this codebase, though a single `ViewThatFits`/size-class branch
   covers it.
4. **Themed characters.** Only the bunny is animated (4 Lotties + a fallback).
   The template's fox / deer / owl / girl / rabbit are reference art, not assets.
5. **Painted scenes for 39 of the 40 themes.** `ForestPlace` has eight forest
   variants; nothing for space, ocean, castle, city, airport…
6. **A SwiftData row and repository** for word-search progress (level reached,
   stars, words found for the parent dashboard).

## Risks, in order of likelihood

### 1. The 40 themes cannot each own 8 unique words — *content, high*

The prompt forbids any repeat across all 40, then lists themes that share a
vocabulary. Measured overlap in §6:

- Ocean Friends (03) / Underwater Adventure (22) / Coral Reef (23) / Beach Day (09) / River Adventure (35) — five sheets drawing on water words
- Dinosaur Valley (04) / Dinosaur Fossil Hunt (33)
- Space Adventure (05) / Space Station (24)
- Friendly Farm (02) / Farm Harvest (36)
- Enchanted Forest (07) / Woodland Camp (20) / Rainforest (34) / Jungle (06) / Nature Discovery (39)
- Sunny Garden (01) / Spring Meadow (11) / Butterfly Garden (17) / Bug Explorer (18)
- Magical Castle (29) / Dragon Valley (30)

That is 26 of 40 sheets in seven overlapping clusters. A five-sheet water cluster
needs 40 distinct, concrete, 4–7-year-old water words with no plural or
derivative collisions. It is doable — but only with the later sheets in a cluster
taking longer, rarer words (stage 3–4 allow up to 10 letters), which is
conveniently how the difficulty curve is meant to run anyway.

**Mitigation:** author the word table *first*, as data with a unit test that
fails on any duplicate, plural (`s`/`es`), or shared 4-letter stem. This is
exactly `WordBankTests`' existing job, extended.

### 2. Filler letters spell things — *correctness, medium*

Random filler on a 10×10 grid will occasionally form a real word (or a rude one)
by accident, and will sometimes form a *second* copy of a target, making the
puzzle ambiguous. The generator must re-roll fillers until no target appears
twice in any direction, and screen fillers against a small blocklist. Cheap, but
it must be a test, not a hope.

### 3. Diagonal drag on small cells — *UX, medium*

Stage 3–4 grids are 8–10 wide. On an iPhone SE-class width (~320pt usable) that
is 30–38pt cells, under the prompt's 48pt floor. `PuzzleGridView` already
handles the geometry; the decision is whether stage 4 boards scroll, shrink, or
are iPad-preferred. **Recommendation:** shrink to a 32pt floor on phone and
snap the drag to the nearest cell centre line, which forgives the finger — the
same approach `DotConnectView` takes.

### 4. Art volume — *budget, certain*

Per the prompt: 40 mascots × 8 states, ~40 environments, ~320 word
illustrations, 3 raster scales. Nothing in the repo approaches this, and the
existing Lotties were authored programmatically. **Recommendation:** ship v1
with one mascot (the bunny — the app's existing companion, with `wave`, `cheer`,
`thinking` already covering IDLE/CELEBRATE/HINT) and emoji word pictures, and
let the templates define the *asset contract* (`WS_CHAR_xx_Idle` etc.) that art
fills in later. The prompt's own layering rules make this a swap, not a rewrite.

### 5. Reading level — *product, low but real*

Ages 4–5 (stage 1) are pre-readers. `WordBank`'s comment says "words a
five-year-old can *read*", and the ABC adventure pairs every word with a
picture for that reason. The prompt agrees (§9: "🐝 BEE, not BEE"). For stage 1
the picture is not decoration — it is the puzzle. Word-list rows must carry the
illustration from day one, and stage 1 should accept **letter-shape matching**
as the skill, not reading.

## Where it should live

Two viable homes; the template's footers say **SOLVEIT** on `template-garden-solveit.png` and
**FOREST ADVENTURE** on `template-forest-fox.png`, so the art was drafted for both apps.

- **As a Puzzle Quest kind** (`PuzzleKind.wordSearch`, answer mode `.dragLine`):
  inherits worlds, chapters, crystals, daily/weekend runs, the progression
  engine and the parent dashboard for free. But Puzzle Quest's nine worlds do
  not match the prompt's forty themes, and its `PuzzleGrid`/`PuzzleTile` model
  has no letter concept — `PuzzleTile.text` exists but the option/answer
  machinery is built around glyphs.
- **As its own feature** (`Features/WordSearch/`, own engine, own progress
  row): matches the prompt's "40 worksheets in four stages" exactly, and keeps
  the letter-grid model clean. Costs a small repository and dashboard hook.

**Recommendation: own feature.** The prompt's structure (fixed sheet order,
staged difficulty, per-sheet theme) is a *campaign*, not a puzzle kind, and
bending Puzzle Quest's world model to hold 40 themes would cost more than a
40-line repository.

## Estimated effort (engineering only, one developer)

| Slice | Days | Deliverable |
|---|---|---|
| Word table + uniqueness tests | 1–2 | `WordSearchWordBank`: 40 sheets × words, with `illustration` field; test fails on any repeat/plural/stem |
| Generator + stage rules + tests | 2–3 | `WordSearchEngine`: seeded, direction/intersection caps per stage, no accidental duplicates, always solvable |
| Play screen | 3–4 | Grid with drag-select, word list with picture + tick, §15 found-reaction, §16 completion, one mascot |
| Progress, route, dashboard | 1 | SwiftData row, repository, `AppRoute` case, parent-dashboard line |
| iPad layouts | 1 | Size-class branch: stacked on phone, side-by-side in iPad landscape |
| **Total** | **8–11 days** | Playable 40-sheet campaign on existing art |

Art track (not estimated here): per-theme scene, mascot poses, word
illustrations — can land sheet by sheet behind the asset contract.

## What I would do first

1. Write the 40-sheet word table and its duplicate test. This is the only part
   whose feasibility is *not* already proven by existing code, and the overlap
   in risk 1 is where it would fail. If the table cannot be filled honestly, the
   prompt needs its themes merged before any code is worth writing.
2. Then the generator, property-tested over all 40 sheets × 100 seeds.
3. Then the screen, on the bunny and emoji.
