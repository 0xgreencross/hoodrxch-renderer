# HOODRXCH — State → Layer Map (v0.1, for approval)

Status: DRAFT awaiting founder/artist approval. Nothing is drawn until this is signed off.
Precedence: Handoff v1.0.0-draft (mechanics) > Master Prompt v2 (visuals) > this document.

This is the contract between `RenderStateV1` and the picture. Every state dimension is listed with the layer it drives, its z-order, what overrides it, and what it must never cover. The JS reference renderer and `HOODRXCHRendererV1.sol` both implement exactly this table.

---

## 1. Canvas and colour law

| Item | Value |
|---|---|
| viewBox | `0 0 1000 1000` (banner `0 0 3000 1000`) |
| Logical grid | 100 units = 1000 px; all base vertices are integers on the 100-grid, scaled ×10, then jittered ±1…2 units from the genesis RNG (see §8) |
| Colours | `#000000` ground/hood · `#CCFF00` everything lit · `#FF2A2A` only in MARKED, TERMINAL_COFFIN, DIAGNOSTIC |
| Forbidden SVG | `<script>`, `<filter>`, gradients, `opacity`, patterns, external `href`, fonts/`<text>` |
| Text | Block glyphs A–Z 0–9 `#` `/` `.` as `<path>` in `<defs>`, placed via `<use>` |
| Figure height (PLAIN) | 75–80 % of canvas; black ≥ 60 % of canvas on a genesis token |

## 2. Z-order (bottom → top)

| z | Layer id | Driven by | Notes |
|--:|---|---|---|
| 0 | `GROUND` | constant (red border in MARKED / TERMINAL) | full-bleed black rect |
| 1 | `GHOST` | genesis glitch trait 3, kill tier ≥ REAPER, flicker | green silhouette offset 2–3 u behind |
| 2 | `HOOD` | genesis traits (silhouette, rim, edge, collar, block mark) | black mass + green rim |
| 3 | `SKULL` | `deaths` ≥ 1 (tears), COFFINED/TERMINAL (compressed mask) | green, only where exposed |
| 4 | `DAMAGE` | `deaths`, `savesReceived`, `forcedPurges` | tears, cracks, stitch-scars, tally notches |
| 5 | `FACE` | genesis traits eyes / mouth / ward sigil | green cut-outs in hood |
| 6 | `ORNAMENT` | `tierForKills(kills)` | additive kill decoration |
| 7 | `STATUS` | precedence resolver (§4) — exactly one | crosshair / shield / bars / MARKED kit |
| 8 | `SEALS` | `sealsRemaining` | three seal glyphs on figure bottom edge |
| 9 | `BADGES` | kill tier, `latestSeasonBadgeFlags`, `latestAwardSeasonId` | slots A/B/C |
| 10 | `TERRITORY` | `territoryAchievementCount` | thin top strip, own slot |
| 11 | `FRAME_HUD` | `displayMode == 1` only | frame, corner marks, stat panel, padlock if `transferLocked` |
| 12 | `DIAGNOSTIC` | impossible state | replaces all of the above |

Glitch displacement slices (genesis trait, SAVAGE+, MARKED recolour, flicker) are applied to the composed group z1–z6 via `<clipPath>`+`translate`, never to z7+. Status, seals and badges are never sliced, so critical information is never displaced out of the frame.

## 3. Dimension → layer table

### 3.1 Immutable identity

| Field | Layer | Effect |
|---|---|---|
| `genesisHash`, `tokenId` | RNG seed | `rng = keccak256(abi.encodePacked(genesisHash, uint16 tokenId))`; traits drawn in fixed order (§8) |
| `wardId` | FACE (brow sigil) + HUD + banner | Ward 1 chevron, Ward 2 three bars, Ward 3 diamond. Fixed, non-random |
| `blockId` | HOOD (collar block mark, 6 glyph variants) + HUD | `BLOCK 0x` text in STATS |
| `artIndex` | metadata only | not drawn (identity already fully defined by `genesisHash`) |

### 3.2 Life state (`lifeState`, enum MaskLifeState)

| Value | Figure | Colour | Overrides |
|---|---|---|---|
| `ALIVE` (0) | mask | black/green | — |
| `MARKED` (1) | mask + MARKED kit (red crosshair, red eye drips, red band with `purgeDeadline`, red canvas border, slices recolour red) | adds red | all decoration; badges drawn as outlines only |
| `COFFINED` (2) | green coffin outline containing compressed mask (silhouette + eyes readable), death number, `markedByTokenId` as killer, broken seals, kill crest on lid | black/green | everything except seals & crest |
| `TERMINAL_COFFIN` (3) | red coffin, red mask inside, `TERMINAL` glyphs, all seals broken, red border | red | everything. No badges, no animation, no HUD overlays except frame in STATS |

`marked == true` must agree with `lifeState == MARKED`; disagreement is an impossible state.

### 3.3 Exposure state (`exposureState`, enum ExposureState) + booleans

The renderer trusts the booleans `witsecApplies`, `laidLow`, `buyerProtected` for drawing and uses `exposureState` for metadata and consistency checks.

