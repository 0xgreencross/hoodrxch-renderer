# HOODRXCH — METADATA ATTRIBUTE SCHEMA (v1)

`renderMetadata(state)` returns ERC-721 JSON:
`{ name, description, image (base64 SVG data URI), attributes[] }`.
All attributes are `{trait_type, value}`; booleans render as `YES`/`NO`.
Per handoff §16.1, plus renderer/versioning fields.

## Identity
| trait_type | source | values |
|---|---|---|
| Token ID | tokenId | 1–666 |
| Ward | wardId | `WARD 01..03` |
| Block | blockId | `BLOCK 01..06` |
| Art Index | artIndex | uint |

## Canonical game state
| trait_type | source |
|---|---|
| Life State | `ALIVE / MARKED / COFFINED / TERMINAL_COFFIN` |
| Exposure State | `NOT_APPLICABLE / ON_THE_STREET / LAY_LOW / WITSEC / BUYER_PROTECTED / COFFINED / TERMINAL` |
| Canonical Game State | duplicate of Life State (marketplace-facing, handoff §16.1) |
| Seals Remaining | 0–3 |
| Marked By Token ID | 0 = none |
| Purge Deadline | unix ts, 0 = none |
| Transfer Locked / Transfer Lock Expiry | YES/NO, unix ts |
| WITSEC Credits / WITSEC Applies / Lay Low / Buyer Protected / Hunter Selected | uint / YES-NO |

## Stats (permanent, token-bound)
| trait_type | source |
|---|---|
| Kills / Deaths | uint |
| K/D | `UNTESTED` (0/0), `UNDEFEATED` (k>0,d=0), else 1-decimal string |
| Forced Purges / Saves Given / Saves Received | uint |
| Current Kill Streak / Longest Kill Streak / Terminal Kills | uint |
| Historical State Count | uint |

## Achievements
| trait_type | source |
|---|---|
| Lifetime Kill Tier | `NONE / FIRST BLOOD / RISING THREAT / SAVAGE / EXECUTIONER / DEATH DEALER / REAPER` |
| Latest Season / Latest Season Rank | uint (0 = none) |
| Season Top 10 / Season Top 5 | YES/NO from badgeFlags bits |
| Season Award Count | uint |
| Territory Achievements | uint |

## Context (non-material — excluded from stateHash)
Current War, Current Campaign, Current Season, War Phase
(`REGISTRATION / SELECTION / RESCUE / EXECUTION / FINALISATION / ARMISTICE`).

## Renderer
| trait_type | source |
|---|---|
| Display Mode | `PLAIN` / `STATS` |
| Renderer Version / Render-State Schema Version | 1 / 1 |
| State Hash | keccak of material fields (STATE_TO_LAYER_MAP §8) |

## Genesis traits (derived from genesisSeed, immutable)
`Genesis Form` (BROAD/LEAN/SPIRE/SKEW L/SKEW R/SUNKEN/TOWERING/HOLLOW),
`Genesis Lines` (FINE/MID/HEAVY), `Genesis Tear` (CLEAN/TORN/SHREDDED),
`Genesis Spikes` (NONE/FEW/STORM),
`Genesis Eyes` (X / BROKEN X / SMEARED X / VISOR / SPLIT VISOR / X + SLIT /
X + VOID / HOLLOW / DOUBLE X),
`Genesis Treatment` (RAW/ECHO GLOW/CHROMATIC/RIPPLE/FULL SIGNAL — kill tier
may escalate the rendered treatment; the trait records the genesis value),
`Genesis Mouth` (NONE/GASH/GRIN/SEWN), `Genesis Pink` (NONE/ECHO/BLEED),
`Genesis Mosh` (NONE/SHIFTS/HEAVY), `Genesis Sigil` (ward sigil name).

Invalid states still return metadata; the image is the diagnostic render and
the attribute set is unchanged (state is reported as stored).
