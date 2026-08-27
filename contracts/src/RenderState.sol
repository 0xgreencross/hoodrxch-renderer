// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice RenderStateV1 — the renderer's read-only input (handoff §13.2).
/// Field set and semantics mirror the JS reference `defaultState` exactly.
struct RenderStateV1 {
    uint256 schemaVersion;
    uint256 tokenId;
    uint256 artIndex;
    uint256 wardId;
    uint256 blockId;
    bytes32 genesisHash;
    uint256 warId;
    uint256 campaignId;
    uint256 seasonId;
    uint256 activeBlockId;
    uint256 warPhase;
    uint256 lifeState; // 0 ALIVE 1 MARKED 2 COFFINED 3 TERMINAL_COFFIN
    uint256 exposureState; // 0..6
    uint256 sealsRemaining;
    bool hunterSelected;
    bool transferLocked;
    uint256 transferLockUntil;
    bool marked;
    uint256 markedByTokenId;
    uint256 markedByWardId;
    uint256 purgeDeadline;
    uint256 witsecCredits;
    bool witsecApplies;
    bool laidLow;
    bool buyerProtected;
    uint256 kills;
    uint256 deaths;
    uint256 forcedPurges;
    uint256 savesGiven;
    uint256 savesReceived;
    uint256 currentKillStreak;
    uint256 longestKillStreak;
    uint256 terminalKills;
    uint256 lifetimeKillTier;
    uint256 latestAwardSeasonId;
    uint256 latestSeasonRank;
    uint256 latestSeasonBadgeFlags;
    uint256 seasonAwardCount;
    uint256 territoryAchievementCount;
    uint256 deathRecordCount;
    uint256 historicalStateCount;
    uint256 displayMode; // 0 PLAIN 1 STATS
    bool flicker;
}
