# HOODRXCH — INTEGRATION NOTES (v1)

## 1. Contract topology

```
RenderStateProvider (game side)      HOODRXCHRenderer (this repo)
  reads StatsRegistry,                 Keccak-free pure view code:
  SealAndCoffinRegistry,               MaskGeometry (traits/heightfield)
  SeasonRegistry,                      Glitch/SVGBuilder (paths, glyphs)
  AchievementRegistry,                 HOODRXCHRenderer.renderSVG(state)
  EligibilityModule, WarEngine   ───►  .renderMetadata(state) → tokenURI
        └── returns RenderStateV1        .stateHash(state)
```

- The renderer is **read-only** over `RenderStateV1` (schemaVersion 1). It
  performs no game logic, no ranking, no clock reads.
- The NFT contract's `tokenURI` calls
  `renderer.renderMetadata(provider.renderState(tokenId))` and returns a
  `data:application/json;base64` URI.
- Emit **ERC-4906** `MetadataUpdate(tokenId)` whenever any material field
  (STATE_TO_LAYER_MAP §8) changes; `BatchMetadataUpdate` on season
  finalisation and campaign boundaries.

## 2. Determinism contract

- `genesisHash` is fixed at reveal, per token, forever.
- JS reference and Solidity must produce **byte-identical** SVG and metadata
  for the same state. The fixtures file is the contract for that:
  `reference-renderer` → Fixtures tab → *Export fixtures.json* emits the 30
  canonical states with their `stateHash`; the Foundry differential test
  replays them through the Solidity renderer via `test/differential.t.sol`
  (see `contracts/README` when the port lands).
- Any divergence is a renderer bug: fix Solidity to match JS (the JS file is
  the design source of truth; the chain is the operational source of truth).

## 3. Invalid states are rendered, not reverted

`validate()` codes E01–E12 produce the diagnostic SVG. The renderer must
never revert on bad state — a broken provider must still yield a tokenURI
(handoff: renderer accuracy > prettiness). Marketplace impact is contained:
attributes still report the stored state.

## 4. Upgrade path

- Renderer contract is immutable once pointed at; art upgrades ship as a new
  renderer version + `RENDERER_VERSION` bump; the NFT contract may switch
  renderer only through governance defined in the main PRD.
- `schemaVersion` guards the state ABI: a v2 state requires a v2 renderer;
  v1 renderer refuses (E11) rather than misrenders.
- New badge tiers above 100 kills: versioned namespace only (handoff §9.5) —
  add a tier table entry + halo signature, never re-map existing tiers.

## 5. Size / gas budget (JS reference, current build)

- Live token SVG: ~9.5–17 KB (mean ~10.2 KB over FX-001..030).
- Coffins: ~7.8–8.8 KB. Diagnostics: ~5.5 KB. Banner: ~31 KB.
- Metadata JSON ≈ SVG + ~2.5 KB attributes.
- Solidity port targets the same bytes; gas report to accompany the port
  (string building via `abi.encodePacked` chunks, ~O(lines×points)).

## 6. Marketplace notes

- No `<script>`/`<filter>`/opacity/gradients → renders identically in
  OpenSea/Blur iframe sanitisers, wallets, and X image proxies.
- SMIL flicker is ignored by static rasterisers — the first frame is the
  canonical still.
- PFP crops: the composition is verified at 32/48 px circular; status
  overlays (MARKED slash, coffin, censor bar) stay legible at 32 px.
- Banner endpoint (`renderBanner`) emits 3000×1000 for X/Twitter headers.

## 7. Operational checklist for the game team

1. Freeze season/campaign config before season start (handoff §4).
2. On every state-changing tx, ensure provider fields satisfy E01–E12
   invariants — the diagnostics are your canary in staging.
3. `purgeDeadline`/war phase are context: they do not change pixels except
   through `marked`/lifeState; do not expect countdown animation onchain.
4. Season finalisation: write rank+flags+seasonId atomically (E12 guards).
5. After exhumation: deaths retained, sealsRemaining decremented, lifeState
   ALIVE, exposure ON_THE_STREET — scars render automatically.
