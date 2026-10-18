# HOODRXCH — renderer integration guide

**To:** game engineering
**From:** artist side
**Date:** 2026-09-19
**Supersedes:** `hoodrxch_season1_engineering_package` (2026-09-10) and everything vendored before it.

---

## 1. Why the game draws its own version of the art

It isn't drawing its own version. It's drawing a faithful copy of a renderer that is four
generations old.

`scripts/renderer/generate-solidity-genesis-libraries.mjs` reads
`vendor/hoodrxch-renderer/contracts/src/GenesisLib.sol`, checks it against

```
const expectedSha256 = "3ebad4d631c04e6fff746744bb44cb8495893a1fe0fd4785b78c5675354680f0";
```

and text-splits it into `contracts/src/renderer/genesis/*V2.sol`. That pin is commit
`612225ac0918eacfd30bbb6a1874f281a5bc60bd` — **51,646 bytes of GenesisLib against today's
94,170**. Everything shipped since is missing from the game:

| shipped | in the pinned copy |
|---|---|
| THE CONVEYOR — every LINES style flows, wrap-exact (AE=0) | no — the field is static |
| CONSTRUCTION INTRO — populate, extrude, eye ignition, per-mouth glitch | no |
| `cx=50 / cy=52` centre pin (circular-crop safety) | no |
| Season 1 kill tiers `0/1/2/3/4/5/7` | no — still `0/1/10/25/50/75/100` |
| BARCODE + NO SIGNAL animated fields | no |

The proof is in your own generated file. `RendererGenesisBuildV2.sol` line 57:

```solidity
function tierForKills(uint256 kills) internal pure returns (uint256) {
    if (kills >= 100) return 6;   // <- the pre-amendment table
```

Your differential passes 1,332/1,332 because it compares the generated split against that
same stale pin. The gate is sound; the input is old. **Nothing in the game needs
re-architecting. The pin needs moving, and the generator needs to learn the new functions.**

The generator's SHA check is the thing that saved you here — it is doing exactly its job.
Keep it.

---

## 2. What to do, in order

1. **Re-vendor.** Replace `vendor/hoodrxch-renderer/` with this package's `src/`,
   `contracts/`, `build.sh`, `render_cli.js`, `gen_difftest_local.js`,
   `reference-renderer/`.

2. **Update the generator pin** in `generate-solidity-genesis-libraries.mjs`:

   ```
   const expectedSha256 = "e4049abba703e75f9887d6bb62470eade5cfae218f546cd409250f32021ed816";
   ```

3. **Teach the generator the new functions** — see the module map in §3. The seams you
   already have are right; the conveyor is a new module.

4. **Regenerate**, then repoint your differential at this package's `contracts/js_expected/`.
   It now carries **36 fixtures × 6 assertions** instead of 32 × 3 (see §6).

5. **Take the profile selector.** `renderSVG(state, profile)` now exists on the canonical
   renderer with the exact numbering `HOODRXCHRendererV2` already uses:
   `0 CANONICAL_STATIC · 1 ANIMATED · 2 STATS · 3 BANNER`. Point `tokenURI` at profile 0 —
   §5 explains why that is not optional.

6. **Delete the divergence risk.** Once the generated modules match, `RendererLiveV2` and
   `RendererCoffinV2` should carry no art of their own: `_renderValidProfile` routes to the
   generated canonical modules and nothing else. Also delete the duplicated `_killTier` in
   `HOODRXCHRendererV2.sol` and `RendererStateAdapterV2.sol` — both still hold the
   pre-amendment table, and a second copy of a rule is a second chance to be wrong.

---

## 3. Module map for the generator

Existing modules keep their functions. New and moved ones:

