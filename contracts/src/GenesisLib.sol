// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RenderStateV1} from "./RenderState.sol";
import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";
import {Geom} from "./Geom.sol";
import {Mask} from "./Mask.sol";
import {T} from "./Types.sol";

/// @notice buildGenesis — the SIGNAL WRAITH figure, Trait Engine V2.
/// Mirrors src/05_render.js buildGenesis() with identical RNG draw order and
/// identical output bytes across all 110 trait values.
library GenesisLib {
    using Buf for Buf.B;
    using Rng for Rng.R;

    struct Line {
        int256 y;
        int256 w;
        bool dash;
        bool figOnly;
    }

    struct Ctx {
        Rng.R rng;
        Mask.Traits t;
        int256[51] noise;
        int256[4][2] eyePos; // x, y, r, side
        int256[4][2] eyeScr; // displaced screen anchors
        Line[] lines;
        string[] lineD;
        int256[] lineMaxH;
        int256 mw;
        int256 mouthY;
        uint256 tier;
        int256 flatLi;
    }

    function genesisSeed(bytes32 genesisHash, uint256 tokenId) internal pure returns (bytes memory) {
        return abi.encodePacked(genesisHash, uint16(tokenId));
    }

    function damageSeed(bytes32 genesisHash, uint256 tokenId, uint256 deaths) internal pure returns (bytes memory) {
        return abi.encodePacked(genesisHash, uint16(tokenId), uint8(deaths), "DMG");
    }

    function tierForKills(uint256 k) internal pure returns (uint256) {
        if (k >= 100) return 6;
        if (k >= 75) return 5;
        if (k >= 50) return 4;
        if (k >= 25) return 3;
        if (k >= 10) return 2;
        if (k >= 1) return 1;
        return 0;
    }

    // --- eye primitives -----------------------------------------------------

    function eyeArm(int256 cx, int256 cy, int256 dx, int256 dy, int256 r, int256 b, string memory fill)
        internal
        pure
        returns (string memory)
    {
        // JS `cx-b*dy/2|0 || cx`: |0 truncates the WHOLE expression; || guards 0
        int256 p0x = (2 * cx - b * dy) / 2;
        if (p0x == 0) p0x = cx;
        int256 p0y = (2 * cy + b * dx) / 2;
        if (p0y == 0) p0y = cy;
        Geom.Pt[] memory p = new Geom.Pt[](4);
        p[0] = Geom.Pt(p0x, p0y);
        p[1] = Geom.Pt(cx + (b * dy) / 2, cy - (b * dx) / 2);
        p[2] = Geom.Pt(cx + dx * r + (b * dy) / 2, cy + dy * r - (b * dx) / 2);
        p[3] = Geom.Pt(cx + dx * r - (b * dy) / 2, cy + dy * r + (b * dx) / 2);
        return Geom.poly(p, fill);
    }

    /// octagon ring (stroke), identical bytes to JS octRing()
    function octRing(int256 cx, int256 cy, int256 r, int256 w, string memory color)
        internal
        pure
        returns (string memory)
    {
        int256 q = (r * 7) / 10;
        Geom.Pt[] memory pts = new Geom.Pt[](8);
        pts[0] = Geom.Pt(cx - r, cy);
        pts[1] = Geom.Pt(cx - q, cy - q);
        pts[2] = Geom.Pt(cx, cy - r);
        pts[3] = Geom.Pt(cx + q, cy - q);
        pts[4] = Geom.Pt(cx + r, cy);
        pts[5] = Geom.Pt(cx + q, cy + q);
        pts[6] = Geom.Pt(cx, cy + r);
        pts[7] = Geom.Pt(cx - q, cy + q);
        return string(
            abi.encodePacked('<path d="', Geom.pathD(pts), '" fill="none" stroke="', color, '" stroke-width="', Num.itoa(w), '"/>')
        );
    }

    function octFill(int256 cx, int256 cy, int256 r, string memory fill) internal pure returns (string memory) {
        int256 q = (r * 7) / 10;
        Geom.Pt[] memory pts = new Geom.Pt[](8);
        pts[0] = Geom.Pt(cx - r, cy);
        pts[1] = Geom.Pt(cx - q, cy - q);
        pts[2] = Geom.Pt(cx, cy - r);
        pts[3] = Geom.Pt(cx + q, cy - q);
        pts[4] = Geom.Pt(cx + r, cy);
        pts[5] = Geom.Pt(cx + q, cy + q);
        pts[6] = Geom.Pt(cx, cy + r);
        pts[7] = Geom.Pt(cx - q, cy + q);
        return Geom.poly(pts, fill);
    }

    function eyeGlyph(int256 st, uint256 side, int256 cx, int256 cy, int256 r, string memory fill, Rng.R memory rng)
        internal
        pure
        returns (string memory)
    {
        if (st == 0) return Geom.xmark(cx, cy, r, 3, fill, rng);
        if (st == 1) {
            int256[2][4] memory arms = [[int256(1), -1], [int256(-1), 1], [int256(-1), -1], [int256(1), 1]];
            uint256 skip = side == 1 ? 0 : 2;
            bytes memory e;
            for (uint256 k = 0; k < 4; k++) {
                if (k == skip) continue;
                e = abi.encodePacked(e, eyeArm(cx, cy, arms[k][0], arms[k][1], r, 3, fill));
            }
            e = abi.encodePacked(e, eyeArm(cx, cy, arms[skip][0], arms[skip][1], r >> 1, 3, fill));
            return string(e);
        }
        if (st == 2) {
            return string(
                abi.encodePacked(
                    Geom.xmark(cx, cy, r, 3, fill, rng),
                    Geom.rect(side == 1 ? cx + 2 : cx - r - 5, cy - 1, r + 3, 2, fill)
                )
            );
        }
        if (st == 3) return Geom.rect(cx - r - 1, cy - 1, 2 * r + 2, 4, fill);
        if (st == 4) {
            return string(
                abi.encodePacked(
                    Geom.rect(cx - r, cy - r / 2, 2 * r, 3, fill), Geom.rect(cx - r + 2, cy + 2, 2 * r - 2, 3, fill)
                )
            );
        }
        if (st == 5) {
            if (side == 1) return Geom.rect(cx - r, cy - 1, 2 * r, 4, fill);
            return Geom.xmark(cx, cy, r, 3, fill, rng);
        }
        if (st == 6) {
            if (side == 0) return Geom.xmark(cx, cy, r, 3, fill, rng);
            return "";
        }
        if (st == 7) return "";
        if (st == 8) return Geom.xmark(cx, cy, side == 1 ? (r >> 1) + 1 : r + 1, 3, fill, rng);
        if (st == 9) return Geom.rect(cx - r, cy - 1, 2 * r, 2, fill); // SLIT
        if (st == 10) {
            return string(
                abi.encodePacked(Geom.rect(cx - 1, cy - r, 3, 2 * r, fill), Geom.rect(cx + 1, cy - 2, r + 2, 3, fill))
            ); // GLITCH BAR
        }
        if (st == 11) { // PIXEL STORM
            bytes memory e;
            for (uint256 i = 0; i < 5; i++) {
                int256 px = cx - r + rng.rInt(uint256(2 * r));
                int256 py = cy - r + rng.rInt(uint256(2 * r));
                e = abi.encodePacked(e, Geom.rect(px, py, 2, 2, fill));
            }
            return string(e);
        }
        if (st == 12) { // CROSSHAIR
            return string(
                abi.encodePacked(
                    Geom.xmark(cx, cy, r, 3, fill, rng),
                    Geom.rect(cx - 1, cy - r - 4, 2, 3, fill),
                    Geom.rect(cx - 1, cy + r + 1, 2, 3, fill),
                    Geom.rect(cx - r - 4, cy - 1, 3, 2, fill),
                    Geom.rect(cx + r + 1, cy - 1, 3, 2, fill)
                )
            );
        }
        if (st == 13) { // TRIPLE SLIT
            return string(
                abi.encodePacked(
                    Geom.rect(cx - r, cy - 4, 2 * r, 2, fill),
                    Geom.rect(cx - r, cy - 1, 2 * r, 2, fill),
                    Geom.rect(cx - r, cy + 2, 2 * r, 2, fill)
                )
            );
        }
        if (st == 14) return octRing(cx, cy, r, 9, fill); // VOID RING
        if (st == 15) { // NAILED X
            return string(
                abi.encodePacked(
                    Geom.xmark(cx, cy, r, 3, fill, rng),
                    Geom.rect(cx - 1, cy - 3, 2, 6, T.WHITE),
                    Geom.rect(cx - 3, cy - 1, 6, 2, T.WHITE)
                )
            );
        }
        if (st == 16) { // BINARY (1|0)
            if (side == 1) return octRing(cx, cy, r - 1, 9, fill);
            return Geom.rect(cx - 1, cy - r, 3, 2 * r, fill);
        }
        if (st == 17) { // TARGET
            return string(abi.encodePacked(octRing(cx, cy, r + 1, 10, fill), Geom.rect(cx - 2, cy - 2, 3, 3, fill)));
        }
        if (st == 18) { // SPIRAL
            Buf.B memory d = Buf.init(256);
            d.app(abi.encodePacked("M", Num.itoa((cx - r) * 10), " ", Num.itoa((cy - r) * 10)));
            int256[2][4] memory dirs = [[int256(1), 0], [int256(0), 1], [int256(-1), 0], [int256(0), -1]];
            for (uint256 k = 0; k < 7; k++) {
                int256 len = k < 3 ? 2 * r : 2 * r - 3 * int256((k - 1) >> 1);
                if (len < 2) break;
                int256[2] memory dxy = dirs[k % 4];
                if (dxy[0] != 0) d.app(abi.encodePacked("h", Num.itoa(dxy[0] * len * 10)));
                else d.app(abi.encodePacked("v", Num.itoa(dxy[1] * len * 10)));
            }
            return string(abi.encodePacked('<path d="', d.fin(), '" fill="none" stroke="', fill, '" stroke-width="6"/>'));
        }
        if (st == 19) { // WEEPING X
            string memory x1 = Geom.xmark(cx, cy, r, 3, fill, rng);
            return string(abi.encodePacked(x1, Geom.rect(cx + 1, cy + r, 2, 7 + rng.rInt(4), fill)));
        }
        if (st == 20) { // SPLIT PAIR
            if (side == 1) return octRing(cx, cy, r, 9, fill);
            return Geom.xmark(cx, cy, r, 3, fill, rng);
        }
        if (st == 21) { // BURNING X
            string memory a = Geom.xmark(cx + 2, cy + 2, r, 3, T.PINK, rng);
            string memory b = Geom.xmark(cx, cy, r, 3, fill, rng);
            string memory c = Geom.xmark(cx, cy, r >> 1, 2, T.WHITE, rng);
            return string(abi.encodePacked(a, b, c));
        }
        if (st == 22) { // STAR
            Geom.Pt[] memory p = new Geom.Pt[](8);
            p[0] = Geom.Pt(cx, cy - r - 1);
            p[1] = Geom.Pt(cx + 2, cy - 2);
            p[2] = Geom.Pt(cx + r + 1, cy);
            p[3] = Geom.Pt(cx + 2, cy + 2);
            p[4] = Geom.Pt(cx, cy + r + 1);
            p[5] = Geom.Pt(cx - 2, cy + 2);
            p[6] = Geom.Pt(cx - r - 1, cy);
            p[7] = Geom.Pt(cx - 2, cy - 2);
            return Geom.poly(p, fill);
        }
        if (st == 23) return octFill(cx, cy, r, fill); // DEAD LIGHT
        return ""; // 24 ALL SEEING handled at drawEyes level
    }

    function drawEyes(Ctx memory c, string memory fill, int256 ox, int256 oy) internal pure returns (string memory) {
        if (c.t.eyes == 3) {
            int256 lx = c.eyePos[0][0];
            int256 ly = c.eyePos[0][1];
            int256 lr = c.eyePos[0][2];
            int256 rx2 = c.eyePos[1][0];
            int256 rr2 = c.eyePos[1][2];
            int256 dispL = Num.jsRound(Mask.heightAt(c.t, c.noise, lx, ly), 100);
            int256 vy = ly - dispL / 3 + 2;
            Geom.Pt[] memory p = new Geom.Pt[](4);
            p[0] = Geom.Pt(lx - lr, vy + 2);
            p[1] = Geom.Pt(rx2 + rr2, vy);
            p[2] = Geom.Pt(rx2 + rr2, vy + 5);
            p[3] = Geom.Pt(lx - lr, vy + 7);
            return Geom.poly(Geom.offsetPts(p, ox, oy), fill);
        }
        if (c.t.eyes == 24) { // ALL SEEING
            bytes memory e;
            for (uint256 i = 0; i < 2; i++) {
                e = abi.encodePacked(e, octRing(c.eyeScr[i][0] + ox, c.eyeScr[i][1] + oy, c.eyeScr[i][2] - 1, 9, fill));
            }
            int256 mx = (c.eyeScr[0][0] + c.eyeScr[1][0]) / 2;
            int256 ty = Num.min(c.eyeScr[0][1], c.eyeScr[1][1]) - c.t.eyeR - 7;
            e = abi.encodePacked(e, Geom.xmark(mx + ox, ty + oy, c.t.eyeR + 2, 3, fill, c.rng));
            return string(e);
        }
        bytes memory out;
        for (uint256 i = 0; i < 2; i++) {
            int256 ex = c.eyePos[i][0];
            int256 ey2 = c.eyePos[i][1];
            int256 r = c.eyePos[i][2];
            uint256 side = uint256(c.eyePos[i][3]);
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
            out = abi.encodePacked(out, eyeGlyph(c.t.eyes, side, ex + ox, ey2 - disp / 3 + 2 + oy, r, fill, c.rng));
        }
        return string(out);
    }

    // --- the build ----------------------------------------------------------

    struct Pre {
        int256[5][12] spikes; // li, sx, amp per entry (cap 12 for NEEDLES)
        uint256 nSpikes;
        int256 pulseLi;
        int256 pulseAmp;
        bool lightning;
        int256[13] quake;
        bool hasQuake;
        int256[3][6] moth; // bx, by, r
        uint256 nMoth;
        int256 splitY;
        int256[4][3] censor;
        bool hasCensor;
    }

    function build(RenderStateV1 memory s) public pure returns (T.Gen memory g) {
        Ctx memory c;
        c.rng = Rng.init(genesisSeed(s.genesisHash, s.tokenId));
        c.t = Mask.drawTraits(c.rng);
        c.flatLi = -1;
        // column noise walk (PHANTOM doubles the amplitude)
        {
            int256 noiseAmp = c.t.form == 15 ? int256(24) : int256(12);
            int256 n = 0;
            for (uint256 col = 0; col <= 50; col++) {
                n += (c.rng.rInt(3) - 1) * noiseAmp;
                if (n > 150) n = 150;
                if (n < -150) n = -150;
                c.noise[col] = n;
            }
        }
        // field line list per LINES style
        buildLines(c);
        Pre memory pre;
        pre.pulseLi = -1;
        pre.splitY = -1;
        preDraws(c, pre);
        c.mw = 9 + c.rng.rInt(5);
        c.mouthY = c.t.cy + 13 + c.rng.rInt(3);
        buildLinePaths(c, pre);
        c.tier = tierForKills(s.kills);
        g.figure = buildFigure(c, s, pre);
        g.t = c.t;
        g.rng = c.rng;
        g.slices = mkSlices(c, s);
        for (uint256 i = 0; i < 2; i++) {
            int256 ex = c.eyePos[i][0];
            int256 ey2 = c.eyePos[i][1];
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
            g.eyeScreen[i] = [ex, ey2 - disp / 3 + 2, c.eyePos[i][2]];
        }
    }

    function buildLines(Ctx memory c) internal pure {
        int256 lw = c.t.lineW;
        if (lw <= 2) {
            int256 w = lw == 0 ? int256(3) : lw == 1 ? int256(4) : int256(6);
            c.lines = new Line[](47);
            for (uint256 li = 0; li < 47; li++) c.lines[li] = Line(4 + int256(li) * 2, w, false, false);
        } else if (lw == 3) { // DENSE
            c.lines = new Line[](93);
            for (uint256 li = 0; li < 93; li++) c.lines[li] = Line(4 + int256(li), 2, false, false);
        } else if (lw == 4) { // SPARSE
            c.lines = new Line[](24);
            for (uint256 li = 0; li < 24; li++) c.lines[li] = Line(4 + int256(li) * 4, 5, false, false);
        } else if (lw == 5) { // DASHED
            c.lines = new Line[](47);
            for (uint256 li = 0; li < 47; li++) c.lines[li] = Line(4 + int256(li) * 2, 4, true, false);
        } else if (lw == 6) { // DUAL WEIGHT
            c.lines = new Line[](47);
            for (uint256 li = 0; li < 47; li++) c.lines[li] = Line(4 + int256(li) * 2, li % 2 == 1 ? int256(6) : int256(2), false, false);
        } else if (lw == 7) { // BARCODE
            c.lines = new Line[](47);
            for (uint256 li = 0; li < 47; li++) {
                int256 pick3 = c.rng.rInt(3);
                int256 w = pick3 == 0 ? int256(2) : pick3 == 1 ? int256(4) : int256(7);
                c.lines[li] = Line(4 + int256(li) * 2, w, false, false);
            }
        } else { // NO SIGNAL
            c.lines = new Line[](63);
            for (uint256 li = 0; li < 16; li++) c.lines[li] = Line(4 + int256(li) * 6, 3, false, false);
            for (uint256 li = 0; li < 47; li++) c.lines[16 + li] = Line(4 + int256(li) * 2, 3, false, true);
        }
        c.lineD = new string[](c.lines.length);
        c.lineMaxH = new int256[](c.lines.length);
    }

    function preDraws(Ctx memory c, Pre memory pre) internal pure {
        // spike styles (identical draw order to JS)
        int256 sp = c.t.spike;
        if (sp == 1 || sp == 2) {
            uint256 n = uint256(sp == 1 ? 1 + c.rng.rInt(2) : 3 + c.rng.rInt(3));
            for (uint256 i = 0; i < n; i++) {
                pre.spikes[pre.nSpikes][0] = c.rng.rInt(c.lines.length);
                pre.spikes[pre.nSpikes][1] = c.rng.rInt(34);
                int256 amp = 25 + c.rng.rInt(25);
                pre.spikes[pre.nSpikes][2] = c.rng.rInt(3) != 0 ? amp : -amp;
                pre.nSpikes++;
            }
        } else if (sp == 3) { // NEEDLES
            uint256 n = uint256(8 + c.rng.rInt(4));
            for (uint256 i = 0; i < n; i++) {
                pre.spikes[pre.nSpikes][0] = c.rng.rInt(c.lines.length);
                pre.spikes[pre.nSpikes][1] = c.rng.rInt(34);
                pre.spikes[pre.nSpikes][2] = -(8 + c.rng.rInt(8));
                pre.nSpikes++;
            }
        } else if (sp == 4) { // SEISMIC
            pre.spikes[0][0] = c.rng.rInt(c.lines.length);
            pre.spikes[0][1] = c.rng.rInt(34);
            int256 amp = 60 + c.rng.rInt(31);
            pre.spikes[0][2] = c.rng.rInt(3) != 0 ? amp : -amp;
            pre.nSpikes = 1;
        } else if (sp == 5) { // PULSE TRAIN
            pre.pulseLi = c.rng.rInt(c.lines.length);
            pre.pulseAmp = 18 + c.rng.rInt(10);
        } else if (sp == 6) {
            pre.lightning = true;
        } else if (sp == 7) { // EARTHQUAKE
            pre.hasQuake = true;
            for (uint256 i = 0; i < 13; i++) pre.quake[i] = c.rng.rInt(17) - 8;
        } else if (sp == 8) { // FLATLINE SCAR
            int256 target = 25 + c.rng.rInt(50);
            c.flatLi = 0;
            for (uint256 li = 0; li < c.lines.length; li++) {
                if (c.lines[li].y >= target) {
                    c.flatLi = int256(li);
                    break;
                }
            }
        }
        // tear styles
        if (c.t.tear == 4) { // MOTH EATEN
            uint256 nB = uint256(3 + c.rng.rInt(3));
            for (uint256 i = 0; i < nB; i++) {
                pre.moth[i][0] = c.rng.rInt(100);
                pre.moth[i][1] = 4 + c.rng.rInt(90);
                pre.moth[i][2] = 5 + c.rng.rInt(4);
            }
            pre.nMoth = nB;
        } else if (c.t.tear == 5) {
            pre.splitY = 14 + c.rng.rInt(66);
        } else if (c.t.tear == 7) { // CENSORED
            pre.hasCensor = true;
            for (uint256 i = 0; i < 3; i++) {
                pre.censor[i][0] = c.rng.rInt(70);
                pre.censor[i][1] = c.rng.rInt(80);
                pre.censor[i][2] = 12 + c.rng.rInt(14);
                pre.censor[i][3] = 8 + c.rng.rInt(8);
            }
        }
    }

    function buildLinePaths(Ctx memory c, Pre memory pre) internal pure {
        int256 mouthGapLo = c.t.mouth > 0 ? c.mouthY - 1 : int256(0);
        int256 mouthGapHi = c.t.mouth == 11 || c.t.mouth == 13
            ? c.mouthY + 8
            : (c.t.mouth == 4 ? c.mouthY + 2 : (c.t.mouth == 14 || c.t.mouth == 15 ? c.mouthY + 6 : c.mouthY + 4));
        for (uint256 li = 0; li < c.lines.length; li++) {
            Line memory L = c.lines[li];
            int256 baseY = L.y;
            if (int256(li) == c.flatLi) {
                c.lineD[li] = "";
                c.lineMaxH[li] = 0;
                continue;
            }
            Buf.B memory d = Buf.init(2400);
            bool pen = false;
            int256 px = 0;
            int256 py = 0;
            int256 breakLeft = 0;
            int256 maxH = 0;
            for (int256 xi = 0; xi <= 33; xi++) {
                int256 x = xi * 3;
                int256 h = Mask.heightAt(c.t, c.noise, x, baseY);
                if (h > maxH) maxH = h;
                int256 ypx = baseY * 10 - Num.jsRound(h, 10);
                for (uint256 k = 0; k < pre.nSpikes; k++) {
                    if (pre.spikes[k][0] == int256(li) && pre.spikes[k][1] == xi) ypx += pre.spikes[k][2];
                }
                if (int256(li) == pre.pulseLi && xi % 6 < 3) ypx -= pre.pulseAmp;
                if (pre.hasQuake) ypx += pre.quake[uint256((xi + int256(li) * 3) % 13)];
                bool gap = false;
                if (L.figOnly && h <= 300) gap = true;
                {
                    int256 yv = baseY - Num.jsRound(Mask.heightAt(c.t, c.noise, x, baseY), 100);
                    if (Mask.inSocket(c.t, x, yv, 0) || Mask.inSocket(c.t, x, yv, 1)) gap = true;
                }
                if (
                    c.t.mouth > 0 && baseY >= mouthGapLo && baseY <= mouthGapHi
                        && (x > c.t.cx ? x - c.t.cx : c.t.cx - x) < c.mw
                ) gap = true;
                if (L.dash && (xi + baseY) % 7 < 2) gap = true;
                for (uint256 m = 0; m < pre.nMoth; m++) {
                    int256 ddx = x - pre.moth[m][0];
                    int256 ddy = baseY - pre.moth[m][1];
                    if (ddx * ddx + ddy * ddy < pre.moth[m][2] * pre.moth[m][2]) gap = true;
                }
                if (pre.splitY >= 0 && baseY >= pre.splitY && baseY < pre.splitY + 5) gap = true;
                if (pre.hasCensor) {
                    for (uint256 m = 0; m < 3; m++) {
                        if (
                            x >= pre.censor[m][0] && x < pre.censor[m][0] + pre.censor[m][2]
                                && baseY >= pre.censor[m][1] && baseY < pre.censor[m][1] + pre.censor[m][3]
                        ) gap = true;
                    }
                }
                if (breakLeft > 0) {
                    breakLeft--;
                    gap = true;
                } else {
                    bool inFig = h > 300;
                    int256 p0;
                    if (c.t.tear <= 2) {
                        p0 = (c.t.tear == 0 ? int256(3) : c.t.tear == 1 ? int256(12) : int256(26))
                            + (inFig ? (c.t.tear == 0 ? int256(3) : c.t.tear == 1 ? int256(10) : int256(16)) : int256(0));
                    } else if (c.t.tear == 3) {
                        p0 = (xi < 6 || xi > 27) ? int256(45) : int256(4);
                    } else if (c.t.tear == 6) {
                        p0 = Num.max(3, ((92 - baseY) * 13) / 10);
                    } else {
                        p0 = c.t.tear == 4 ? int256(4) : int256(6);
                    }
                    if (c.rng.rInt(1000) < p0) {
                        breakLeft = 1 + c.rng.rInt(5);
                        gap = true;
                    }
                }
                if (gap) {
                    pen = false;
                    continue;
                }
                int256 X = x * 10;
                if (!pen) {
                    d.app(abi.encodePacked("M", Num.itoa(X), " ", Num.itoa(ypx)));
                    pen = true;
                } else {
                    int256 dy = ypx - py;
                    if (dy == 0) d.app(abi.encodePacked("h", Num.itoa(X - px)));
                    else d.app(abi.encodePacked("l", Num.itoa(X - px), " ", Num.itoa(dy)));
                }
                px = X;
                py = ypx;
            }
            c.lineD[li] = d.fin();
            c.lineMaxH[li] = maxH;
        }
    }

    /// stable rank of fig lines sorted by baseY (JS figLines sort order)
    function figRank(Ctx memory c, int256[] memory figIdx) internal pure returns (uint256 nFig) {
        uint256 n = c.lines.length;
        for (uint256 li = 0; li < n; li++) {
            if (bytes(c.lineD[li]).length > 0 && c.lineMaxH[li] > 800) {
                figIdx[li] = 0;
                nFig++;
            } else {
                figIdx[li] = -1;
            }
        }
        for (uint256 li = 0; li < n; li++) {
            if (figIdx[li] < 0) continue;
            int256 rank = 0;
            for (uint256 lj = 0; lj < n; lj++) {
                if (lj == li || figIdx[lj] < -1) continue;
                if (bytes(c.lineD[lj]).length > 0 && c.lineMaxH[lj] > 800) {
                    if (c.lines[lj].y < c.lines[li].y || (c.lines[lj].y == c.lines[li].y && lj < li)) rank++;
                }
            }
            figIdx[li] = rank;
        }
    }

    function swOf(Ctx memory c) internal pure returns (int256) {
        return Num.max(3, Num.min(6, c.lines[0].w));
    }

    function buildFigure(Ctx memory c, RenderStateV1 memory s, Pre memory pre) internal pure returns (string memory) {
        Buf.B memory f = Buf.init(48000);
        // white specks
        {
            Buf.B memory d = Buf.init(1200);
            int256 n = 12 + c.rng.rInt(16);
            for (int256 i = 0; i < n; i++) {
                int256 x = c.rng.rInt(100);
                int256 y = c.rng.rInt(100);
                d.app(abi.encodePacked("M", Num.itoa(x * 10), " ", Num.itoa(y * 10), "h10v10h-10z"));
            }
            f.app(abi.encodePacked('<path d="', d.fin(), '" fill="', T.WHITE, '"/>'));
        }
        int256[] memory figIdx = new int256[](c.lines.length);
        figRank(c, figIdx);
        uint256 crestN = c.tier >= 5 ? 4 : c.tier >= 4 ? 2 : c.tier >= 3 ? 1 : 0;
        bool invert = c.t.pink == 5;
        // echo passes
        {
            int256 dx = (2 + c.rng.rInt(3)) * 10;
            int256 dy = (1 + c.rng.rInt(2)) * 10;
            Buf.B memory e = Buf.init(26000);
            Buf.B memory e2 = Buf.init(12000);
            if (c.t.pink == 1 || c.t.pink == 2 || c.t.pink == 3) {
                int256 k = c.t.pink == 3 ? 8 + c.rng.rInt(3) : (c.t.pink == 2 ? 4 + c.rng.rInt(3) : 2 + c.rng.rInt(2));
                for (int256 i = 0; i < k; i++) {
                    uint256 li = uint256(c.rng.rInt(c.lines.length));
                    if (bytes(c.lineD[li]).length > 0) e.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            } else if (c.t.pink == 4) {
                int256 k = 3 + c.rng.rInt(2);
                for (int256 i = 0; i < k; i++) {
                    uint256 li = uint256(c.rng.rInt(c.lines.length));
                    if (bytes(c.lineD[li]).length > 0) e2.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            } else if (c.t.pink == 6) {
                int256 k = 3 + c.rng.rInt(2);
                for (int256 i = 0; i < k; i++) {
                    uint256 li = uint256(c.rng.rInt(c.lines.length));
                    if (bytes(c.lineD[li]).length > 0) e.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
                k = 2 + c.rng.rInt(2);
                for (int256 i = 0; i < k; i++) {
                    uint256 li = uint256(c.rng.rInt(c.lines.length));
                    if (bytes(c.lineD[li]).length > 0) e2.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            }
            if (c.tier >= 6) {
                for (uint256 li = 0; li < c.lines.length; li++) {
                    if (figIdx[li] >= 0 && figIdx[li] < 8) e.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            }
            if (e.len > 0) {
                f.app(
                    abi.encodePacked(
                        '<g fill="none" stroke="', T.PINK, '" stroke-width="', Num.itoa(swOf(c)),
                        '" transform="translate(', Num.itoa(dx), " ", Num.itoa(dy), ')">'
                    )
                );
                f.app(e.fin());
                f.app(bytes("</g>"));
            }
            if (e2.len > 0) {
                f.app(
                    abi.encodePacked(
                        '<g fill="none" stroke="', T.WHITE, '" stroke-width="', Num.itoa(swOf(c)),
                        '" transform="translate(', Num.itoa(-dx), " ", Num.itoa(dy), ')">'
                    )
                );
                f.app(e2.fin());
                f.app(bytes("</g>"));
            }
        }
        // the signal field, grouped by (colour role, stroke width)
        fieldGroups(c, f, figIdx, crestN, invert);
        // FLATLINE SCAR
        if (c.flatLi >= 0) {
            f.app(
                abi.encodePacked(
                    '<path d="M0 ', Num.itoa(c.lines[uint256(c.flatLi)].y * 10),
                    'h1000" fill="none" stroke="', T.WHITE, '" stroke-width="6"/>'
                )
            );
        }
        // LIGHTNING
        if (pre.lightning) {
            Buf.B memory d = Buf.init(512);
            d.app(abi.encodePacked("M0 ", Num.itoa((20 + c.rng.rInt(60)) * 10)));
            for (int256 x = 8; x <= 100; x += 8) {
                int256 ny = 10 + c.rng.rInt(80);
                d.app(abi.encodePacked("L", Num.itoa(x * 10), " ", Num.itoa(ny * 10)));
            }
            string memory dd = d.fin();
            f.app(abi.encodePacked('<path d="', dd, '" fill="none" stroke="', T.PINK, '" stroke-width="6"/>'));
            f.app(abi.encodePacked('<path d="', dd, '" fill="none" stroke="', T.WHITE, '" stroke-width="3"/>'));
        }
        // HEARTBEAT
        if (c.t.pink == 7) {
            int256 hy = (20 + c.rng.rInt(60)) * 10;
            int256 bx = (10 + c.rng.rInt(60)) * 10;
            f.app(
                abi.encodePacked(
                    '<path d="M0 ', Num.itoa(hy), "h", Num.itoa(bx), "l15 -70 15 140 15 -70h",
                    Num.itoa(1000 - bx - 45), '" fill="none" stroke="', T.PINK, '" stroke-width="6"/>'
                )
            );
        }
        // eyes + treatments + records + marks + halo
        eyesAndRest(c, s, f);
        return f.fin();
    }

    function fieldGroups(Ctx memory c, Buf.B memory f, int256[] memory figIdx, uint256 crestN, bool invert)
        internal
        pure
    {
        bool whiteFig = c.tier >= 6;
        bool pinkFigAll = c.tier >= 4;
        bool pinkFigUpper = c.tier == 3;
        bool pinkCrest6 = c.tier == 2;
        // per-line colour codes
        uint8[] memory colOf = new uint8[](c.lines.length);
        for (uint256 li = 0; li < c.lines.length; li++) {
            if (bytes(c.lineD[li]).length == 0) {
                colOf[li] = 9;
                continue;
            }
            uint8 col = 0;
            if (figIdx[li] >= 0) {
                if (invert) col = 1;
                if (whiteFig) col = 2;
                else if (pinkFigAll) col = 1;
                else if (pinkFigUpper && c.lines[li].y < c.t.cy) col = 1;
                else if (pinkCrest6 && figIdx[li] < 6) col = 1;
                if (!whiteFig && uint256(figIdx[li]) < crestN) col = 2;
            }
            colOf[li] = col;
        }
        for (uint8 col = 0; col < 3; col++) {
            for (int256 w = 2; w <= 7; w++) {
                bool any = false;
                for (uint256 li = 0; li < c.lines.length; li++) {
                    if (colOf[li] == col && c.lines[li].w == w) {
                        any = true;
                        break;
                    }
                }
                if (!any) continue;
                string memory stroke = col == 0 ? T.ACID : col == 1 ? T.PINK : T.WHITE;
                int256 wOut = (col == 0 && c.tier >= 5) ? Num.max(2, w - 1) : w;
                f.app(abi.encodePacked('<g fill="none" stroke="', stroke, '" stroke-width="', Num.itoa(wOut), '">'));
                for (uint256 li = 0; li < c.lines.length; li++) {
                    if (colOf[li] == col && c.lines[li].w == w) {
                        f.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                    }
                }
                f.app(bytes("</g>"));
            }
        }
    }

    function eyesAndRest(Ctx memory c, RenderStateV1 memory s, Buf.B memory f) internal pure {
        // eye positions
        {
            int256 rB = c.t.eyeR;
            c.eyePos[0] = [c.t.cx - (11 + c.rng.rInt(4)), c.t.cy + c.t.sLdy, rB, int256(0)];
            c.eyePos[1] =
                [c.t.cx + (11 + c.rng.rInt(4)), c.t.cy + c.t.sRdy, Num.max(5, rB + c.rng.rInt(4) - 1), int256(1)];
        }
        // screen-space eye centres
        for (uint256 i = 0; i < 2; i++) {
            int256 ex = c.eyePos[i][0];
            int256 ey2 = c.eyePos[i][1];
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
            c.eyeScr[i] = [ex, ey2 - disp / 3 + 2, c.eyePos[i][2], c.eyePos[i][3]];
        }
        // treatment escalation (specials 5+ untouched)
        {
            int256 base = c.t.treat;
            if (base <= 4) c.t.treat = c.tier >= 4 ? int256(4) : (c.tier >= 2 ? Num.max(1, base) : base);
        }
        string memory mainFill = T.ACID;
        if (c.t.treat == 1 || c.t.treat == 4) {
            f.app(drawEyes(c, T.PINK, 3, 2));
            f.app(drawEyes(c, T.ACID, -2, -2));
        } else if (c.t.treat == 2 || (c.t.mosh > 0 && c.t.treat == 0)) {
            f.app(drawEyes(c, T.PINK, 2, 2));
        }
        if (c.t.treat == 3 || c.t.treat == 4) {
            for (uint256 i = 0; i < 2; i++) {
                if (c.t.eyes == 6 && c.eyePos[i][3] == 1) continue;
                if (c.t.eyes == 7) continue;
                int256 ex = c.eyePos[i][0];
                int256 ey2 = c.eyePos[i][1];
                int256 r = c.eyePos[i][2];
                int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
                int256 cyp = ey2 - disp / 3 + 2;
                int256 kMax = c.t.treat == 4 ? int256(1) : int256(2);
                for (int256 k = 1; k <= kMax; k++) {
                    int256 rr = r + 3 + k * 4;
                    int256 q = (rr * 7) / 10;
                    Geom.Pt[] memory oct = new Geom.Pt[](8);
                    oct[0] = Geom.Pt(ex - rr, cyp);
                    oct[1] = Geom.Pt(ex - q, cyp - q);
                    oct[2] = Geom.Pt(ex, cyp - rr);
                    oct[3] = Geom.Pt(ex + q, cyp - q);
                    oct[4] = Geom.Pt(ex + rr, cyp);
                    oct[5] = Geom.Pt(ex + q, cyp + q);
                    oct[6] = Geom.Pt(ex, cyp + rr);
                    oct[7] = Geom.Pt(ex - q, cyp + q);
                    f.app(
                        abi.encodePacked(
                            '<path d="', Geom.pathD(oct), '" fill="none" stroke="', k == 1 ? T.ACID : T.PINK,
                            '" stroke-width="5"/>'
                        )
                    );
                }
            }
        } else if (c.t.treat == 5) { // STATIC
            int256 n = 10 + c.rng.rInt(6);
            int256 x0 = c.eyeScr[0][0] - 10;
            int256 x1 = c.eyeScr[1][0] + 10;
            Buf.B memory d = Buf.init(700);
            for (int256 i = 0; i < n; i++) {
                int256 x = x0 + c.rng.rInt(uint256(Num.max(4, x1 - x0)));
                int256 y = Num.min(c.eyeScr[0][1], c.eyeScr[1][1]) - 8 + c.rng.rInt(16);
                d.app(abi.encodePacked("M", Num.itoa(x * 10), " ", Num.itoa(y * 10), "h10v10h-10z"));
            }
            f.app(abi.encodePacked('<path d="', d.fin(), '" fill="', T.WHITE, '"/>'));
        } else if (c.t.treat == 6) { // CROSS FLARE
            for (uint256 i = 0; i < 2; i++) {
                int256 ex = c.eyeScr[i][0];
                int256 cyp = c.eyeScr[i][1];
                int256 r = c.eyeScr[i][2];
                f.app(Geom.rect(ex - 1, cyp - r - 8, 2, 6, T.ACID));
                f.app(Geom.rect(ex - 1, cyp + r + 2, 2, 6, T.ACID));
                f.app(Geom.rect(ex - r - 8, cyp - 1, 6, 2, T.ACID));
                f.app(Geom.rect(ex + r + 2, cyp - 1, 6, 2, T.ACID));
                f.app(Geom.rect(ex - 1, cyp - r - 10, 2, 2, T.PINK));
                f.app(Geom.rect(ex - 1, cyp + r + 8, 2, 2, T.PINK));
            }
        } else if (c.t.treat == 7) { // HALO EYES
            for (uint256 i = 0; i < 2; i++) {
                f.app(octRing(c.eyeScr[i][0], c.eyeScr[i][1], c.eyeScr[i][2] + 5, 5, T.WHITE));
            }
        } else if (c.t.treat == 8) { // SMEAR TRAIL
            f.app(drawEyes(c, T.PINK, 8, 0));
            f.app(drawEyes(c, T.WHITE, 4, 0));
        } else if (c.t.treat == 9) { // INVERTED
            for (uint256 i = 0; i < 2; i++) {
                int256 r = c.eyeScr[i][2];
                f.app(Geom.rect(c.eyeScr[i][0] - r - 3, c.eyeScr[i][1] - r + 1, 2 * r + 6, 2 * r - 1, T.ACID));
            }
            mainFill = T.BLACK;
        } else if (c.t.treat == 10) { // PRISM
            f.app(drawEyes(c, T.PINK, 4, 3));
            f.app(drawEyes(c, T.WHITE, -4, -3));
        } else if (c.t.treat == 11) { // GOD RAYS
            for (uint256 i = 0; i < 2; i++) {
                int256 ex = c.eyeScr[i][0];
                int256 cyp = c.eyeScr[i][1];
                f.app(
                    abi.encodePacked(
                        '<path d="M', Num.itoa(ex * 10), " ", Num.itoa(cyp * 10), "L0 0M", Num.itoa(ex * 10), " ",
                        Num.itoa(cyp * 10), "L1000 0M", Num.itoa(ex * 10), " ", Num.itoa(cyp * 10), "L",
                        ex > 50 ? "1000" : "0", " ", Num.itoa(cyp * 10 - 300), '" fill="none" stroke="', T.ACID,
                        '" stroke-width="4"/>'
                    )
                );
            }
        }
        f.app(drawEyes(c, mainFill, 0, 0));
        // kill notches
        if (s.kills > 0) {
            uint256 n = s.kills < 9 ? s.kills : 9;
            int256 lx = c.eyePos[0][0];
            int256 ly = c.eyePos[0][1];
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, lx, ly), 100);
            int256 ny2 = ly - disp / 3 - c.t.eyeR - 5;
            for (uint256 i = 0; i < n; i++) {
                f.app(Geom.rect(lx - c.t.eyeR + int256(i) * 3, ny2, 2, 3, T.PINK));
            }
        }
        if (s.forcedPurges > 0) {
            uint256 n = s.forcedPurges < 10 ? s.forcedPurges : 10;
            for (uint256 i = 0; i < n; i++) f.app(Geom.rect(8 + int256(i) * 4, 95, 2, 3, T.WHITE));
        }
        if (s.savesReceived > 0) {
            uint256 n = s.savesReceived < 5 ? s.savesReceived : 5;
            for (uint256 i = 0; i < n; i++) f.app(Geom.xmark(8 + int256(i) * 6, 88, 2, 1, T.PINK, c.rng));
        }
        if (s.deaths > 0) {
            Rng.R memory drng = Rng.init(damageSeed(s.genesisHash, s.tokenId, s.deaths));
            for (uint256 k2 = 0; k2 < s.deaths; k2++) {
                int256 sy2 = c.t.cy - 14 + drng.rInt(26);
                f.app(
                    abi.encodePacked(
                        '<path d="M', Num.itoa((c.t.cx - c.t.rw + 2) * 10), " ", Num.itoa(sy2 * 10), "l",
                        Num.itoa((c.t.rw - 4 + drng.rInt(8)) * 10), " ", Num.itoa((drng.rInt(5) - 2) * 10),
                        '" stroke="', T.WHITE, '" stroke-width="4" fill="none"/>'
                    )
                );
            }
        }
        mouthMarks(c, f);
        f.app(Mask.sigilSVG(s.wardId, 8, 8, T.ACID));
        f.app(Mask.blockMarkSVG(s.blockId, 90, 93, c.rng, T.ACID));
        if (c.tier > 0) haloInto(f, c);
    }

    function mouthMarks(Ctx memory c, Buf.B memory f) internal pure {
        if (c.t.mouth == 0) return;
        Mask.Traits memory t = c.t;
        int256 dispM = Num.jsRound(Mask.heightAt(t, c.noise, t.cx, c.mouthY), 100);
        int256 my = c.mouthY - dispM / 3 + 2;
        int256 mw = c.mw;
        int256 mo = t.mouth;
        if (mo == 1) {
            if (t.pink > 0) f.app(Geom.rect(t.cx - mw + 2, my + 1, mw, 1, T.PINK));
        } else if (mo == 2) {
            for (int256 x = t.cx - mw + 2; x < t.cx + mw - 1; x += 4) {
                int256 disp = Num.jsRound(Mask.heightAt(t, c.noise, x, c.mouthY), 100);
                f.app(Geom.rect(x, c.mouthY - disp / 3 + 2, 2, 5, T.ACID));
            }
        } else if (mo == 3) {
            for (int256 i = -1; i <= 1; i++) {
                int256 x = t.cx + i * 6;
                int256 disp = Num.jsRound(Mask.heightAt(t, c.noise, x, c.mouthY), 100);
                f.app(Geom.xmark(x, c.mouthY - disp / 3 + 3, 2, 1, T.ACID, c.rng));
            }
        } else if (mo == 4) {
            f.app(Geom.rect(t.cx - mw + 2, my + 1, 2 * mw - 4, 1, T.WHITE));
        } else if (mo == 5) {
            int256 i = 0;
            for (int256 x = t.cx - mw + 2; x < t.cx + mw - 1; x += 4) {
                if (i % 2 == 0) f.app(Geom.rect(x, my, 2, 5, T.ACID));
                else f.app(Geom.xmark(x + 1, my + 2, 2, 1, T.PINK, c.rng));
                i++;
            }
        } else if (mo == 6) {
            f.app(Geom.rect(t.cx - mw + 2, my, 2 * mw - 4, 2, T.ACID));
            f.app(Geom.rect(t.cx - mw + 3, my + 3, 2 * mw - 6, 2, T.PINK));
        } else if (mo == 7) {
            f.app(Geom.rect(t.cx, my + 1, mw, 2, T.ACID));
            f.app(Geom.rect(t.cx + mw - 2, my - 2, 2, 3, T.ACID));
        } else if (mo == 8) {
            f.app(Geom.rect(t.cx - mw + 2, my + 1, 2 * mw - 4, 1, T.WHITE));
            for (int256 x = t.cx - mw + 3; x < t.cx + mw - 2; x += 3) f.app(Geom.rect(x, my - 1, 1, 5, T.WHITE));
        } else if (mo == 9) {
            Geom.Pt[] memory p = new Geom.Pt[](4);
            p[0] = Geom.Pt(-mw + 2, 3);
            p[1] = Geom.Pt(mw - 2, -2);
            p[2] = Geom.Pt(mw - 2, 0);
            p[3] = Geom.Pt(-mw + 2, 5);
            f.app(Geom.poly(Geom.offsetPts(p, t.cx, my), T.ACID));
        } else if (mo == 10) {
            f.app(Geom.rect(t.cx - mw + 2, my, 2 * mw - 4, 2, T.ACID));
            f.app(Geom.drip(t.cx - 2, my + 2, 6 + c.rng.rInt(4), 1, T.PINK, c.rng));
            f.app(Geom.drip(t.cx + 4, my + 2, 4 + c.rng.rInt(3), 1, T.PINK, c.rng));
        } else if (mo == 11) {
            for (int256 x = t.cx - mw + 2; x < t.cx + mw - 1; x += 3) {
                int256 hh = 5 + c.rng.rInt(5);
                f.app(Geom.rect(x, my, 2, hh, T.ACID));
            }
        } else if (mo == 12) {
            f.app(Geom.rect(t.cx - mw + 2, my, 2 * mw - 4, 2, T.ACID));
            Geom.Pt[] memory p1 = new Geom.Pt[](3);
            p1[0] = Geom.Pt(-4, 2);
            p1[1] = Geom.Pt(-1, 2);
            p1[2] = Geom.Pt(-2, 7);
            f.app(Geom.poly(Geom.offsetPts(p1, t.cx, my), T.WHITE));
            Geom.Pt[] memory p2 = new Geom.Pt[](3);
            p2[0] = Geom.Pt(2, 2);
            p2[1] = Geom.Pt(5, 2);
            p2[2] = Geom.Pt(4, 7);
            f.app(Geom.poly(Geom.offsetPts(p2, t.cx, my), T.WHITE));
        } else if (mo == 13) {
            f.app(octRing(t.cx, my + 3, 5, 4, T.ACID));
        } else if (mo == 14) {
            f.app(Geom.rect(t.cx - mw, my - 2, 2 * mw, 7, T.BLACK));
            f.app(
                abi.encodePacked(
                    '<rect x="', Num.itoa((t.cx - mw) * 10), '" y="', Num.itoa((my - 2) * 10), '" width="',
                    Num.itoa(2 * mw * 10), '" height="70" fill="none" stroke="', T.ACID, '" stroke-width="5"/>'
                )
            );
            f.app(Geom.rect(t.cx - 4, my - 1, 1, 5, T.ACID));
            f.app(Geom.rect(t.cx, my - 1, 1, 5, T.ACID));
            f.app(Geom.rect(t.cx + 4, my - 1, 1, 5, T.ACID));
        } else if (mo == 15) {
            f.app(Geom.rect(t.cx - mw + 1, my - 1, mw + 3, 2, T.ACID));
            f.app(Geom.rect(t.cx - mw + 4, my + 2, mw + 3, 2, T.PINK));
            f.app(Geom.rect(t.cx - mw - 1, my + 5, mw + 3, 2, T.WHITE));
        }
    }

    function mkSlices(Ctx memory c, RenderStateV1 memory s) internal pure returns (T.Slc[] memory) {
        T.Slc[] memory tmp = new T.Slc[](16);
        uint256 nm = 0;
        if (c.t.mosh == 1 || c.t.mosh == 2) {
            uint256 n = uint256(c.t.mosh == 2 ? 4 + c.rng.rInt(2) : 2 + c.rng.rInt(2));
            for (uint256 i = 0; i < n; i++) {
                T.Slc memory e = tmp[nm++];
                e.y = 6 + c.rng.rInt(84);
                e.h = 2 + c.rng.rInt(5);
                int256 base = 2 + c.rng.rInt(7);
                e.dx = c.rng.rInt(2) != 0 ? base : -base;
            }
        } else if (c.t.mosh == 3) {
            T.Slc memory e = tmp[nm++];
            e.y = 6 + c.rng.rInt(70);
            e.h = 8 + c.rng.rInt(5);
            int256 base = 12 + c.rng.rInt(7);
            e.dx = c.rng.rInt(2) != 0 ? base : -base;
        } else if (c.t.mosh == 4) {
            uint256 n = uint256(8 + c.rng.rInt(3));
            for (uint256 i = 0; i < n; i++) {
                T.Slc memory e = tmp[nm++];
                e.y = 4 + c.rng.rInt(88);
                e.h = 2 + c.rng.rInt(3);
                int256 base = 3 + c.rng.rInt(7);
                e.dx = c.rng.rInt(2) != 0 ? base : -base;
            }
        } else if (c.t.mosh == 5) {
            int256 d5 = 6 + c.rng.rInt(4);
            int256 sgn = c.rng.rInt(2) != 0 ? int256(1) : int256(-1);
            T.Slc memory e1 = tmp[nm++];
            e1.y = 4;
            e1.h = 46;
            e1.dx = d5 * sgn;
            T.Slc memory e2 = tmp[nm++];
            e2.y = 50;
            e2.h = 46;
            e2.dx = -d5 * sgn;
        } else if (c.t.mosh == 6) {
            T.Slc memory e0 = tmp[nm++];
            e0.y = 30 + c.rng.rInt(40);
            e0.h = 6 + c.rng.rInt(5);
            e0.smear = true;
            for (uint256 i = 0; i < 3; i++) {
                T.Slc memory e = tmp[nm++];
                e.y = 6 + c.rng.rInt(84);
                e.h = 2 + c.rng.rInt(4);
                int256 base = 4 + c.rng.rInt(7);
                e.dx = c.rng.rInt(2) != 0 ? base : -base;
            }
        }
        // death slices
        uint256 total = nm + s.deaths;
        T.Slc[] memory sl = new T.Slc[](total);
        for (uint256 i = 0; i < nm; i++) sl[i] = tmp[i];
        if (s.deaths > 0) {
            Rng.R memory drng = Rng.init(damageSeed(s.genesisHash, s.tokenId, s.deaths));
            for (uint256 k2 = 0; k2 < s.deaths; k2++) {
                T.Slc memory e = sl[nm + k2];
                e.y = c.t.cy - 16 + drng.rInt(30);
                e.h = 3 + drng.rInt(4);
                int256 base = 5 + drng.rInt(8);
                e.dx = drng.rInt(2) != 0 ? base : -base;
            }
        }
        return sl;
    }

    function haloInto(Buf.B memory f, Ctx memory c) internal pure {
        int256[34] memory crest;
        for (int256 xi = 0; xi <= 33; xi++) {
            int256 x = xi * 3;
            int256 best = 100000;
            for (uint256 li = 0; li < 47; li++) {
                int256 baseY = 4 + int256(li) * 2;
                int256 h = Mask.heightAt(c.t, c.noise, x, baseY);
                if (h > 300) {
                    int256 vy = baseY * 10 - Num.jsRound(h, 10);
                    if (vy < best) best = vy;
                }
            }
            crest[uint256(xi)] = best == 100000 ? int256(-1) : best;
        }
        string memory gcol = c.tier >= 4 ? T.WHITE : T.PINK;
        uint256 nArcs = c.tier == 1 ? 1 : c.tier == 2 ? 2 : c.tier == 3 ? 3 : c.tier >= 5 ? 2 : 1;
        for (uint256 k = 0; k < nArcs; k++) {
            Buf.B memory d = Buf.init(1600);
            if (c.tier == 3 && k == 2) {
                bool pen = false;
                for (uint256 xi = 0; xi <= 33; xi++) {
                    int256 cc = crest[xi];
                    if (cc < 0 || xi % 5 == 0) {
                        pen = false;
                        continue;
                    }
                    int256 X = int256(xi) * 30;
                    int256 Y = cc - 110;
                    if (Y < 20) {
                        pen = false;
                        continue;
                    }
                    if (!pen) {
                        d.app(abi.encodePacked("M", Num.itoa(X), " ", Num.itoa(Y)));
                        pen = true;
                    } else {
                        d.app(abi.encodePacked("L", Num.itoa(X), " ", Num.itoa(Y)));
                    }
                }
            } else {
                int256 off = 5 + int256(k) * 3;
                bool pen = false;
                for (uint256 xi = 0; xi <= 33; xi++) {
                    int256 cc = crest[xi];
                    if (cc < 0) {
                        pen = false;
                        continue;
                    }
                    int256 X = int256(xi) * 30;
                    int256 Y = cc - off * 10;
                    if (Y < 20) {
                        pen = false;
                        continue;
                    }
                    if (!pen) {
                        d.app(abi.encodePacked("M", Num.itoa(X), " ", Num.itoa(Y)));
                        pen = true;
                    } else {
                        d.app(abi.encodePacked("L", Num.itoa(X), " ", Num.itoa(Y)));
                    }
                }
            }
            if (d.len > 0) {
                f.app(
                    abi.encodePacked(
                        '<path d="', d.fin(), '" fill="none" stroke="', gcol, '" stroke-width="',
                        c.tier >= 4 ? "5" : "4", '"/>'
                    )
                );
            }
        }
        if (c.tier >= 4) {
            for (uint256 xi = 1; xi < 33; xi += 3) {
                int256 cc = crest[xi];
                if (cc < 0) continue;
                int256 X = int256(xi) * 30;
                int256 Y = cc - 50;
                if (Y > 60) {
                    f.app(
                        abi.encodePacked(
                            '<path d="M', Num.itoa(X), " ", Num.itoa(Y - 10), "V",
                            Num.itoa(Num.max(20, Y - 10 - (c.tier >= 5 ? int256(50) : int256(30)))), '" stroke="',
                            gcol, '" stroke-width="4" fill="none"/>'
                        )
                    );
                }
            }
        }
        if (c.tier >= 5) {
            for (uint256 xi = 2; xi < 33; xi += 4) {
                int256 cc = crest[xi];
                if (cc < 0) continue;
                int256 X = int256(xi) * 3;
                int256 Y = Num.jsRound(cc, 10) - 9;
                if (Y > 7) {
                    Geom.Pt[] memory p = new Geom.Pt[](3);
                    p[0] = Geom.Pt(X - 1, Y);
                    p[1] = Geom.Pt(X + 1, Y);
                    p[2] = Geom.Pt(X, Num.max(3, Y - 4));
                    f.app(Geom.poly(p, T.PINK));
                }
            }
        }
        if (c.tier >= 6) {
            int256 rcx = c.t.cx * 10;
            int256 rcy = (c.t.cy - 2) * 10;
            int256 rx = Num.min((c.t.rw + 16) * 10, Num.min(rcx - 20, 1000 - rcx - 20));
            int256 ry = Num.min((c.t.rh + c.t.amp / 2 + 12) * 10, rcy - 20);
            f.app(
                abi.encodePacked(
                    '<ellipse cx="', Num.itoa(rcx + 8), '" cy="', Num.itoa(rcy + 6), '" rx="', Num.itoa(rx),
                    '" ry="', Num.itoa(ry), '" fill="none" stroke="', T.PINK, '" stroke-width="4"/>'
                )
            );
            f.app(
                abi.encodePacked(
                    '<ellipse cx="', Num.itoa(rcx), '" cy="', Num.itoa(rcy), '" rx="', Num.itoa(rx), '" ry="',
                    Num.itoa(ry), '" fill="none" stroke="', T.WHITE, '" stroke-width="5"/>'
                )
            );
        }
    }
}
