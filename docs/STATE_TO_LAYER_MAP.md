# HOODRXCH — STATE → LAYER MAP (v1, SIGNAL WRAITH)

Renderer version 1 · schema version 1 · canonical mechanics: `HOODRXCH_Dynamic_NFT_Mechanics_Handoff.md`

The renderer is a **pure function of RenderStateV1**. It never reads clocks,
block numbers or randomness at render time. Same state → byte-identical SVG,
in the JS reference (`reference-renderer/index.html`) and in `contracts/`.

## 1. The visual language

Every token is a field of 47 horizontal signal lines on a 100-unit grid
(×10 px, integer coordinates only). A skull-form heightfield — flat-top
plateau + crown peak + jaw shelf − nasal dent, all integer centi-unit math —
displaces the lines upward, so the hooded figure exists only as a
*disturbance in the signal*. Eyes are the only solid fills.

Palette (locked): `#000000` ground · `#CCFF00` acid signal · `#FF3EB5` pink
echo · `#FFFFFF` white (specks, crests, structure). `#FF2A2A` red is
**reserved**: it may appear only in the MARKED overlay, the TERMINAL coffin
verdict, and diagnostic renders.

Constraints: no `<script>`, no `<filter>`, no gradients, no opacity, no
external refs. `<defs>/<use>` for the figure group and block glyphs.
Animation is SMIL only (`flicker`). Text on tokens uses the 5×7 block-glyph
font; the live figure itself is wordless.

## 2. Z-order

| z | layer | source fields |
|---|-------|---------------|
| z0 | black ground | — |
| z1 | white specks | genesisHash |
| z2 | pink echo pass | genesis trait `pink`, kill tier ≥ REAPER |
| z3 | signal field (colour-grouped acid/pink/white) | genesisHash, kills |
| z4 | eyes + treatments | genesis traits, kill tier escalation |
| z5 | permanent record: kill notches, purge tallies, save stitches, death scars, mouth marks | kills, forcedPurges, savesReceived, deaths |
| z6 | ward sigil (top-left) + block mark (bottom-right) + kill-tier halo | wardId, blockId, kills |
| z6.5 | mosh slices + death slices (displace z1–z6) | genesis trait `mosh`, deaths (damageSeed) |
| z7 | status overlay (exactly one, see §4) | resolveStatus(state) |
| z8 | HUD: seal pips (top-right), latest season chips (left), territory ladder (right edge) | sealsRemaining, latestSeason*, territoryAchievementCount |
| z9 | STATS band (hem) | displayMode = STATS |
| z10 | flicker scanlines (SMIL) | flicker |

COFFINED / TERMINAL_COFFIN replace z1–z7 with the coffin composition (§5).
Invalid states replace everything with the diagnostic render (§7).

## 3. Kill-tier ladder (z3/z4/z6)

Tier = `tierForKills(kills)`: 1/10/25/50/75/100 →
FIRST_BLOOD/RISING_THREAT/SAVAGE/EXECUTIONER/DEATH_DEALER/REAPER.

Colour roles within the locked palette:

| tier | figure signal | crest lines | eyes | halo (crest-following corona) |
|------|---------------|-------------|------|-------------------------------|
| 0 NONE | acid | — | trait | — |
| 1 FIRST BLOOD | acid | — | trait | 1 pink arc |
| 2 RISING THREAT | crest-6 pink | — | ≥ ECHO GLOW | 2 pink arcs |
| 3 SAVAGE | upper figure pink | 1 white | ≥ ECHO GLOW | 3 pink arcs, outer broken |
| 4 EXECUTIONER | full figure pink | 2 white | FULL SIGNAL | white arc + radiating ticks |
| 5 DEATH DEALER | full figure pink, background thinned | 4 white | FULL SIGNAL | + corona ray triangles |
| 6 REAPER | full figure white + pink echo of 8 crest lines | — | FULL SIGNAL | full white ellipse ring + pink echo ring |

Halos are crisp strokes — **no glow layers** (art direction, 2026-08-27).
Kill notches: 1 pink notch per kill above the left eye, cap 9.

## 4. Status overlays (z7) — precedence

`resolveStatus`: TERMINAL_COFFIN > COFFINED > MARKED > WITSEC >
BUYER_PROTECTED > LAY_LOW > HUNTER_SELECTED > ALIVE. Exactly one overlay
renders. Overlays sit **above** the mosh slices so status stays legible.

