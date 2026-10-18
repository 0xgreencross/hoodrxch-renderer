// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RenderStateV1} from "./RenderState.sol";
import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";
import {Geom} from "./Geom.sol";
import {Mask} from "./Mask.sol";
import {T} from "./Types.sol";
import {GenesisLib} from "./GenesisLib.sol";
import {StatusLib} from "./StatusLib.sol";
import {Intro} from "./Intro.sol";
import {MetaLib} from "./MetaLib.sol";
import {BannerLib} from "./BannerLib.sol";
import {Glyphs} from "./Glyphs.sol";

/// @title HOODRXCH renderer v1 — pure view mirror of reference-renderer/index.html.
/// Same RenderStateV1 → byte-identical SVG / metadata / stateHash as the JS.
contract HOODRXCHRenderer {
    using Buf for Buf.B;

    uint256 public constant RENDERER_VERSION = 2;
    uint256 public constant SCHEMA_VERSION = 2;

    // --- validation (E01–E14) ----------------------------------------------

    function validate(RenderStateV1 memory s) public pure returns (string[] memory) {
        bool[14] memory e;
        uint256 prot = (s.witsecApplies ? 1 : 0) + (s.laidLow ? 1 : 0) + (s.buyerProtected ? 1 : 0);
        bool Tt = s.lifeState == 3;
        bool C = s.lifeState == 2;
        bool M = s.lifeState == 1 || s.marked;
        if (Tt && (prot > 0 || s.hunterSelected || s.marked)) e[0] = true;
        if (C && (prot > 0 || s.hunterSelected || s.marked)) e[1] = true;
        if (M && (s.witsecApplies || s.laidLow)) e[2] = true;
        if (s.sealsRemaining == 0 && !Tt) e[3] = true;
        if ((s.deaths >= 3 && !Tt) || (Tt && s.deaths < 3)) e[4] = true;
        uint256 dmin = s.deaths < 3 ? s.deaths : 3;
        if (s.sealsRemaining + dmin != 3) e[5] = true;
        if ((s.latestSeasonBadgeFlags & 2 != 0) && (s.latestSeasonBadgeFlags & 1 == 0)) e[6] = true;
        if (prot > 1) e[7] = true;
        if (s.marked != (s.lifeState == 1)) e[8] = true;
        bool exC = s.exposureState == 5;
        bool exT = s.exposureState == 6;
        if ((exT && !Tt) || (Tt && !exT) || (exC && !C) || (C && !exC)) e[9] = true;
        if (
            s.wardId < 1 || s.wardId > 3 || s.blockId < 1 || s.blockId > 6 || s.tokenId < 1 || s.tokenId > 666
                || (s.schemaVersion != 1 && s.schemaVersion != 2)
        ) e[10] = true;
        if (s.latestSeasonBadgeFlags != 0 && (s.latestSeasonRank == 0 || s.latestAwardSeasonId == 0)) e[11] = true;
        if (s.latestSeasonRank >= 1 && s.latestSeasonRank <= 5 && s.latestSeasonBadgeFlags != 3) e[11] = true;
        if (s.latestSeasonRank >= 6 && s.latestSeasonRank <= 10 && s.latestSeasonBadgeFlags != 1) e[11] = true;
        // PURGED is the warrant bought out: it cannot coexist with the warrant
        // itself, and a wraith in the ground was never released.
        if (s.purged && M) e[12] = true;
        if (s.purged && (C || Tt)) e[13] = true;
        uint256 n;
        for (uint256 i = 0; i < 14; i++) {
            if (e[i]) n++;
        }
        string[14] memory names =
            ["E01", "E02", "E03", "E04", "E05", "E06", "E07", "E08", "E09", "E10", "E11", "E12", "E13", "E14"];
        string[] memory out = new string[](n);
        uint256 j;
        for (uint256 i = 0; i < 14; i++) {
            if (e[i]) out[j++] = names[i];
        }
        return out;
    }

    // --- stateHash ----------------------------------------------------------

    function stateHash(RenderStateV1 memory s) public pure returns (bytes32) {
        bytes memory a = abi.encode(
            s.schemaVersion,
            s.tokenId,
            s.artIndex,
            s.wardId,
            s.blockId,
            s.genesisHash,
            s.seasonId,
            s.lifeState,
            s.exposureState,
            s.sealsRemaining
        );
        bytes memory b = abi.encode(
            s.hunterSelected ? uint256(1) : uint256(0),
            s.transferLocked ? uint256(1) : uint256(0),
            s.marked ? uint256(1) : uint256(0),
            s.markedByTokenId,
            s.purgeDeadline,
            s.witsecApplies ? uint256(1) : uint256(0),
            s.laidLow ? uint256(1) : uint256(0),
            s.buyerProtected ? uint256(1) : uint256(0),
            s.kills,
            s.deaths
        );
        bytes memory c = abi.encode(
            s.forcedPurges,
            s.savesReceived,
            s.currentKillStreak,
            s.latestAwardSeasonId,
            s.latestSeasonRank,
            s.latestSeasonBadgeFlags,
            s.territoryAchievementCount,
            s.displayMode
        );
        // `purged` is material — it changes the art — but it is only hashed for
        // states that declare schema 2, so every v1 state keeps exactly the
        // hash it had before this field existed.
        if (s.schemaVersion >= 2) {
            return keccak256(bytes.concat(a, b, c, abi.encode(s.purged ? uint256(1) : uint256(0))));
        }
        return keccak256(bytes.concat(a, b, c));
    }

    // --- status -------------------------------------------------------------

    /// 0 ALIVE 1 MARKED 2 COFFINED 3 TERMINAL 4 WITSEC 5 BUYER 6 LAYLOW
    /// 7 HUNTER 8 PURGED
    function resolveStatusCode(RenderStateV1 memory s) public pure returns (uint256) {
        if (s.lifeState == 3) return 3;
        if (s.lifeState == 2) return 2;
        if (s.lifeState == 1 || s.marked) return 1;
        if (s.purged) return 8;
        if (s.witsecApplies) return 4;
        if (s.buyerProtected) return 5;
        if (s.laidLow) return 6;
        if (s.hunterSelected) return 7;
        return 0;
    }

    function statusName(uint256 code, bool spaced) internal pure returns (string memory) {
        if (code == 1) return "MARKED";
        if (code == 2) return "COFFINED";
        if (code == 3) return "TERMINAL";
        if (code == 4) return "WITSEC";
        if (code == 5) return spaced ? "BUYER PROTECTED" : "BUYER_PROTECTED";
        if (code == 6) return spaced ? "LAY LOW" : "LAY_LOW";
        if (code == 7) return spaced ? "HUNTER SELECTED" : "HUNTER_SELECTED";
        if (code == 8) return "PURGED";
        return "ALIVE";
    }

    // --- diagnostic ---------------------------------------------------------

    function diagnosticSVG(RenderStateV1 memory s, string[] memory errs) internal pure returns (string memory) {
        Glyphs.Used memory used = Glyphs.newUsed();
        Buf.B memory body = Buf.init(16000);
        body.app(Glyphs.text("INVALID STATE", 74, 380, 11, T.RED, used));
        {
            Buf.B memory j = Buf.init(256);
            for (uint256 i = 0; i < errs.length; i++) {
                if (i > 0) j.app(bytes(" "));
                j.app(errs[i]);
            }
            body.app(Glyphs.text(j.fin(), 110, 520, 10, T.RED, used));
        }
        body.app(Glyphs.text(string(abi.encodePacked("#", Num.utoa(s.tokenId))), 110, 620, 10, T.RED, used));
        body.app(Glyphs.text(Num.hexUpper(stateHash(s), 8), 110, 710, 8, T.RED, used));
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"><defs>',
                Glyphs.glyphDefs(used),
                '</defs><rect width="1000" height="1000" fill="',
                T.BLACK,
                '"/><rect x="20" y="20" width="960" height="960" fill="none" stroke="',
                T.RED,
                '" stroke-width="24"/>',
                body.fin(),
                "</svg>"
            )
        );
    }

    // --- renderSVG ----------------------------------------------------------

    /// PROFILES: 0 CANONICAL_STATIC · 1 ANIMATED · 2 STATS · 3 BANNER.
    /// The static profiles emit the finished character with NO SMIL at all —
    /// both the marketplace-safe still frame and the only way tokenURI fits a
    /// sane gas ceiling (keyframe `values=` are ~86% of an animated payload).
    /// Free by the renderer's standing invariant: every base attribute is
    /// already the finished art and animations only ride on top.
    uint8 public constant PROFILE_CANONICAL_STATIC = 0;
    uint8 public constant PROFILE_ANIMATED = 1;
    uint8 public constant PROFILE_STATS = 2;
    uint8 public constant PROFILE_BANNER = 3;
    uint8 public constant PROFILE_MARKETPLACE = 4;

    /// Default profile stays ANIMATED, so every existing caller and every
    /// fixture keeps its exact bytes.
    function renderSVG(RenderStateV1 memory s) public pure returns (string memory) {
        return renderSVG(s, PROFILE_ANIMATED);
    }

    function renderSVG(RenderStateV1 memory s, uint8 profile) public pure returns (string memory) {
        if (profile == PROFILE_BANNER) return renderBanner(s);
        // memory structs pass by reference, so the STATS override is borrowed
        // and handed straight back — a caller's state is never left mutated.
        uint256 prevMode = s.displayMode;
        if (profile == PROFILE_STATS) s.displayMode = 1;
        (string memory core,) = renderCore(s, profile == PROFILE_ANIMATED);
        s.displayMode = prevMode;
        return string(
            abi.encodePacked('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">', core, "</svg>")
        );
    }

    /// core = inner content of the token SVG (everything between the svg tags)
    function renderCore(RenderStateV1 memory s, bool anim) internal pure returns (string memory, uint256 nErrs) {
        string[] memory errs = validate(s);
        if (errs.length > 0) {
            string memory d = diagnosticSVG(s, errs);
            return (stripSvg(d), errs.length);
        }
        uint256 status = resolveStatusCode(s);
        if (status == 2 || status == 3) {
            return (stripSvg(StatusLib.coffinSVG(s, anim)), 0);
        }
        T.Gen memory g = GenesisLib.build(s, anim);
        Glyphs.Used memory used = Glyphs.newUsed();
        Buf.B memory body = Buf.init(112000);
        body.app(abi.encodePacked('<rect width="1000" height="1000" fill="', T.BLACK, '"/>'));
        body.app(bytes('<use href="#f"/>'));
        for (uint256 ci = 0; ci < g.slices.length; ci++) {
            T.Slc memory sl = g.slices[ci];
            if (sl.smear) {
                body.app(
                    abi.encodePacked(
                        '<clipPath id="c',
                        Num.utoa(ci + 1),
                        '"><rect x="0" y="',
                        Num.itoa(sl.y * 10),
                        '" width="1000" height="',
                        Num.itoa(sl.h * 10),
                        '"/></clipPath><g clip-path="url(#c',
                        Num.utoa(ci + 1),
                        ')"><rect width="1000" height="1000" fill="',
                        T.BLACK,
                        '"/><use href="#f" transform="translate(-500 0) scale(2 1)"/></g>'
                    )
                );
            } else {
                body.app(Geom.slice(ci + 1, sl.y, sl.h, sl.dx, T.BLACK));
            }
        }
        // construction intro: the body layers join the 0.25s succession,
        // continuing the figure's sequence (base = tMouth = 1.42s)
        uint256 seq = g.introSeq;
        if (status == 1) body.app(Intro.reveal(anim, StatusLib.markedOverlay(g), 142 + 25 * int256(++seq)));
        else if (status == 8) body.app(Intro.reveal(anim, StatusLib.purgedOverlay(g), 142 + 25 * int256(++seq)));
        else if (status == 4) body.app(Intro.reveal(anim, StatusLib.witsecOverlay(g, anim), 142 + 25 * int256(++seq)));
        else if (status == 6) body.app(Intro.reveal(anim, StatusLib.layLowOverlay(g), 142 + 25 * int256(++seq)));
        else if (status == 5) body.app(Intro.reveal(anim, StatusLib.buyerOverlay(g, anim), 142 + 25 * int256(++seq)));
        else if (status == 7) body.app(Intro.reveal(anim, StatusLib.hunterOverlay(g), 142 + 25 * int256(++seq)));
        body.app(Intro.reveal(anim, StatusLib.sealHud(s), 142 + 25 * int256(++seq)));
        {
            string memory c1 = StatusLib.seasonChips(s, used);
            if (bytes(c1).length > 0) body.app(Intro.reveal(anim, c1, 142 + 25 * int256(++seq)));
        }
        {
            string memory c2 = StatusLib.territoryHud(s);
            if (bytes(c2).length > 0) body.app(Intro.reveal(anim, c2, 142 + 25 * int256(++seq)));
        }
        if (s.displayMode == 1) body.app(Intro.reveal(anim, StatusLib.statsBand(s, used), 142 + 25 * int256(++seq)));
        {
            string memory c3 = StatusLib.flickerSVG(s, anim);
            if (bytes(c3).length > 0) body.app(Intro.reveal(anim, c3, 142 + 25 * int256(++seq)));
        }
        return (
            string(
                abi.encodePacked(
                    "<defs>", '<g id="f">', g.figure, "</g>", Glyphs.glyphDefs(used), "</defs>", body.fin()
                )
            ),
            0
        );
    }

    function stripSvg(string memory svg) internal pure returns (string memory) {
        bytes memory b = bytes(svg);
        // find first '>' (end of the opening <svg ...> tag)
        uint256 i = 0;
        while (b[i] != ">") i++;
        i++;
        uint256 end = b.length - 6; // strip trailing "</svg>"
        bytes memory out = new bytes(end - i);
        for (uint256 k = 0; k < out.length; k++) out[k] = b[i + k];
        return string(out);
    }

    // --- banner / metadata ---------------------------------------------------

    function renderBanner(RenderStateV1 memory s) public pure returns (string memory) {
        (string memory core, uint256 nErrs) = renderCore(s, true);
        uint256 status = resolveStatusCode(s);
        bool statusRed = status == 1 || status == 3;
        return BannerLib.banner(s, core, nErrs, statusName(status, true), statusRed, status == 0);
    }

    function renderMetadata(RenderStateV1 memory s) public pure returns (string memory) {
        return renderMetadata(s, PROFILE_ANIMATED);
    }

    /// The image the metadata embeds follows `profile`; the stateHash never
    /// does — it covers the state, not the presentation.
    function renderMetadata(RenderStateV1 memory s, uint8 profile) public pure returns (string memory) {
        uint256 prevMode = s.displayMode;
        if (profile == PROFILE_STATS) s.displayMode = 1;
        // sequenced explicitly: Solidity does not fix argument evaluation order,
        // and all three readings must see the same state.
        if (profile == PROFILE_MARKETPLACE) {
            string memory still = renderSVG(s, PROFILE_CANONICAL_STATIC);
            string memory moving = renderSVG(s, PROFILE_ANIMATED);
            bytes32 hm = stateHash(s);
            string memory outM = MetaLib.metadata(s, still, moving, hm);
            s.displayMode = prevMode;
            return outM;
        }
        string memory svg = renderSVG(s, profile);
        bytes32 h = stateHash(s);
        string memory out = MetaLib.metadata(s, svg, h);
        s.displayMode = prevMode;
        return out;
    }

    // --- pre-reveal ----------------------------------------------------------

    /// What all 666 show between mint and reveal. Takes no state at all, by
    /// construction: there is no argument through which a trait could leak.
    function renderPrereveal(uint8 profile) public pure returns (string memory) {
        bool anim = profile == PROFILE_ANIMATED;
        Buf.B memory o = Buf.init(8192);
        o.app(abi.encodePacked('<rect width="1000" height="1000" fill="', T.BLACK, '"/>'));
        Buf.B memory rows = Buf.init(6144);
        // 48 rows at a 2-unit pitch: one more than a live render, so the drift
        // always has a row to bring up from under the bottom edge.
        for (uint256 li = 0; li < 48; li++) {
            rows.app(
                abi.encodePacked(
                    '<path d="M0 ', Num.utoa((4 + li * 2) * 10), 'h1000" fill="none" stroke="', T.ACID,
                    '" stroke-width="4"/>'
                )
            );
        }
        // the field drifts by exactly one row pitch, so the loop is seamless.
        // Base attributes stay the finished art: a non-SMIL renderer sees the
        // still field, which is the whole static-fallback rule.
        if (anim) {
            o.app(
                abi.encodePacked(
                    "<g>",
                    rows.fin(),
                    '<animateTransform attributeName="transform" type="translate" values="0 0;0 -20" dur="2.4s" repeatCount="indefinite"/></g>'
                )
            );
        } else {
            o.app(rows.fin());
        }
        o.app(abi.encodePacked('<rect x="0" y="430" width="1000" height="140" fill="', T.BLACK, '"/>'));
        o.app(GenesisLib.octRing(50, 50, 14, 6, T.ACID));
        o.app(GenesisLib.octRing(50, 50, 22, 2, T.WHITE));
        return string(
            abi.encodePacked('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">', o.fin(), "</svg>")
        );
    }

    function prerevealMetadata() public pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"HOODRXCH","description":"Unrevealed. 666 signal wraiths, fully onchain.","image":"data:image/svg+xml;base64,',
                Num.base64(bytes(renderPrereveal(PROFILE_CANONICAL_STATIC))),
                '","animation_url":"data:image/svg+xml;base64,',
                Num.base64(bytes(renderPrereveal(PROFILE_ANIMATED))),
                '","attributes":[{"trait_type":"Status","value":"UNREVEALED"},{"trait_type":"Renderer Version","value":',
                Num.utoa(RENDERER_VERSION),
                "}]}"
            )
        );
    }
}
