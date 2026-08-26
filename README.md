# ByteBite

Eat. Score. Streak.

ByteBite is an offline-first calorie and macro tracker for people who want a terminal-flavoured food log. It reads Open Food Facts, caches every resolved packet on device, and scores each commit. There is no account, no ads, no analytics, and no medical claim — it is a personal food log.

## Architecture

ByteBite uses **MVI (Model-View-Intent)**.

Each screen owns:

- an `Intent` enum (the only thing a view may emit)
- an immutable `Model` render state
- a `Processor` that maps `Intent → Model`

Views have exactly one `render(model:)` entry. Transitions are total `switch`es, so illegal input (zero grams, planning an interrupt, a stale search response) is a defined model, not a crash. That fits a gamified logger: every swipe, scan and commit is a discrete event that must be replayable and testable.

The kitchen seam is `KitchenKernel`. Renderers never touch the event tape. Persistence is an append-only JSONL log (`events.jsonl`) plus an in-memory projection, snapshotted every 200 events and replayed on launch.

Files are grouped **by intent**: `Intents/`, `Models/`, `Processors/`, `Renderers/`, `Kernel/`.

Scoring and streak math live in the local SPM package `Packages/ByteKit`, referenced by relative path.

## Unique feature

Gamification is the reason to pick this app over a plain diary.

- XP per eaten commit (reduced when energy data is missing)
- combo multiplier when two or three macros land inside a ±15% band of target
- daily streak with freeze tokens (one missed day can be bridged; a token is granted every 7 streak days)
- unlockable badges on the profile card

Today draws the XP bar and streak flame in `Canvas` + `TimelineView`. Profile shows level, XP curve and a badge grid. Plan horizon is **14 cycles**.

Slots are named for a machine: **boot / runtime / shutdown / interrupt**. Interrupt is snack: eaten-only. A future date remaps interrupt to **runtime** (midday).

A day is an `Int` YYYYMMDD, shown as hex (`0x01352B19`).

## How this app differs

It is not a tab bar reskin. Navigation is a **swipeable card stack** (today, log, plan, wish, profile). Search and scan are full-screen overlays. Detail and assign are one **commit card** that awards XP.

UI chrome is drawn in Canvas, not stacked meter views. Copy is lowercase Courier New on a black phosphor terminal. Naming follows a computing lexicon (`IntakeBuffer`, `KitchenKernel`, `flushBuffer()`).

## Build

```bash
cd App09_ByteBite
/path/to/xcodegen generate
xcodebuild -scheme ByteBite -destination 'generic/platform=iOS' build
xcodebuild -scheme ByteBite -destination 'platform=iOS Simulator,name=iPhone 16' test
```

iOS 17+, Swift 6.2, strict concurrency complete. No CocoaPods. Local package: `Packages/ByteKit`.

Simulator-only demo seed is gated by `byb.demo.v1`.

Contact: https://bytebite.pro/contact-us

Nutrition data is credited to [Open Food Facts](https://world.openfoodfacts.org).

## AI art

Style: 16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel.

Base prompt reused for every asset:

```
16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel
```

Exact prompts:

**byb_AppIcon** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, the app's single emblem, centred, filling the canvas edge to edge`

**byb_Splash** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a vertical hero composition with a calm, uncluttered centre band`

**byb_Onboarding1** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a person or object representing discovering what is in packaged food`

**byb_Onboarding2** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a scanning or measuring motif showing a product being identified`

**byb_Onboarding3** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a goal or target motif showing daily progress being met`

**byb_EmptyLog** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an empty vessel, surface or container waiting to be filled`

**byb_EmptySearch** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a search motif that has come back with nothing found`

**byb_EmptyPlan** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an empty schedule, grid or horizon with nothing scheduled`

**byb_EmptyWish** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an empty basket, list or shelf`

**byb_SlotBoot** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a morning motif appropriate to the theme`

**byb_SlotRuntime** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a midday motif appropriate to the theme`

**byb_SlotShutdown** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an evening motif appropriate to the theme`

**byb_SlotInterrupt** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a small extra or in-between motif appropriate to the theme`

**byb_MacroProtein** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a symbol standing for protein, rendered as a single clear emblem`

**byb_MacroCarbs** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a symbol standing for carbohydrate, rendered as a single clear emblem`

**byb_MacroFat** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a symbol standing for dietary fat, rendered as a single clear emblem`

**byb_ProductPlaceholder** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a generic packaged grocery item with no readable branding`

**byb_CardBackdrop** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an abstract backdrop suitable for sitting behind a product card`

**byb_Texture** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a seamless repeating surface pattern`

**byb_ControlFace** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, the face of a single physical control such as a dial, key or slider handle`

**byb_ScanOverlay** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a framing reticle or targeting bracket, open in the middle`

**byb_TwistHero** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, an emblem representing this app's signature feature`

**byb_SuccessMark** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a confirmation mark or celebratory emblem`

**byb_HeaderDecor** — `16-bit pixel art, retro game sprite, neon green phosphor and amber on black, chunky pixels, CRT scanline feel, a wide decorative band or ornament`
