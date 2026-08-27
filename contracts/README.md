# HOODRXCH — Solidity renderer (v1)

Byte-identical Solidity port of `reference-renderer/index.html`. Same
`RenderStateV1` → same SVG, same metadata JSON, same stateHash, same banner —
verified by a differential test suite against the JS reference.

## Layout

```
src/RenderState.sol      RenderStateV1 struct (handoff §13.2)
src/Rng.sol              keccak byte-stream RNG (pool, rehash on exhaustion)
src/Buf.sol              appendable byte buffer (linear-memory string build)
src/Num.sol              itoa / jsRound / floorDiv / base64 / hex helpers
src/Glyphs.sol           5×7 block-glyph font, first-use-ordered <defs>
src/Geom.sol             pathD / poly / rect / xmark / slice primitives
src/Mask.sol             traits + heightfield + sigils (MaskGeometry)
src/Types.sol            shared pipeline types
src/GenesisLib.sol       buildGenesis — the SIGNAL WRAITH figure
src/StatusLib.sol        coffins, status overlays, HUD, stats band, flicker
src/MetaLib.sol          ERC-721 metadata JSON
src/BannerLib.sol        3000×1000 banner
src/HOODRXCHRenderer.sol validate / stateHash / renderSVG / renderMetadata / renderBanner
test/Differential.t.sol  AUTO-GENERATED — FX-001..FX-030 vs JS reference hashes
test/Gas.t.sol           per-call gas + byte report
```

## Differential testing

The JS reference is the design source of truth. Regenerate expectations after
any renderer change:

```
node tools/gen_difftest.js   # (from the repo root; writes test/Differential.t.sol
                             #  and contracts/js_expected/*.svg|json for eyeballing)
forge test
```

All 30 fixtures assert keccak256 equality of: `stateHash`, `renderSVG` bytes,
`renderMetadata` bytes, and (FX-001/007/009/016/028) `renderBanner` bytes.
Any intentional art change ⇒ rerun the generator; any unintentional
divergence ⇒ fix Solidity to match JS.

## Gas / size (solc 0.8.28, via-ir, optimizer runs=1)

| fixture | renderSVG gas | renderMetadata gas | svg bytes |
|---|---|---|---|
| GENESIS | 32.5M | 36.6M | 8,142 |
| REAPER (100 kills) | 46.1M | 53.3M | 14,328 |
| MARKED | 33.2M | 38.1M | 9,639 |
| COFFINED | 32.5M | 36.6M | 7,993 |
| TERMINAL | 31.5M | 35.4M | 7,784 |
| STATS mode | 47.2M | 55.3M | 16,132 |
| diagnostic | 3.5M | 6.4M | 5,569 |
| banner | 41.9M | — | 21,608 |

`tokenURI`/`renderSVG` are `view` — users never pay this gas; it runs in
`eth_call`. Budget accordingly on the RPC side (some public RPCs cap eth_call
gas around 50M; self-hosted nodes and indexers should raise the cap). No
render path writes state.

## Building

Requires [Foundry](https://getfoundry.sh) and `forge-std`
(`forge install foundry-rs/forge-std`). `via_ir = true` is required.

## Notes

- All arithmetic mirrors JS semantics exactly: `Math.trunc` division →
  native int division; `Math.round(a/b)` → `floorDiv(a + b/2, b)`;
  `x|0` truncation including its JS operator-precedence quirks.
- The renderer never reverts on impossible states — it renders the red
  diagnostic frame with E-codes, exactly like the JS.
- `RenderStateProvider` wiring, ERC-721 integration and ERC-4906 events are
  the game repo's responsibility (see docs/INTEGRATION_NOTES.md).
