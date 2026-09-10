# HOODRXCH artist handoff

Date: 2026-09-10. Game rules: `HOODRXCH_SEASON_1_RULES_V1`. This document is the artwork brief for the final single-Season mechanics. Read it independently of the old six-day/Hunter game. The accompanying [mechanics specification](GAME_MECHANICS_LOCK_20260910.md) defines authoritative outcomes; the renderer only draws them.

## What to deliver

Adapt the existing [HOODRXCH renderer](https://0xgreencross.github.io/hoodrxch-renderer/) to the game below. Keep the SIGNAL WRAITH visual identity, geometry, committed traits, signal lines, palette, glyphs, coffins, scars, halos and banner language. The user has authorized changes to dynamic art to match the final game. Do not redesign genesis traits or change token assignments to make fixtures look better.

Deliver the updated JavaScript reference, matching Solidity renderer source/generators, a new versioned render-state contract, all seven updated preview tabs, full fixtures, a change log and a pinned source commit. If the artist delivers only the JavaScript/reference artwork, clearly label the Solidity port as outstanding for the game engineers. Do not claim JS/Solidity parity without comparing actual outputs.

The game currently vendors `612225ac0918eacfd30bbb6a1874f281a5bc60bd`. The last fully inspected live reference is `863a164f93f5529a095a7452679ef4a8ac86edd6`. Preserve the original user `fixtures.json`; export a separately versioned new fixture set. Browser-local Curate decisions require their own `hoodrxch_trait_rules.json` export and are not contained in `fixtures.json`.

## The game in one page

- 666 NFTs. Three Wards, each with six Blocks. There are 18 Ward/Block combinations, 37 characters per combination.
- One Season, six War slots, normally 72 hours each. All Blocks participate together.
- Living characters are automatically exposed unless their owner bought WITSEC before that War.
- Owners can request up to three targets during the first 24 hours. Pending requests are not active marks. Random allocation resolves competing requests.
- Accepted attacks activate together. Marked characters have 24 hours to Purge. Execution then has a six-hour window.
- WITSEC costs 0.0023 ETH for one War. Purge costs 0.0033 ETH to save a marked character. These prices belong in the app/reference controls, not permanent genesis art.
- First death: coffin, then return with scars next War. Second death: another coffin and return with more history. Third death: permanent terminal coffin.
- The final closing also returns first-/second-death coffins. There is no War 7. Temporary statuses clear; permanent earned art remains.
- An attack accepted before the attacker died can still earn that attacker a kill. A terminal character can therefore advance visually and win a Season badge.

## 1. Seven achievable evolution stages

Use actual kills and a single versioned shared threshold table. Preserve the existing seven distinct visual treatments. Do not fake a count of 100 to get the Reaper layer.

| Actual kills | Stage | Existing treatment to retain |
|---:|---|---|
| 0 | NONE | Genesis signal and eyes |
| 1 | FIRST BLOOD | First pink halo arc |
| 2 | RISING THREAT | Pink crest escalation and second arc |
| 3 | SAVAGE | Stronger pink figure, white crest and broken outer arc |
| 4 | EXECUTIONER | Pink figure, stronger white structure and radiating ticks |
| 5–6 | DEATH DEALER | Extended white crest/corona treatment |
| 7+ | REAPER | White figure, pink echo and full ring treatment |

This replaces both the original `0/1/10/25/50/75/100` and the interim `0/1/2/3/5/7/10` proposal. Numeric kills continue above seven. Kill notches may retain their nine-notch visual cap, but metadata and the stats band must show the real value. A visual cap is not a capped stat.

Death never lowers a tier. On coffins, preserve the coffin composition and show earned tier through a compatible small crest/halo or record treatment. The terminal red verdict must remain dominant and unmistakable. Reaper must not make a terminal character appear alive.

## 2. Active states and precedence

Use this precedence for the primary composition: `TERMINAL > COFFINED > MARKED > WITSEC > PURGED > ALIVE`. Treat mutually contradictory inputs as diagnostics rather than silently hiding the contradiction. Season phase and finite transfer lock are context, not extra protection choices.

| State | Art requirement | Meaning |
|---|---|---|
| ALIVE | Existing living figure, permanent history visible | Exposed during combat; resting before/after it |
| Pending request/allocation | Keep ordinary living art; app/reference may show a pending label | No accepted incoming attack yet; never show MARKED red early |
| MARKED | Existing red danger treatment | Accepted incoming attack, still awaiting Purge/execution/expiry; same-Ward attacker is valid |
| WITSEC | Retain recognisable eye-redaction treatment | Protection bought before this War; cannot attack or be attacked |
| PURGED | New distinct acid/white rescued treatment, permanent save stitch visible | Incoming attack was paid off; safe for the rest of this War |
| COFFINED | Existing first-/second-death coffin and remaining seals | Returns next War or at Season closing |
| TERMINAL | Existing permanent red terminal coffin | Three deaths, zero seals; collectible and eligible for awards |
| Season COMPLETE | Final living or terminal composition and final records | No current threat/protection countdown |
| Season INTERRUPTED | Same permanent state plus a restrained archival label in stats/banner | Emergency ended play; history is still real |

PURGED must not reuse the red danger slash, imply an extra life or look identical to WITSEC. Reuse existing save-stitch and acid/white vocabulary. A small shield/clearance treatment is acceptable if it remains distinct at 32 pixels. On the next War, remove the temporary rescued overlay but retain its permanent save history.

Remove HUNTER SELECTED, LAY LOW and BUYER PROTECTED from Season 1 choices, metadata and the Evolution status row. Dormant historical source can remain versioned. Do not disguise one of those names as the new Purged state. Remove three-credit WITSEC counters and single-active-Block labels. A finite transfer lock does not mean the character is protected.

## 3. Death, scars and seals

| History | Current composition | Seals |
|---|---|---:|
| No deaths | Living genesis/progression figure | 3 |
| First death, waiting | Coffin 1 | 2 |
| First return | Living, first permanent scar history | 2 |
| Second death, waiting | Coffin 2 | 1 |
| Second return | Living, both permanent scar histories | 1 |
| Third death | Terminal coffin permanently | 0 |

Use canonical game-supplied damage seeds. Do not reconstruct scars from current owner, block timestamp, demo seed, transaction order or an unrelated token number. The same death history must produce the same scars after revival and transfer. Never clear scars when protection begins or the Season finishes.

Each death record identifies the actual killer and victim, their Wards and Blocks, death number and War. Both same-Ward and cross-Ward histories are valid. Showing the killer's identity does not mean ownership changed.

## 4. Wards, Blocks and badges

Keep all three Ward sigils and all six Block marks. Labels must read the character's immutable Ward and Block. Block 1 in Ward 1 differs from Block 1 in Ward 2. Do not show a rotating active Block because every cell is active.

Season awards use kills, then fewer deaths. Tied characters share a competition rank. More than ten characters can receive Top 10, and more than five can receive Top 5. Rank 1, 1, 3 is valid; never invent unique ranks to fit a ten-item display.

Retain the white Top 10 and pink Top 5 vocabulary. Show both on Top 5 recipients, together with Season ID. Make them visible on living, revivable coffin and terminal art, and in banners and stats profiles. Badges belong to the NFT's history; whether a wallet has claimed ETH is not an art achievement and must not remove or change a badge.

The territory ladder records one award per qualifying War, at most six this Season. A winning Ward must have a positive rival-combat score; its characters need at least one rival-Ward kill that War to earn the tick. The game supplies the count and result. The artist must not derive winners from palette, holdings, saves, money spent or a same-Ward kill. Preserve true totals if a future version extends the visual count.

## 5. State data supplied by game engineering

The semantic fields below are the artist/game agreement. They are not permission to append fields to the existing ABI-frozen `RenderStateV2`. Engineering must publish a new schema/interface and wire Core, provider, renderer and indexer together.

| Group | Required data and rendering rule |
|---|---|
| Version | New schema version, renderer version and rules/tier-table version |
| Identity | `tokenId`, `artIndex`, `wardId`, `blockId`, immutable trait commitment and genesis seed input |
| Season context | Season ID, War number 0–6, phase, complete/interrupted status; no fake Campaign/active Block |
| Primary state | Life state, protection `NONE/WITSEC/PURGED`, deaths 0–3 and seals 0–3 |
| Incoming attack | Attacker token/Ward/Block, common activation, Purge deadline and execution cutoff; zero when no live incoming attack |
| Transfer | Effective lock flag and finite expiry, independent of protection |
| Combat history | Actual kills, terminal kills, forced Purges, saves received and given |
| Streak | Current/longest values from the last settled War; label that scope in reference/metadata |
| Death history | Up to three canonical death seeds/records; unused slots zero; past records immutable |
| Awards | Final competition rank, Top 10/Top 5 flags, award Season, territory count |
| Display | Canonical static, animated, stats and 3000×1000 banner profiles |

Genesis generation uses `artIndex`. Displayed NFT numbers use `tokenId`. Explicitly test token 42 with art index 7: all banners and metadata must say `#42`, while the original art-index-7 identity remains unchanged.

Numeric metadata must be truthful. Remove obsolete Hunter/credit/buyer-protection attributes in the new schema. Keep WITSEC and Purged distinguishable. Invalid inputs produce deterministic diagnostics with the actual token ID and versioned state hash. A valid same-Ward attack must never fall back to genesis or diagnostics.

The renderer takes a supplied state and renders it. It does not call an oracle, read live clocks, award ranks, calculate payments or write game state. Countdown timers belong in the app. Use a versioned canonical state hash that includes every field affecting bytes; avoid collisions between visual profiles or rule versions. The same complete input must yield the same SVG and metadata bytes.

## 6. Update every preview tab

| Tab | Required amendment |
|---|---|
| Workbench | New schema controls, Purged state, six-War/closed context, real IDs, all profiles and diagnostic cases |
| Review 24 | Revised status/progression/terminal-badge samples at large, small and circular sizes |
| Gallery 666 | Preserve demo-vs-committed assignment distinction; exercise all 18 Ward/Block cells and avoid changing genesis allocation |
| Evolution | Seven stages `0/1/2/3/4/5/7`; full death/return strip; ALIVE, MARKED, WITSEC, PURGED, COFFINED and TERMINAL examples; terminal winner |
| Fixtures | New full-state fixtures and expected complete outputs/hashes, with explicitly invalid cases kept separate |
| Banner | Living, Marked, WITSEC, Purged, both coffins, terminal Reaper, tied winner and closed/interrupted examples |
| Curate | Preserve nine immutable trait axes; export curation rules separately; dynamic gameplay toggles must not rewrite genesis traits |

## 7. Fixture and acceptance checklist

Provide a versioned fixture bundle with full input state, expected diagnostic codes, SVG, metadata JSON, banner SVG and content hashes. Length alone is not parity. Preserve old fixtures as historical evidence; do not rewrite their expected bytes under an unchanged version.

Required coverage:

- Actual kills 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 and 18, across all visual profiles. Verify seven is Reaper and six is Death Dealer.
- All 18 Ward/Block combinations and at least one `tokenId != artIndex` fixture in every profile.
- Every primary state, first/second scar returns, terminal with zero kills and terminal with Reaper and Top 5 awards.
- A terminal attacker's kills increasing after death, without losing its terminal composition or changing old scars.
- Same-Ward/different-Block mark, Purge and all three deaths, as well as cross-Ward equivalents.
- Pre-activation requests, activation, exact Purge boundary, execution, expiry, cancelled War, delayed start, final return and interrupted Season.
- Tied Top 5 and Top 10 recipients, zero awards, six territory ticks, and award visibility on coffins/banners.
- WITSEC transfer, post-Purge outgoing kill, finite transfer lock without protection, and final cleared temporary state.
- Invalid combinations: terminal with seals; living with three deaths; MARKED plus WITSEC/Purged; coffin with active mark; wrong Ward/Block/ID; missing or dirty death slots; Top 5 without Top 10; stale mark fields; unsupported version.
- Determinism, JSON/XML validity, no external asset dependence, small circular crops, readable still frames and animation-disabled output.

The canonical static image must show a complete character immediately. The animated version may use an introduction, but a static rasterizer must not receive an empty construction frame as the sole image. Keep all SVG/metadata fully onchain and self-contained. Use the existing integer geometry and embedded glyph approach. No external fonts, images, scripts or network fetches are needed to render a token.

The latest reviewed animated reference reached about 505,075 SVG characters. Old roughly-10-KB notes are obsolete. Engineering must measure compiled runtime size, worst-case rendering gas, encoded tokenURI size and actual RPC/marketplace acceptance. Do not silently remove the animation, replace art with an offchain URL or claim marketplace support from local screenshots. Byte-identical JS/Solidity output and real integration checks remain outstanding until the new delivery exists.

## 8. Division of work

The artist owns visual adaptation, reference controls, visual fixtures, documentation and the agreed renderer source delivery. Game engineering owns state truth, new schema/ABI integration, canonical seeds, snapshots, treasury logic, version switching and emitted metadata-update events. Both review parity and small-size visibility.

Engineering must fix the existing indexed ERC-4906 event layout, banner ID mix-up and missing collection invalidation on renderer switches. These cannot be fixed by changing artwork alone. Every kill, Purge, death, revival, award, boundary status change and approved renderer switch needs correct metadata refresh.

Final acceptance means the artist's exact pinned output is reproduced through the game's actual onchain provider and `tokenURI`, with valid end-to-end history. The handoff defines that destination; it does not claim the current contracts already deliver it.