| module | functions |
|---|---|
| `RendererGenesisTypesV2` | structs `Line`, `Ctx` (**now carries `bool anim` and `int256[] hm`**), `Pre`, `Sched`, **`Conv`** |
| `RendererGenesisFieldV2` | `buildLines`, `preDraws`, `buildLinePaths` *(unchanged seam)* |
| **`RendererGenesisConveyorV2`** *(new — the largest module)* | `convDisturb`, `convRowKey`, `convColors`, `convEchoes`, `rowWOf`, `bcSlotW`, `strokeOfCol`, `widthOfCol`, `dashHas`, `dashFv`, `convDash`, `convIntroRow`, `convEmitRow`, `convHoles`, `hAt`, `socketBandX`, `convGapC`, `convCovers`, `bandData`, `conveyorField`, `noSignalField`, `legacyEchoes`, `fieldGroups` |
| `RendererGenesisEyeGlyphV2` | `eyeArm`, `octRing`, `octFill`, `eyeGlyph`, `drawEyes` |
| `RendererGenesisMouthV2` | `mouthMarks`, **`glitchReveal`**, **`gAn`**, **`gTr`**, **`gClip`**, **`gSc`** |
| `RendererGenesisEyesV2` | `eyesAndRest`, `damageSeed` |
| `RendererGenesisHaloV2` | `haloInto` |
| `RendererGenesisFigureV2` | `buildFigure`, `figRank`, `swOf` |
| `RendererGenesisSlicesV2` | `mkSlices`, `damageSeed` |
| `RendererGenesisBuildV2` | `build`, `genesisSeed`, `damageSeed`, `tierForKills` |

New shared dependency: **`Intro.sol`** (`secs`, `kt4`, `reveal`, `flickL`, `flickR`, `ghost`) —
vendor it alongside `Mask`/`Rng`/`Num` rather than generating it.

Two signature changes the `typed()` rewrites must carry:

- `GenesisLib.build(RenderStateV1 s, bool anim)` — the profile flag threads through `Ctx.anim`.
- `StatusLib.coffinSVG(s, anim)`, `witsecOverlay(g, anim)`, `buyerOverlay(g, anim)`,
  `flickerSVG(s, anim)` — same flag.

`Ctx.hm` is a 17,408-entry memoisation grid (§5). **It must never cross an ABI boundary** —
encoding it would cost more than the render. Allocate it inside whichever module owns
`convCovers`/`noSignalField`, not in `build`.

---

## 4. The two correctness items from your review — fixed

Your `ENGINEERING_PACKAGE_REVIEW_20260911.md` said the package "uses token ID where art index
must seed identity" and "rerolls earlier scars". Both are now fixed in the renderer, and both
have standing tests.

**Identity.** `genesisSeed(genesisHash, artIndex)`. The token ID reaches metadata and the HUD
and nothing else. `test_ArtIndexSeedsTheWraith` runs the handoff's own case — token 42 wearing
art index 7 — and asserts all nine traits equal art index 7's, then asserts art index 42's
traits differ, so the test can't pass vacuously. Fixture `FX_033` pins the bytes.

Note the demo `genesisHash` is now keyed on the art index too
(`keccak("HOODRXCH_GENESIS_V1", artIndex)`), matching `_genesisHashForArtIndex` in
`HOODRXCHRendererV2.sol`. Ward and block still come from token state, as they should — they
are registry facts, not art.

**Scars.** Was:

```solidity
Rng.init(damageSeed(genesisHash, tokenId, s.deaths))   // ONE stream for ALL deaths
```

so a second death re-rolled the first scar and a wraith's history rewrote itself. Now:

```solidity
for (k2 = 0; k2 < s.deaths; k2++)
    Rng.init(damageSeed(genesisHash, artIndex, k2 + 1))   // one death, one stream
```

`test_EarlierScarsNeverMove` renders the same token at one death and at two, extracts the
first scar path from the one-death render, and asserts it appears byte-for-byte in the
two-death render. Fixtures `FX_034/035/036` walk one token through deaths 1 → 2 → 3.

A single-death token renders identically to before. Only tokens with 2+ deaths move, and only
because their later scars are now bound to the death that caused them.

**This is a deliberate art change.** If you are holding earlier renders as evidence, they
change for multi-death tokens.

---

## 5. Feasibility — measured, not estimated

Your `KNOWN_BLOCKERS.md` sets the ceiling at "the lower of 45,000,000 gas or 80% of the lowest
certified limit", and the handoff asked for runtime code size and heaviest-path gas to be
measured. Both are measured now, on this package, under `via_ir`, `optimizer_runs = 1`,
`evm_version = "cancun"`.

