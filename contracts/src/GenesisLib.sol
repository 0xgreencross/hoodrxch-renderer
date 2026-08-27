// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RenderStateV1} from "./RenderState.sol";
import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";
import {Geom} from "./Geom.sol";
import {Mask} from "./Mask.sol";
import {T} from "./Types.sol";

/// @notice buildGenesis — the SIGNAL WRAITH figure. Mirrors src/05_render.js
/// buildGenesis() with identical RNG draw order and identical output bytes.
library GenesisLib {
    using Buf for Buf.B;
    using Rng for Rng.R;

    struct Ctx {
        Rng.R rng;
        Mask.Traits t;
        int256[51] noise;
        int256[4][2] eyePos; // x, y, r, side
        string[47] lineD;
        int256[47] lineMaxH;
        int256 mw;
        int256 mouthY;
        uint256 tier;
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

    /// eyeArm — one X arm quad (no rng)
    function eyeArm(int256 cx, int256 cy, int256 dx, int256 dy, int256 r, int256 b, string memory fill)
        internal
        pure
        returns (string memory)
    {
        // JS: `cx-b*dy/2|0 || cx` — precedence: the |0 truncates the WHOLE
        // (cx - b*dy/2) expression; || only guards a 0 result.
        int256 p0x = (2 * cx - b * dy) / 2; // trunc of cx - b*dy/2
        if (p0x == 0) p0x = cx;
        int256 p0y = (2 * cy + b * dx) / 2; // trunc of cy + b*dx/2
        if (p0y == 0) p0y = cy;
        Geom.Pt[] memory p = new Geom.Pt[](4);
        p[0] = Geom.Pt(p0x, p0y);
        p[1] = Geom.Pt(cx + (b * dy) / 2, cy - (b * dx) / 2);
        p[2] = Geom.Pt(cx + dx * r + (b * dy) / 2, cy + dy * r - (b * dx) / 2);
        p[3] = Geom.Pt(cx + dx * r - (b * dy) / 2, cy + dy * r + (b * dx) / 2);
        return Geom.poly(p, fill);
    }

    function eyeGlyph(
        int256 st,
        uint256 side,
        int256 cx,
        int256 cy,
        int256 r,
        string memory fill,
        Rng.R memory rng
    ) internal pure returns (string memory) {
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
        return "";
    }

    function drawEyes(Ctx memory c, string memory fill, int256 ox, int256 oy) internal pure returns (string memory) {
        if (c.t.eyes == 3) {
            int256 lx = c.eyePos[0][0];
            int256 ly = c.eyePos[0][1];
            int256 lr = c.eyePos[0][2];
            int256 rx2 = c.eyePos[1][0];
            int256 ry2 = c.eyePos[1][1];
            int256 rr2 = c.eyePos[1][2];
            ry2; // silence
            int256 dispL = Num.jsRound(Mask.heightAt(c.t, c.noise, lx, ly), 100);
            int256 vy = ly - dispL / 3 + 2;
            Geom.Pt[] memory p = new Geom.Pt[](4);
            p[0] = Geom.Pt(lx - lr, vy + 2);
            p[1] = Geom.Pt(rx2 + rr2, vy);
            p[2] = Geom.Pt(rx2 + rr2, vy + 5);
            p[3] = Geom.Pt(lx - lr, vy + 7);
            return Geom.poly(Geom.offsetPts(p, ox, oy), fill);
        }
        bytes memory e;
        for (uint256 i = 0; i < 2; i++) {
            int256 ex = c.eyePos[i][0];
            int256 ey2 = c.eyePos[i][1];
            int256 r = c.eyePos[i][2];
            uint256 side = uint256(c.eyePos[i][3]);
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
            e = abi.encodePacked(e, eyeGlyph(c.t.eyes, side, ex + ox, ey2 - disp / 3 + 2 + oy, r, fill, c.rng));
        }
        return string(e);
    }

    /// full genesis build; returns figure + slices + traits + rng + eye anchors
    function build(RenderStateV1 memory s) public pure returns (T.Gen memory g) {
        Ctx memory c;
        c.rng = Rng.init(genesisSeed(s.genesisHash, s.tokenId));
        c.t = Mask.drawTraits(c.rng);
        // column noise walk
        {
            int256 n = 0;
            for (uint256 col = 0; col <= 50; col++) {
                n += (c.rng.rInt(3) - 1) * 12;
                if (n > 150) n = 150;
                if (n < -150) n = -150;
                c.noise[col] = n;
            }
        }
        // spikes
        int256[5] memory spikeLi;
        int256[5] memory spikeSx;
        int256[5] memory spikeAmp;
        uint256 nSpikes;
        {
            // JS evaluates the whole array literal: two draws always happen
            int256 s1 = 1 + c.rng.rInt(2);
            int256 s2 = 3 + c.rng.rInt(3);
            int256 nS = c.t.spike == 0 ? int256(0) : (c.t.spike == 1 ? s1 : s2);
            nSpikes = uint256(nS);
            for (uint256 i = 0; i < nSpikes; i++) {
                spikeLi[i] = c.rng.rInt(47);
                spikeSx[i] = c.rng.rInt(34);
                int256 amp = 25 + c.rng.rInt(25);
                spikeAmp[i] = c.rng.rInt(3) != 0 ? amp : -amp;
            }
        }
        c.mw = 9 + c.rng.rInt(5);
        c.mouthY = c.t.cy + 13 + c.rng.rInt(3);
        // line paths
        for (uint256 li = 0; li < 47; li++) {
            int256 baseY = 4 + int256(li) * 2;
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
                for (uint256 k = 0; k < nSpikes; k++) {
                    if (spikeLi[k] == int256(li) && spikeSx[k] == xi) ypx += spikeAmp[k];
                }
                bool gap = false;
                {
                    int256 yv = baseY - Num.jsRound(Mask.heightAt(c.t, c.noise, x, baseY), 100);
                    if (Mask.inSocket(c.t, x, yv, 0) || Mask.inSocket(c.t, x, yv, 1)) gap = true;
                }
                if (
                    c.t.mouth > 0 && baseY >= c.mouthY - 1 && baseY <= c.mouthY + 4
                        && (x > c.t.cx ? x - c.t.cx : c.t.cx - x) < c.mw
                ) gap = true;
                if (breakLeft > 0) {
                    breakLeft--;
                    gap = true;
                } else {
                    bool inFig = h > 300;
                    int256 p0 = (c.t.tear == 0 ? int256(3) : c.t.tear == 1 ? int256(12) : int256(26))
                        + (inFig ? (c.t.tear == 0 ? int256(3) : c.t.tear == 1 ? int256(10) : int256(16)) : int256(0));
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
        c.tier = tierForKills(s.kills);
        g.figure = buildFigure(c, s);
        g.t = c.t;
        g.rng = c.rng;
        g.slices = mkSlices(c, s);
        mkEyeScreen(c, g);
    }

    // slices (mosh, then deaths)
    function mkSlices(Ctx memory c, RenderStateV1 memory s) internal pure returns (T.Slc[] memory sl) {
        uint256 nm = 0;
        if (c.t.mosh > 0) nm = uint256(c.t.mosh == 2 ? 4 + c.rng.rInt(2) : 2 + c.rng.rInt(2));
        sl = new T.Slc[](nm + s.deaths);
        for (uint256 i = 0; i < nm; i++) {
            T.Slc memory e = sl[i];
            e.y = 6 + c.rng.rInt(84);
            e.h = 2 + c.rng.rInt(5);
            int256 base = 2 + c.rng.rInt(7);
            e.dx = c.rng.rInt(2) != 0 ? base : -base;
        }
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
    }

    // eye anchors for overlays
    function mkEyeScreen(Ctx memory c, T.Gen memory g) internal pure {
        for (uint256 i = 0; i < 2; i++) {
            int256 ex = c.eyePos[i][0];
            int256 ey2 = c.eyePos[i][1];
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, ex, ey2), 100);
            g.eyeScreen[i] = [ex, ey2 - disp / 3 + 2, c.eyePos[i][2]];
        }
    }

    /// the figure string (z1–z6), continuing the ctx rng stream
    function buildFigure(Ctx memory c, RenderStateV1 memory s) internal pure returns (string memory) {
        Buf.B memory f = Buf.init(40000);
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
        // fig line classification
        int256[47] memory figIdx; // index within figLines, or -1
        uint256 nFig = 0;
        for (uint256 li = 0; li < 47; li++) {
            if (bytes(c.lineD[li]).length > 0 && c.lineMaxH[li] > 800) {
                figIdx[li] = int256(nFig);
                nFig++;
            } else {
                figIdx[li] = -1;
            }
        }
        uint256 crestN = c.tier >= 5 ? 4 : c.tier >= 4 ? 2 : c.tier >= 3 ? 1 : 0;
        // pink echo pass
        {
            int256 dx = (2 + c.rng.rInt(3)) * 10;
            int256 dy = (1 + c.rng.rInt(2)) * 10;
            Buf.B memory e = Buf.init(24000);
            if (c.t.pink > 0) {
                int256 k = c.t.pink == 2 ? 4 + c.rng.rInt(3) : 2 + c.rng.rInt(2);
                for (int256 i = 0; i < k; i++) {
                    uint256 li = uint256(c.rng.rInt(47));
                    if (bytes(c.lineD[li]).length > 0) e.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            }
            if (c.tier >= 6) {
                for (uint256 li = 0; li < 47; li++) {
                    if (figIdx[li] >= 0 && figIdx[li] < 8) e.app(abi.encodePacked('<path d="', c.lineD[li], '"/>'));
                }
            }
            if (e.len > 0) {
                f.app(
                    abi.encodePacked(
                        '<g fill="none" stroke="',
                        T.PINK,
                        '" stroke-width="',
                        Num.itoa(sw(c.t)),
                        '" transform="translate(',
                        Num.itoa(dx),
                        " ",
                        Num.itoa(dy),
                        ')">'
                    )
                );
                f.app(e.fin());
                f.app(bytes("</g>"));
            }
        }
        // field grouped by colour role
        {
            Buf.B memory gA = Buf.init(24000);
            Buf.B memory gP = Buf.init(24000);
            Buf.B memory gW = Buf.init(24000);
            bool whiteFig = c.tier >= 6;
            bool pinkFigAll = c.tier >= 4;
            bool pinkFigUpper = c.tier == 3;
            bool pinkCrest6 = c.tier == 2;
            for (uint256 li = 0; li < 47; li++) {
                if (bytes(c.lineD[li]).length == 0) continue;
                uint8 col = 0; // A
                if (figIdx[li] >= 0) {
                    if (whiteFig) col = 2;
                    else if (pinkFigAll) col = 1;
                    else if (pinkFigUpper && (4 + int256(li) * 2) < c.t.cy) col = 1;
                    else if (pinkCrest6 && figIdx[li] < 6) col = 1;
                    if (!whiteFig && figIdx[li] >= 0 && uint256(figIdx[li]) < crestN) col = 2;
                }
                bytes memory pth = abi.encodePacked('<path d="', c.lineD[li], '"/>');
                if (col == 0) gA.app(pth);
                else if (col == 1) gP.app(pth);
                else gW.app(pth);
            }
            int256 bgw = c.tier >= 5 ? Num.max(2, sw(c.t) - 1) : sw(c.t);
            if (gA.len > 0) {
                f.app(abi.encodePacked('<g fill="none" stroke="', T.ACID, '" stroke-width="', Num.itoa(bgw), '">'));
                f.app(gA.fin());
                f.app(bytes("</g>"));
            }
            if (gP.len > 0) {
                f.app(abi.encodePacked('<g fill="none" stroke="', T.PINK, '" stroke-width="', Num.itoa(sw(c.t)), '">'));
                f.app(gP.fin());
                f.app(bytes("</g>"));
            }
            if (gW.len > 0) {
                f.app(
                    abi.encodePacked('<g fill="none" stroke="', T.WHITE, '" stroke-width="', Num.itoa(sw(c.t)), '">')
                );
                f.app(gW.fin());
                f.app(bytes("</g>"));
            }
        }
        // eyes
        {
            int256 rB = c.t.eyeR;
            c.eyePos[0] = [c.t.cx - (11 + c.rng.rInt(4)), c.t.cy + c.t.sLdy, rB, int256(0)];
            c.eyePos[1] =
                [c.t.cx + (11 + c.rng.rInt(4)), c.t.cy + c.t.sRdy, Num.max(5, rB + c.rng.rInt(4) - 1), int256(1)];
        }
        {
            // treatment escalation
            int256 base = c.t.treat;
            c.t.treat = c.tier >= 4 ? int256(4) : (c.tier >= 2 ? Num.max(1, base) : base);
        }
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
                            '<path d="',
                            Geom.pathD(oct),
                            '" fill="none" stroke="',
                            k == 1 ? T.ACID : T.PINK,
                            '" stroke-width="3"/>'
                        )
                    );
                }
            }
        }
        f.app(drawEyes(c, T.ACID, 0, 0));
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
        // forced-purge tallies
        if (s.forcedPurges > 0) {
            uint256 n = s.forcedPurges < 10 ? s.forcedPurges : 10;
            for (uint256 i = 0; i < n; i++) {
                f.app(Geom.rect(8 + int256(i) * 4, 95, 2, 3, T.WHITE));
            }
        }
        // survival stitches
        if (s.savesReceived > 0) {
            uint256 n = s.savesReceived < 5 ? s.savesReceived : 5;
            for (uint256 i = 0; i < n; i++) {
                f.app(Geom.xmark(8 + int256(i) * 6, 88, 2, 1, T.PINK, c.rng));
            }
        }
        // death scars
        if (s.deaths > 0) {
            Rng.R memory drng = Rng.init(damageSeed(s.genesisHash, s.tokenId, s.deaths));
            for (uint256 k2 = 0; k2 < s.deaths; k2++) {
                int256 sy2 = c.t.cy - 14 + drng.rInt(26);
                f.app(
                    abi.encodePacked(
                        '<path d="M',
                        Num.itoa((c.t.cx - c.t.rw + 2) * 10),
                        " ",
                        Num.itoa(sy2 * 10),
                        "l",
                        Num.itoa((c.t.rw - 4 + drng.rInt(8)) * 10),
                        " ",
                        Num.itoa((drng.rInt(5) - 2) * 10),
                        '" stroke="',
                        T.WHITE,
                        '" stroke-width="4" fill="none"/>'
                    )
                );
            }
        }
        // mouth details
        if (c.t.mouth == 2) {
            for (int256 x = c.t.cx - c.mw + 2; x < c.t.cx + c.mw - 1; x += 4) {
                int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, x, c.mouthY), 100);
                f.app(Geom.rect(x, c.mouthY - disp / 3 + 2, 2, 5, T.ACID));
            }
        } else if (c.t.mouth == 3) {
            for (int256 i = -1; i <= 1; i++) {
                int256 x = c.t.cx + i * 6;
                int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, x, c.mouthY), 100);
                f.app(Geom.xmark(x, c.mouthY - disp / 3 + 3, 2, 1, T.ACID, c.rng));
            }
        } else if (c.t.mouth == 1 && c.t.pink > 0) {
            int256 disp = Num.jsRound(Mask.heightAt(c.t, c.noise, c.t.cx, c.mouthY), 100);
            f.app(Geom.rect(c.t.cx - c.mw + 2, c.mouthY - disp / 3 + 3, c.mw, 1, T.PINK));
        }
        // ward sigil + block mark
        f.app(Mask.sigilSVG(s.wardId, 8, 8, T.ACID));
        f.app(Mask.blockMarkSVG(s.blockId, 90, 93, c.rng, T.ACID));
        // kill-tier halo
        if (c.tier > 0) haloInto(f, c);
        return f.fin();
    }

    function sw(Mask.Traits memory t) internal pure returns (int256) {
        return t.lineW == 0 ? int256(3) : t.lineW == 1 ? int256(4) : int256(6);
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
                        '<path d="',
                        d.fin(),
                        '" fill="none" stroke="',
                        gcol,
                        '" stroke-width="',
                        c.tier >= 4 ? "5" : "4",
                        '"/>'
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
                            '<path d="M',
                            Num.itoa(X),
                            " ",
                            Num.itoa(Y - 10),
                            "V",
                            Num.itoa(Num.max(20, Y - 10 - (c.tier >= 5 ? int256(50) : int256(30)))),
                            '" stroke="',
                            gcol,
                            '" stroke-width="4" fill="none"/>'
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
                    '<ellipse cx="',
                    Num.itoa(rcx + 8),
                    '" cy="',
                    Num.itoa(rcy + 6),
                    '" rx="',
                    Num.itoa(rx),
                    '" ry="',
                    Num.itoa(ry),
                    '" fill="none" stroke="',
                    T.PINK,
                    '" stroke-width="4"/>'
                )
            );
            f.app(
                abi.encodePacked(
                    '<ellipse cx="',
                    Num.itoa(rcx),
                    '" cy="',
                    Num.itoa(rcy),
                    '" rx="',
                    Num.itoa(rx),
                    '" ry="',
                    Num.itoa(ry),
                    '" fill="none" stroke="',
                    T.WHITE,
                    '" stroke-width="5"/>'
                )
            );
        }
    }
}