| Condition | STATUS layer | Eyes |
|---|---|---|
| `witsecApplies` | solid green shield contour around head | thin lines |
| `buyerProtected` | dashed green shield contour | thin lines |
| `laidLow` | three horizontal black bars across face | hairline slits |
| `ON_THE_STREET`, none of the above | nothing | genesis eyes |

Only one of these three may be true (handoff §14.1, §3: buyer protection consumes no WITSEC, Lay Low is manual). If more than one is true → impossible state.

### 3.4 Combat role

| Field | Layer | Effect |
|---|---|---|
| `hunterSelected` | STATUS (lowest precedence) | green crosshair etched on forehead. Hidden when any protection or MARKED/coffin applies |
| `markedByTokenId`, `markedByWardId` | MARKED band / coffin text | glyphs `BY #0123` |
| `purgeDeadline` | MARKED band | unix seconds in block glyphs (no countdown — handoff §5) |

### 3.5 Permanent progression

| Field | Layer | Effect |
|---|---|---|
| `kills` → `tierForKills` | ORNAMENT + BADGES slot A + HUD | NONE nothing · FIRST_BLOOD X-stitch one eye + mouth drip · RISING_THREAT X both eyes + spike row · SAVAGE shoulder chain + permanent 2nd slice · EXECUTIONER collar noose + flame-teeth edge · DEATH_DEALER flame crown + both chains · REAPER tall cowl + scythe + ghost duplicate. Strictly additive |
| `lifetimeKillTier` (provided) | none | **ignored for drawing**; renderer derives from `kills` (handoff §9.3). Mismatch is reported by the fixture harness, not rendered |
| `deaths` | SKULL + DAMAGE + coffin text | 1: one tear exposing skull patch · 2: second larger tear, cracks, missing teeth · 3: must be TERMINAL |
| `sealsRemaining` | SEALS | 3/2/1/0 intact glyphs; broken = hollow cracked outline. Must equal `3 - deaths` |
| `savesReceived` | DAMAGE | one stitch-scar per save across hood, max 5 drawn |
| `forcedPurges` | DAMAGE | tally notches on collar (or scythe at REAPER), max 10 drawn |
| `savesGiven`, `currentKillStreak`, `longestKillStreak`, `terminalKills` | HUD (STATS) + metadata | `STREAK` shows `currentKillStreak` |

Tear placement (jaw vs cheek, left vs right) and scar angles are chosen from a **death seed**. `RenderStateV1` does not carry `coffinSeed` — see open item O-3. Until resolved, the reference renderer derives `damageSeed = keccak256(genesisHash, tokenId, deaths)` and flags it as provisional.

### 3.6 Achievements

| Field | Layer | Effect |
|---|---|---|
| `latestSeasonBadgeFlags` bit0 `TOP_10` | BADGES slot B | crowned-skull shield, season number inside |
| `latestSeasonBadgeFlags` bit1 `TOP_5` | BADGES slot C | laurel shield, season number inside. Drawn only if slot B drawn; bit1 without bit0 → impossible state |
| `latestAwardSeasonId`, `latestSeasonRank` | inside crests / HUD `SEASON` | |
| `seasonAwardCount` | metadata only | older seasons are not drawn (handoff §10.6) |
| `territoryAchievementCount > 0` | TERRITORY strip | Ward sigil + count, top edge, never replaces B/C |

Badge slots in PLAIN: three 8×8 u cells at lower-left of the figure area (x 4–12, y 66–90 approx). STATS: a full left column at 16×16. Badges are green only; in MARKED they reduce to outlines; in coffin states only the kill crest survives (on the lid); in TERMINAL nothing.

### 3.7 Temporary context

| Field | Layer | Effect |
|---|---|---|
| `warId`, `campaignId`, `seasonId`, `activeBlockId`, `warPhase` | metadata + HUD | `SEASON` in stat panel; rest metadata only |
| `transferLocked`, `transferLockUntil` | metadata; padlock glyph in STATS frame | never in PLAIN |
| `displayMode` (proposed) | FRAME_HUD | 0 PLAIN, 1 STATS |
| `flicker` (proposed) | SMIL on z1–z6 only | off by default; frame 0 = static composition; never touches z7+ |

## 4. Precedence resolver (handoff §14, law)

```
if lifeState == TERMINAL_COFFIN        → TERMINAL
else if lifeState == COFFINED          → COFFINED
else if lifeState == MARKED || marked  → MARKED
else if witsecApplies                  → WITSEC
else if buyerProtected                 → BUYER_PROTECTED
else if laidLow                        → LAY_LOW
else if hunterSelected                 → HUNTER_SELECTED
else                                   → ALIVE
```

Permanent layers (identity, damage, seals, ornament, badges, territory) are drawn alongside the resolved status except where the table in §3.2 says the status suppresses them. Nothing above z7 may cover a red mark, the red band, or the terminal coffin.

## 5. Impossible states → DIAGNOSTIC layer

Rendered as: black field, red border, red block glyphs `INVALID STATE`, a short reason code, and the 8-hex-byte prefix of `stateHash`. Never guessed.