### 5.1 EIP-170 — the renderer does not fit, and never did

```
GenesisLib         86,130 B   limit 24,576   OVER BY 61,554
HOODRXCHRenderer   45,822 B   limit 24,576   OVER BY 21,246
StatusLib          24,829 B   limit 24,576   OVER BY    253
```

The monolith is undeployable. **Your generated split is not an optimisation — it is the only
reason the art can go on chain at all.** Treat it as load-bearing architecture and keep it.
`StatusLib` is 253 bytes over and needs one function moved out; the coffin EKG block is the
obvious candidate.

### 5.2 tokenURI gas

Measured as `renderMetadata(state, profile)` — the full base64 data-URI payload, which is what
`tokenURI` returns.

| fixture | static payload | static gas | animated payload | animated gas |
|---|---|---|---|---|
| FX_001 ALIVE | 30,565 B | 68.4M | 311,153 B | 386M |
| FX_011 WITSEC | 44,263 B | 70.3M | 378,471 B | 409M |
| FX_025 STATS | 44,737 B | 71.9M | 335,537 B | 414M |
| FX_031 BARCODE | 34,016 B | 78.4M | 336,872 B | 408M |
| FX_026 FLICKER | 35,228 B | 73.5M | 563,540 B | 827M |
| FX_020 heaviest records | 43,284 B | 101.7M | 675,988 B | 1,119M |
| FX_032 NO SIGNAL | 42,032 B | 111.8M | 606,872 B | — |
| FX_016 TERMINAL | 12,768 B | 35.2M | 12,768 B | 35.2M |

Where it started, before this pass: **526M–1,072M gas** for the same static renders, and
**675,988 bytes** of tokenURI at worst. What moved it:

1. **CANONICAL STATIC profile** — zero `<animate>` elements. Keyframe `values=` attributes
   were 86% of an animated payload. Free, because of the renderer's standing invariant: every
   base attribute is already the finished art and animations only ride on top. A marketplace
   that ignores SMIL already saw exactly this frame.
2. **Skipping unread keyframes** — a static render emits frame 0, so the other ten keyframes
   per row were being computed and thrown away. Largest single win.
3. **Memoising the height field** — `convCovers` and the NO SIGNAL clip walk the same
   34×512 sampling grid, and each walked it twice. Now computed once (`Ctx.hm`), plus an
   x-bounds test that skips the height sample entirely for columns that cannot touch an eye
   socket.
4. **Arithmetic** — `unchecked` on the bump/height/rounding math (the overflow checks cost
   ~7× the arithmetic they guarded: 6,542 → 1,695 gas per `heightAtD`), an assembly `itoa`
   (3,132 → 1,156 gas per number printed), an assembly base64, and `MCOPY` in `Buf.app`.

All of it proved byte-identical by the differential. Not one pixel moved.

#### Profile 4 MARKETPLACE — measured

The approved marketplace policy (still as `image`, animation as `animation_url`) is
implemented and under the gate, but one call pays for **both** renders:

| fixture | market payload | market gas |
|---|---|---|
| FX_001 ALIVE | 339,251 B | 476M |
| FX_037 PURGED | 338,739 B | 481M |
| FX_016 TERMINAL | 23,062 B | 63.8M |
| FX_044 TERMINAL + crest | 24,999 B | 64.8M |

Read that against §5.3 before pointing `tokenURI` at profile 4: on a live wraith it is ~7×
the static profile. The decision is design-correct and costs nothing in design terms — the
static art was always the finished art — but serving it from `tokenURI` depends on closing
the gap below, and render-and-store (option 1) closes it for profile 4 as cleanly as for
profile 0. Until then, point `tokenURI` at profile 0 and let an indexer that can raise its
own `eth_call` cap serve profile 4.

### 5.3 The remaining gap

**Static tokenURI is 68M–112M against a 45M ceiling.** Honest reading: another ~2× is
probably available with more work on `convCovers` and the emit path, but it is not sitting
there waiting. Three ways to close it, in the order I'd rank them:

