# HOODRXCH — Signal Wraith Renderer (V1, work in progress)

Fully generative, fully onchain-ready SVG renderer for the 666-supply dynamic
ERC-721 collection on Base. The reference implementation is a single
self-contained HTML file — no build step, no dependencies, no external assets.

## View the generator

Open **`reference-renderer/index.html`** in any browser (double-click works).
Tabs:

- **Workbench** — every `RenderStateV1` field as a control; live SVG at
  512/128/64/32px and circular PFP crop on black & white; metadata JSON + byte sizes.
- **Review 24** — 24 random tokens at 256/64/32, reseedable.
- **Gallery 666** — the whole collection + trait rarity table.
- **Evolution** — kill tiers 0→100 (colour ladder + halo corona) and death damage.
- Fixtures / Banner — next build steps.

## How the art works

The image is a field of horizontal signal lines displaced by a skull-form
heightfield (integer centi-unit math, bit-exact portable to Solidity). The
hooded figure exists only as a disturbance in the signal. Eyes are the only
solid fills (X-dynasty archetypes + glow treatments). Kill tier drives a
colour ladder (acid → pink → white) and a crest-following halo corona,
ending in the full REAPER ring.

Palette: `#000000` · `#CCFF00` acid · `#FF3EB5` pink · `#FFFFFF` white ·
`#FF2A2A` red reserved for MARKED / TERMINAL.

## Repo layout

- `src/` — the renderer source, concatenated by `build.sh` into `reference-renderer/index.html`
- `tools/` — node scripts for CLI rendering and proof sheets (need `npm i playwright` for screenshots)
- `proofs/` — current review sheets, PFP-size simulations, evolution ladder
- `docs/` — state→layer mapping (being rewritten for the signal-wraith language)

Mechanics source of truth: `HOODRXCH_Dynamic_NFT_Mechanics_Handoff.md` (not in this repo).
