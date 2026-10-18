# Season One art decisions — approved 2026-10-18

Five decisions the game was waiting on. Each was drawn by the real renderer as
two to three candidates, reviewed against the live states they have to sit next
to, and chosen. Proof sheet: `proofs/season1_states.png`.

Everything here is shipped and under the differential gate. The one thing that
is *not* shipped is the game-side plumbing for a single new bit — see §6.

---

## 1. PURGED — candidate A, "warrant cut"

Someone paid to close an active warrant and the wraith lived. It stays PURGED
for the rest of that War.

The look is deliberately MARKED's own geometry, undone:

| | MARKED | PURGED |
|---|---|---|
| scope ring | RED, unbroken | ACID, severed at four cardinal points, capped at each cut |
| chevrons | inside the ring, closing in | outside the ring, released |
| corner brackets | closing, 14px RED | opening, 10px ACID |
| warrant strip | eight RED ticks | eight ACID ticks, struck through in white |

Red never appears in this state. Red belongs to the warrant and to the terminal
verdict, and PURGED is the opposite of both. It also had to read differently
from WITSEC, which is a static band over the feed — that is hiding, not rescue.

**Robustness note.** The scope ring is wider than the canvas on the tall head
forms (`rh` up to 44 → `R` up to 56 against a 100-unit canvas), exactly as
MARKED's is. The three chevrons are therefore clamped to stay on the canvas; an
arrow half outside the frame reads as nothing at all. The top cardinal is left
bare on purpose — that is where the warrant strip lives, and the strike through
it is the marker that belongs there. Fixtures FX_037–FX_040 cover four head
forms for this reason.

`StatusLib.purgedOverlay` · status code 8 · precedence MARKED > **PURGED** >
WITSEC > BUYER > LAY_LOW > HUNTER.

## 2. Coffin kill crest — candidate B, "head crest"

A wraith that died having earned REAPER no longer looks like one that died
having killed nobody.

An octagon crest at the coffin head, one pip per tier: acid up to EXECUTIONER,
white for the last two. Pitch 2, width 1, centred on 49.5 at every tier, so
seven pips still clear the ring's inner wall.

It is drawn **after the death scars** — history is not something the scars get
to shred — and **before the verdict**, so on a terminal grave the red X stays
the loudest thing in the frame. That ordering is the whole design; the
candidate was approved on exactly that check (`FX_044`).

Needs nothing from the schema: `kills` and `lifeState` already exist in
`RenderStateV2`. Fixtures FX_041–FX_044 sit on the tier boundaries that change
the pip row.

## 3. Pre-reveal — candidate A, "empty field"

What all 666 show between mint and reveal: the signal field running with
nothing standing in it yet, and the collection sigil at the crown.

`renderPrereveal(profile)` takes **no state at all**. That is the security
property, not a convenience: there is no argument through which a trait could
leak early. 48 rows at a 2-unit pitch, one more than a live render, so the
animated profile can drift by exactly one pitch and loop seamlessly. The static
profile is the still field, which is the static-fallback rule holding as usual.

`prerevealMetadata()` is identical for every token.

## 4. Fallback — keep it loud

An impossible state keeps rendering the red diagnostic frame: error codes, the
token number, the state hash. No change.

A broken token should look broken. It should never fire in production, and if
it does we want to find out immediately rather than ship a quiet grey card that
a buyer mistakes for art.

Two new codes land with PURGED: **E13** (purged and marked at once) and **E14**
(purged in the ground). Both are contradictions the game must not be able to
produce.

## 5. Marketplace animation — still as the image, animation alongside

Profile **4 MARKETPLACE**: `image` is the CANONICAL STATIC render, and
`animation_url` is the animated one. A marketplace that plays motion plays it;
one that does not still shows a finished wraith rather than a frame-zero
accident. This costs nothing in *design* terms — the static art is already the
finished art, which is the invariant the whole renderer is built on.

It is not free in gas terms, because one call pays for both renders. See the
measured numbers in `INTEGRATION_GUIDE.md` §5.2 before pointing `tokenURI` at
it.

Profiles 0–3 are unchanged and every existing fixture is byte-identical.

---

## 6. The one thing still owed by the game

`bool purged` on the render state. That is the entire delta — one bit.

The renderer now declares `SCHEMA_VERSION = 2` and accepts **both**: a state
that declares `schemaVersion = 1` renders exactly as it did before and hashes
exactly as it did before (`purged` is only folded into `stateHash` for states
that declare 2). So nothing breaks the day this lands, and PURGED starts
working the day the game sets the bit.

The other V3 items in `INTEGRATION_GUIDE.md` §7 still stand, but none of them
block art any more.
