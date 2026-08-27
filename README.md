# HOODRXCH — Signal Wraith Renderer (V1)

Fully generative, fully onchain SVG renderer for the 666-supply dynamic
ERC-721 collection on Base. The reference implementation is a single
self-contained HTML file — no build step, no dependencies, no external assets —
mirrored one-to-one by a Solidity renderer with differential tests.

**Live generator:** https://0xgreencross.github.io/hoodrxch-renderer/

## View the generator

Open **`reference-renderer/index.html`** in any browser (or use the live link).
Tabs:

- **Workbench** — every `RenderStateV1` field as a control; live SVG at
  512/128/64/32px and circular PFP crop on black & white; metadata JSON + byte sizes.
- **Review 24** — 24 random tokens at 256/64/32, reseedable.
- **Gallery 666** — the whole collection + trait rarity table.
- **Evolution** — kill tiers 0→100 (colour ladder + halo corona), the full
  death cycle (COFFINED → EXHUMED → TERMINAL), and every status overlay.
- **Fixtures** — FX-001..FX-030 canonical states (diagnostics included) +
  `fixtures.json` export for the Solidity differential tests.
- **Banner** — 3000×1000 X-banner compositions.

## How the art works

The image is a field of horizontal signal lines displaced by a skull-form
heightfield (integer centi-unit math, bit-exact portable to Solidity). The
hooded figure exists only as a disturbance in the signal. Eyes are the only
solid fills (X-dynasty archetypes + glow treatments). Kill tier drives a
colour ladder (acid → pink → white) and a crest-following halo corona,
ending in the full REAPER ring. Death flatlines the signal into a coffin
void; the third death nails it shut in red.

Palette: `#000000` · `#CCFF00` acid · `#FF3EB5` pink · `#FFFFFF` white ·
`#FF2A2A` red reserved for MARKED / TERMINAL / diagnostics.

## Repo layout

- `src/` — the renderer source, concatenated by `build.sh` into `reference-renderer/index.html`
- `contracts/` — Solidity port (Foundry): byte-identical renderer + 30-fixture
  differential test suite + gas report — see `contracts/README.md`
- `docs/` — STATE_TO_LAYER_MAP, BADGE_REGISTRY, ATTRIBUTE_SCHEMA, INTEGRATION_NOTES
- `tools/` — node scripts for CLI rendering, proof sheets, and differential-test
  generation (`gen_difftest.js`)
- `proofs/` — review sheets, PFP-size simulations, state proofs

Mechanics source of truth: `HOODRXCH_Dynamic_NFT_Mechanics_Handoff.md` (not in this repo).

## Determinism

Same `RenderStateV1` → byte-identical SVG and metadata in JS and Solidity.
`genesisSeed = keccak(genesisHash ‖ uint16(tokenId))` fixes the art forever;
`damageSeed` scars are stable per death count. The renderer reads state only —
no clocks, no chain randomness, no game logic.