| Code | Condition |
|---|---|
| `E01` | `TERMINAL_COFFIN` with any of `witsecApplies`, `laidLow`, `buyerProtected`, `hunterSelected`, `marked` |
| `E02` | `COFFINED` with `hunterSelected`, `marked`, or any protection |
| `E03` | `MARKED` (or `marked`) with `witsecApplies` or `laidLow` |
| `E04` | `sealsRemaining == 0` and `lifeState != TERMINAL_COFFIN` |
| `E05` | `deaths >= 3` and `lifeState != TERMINAL_COFFIN`, or `TERMINAL_COFFIN` with `deaths < 3` |
| `E06` | `sealsRemaining + deaths != 3` |
| `E07` | `TOP_5` flag set without `TOP_10` |
| `E08` | more than one of `witsecApplies` / `laidLow` / `buyerProtected` |
| `E09` | `marked != (lifeState == MARKED)` |
| `E10` | `exposureState` inconsistent with `lifeState` (`COFFINED`/`TERMINAL` exposure on alive token or vice-versa) |
| `E11` | `wardId ∉ 1..3`, `blockId ∉ 1..6`, `tokenId ∉ 1..666`, `schemaVersion != 1` |
| `E12` | `latestSeasonBadgeFlags != 0` with `latestSeasonRank == 0` or `latestAwardSeasonId == 0`; or rank 1–5 without TOP_5 / 6–10 without TOP_10 |

Question for founder: should E06/E12 be hard diagnostics or soft (render, report in harness only)? Default here: **hard**.

## 6. State hash (material fields)

`stateHash = keccak256(abi.encode(schemaVersion, tokenId, artIndex, wardId, blockId, genesisHash, seasonId, lifeState, exposureState, sealsRemaining, hunterSelected, transferLocked, marked, markedByTokenId, purgeDeadline, witsecApplies, laidLow, buyerProtected, kills, deaths, forcedPurges, savesReceived, currentKillStreak, latestAwardSeasonId, latestSeasonRank, latestSeasonBadgeFlags, territoryAchievementCount, displayMode))`

Excluded (do not change the SVG): `warId`, `campaignId`, `activeBlockId`, `warPhase`, `transferLockUntil`, `markedByWardId`, `witsecCredits`, `savesGiven`, `longestKillStreak`, `terminalKills`, `lifetimeKillTier`, `seasonAwardCount`, `deathRecordCount`, `historicalStateCount`, `flicker`. They appear in JSON only; the JSON hash is a separate concern. Open item O-4 asks whether the provider's `stateHash` should use this exact list.

## 7. Display modes

| | PLAIN (0) | STATS (1) |
|---|---|---|
| Frame | none | crude-clean frame, corner marks |
| Text | none (except MARKED deadline, coffin numbers) | `#id`, `WARD 0x`, badge column with tier name + threshold, stat panel KILLS/DEATHS/K/D/SEALS/SEASON/STREAK, bottom `RXCH` / `BLOCK 0x`, padlock if locked |
| Figure | 75–80 % height | scaled to ~60 % in a right-of-centre cell |
| Badges | 8×8 | 16×16 column |

K/D per handoff §16.3: `UNTESTED` / `UNDEFEATED` / one-decimal ratio.

## 8. Genesis trait draw order (locked once approved)

1 hood silhouette (8) · 2 eyes (10) · 3 mouth (8) · 4 ward sigil (fixed) · 5 rim (4) · 6 edge (5) · 7 glitch (4, ≤ 1 in 3 tokens non-none) · 8 collar (5) · 9 block mark (fixed by `blockId`, 6). Then jitter stream. Changing the order changes every token, so this is part of the provenance commitment.

## 9. Open items (not resolved silently)

| ID | Item | Proposed default |
|---|---|---|
| O-1 | "SEASON CHAMPION 01" in founder reference; handoff defines TOP_10/TOP_5 only | Style TOP_5 crest as the champion-grade laurel; no third badge until `SeasonRegistry` exposes a rank-1 flag |
| O-2 | `displayMode` and `flicker` absent from `RenderStateV1` | Add `uint8 displayMode` + `bool flicker` to the struct, or read from a `BadgeDisplayRegistry`; default 0/false |
| O-3 | No death/coffin seed in `RenderStateV1`; coffin composition and tear placement need one | Add `bytes32 latestCoffinSeed` (handoff §15.1) to the provider struct. Reference renderer uses a provisional derived seed until then |
| O-4 | Which fields the provider's `stateHash` covers | The list in §6 |
| O-5 | Killer tokenId in coffin text: reuse `markedByTokenId` or add `killedByTokenId`? | Reuse `markedByTokenId` (the executed warrant), but confirm it is retained after execution |
| O-6 | 100-unit grid + deterministic jitter as frozen provenance (vs 64×64 bitmap in ART-MECH-TBD-010) | Accept 100-unit vector grid; the manifest hashes renderer build + trait draw order instead of bitmaps |
| O-7 | Coffins keep the kill crest on the lid | Yes |
| O-8 | Animated SVG in canonical `tokenURI` | No; static default, `flicker` opt-in via display state |
| O-9 | Hard vs soft diagnostics for E06/E12 | Hard |
