# HOODRXCH renderer — change log (newest first)

Every entry ships through the differential gate (all fixtures byte-identical JS↔Solidity)
unless marked JS-only.

> ⚠ **CURATION IN PROGRESS**: a trait-compatibility rules pass will produce one more renderer
> change and a rules-final pinned commit. Build against this freely; make the FINAL renderer
> deployment only from the rules-final pin.

## 2026-09-19 — integration pass: profiles, identity, feasibility

- **CANONICAL STATIC profile.** `renderSVG(s, profile)` / `renderMetadata(s, profile)` with
  `0 STATIC · 1 ANIMATED · 2 STATS · 3 BANNER`, matching the numbering the game's
  `IHOODRXCHRendererV2` already uses. Profile 0 emits zero `<animate>` elements — free,
  because every base attribute was already the finished art. Default stays ANIMATED and is
  asserted byte-identical per fixture. JS `_renderMetadata` now calls `_renderSVG`, so a
  static profile's metadata can no longer embed the animated image.
- **Identity: `genesisSeed(genesisHash, artIndex)`.** The token ID reaches metadata and the
  HUD only. Demo `genesisHash` keyed on art index to match production's
  `_genesisHashForArtIndex`. New fixture FX_033 (token 42 / art index 7) + invariant test.
- **Scars bound to their own death.** `damageSeed(genesisHash, artIndex, deathIndex)` replaces
  the running-total seed, so a second death can no longer re-roll the first scar. New fixtures
  FX_034/035/036 walk one token through deaths 1→2→3 + invariant test. Art change: tokens with
  2+ deaths render differently; single-death tokens are unchanged.
- **Feasibility work** (all byte-exact, proven by the gate):
  - static renders no longer compute the ten conveyor keyframes they never emit
  - `Ctx.hm` memoises the 34×512 height sampling grid shared by `convCovers` and the NO SIGNAL
    clip; `socketBandX` skips the height sample for columns that cannot touch an eye socket
  - `unchecked` on the bump/height/rounding math (`heightAtD` 6,542 → 1,695 gas)
  - assembly `itoa` (3,132 → 1,156 gas), assembly base64, `MCOPY` in `Buf.app`
  - `evm_version = "cancun"` to match the game repo's frozen toolchain
  - result: static tokenURI 526M–1,072M → 68M–112M gas, payload 675,988 → 44,737 bytes worst
- **Measured EIP-170 for the first time:** `GenesisLib` 86,130 B, `HOODRXCHRenderer` 45,822 B,
  `StatusLib` 24,829 B against a 24,576 limit. The monolith is undeployable; the game's
  generated module split is load-bearing. See `INTEGRATION_GUIDE.md` §5.1.
- New `Identity.t.sol` and `Budget.t.sol`; `Differential.t.sol` grows to 36 fixtures with six
  assertions each. `gen_difftest_local.js` fails the build if a static profile emits SMIL.

## 2026-09-10 — Season 1 art progression
- Kill tiers now ACHIEVABLE per `HOODRXCH_SEASON_1_RULES_V1`: 0/1/2/3/4/5/7
  (was 0/1/10/25/50/75/100). 5–6 = DEATH DEALER, 7+ = REAPER. Only the threshold table moved.
- Evolution tab strip → 0/1/2/3/4/5/7. Fixtures re-spread to realistic kills incl. the 6-vs-7
  boundary.

## 2026-09-09 — Curation system + GIF export (JS/workbench tooling)
- CURATE tab: `TRAIT_OV` seed bypass (forces trait values while burning the exact blessed rng
  stream — `TRAIT_OV=null` is byte-identical to production), guided pairwise sweep, export.
- `export_gif.js`: seamless loop-only PFP GIF; optional construction-intro mode.

## 2026-09-09 — CONSTRUCTION INTRO + animation architecture fixes
- Construction intro, fully onchain (SMIL, one-shot): field populates bottom-up (0.5s), hood
  extrudes via variable-speed columns from the spine (0.5s), eyes ignite on independent
  flicker rhythms, mouth materialises per-motif (15 distinct effects), then the rest in 0.25s
  succession. Base attributes stay the finished art.
- Dash-phase continuity; BARCODE intro width morph; coffin heartbeat rises out of the flatline.
- `cy` pinned to 52 (with `cx=50`): every hood dead-centre for circular crops. New `Intro.sol`.

## 2026-09-07 — All 9 LINES styles animated (conveyor completion)
- BARCODE standing slot widths; NO SIGNAL dual band clipped to the hood silhouette.
  Fixtures 30 → 32.

## 2026-09-07 — THE CONVEYOR (eternal loop) + dead-centre hoods
- Per-row animate-d keyframes in integer deci-units, image-identical wrap; blessed break runs
  as stationary holes; position-keyed kill-tier colours; echoes as static ghosts.

## 2026-09-06 — Circular-crop safety + coffin/status polish
