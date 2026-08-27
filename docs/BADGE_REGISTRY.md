# HOODRXCH — BADGE REGISTRY (renderer view, v1)

How canonical achievements map to pixels. The renderer **never derives**
awards — it reads them from RenderStateV1 (which mirrors StatsRegistry /
SeasonRegistry / AchievementRegistry per the mechanics handoff §12).

## 1. Lifetime kill badges (SLOT A)

Derived display of `tierForKills(kills)` — thresholds are canonical and
frozen (handoff §9.1): 1 / 10 / 25 / 50 / 75 / 100.

| id | name | visual signature (always on the live figure) |
|----|------|----------------------------------------------|
| 0 | NONE | pure acid signal |
| 1 | FIRST_BLOOD | 1 pink halo arc + pink kill notches begin |
| 2 | RISING_THREAT | 2 pink halo arcs, crest-6 lines pink, eyes ≥ ECHO GLOW |
| 3 | SAVAGE | 3 pink arcs (outer broken), upper figure pink, 1 white crest |
| 4 | EXECUTIONER | white halo arc + ticks, full figure pink, 2 white crests, eyes FULL SIGNAL |
| 5 | DEATH_DEALER | + corona rays, 4 white crests, background thinned |
| 6 | REAPER | full white ellipse ring + pink echo ring, figure white |

Badges are never removed; coffin/WITSEC/LAY_LOW do not erase them from
metadata (handoff §9). The coffin composition prioritises the death state on
the image; the tier stays in attributes.

## 2. Season badges (SLOT B / SLOT C)

Read from `latestAwardSeasonId / latestSeasonRank / latestSeasonBadgeFlags`
(`1<<0` TOP_10, `1<<1` TOP_5). Only the **latest** award renders (handoff
§10.6); the full history lives in the registry, `seasonAwardCount` counts it.

Visual: left column stack — acid `S<seasonId>` glyph label, white-outline
chip `10` for TOP_10, pink-outline chip `5` added for TOP_5. Rank prints in
the STATS band (`S<n> RANK <r>`), not on the default image.

Renderer-side consistency guards (diagnostic if violated): E07 (TOP_5
without TOP_10), E12 (flags without rank/season, or rank↔flags mismatch).

## 3. Territory achievements

`territoryAchievementCount` → acid tick ladder on the right edge, one tick
per achievement, display cap 12 (count continues in metadata). Territory
never replaces season badge slots (handoff §11).

## 4. Permanent record marks (not badges, never removable)

| mark | field | visual |
|------|-------|--------|
| kill notches | kills (cap 9 shown) | pink notches above the left eye |
| forced-purge tallies | forcedPurges (cap 10 shown) | white ticks along the hem |
| survival stitches | savesReceived (cap 5 shown) | pink x-stitches, low left |
| death scars | deaths + damageSeed | white scar strokes + displaced slices |
| broken seals | 3 − sealsRemaining | pink slashed pips (red in TERMINAL) |

## 5. Slots & bounds

At most: 1 tier signature + 2 season chips + 12 territory ticks + capped
record marks compose into the primary SVG — bounded, per handoff §10.6.
A future `BadgeDisplayRegistry` (owner-selected historical badges) would
swap the chip source only; it must never render an unearned badge and never
suppress MARKED/TERMINAL status.