| status | composition |
|--------|-------------|
| MARKED | red warrant slash corner-to-corner, red corner brackets, 8 red purge ticks on the crown edge. Only red use on a live token. |
| WITSEC | the eyes are redacted: white censor bar across both sockets + two white interference bars below |
| LAY_LOW | gone dark: black blinds close over the figure + small acid down-chevron above the crown |
| BUYER_PROTECTED | in escrow: thin acid holding frame inset 60 px + acid diamond top-centre |
| HUNTER_SELECTED | quiet white sight ticks N/S/E/W of the skull |
| ALIVE | no overlay |

## 5. Coffin compositions (COFFINED / TERMINAL_COFFIN)

The signal flatlines. The field renders **undisplaced** (still, torn), and a
coffin-shaped hexagonal void interrupts it — the wraith is gone; the signal
refuses to run where the body lies. Structure (outline, nails) is white.

- COFFINED (revivable): white flatline across the canvas with **one residual
  heartbeat blip**; the eye archetype survives as pink ember glyphs inside
  the void; seal pips inside the coffin (acid = intact, pink slashed =
  broken). Exhumation restores the live figure with scars.
- TERMINAL_COFFIN (permanent): perfectly flat **red** line, two red planks
  nail the void shut, three red broken seals, no eyes. Field tears heavier.

Identity persists in both: ward sigil, block mark, genesis-derived field
texture, death-scar slices (damageSeed). Kill/season records remain in
metadata (handoff §2.4).

## 6. HUD (z8–z9)

- **Seal pips** (top-right, live states): 3 pips; acid filled = remaining,
  pink slashed outline = broken. Coffins carry their pips inside the void.
- **Season chips** (left, SLOT B/C per handoff §10.6): latest award only.
  `S<n>` label + white `10` chip when `badgeFlags&1`; + pink `5` chip when
  `badgeFlags&2`. Never rendered without a valid rank/season (E12).
- **Territory ladder** (right edge): 1 acid tick per
  `territoryAchievementCount`, cap 12, climbing from the hem.
- **STATS band** (`displayMode=STATS`): black hem band, acid rule, two
  glyph rows — `K/D/KD/STK` and `TIER / W B / S RANK`.
- **Flicker**: two SMIL scanline sweeps (white 7 s down, pink 11 s up).

## 7. Impossible states → diagnostic render

`validate(state)` returns codes; any code ⇒ red-framed diagnostic SVG with
`INVALID STATE`, the codes, tokenId and stateHash prefix. Codes:

| code | rule |
|------|------|
| E01 | TERMINAL with protection/hunter/marked |
| E02 | COFFINED with protection/hunter/marked |
| E03 | MARKED with witsec or laidLow |
| E04 | sealsRemaining 0 but not TERMINAL |
| E05 | deaths/TERMINAL mismatch (3 deaths ⇔ TERMINAL) |
| E06 | sealsRemaining + min(deaths,3) ≠ 3 |
| E07 | TOP_5 flag without TOP_10 |
| E08 | more than one protection flag |
| E09 | marked flag ≠ (lifeState==MARKED) |
| E10 | lifeState/exposureState coffin mismatch |
| E11 | ward/block/tokenId/schema out of range |
| E12 | badge flags inconsistent with rank/season |

## 8. stateHash

keccak256 over `abi.encode`-style 32-byte words of the material fields, in
order: schemaVersion, tokenId, artIndex, wardId, blockId, genesisHash,
seasonId, lifeState, exposureState, sealsRemaining, hunterSelected,
transferLocked, marked, markedByTokenId, purgeDeadline, witsecApplies,
laidLow, buyerProtected, kills, deaths, forcedPurges, savesReceived,
currentKillStreak, latestAwardSeasonId, latestSeasonRank,
latestSeasonBadgeFlags, territoryAchievementCount, displayMode.
Non-material fields (warId, campaignId, warPhase, counts…) are excluded.

## 9. Determinism seeds

- `genesisSeed = keccak(genesisHash ‖ uint16(tokenId))` — all genesis traits
  and the render byte stream (`Rng`: keccak pool, rehash on exhaustion).
- `damageSeed = keccak(genesisHash ‖ tokenId ‖ deaths ‖ "DMG")` — death
  scars and death slices; stable per death count, survives exhumation.
- Banner extension stream: `keccak(genesisSeed ‖ "BNR")`.

## 10. Banner (3000×1000)

The token's own render (any state, coffins and diagnostics included) sits in
the left third as a nested `<svg>`; its signal field continues across the
full width; `HOODRXCH` wordmark + `#id / WARD / BLOCK / TIER` line +
status line (red for MARKED/TERMINAL) in block glyphs; seal pips and a kill
tally block on the right edge; acid divider at x=1000.
