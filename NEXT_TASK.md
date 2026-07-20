# Next task — resume here (saved for after usage-limit reset)

Requested by gautam. Continue from this when the session resumes.

## 1. Home screen — beautify the meadow & bunny
- **Redraw the bunny** (currently a plain SF-symbol/simple shape): give it
  fur texture, visible legs, and a properly waving hand/paw. Make it CUTE
  and detailed, drawn in SwiftUI (no Lottie dependency needed, but a Lottie
  version is acceptable — see Resources/Animations, python-lottie is
  available in the workspace to author JSON).
- **Fix sizing/overlap**: the bunny is too big and covers the
  "Welcome back Reyaansh!" speech bubble. Shrink it / reposition so the
  greeting is always readable.
- **Add hopping rabbits along the bottom** of the home page — realistic
  hop cycle (crouch → push → airborne → land), a few of them, looping.
- **Real meadow background** instead of the flat green→black gradient:
  layered rolling hills, grass, sky with soft clouds, sun. Give it a
  sense of DEPTH / pseudo-3D (parallax layers, overlapping hills,
  lighting/shading gradients per layer).
- **Add a little house** in the meadow (cottage: walls, roof, door,
  window, maybe smoke).

Relevant files: Features/Home/HomeView.swift, RootView.swift (ForestIntro
+ Splash use LottieView .bunnyWave), DesignSystem/AnimatedForestBackground.swift,
DesignSystem/LottieView.swift, Resources/Animations/*.json.

## 2. "Your Forest" screen — turn it into an immersive 3D forest
Current state: Features/Forest/ForestView.swift renders unlocked
ForestElements as scattered EMOJI (`element.emoji`) at fixed positions —
looks like emojis piled on each other (houses on foxes), flat/2D.

Wanted:
- An **immersive 3D forest** the child can **scroll/pan through with a
  finger** (explore left/right/into depth).
- Proper scene composition (no overlapping/mixed-up elements): ground
  plane, trees at varying depths, **castle on a faraway hill**,
  **dragon flying in the sky** (already have a snake-flight dragon in
  ForestView — reuse/upgrade), **foxes running around**, **flowers**,
  **real butterflies moving**. Everything animated.
- **Double-tap to enter** the forest (zoom/immerse), **double-tap again
  to exit**. Should feel like being INSIDE the forest.
- Likely approach: RealityKit/SceneKit for true 3D (we already have
  RealityKit in Features/ARForest), OR a layered parallax pseudo-3D in
  SwiftUI with Canvas + drag-to-pan + depth scaling. Decide based on
  effort; parallax SwiftUI is the pragmatic first pass, RealityKit is the
  "real 3D" version. Discuss trade-off with user, or ship parallax first.

## Working notes
- Keep the app fully offline; no new copyrighted assets.
- python-lottie, cairosvg, ffmpeg are available in the workspace for
  authoring animations/sounds/art and VALIDATING them (render frames to
  PNG and view before shipping — this caught real bugs before).
- Commit in reviewable chunks with the established author identity.
- Branch is several commits ahead of origin; user pushes manually.