1. **Render-and-store.** Compute the static SVG once per state change into SSTORE2 and have
   `tokenURI` read it back. State changes are rare — a kill, a death, a protection change — and
   a read is trivial. This is the standard pattern for art this heavy and it fits your
   registry cleanly. It also makes the ceiling a non-question forever.
2. **Raise the `eth_call` cap** on infrastructure you control. `tokenURI` is a view call; no
   on-chain gas is spent. The 45M figure is a policy choice about third-party RPC limits, not
   physics. Worth confirming what the marketplaces and indexers you actually care about will
   execute before optimising against a number nobody enforces.
3. **Keep optimising.** Real, but with diminishing returns and rising risk to byte-exactness.

TERMINAL and COFFINED states already land at 35M, comfortably inside.

---

## 6. How to verify

```sh
sh build.sh                                    # JS reference -> reference-renderer/index.html
node gen_difftest_local.js                     # regenerate Differential.t.sol + js_expected/
cd contracts && forge test                     # 111 tests, ~5 min
```

Three suites:

- **`Differential`** — 36 fixtures. Each asserts `stateHash`, and `keccak256` of: the animated
  SVG, the metadata, the **static SVG**, the **stats SVG**, the **static metadata**, and the
  explicitly-numbered profile 1 (so the default can never silently drift from ANIMATED).
  Five fixtures also assert the banner. Full output hashes, never lengths.
- **`Identity`** — the two invariants from §4.
- **`Budget`** — prints the §5.2 table.

`gen_difftest_local.js` also fails the build if either static profile emits a single
`<animate>` element.

---

## 7. Still owed by engineering — the schema

Your review said engineering owns this, and I agree: *"Publish `RenderStateV3`, profile
selectors, version getters, complete hash encoding, identity rules and canonical death-record
semantics."* Profile selectors and identity rules are delivered above. The struct is yours.
What the art needs from it:

- **~~`protection` as `NONE / WITSEC / PURGED`~~ → now just `bool purged`.** Superseded:
  the PURGED treatment is designed, approved and shipped (`docs/SEASON_1_ART_DECISIONS.md`
  §1). It needs exactly one bit. The renderer declares `SCHEMA_VERSION = 2`, accepts
  `schemaVersion` 1 **or** 2, and only folds `purged` into `stateHash` for states that
  declare 2 — so a v1 state renders and hashes exactly as it did before, and PURGED starts
  working the day the game sets the bit. Nothing on the art side is blocked on this any
  more; the state just renders as ALIVE until the bit arrives. A fuller `protection` enum is
  fine too if you prefer it — map `PURGED` onto this bit and the art is unchanged.
- **Drop `hunterSelected`, `laidLow`, `buyerProtected`, `witsecCredits`, `activeBlockId`.**
  Season 1 removes them. Deleting their overlays also buys back contract size, which §5.1 says
  we need.
- **`warId` 0–6, `warPhase`, `warComplete`, `warInterrupted`.**
- **Canonical death records.** `RenderStateV2` already carries `bytes32[3] deathSeeds`,
  `uint16[3] killerTokenIds`, `uint64[3] executionBlocks` — exactly right. Today the renderer
  derives each scar's seed as `keccak(genesisHash, artIndex, deathIndex, "DMG")`, which is
  already immutable per death. When V3 lands I'll switch scar *k* to read `deathSeeds[k]` so
  the mark is tied to the execution that caused it. Same property, better provenance.
- **`currentKillStreak` scoped to the last settled War**, per the amendment.
- A new versioned `stateHash` covering every byte-affecting field. The current one is
  V1-shaped and will need to grow.

Send the struct and worked JSON examples; the art side implements against it and ships a new
separately-versioned fixture bundle. The current `js_expected/` stays as historical evidence
under its own version.

---

## 8. One thing still open on the art side

A trait-compatibility curation pass is in progress — which trait values may appear together.
It changes only which bytes *some* tokens render to, inside the trait engine, behind the
state→bytes interface. **Nothing in §2 needs redoing when it lands**, but hold the final
renderer deployment until the rules-final pin ships.
