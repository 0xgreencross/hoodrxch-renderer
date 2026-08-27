// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RenderStateV1} from "./RenderState.sol";
import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";
import {Mask} from "./Mask.sol";
import {GenesisLib} from "./GenesisLib.sol";
import {StatusLib} from "./StatusLib.sol";

/// @notice ERC-721 metadata JSON — byte-identical to JS renderMetadata().
library MetaLib {
    using Buf for Buf.B;

    function lifeName(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "ALIVE";
        if (v == 1) return "MARKED";
        if (v == 2) return "COFFINED";
        return "TERMINAL_COFFIN";
    }

    function expoName(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "NOT_APPLICABLE";
        if (v == 1) return "ON_THE_STREET";
        if (v == 2) return "LAY_LOW";
        if (v == 3) return "WITSEC";
        if (v == 4) return "BUYER_PROTECTED";
        if (v == 5) return "COFFINED";
        return "TERMINAL";
    }

    function phaseName(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "REGISTRATION";
        if (v == 1) return "SELECTION";
        if (v == 2) return "RESCUE";
        if (v == 3) return "EXECUTION";
        if (v == 4) return "FINALISATION";
        if (v == 5) return "ARMISTICE";
        return Num.utoa(v); // JS: PHASES[x] || String(x)
    }

    function formName(int256 v) internal pure returns (string memory) {
        string[8] memory n = ["BROAD", "LEAN", "SPIRE", "SKEW L", "SKEW R", "SUNKEN", "TOWERING", "HOLLOW"];
        return n[uint256(v)];
    }

    function lineName(int256 v) internal pure returns (string memory) {
        string[3] memory n = ["FINE", "MID", "HEAVY"];
        return n[uint256(v)];
    }

    function tearName(int256 v) internal pure returns (string memory) {
        string[3] memory n = ["CLEAN", "TORN", "SHREDDED"];
        return n[uint256(v)];
    }

    function spikeName(int256 v) internal pure returns (string memory) {
        string[3] memory n = ["NONE", "FEW", "STORM"];
        return n[uint256(v)];
    }

    function eyeName(int256 v) internal pure returns (string memory) {
        string[9] memory n =
            ["X", "BROKEN X", "SMEARED X", "VISOR", "SPLIT VISOR", "X + SLIT", "X + VOID", "HOLLOW", "DOUBLE X"];
        return n[uint256(v)];
    }

    function treatName(int256 v) internal pure returns (string memory) {
        string[5] memory n = ["RAW", "ECHO GLOW", "CHROMATIC", "RIPPLE", "FULL SIGNAL"];
        return n[uint256(v)];
    }

    function mouthName(int256 v) internal pure returns (string memory) {
        string[4] memory n = ["NONE", "GASH", "GRIN", "SEWN"];
        return n[uint256(v)];
    }

    function pinkName(int256 v) internal pure returns (string memory) {
        string[3] memory n = ["NONE", "ECHO", "BLEED"];
        return n[uint256(v)];
    }

    function moshName(int256 v) internal pure returns (string memory) {
        string[3] memory n = ["NONE", "SHIFTS", "HEAVY"];
        return n[uint256(v)];
    }

    function wardName(uint256 v) internal pure returns (string memory) {
        string[4] memory n = ["", "CHEVRON", "THREE BARS", "DIAMOND"];
        return n[v];
    }

    function aStr(Buf.B memory b, string memory t, string memory v, bool comma) internal pure {
        b.app(abi.encodePacked(comma ? "," : "", '{"trait_type":"', t, '","value":"', v, '"}'));
    }

    function aNum(Buf.B memory b, string memory t, uint256 v, bool comma) internal pure {
        b.app(abi.encodePacked(comma ? "," : "", '{"trait_type":"', t, '","value":', Num.utoa(v), "}"));
    }

    function yesNo(bool v) internal pure returns (string memory) {
        return v ? "YES" : "NO";
    }

    /// metadata JSON; `svg` must be the already-rendered image for the state
    function metadata(RenderStateV1 memory s, string memory svg, bytes32 sh) public pure returns (string memory) {
        uint256 tier = GenesisLib.tierForKills(s.kills);
        Buf.B memory b = Buf.init(bytes(svg).length * 2 + 8192);
        b.app(
            abi.encodePacked(
                '{"name":"HOODRXCH #',
                Num.utoa(s.tokenId),
                '","description":"A persistent onchain HOODRXCH mask. Fully generative, fully onchain.","image":"data:image/svg+xml;base64,',
                Num.base64(bytes(svg)),
                '","attributes":['
            )
        );
        aNum(b, "Token ID", s.tokenId, false);
        aStr(b, "Ward", string(abi.encodePacked("WARD 0", Num.utoa(s.wardId))), true);
        aStr(b, "Block", string(abi.encodePacked("BLOCK 0", Num.utoa(s.blockId))), true);
        aNum(b, "Art Index", s.artIndex, true);
        aStr(b, "Life State", lifeName(s.lifeState), true);
        aStr(b, "Exposure State", expoName(s.exposureState), true);
        aNum(b, "Seals Remaining", s.sealsRemaining, true);
        aNum(b, "Kills", s.kills, true);
        aNum(b, "Deaths", s.deaths, true);
        aStr(b, "K/D", StatusLib.kdText(s), true);
        aNum(b, "Forced Purges", s.forcedPurges, true);
        aNum(b, "Saves Given", s.savesGiven, true);
        aNum(b, "Saves Received", s.savesReceived, true);
        aNum(b, "Current Kill Streak", s.currentKillStreak, true);
        aNum(b, "Longest Kill Streak", s.longestKillStreak, true);
        aNum(b, "Terminal Kills", s.terminalKills, true);
        aStr(b, "Lifetime Kill Tier", StatusLib.tierName(tier), true);
        aNum(b, "Latest Season", s.latestAwardSeasonId, true);
        aNum(b, "Latest Season Rank", s.latestSeasonRank, true);
        aStr(b, "Season Top 10", yesNo(s.latestSeasonBadgeFlags & 1 != 0), true);
        aStr(b, "Season Top 5", yesNo(s.latestSeasonBadgeFlags & 2 != 0), true);
        aNum(b, "Season Award Count", s.seasonAwardCount, true);
        aNum(b, "Territory Achievements", s.territoryAchievementCount, true);
        aNum(b, "Current War", s.warId, true);
        aNum(b, "Current Campaign", s.campaignId, true);
        aNum(b, "Current Season", s.seasonId, true);
        aStr(b, "War Phase", phaseName(s.warPhase), true);
        aNum(b, "WITSEC Credits", s.witsecCredits, true);
        aStr(b, "WITSEC Applies", yesNo(s.witsecApplies), true);
        aStr(b, "Lay Low", yesNo(s.laidLow), true);
        aStr(b, "Buyer Protected", yesNo(s.buyerProtected), true);
        aStr(b, "Hunter Selected", yesNo(s.hunterSelected), true);
        aNum(b, "Marked By Token ID", s.markedByTokenId, true);
        aNum(b, "Purge Deadline", s.purgeDeadline, true);
        aStr(b, "Transfer Locked", yesNo(s.transferLocked), true);
        aNum(b, "Transfer Lock Expiry", s.transferLockUntil, true);
        aNum(b, "Historical State Count", s.historicalStateCount, true);
        aStr(b, "Display Mode", s.displayMode != 0 ? "STATS" : "PLAIN", true);
        aStr(b, "Canonical Game State", lifeName(s.lifeState), true);
        aNum(b, "Renderer Version", 1, true);
        aNum(b, "Render-State Schema Version", 1, true);
        aStr(b, "State Hash", Num.hex0x(sh), true);
        {
            Mask.Traits memory t = Mask.drawTraits(Rng.init(GenesisLib.genesisSeed(s.genesisHash, s.tokenId)));
            aStr(b, "Genesis Form", formName(t.form), true);
            aStr(b, "Genesis Lines", lineName(t.lineW), true);
            aStr(b, "Genesis Tear", tearName(t.tear), true);
            aStr(b, "Genesis Spikes", spikeName(t.spike), true);
            aStr(b, "Genesis Eyes", eyeName(t.eyes), true);
            aStr(b, "Genesis Treatment", treatName(t.treat), true);
            aStr(b, "Genesis Mouth", mouthName(t.mouth), true);
            aStr(b, "Genesis Pink", pinkName(t.pink), true);
            aStr(b, "Genesis Mosh", moshName(t.mosh), true);
            aStr(b, "Genesis Sigil", wardName(s.wardId), true);
        }
        b.app(bytes("]}"));
        return b.fin();
    }
}
