// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Num} from "./Num.sol";
import {Rng} from "./Rng.sol";
import {Geom} from "./Geom.sol";

/// @notice Genesis anatomy: traits, heightfield, ward sigils, block marks.
/// Mirrors src/04_genesis.js (SIGNAL WRAITH). Integer centi-unit math only.
library Mask {
    using Rng for Rng.R;

    string internal constant PINK = "#FF3EB5";
    string internal constant WHITE = "#FFFFFF";

    struct Traits {
        int256 cx;
        int256 cy;
        int256 rw;
        int256 rh;
        int256 amp;
        int256 peak;
        int256 pamp;
        int256 jawY;
        int256 sLdx;
        int256 sLdy;
        int256 sLr;
        int256 sLd;
        int256 sRdx;
        int256 sRdy;
        int256 sRr;
        int256 sRd;
        int256 nas;
        int256 lineW;
        int256 tear;
        int256 spike;
        int256 eyes;
        int256 eyeR;
        int256 treat;
        int256 mouth;
        int256 pink;
        int256 mosh;
        int256 form;
        int256 x2mode; // 0 none · 1 twin peak · 2 horns · 3 crater
        int256 x2amp;
        int256 x2dx;
    }

    // --- TRAIT ENGINE V2: per-mille weight tables (six rarity tiers) ---
    function wForm() internal pure returns (uint16[16] memory) {
        return [uint16(195), 185, 95, 95, 90, 80, 55, 55, 30, 30, 28, 25, 12, 12, 8, 5];
    }

    function wLine() internal pure returns (uint16[9] memory) {
        return [uint16(240), 260, 210, 90, 90, 55, 35, 15, 5];
    }

    function wTear() internal pure returns (uint16[8] memory) {
        return [uint16(330), 330, 150, 90, 50, 30, 15, 5];
    }

    function wSpike() internal pure returns (uint16[9] memory) {
        return [uint16(300), 330, 130, 90, 50, 45, 35, 15, 5];
    }

    function wEye() internal pure returns (uint16[25] memory) {
        return [uint16(155), 100, 55, 100, 45, 95, 45, 40, 30, 50, 45, 40, 30, 28, 27, 25, 25, 12, 12, 12, 9, 5, 5, 5, 5];
    }

    function wTreat() internal pure returns (uint16[12] memory) {
        return [uint16(190), 240, 190, 90, 120, 60, 35, 25, 25, 12, 8, 5];
    }

    function wMouth() internal pure returns (uint16[16] memory) {
        return [uint16(200), 165, 160, 128, 60, 55, 50, 45, 32, 30, 28, 14, 13, 8, 7, 5];
    }

    function wPink() internal pure returns (uint16[8] memory) {
        return [uint16(320), 350, 150, 80, 50, 30, 15, 5];
    }

    function wMosh() internal pure returns (uint16[7] memory) {
        return [uint16(360), 330, 160, 80, 50, 15, 5];
    }

    /// weighted pick against a cumulative per-mille table
    function pick(Rng.R memory rng, uint16[] memory W) internal pure returns (int256) {
        int256 r = rng.r1000();
        for (uint256 i = 0; i < W.length; i++) {
            r -= int256(uint256(W[i]));
            if (r < 0) return int256(i);
        }
        return int256(W.length - 1);
    }

    function dyn16(uint16[16] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](16);
        for (uint256 i = 0; i < 16; i++) o[i] = a[i];
    }

    function dyn9(uint16[9] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](9);
        for (uint256 i = 0; i < 9; i++) o[i] = a[i];
    }

    function dyn8(uint16[8] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](8);
        for (uint256 i = 0; i < 8; i++) o[i] = a[i];
    }

    function dyn25(uint16[25] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](25);
        for (uint256 i = 0; i < 25; i++) o[i] = a[i];
    }

    function dyn12(uint16[12] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](12);
        for (uint256 i = 0; i < 12; i++) o[i] = a[i];
    }

    function dyn7(uint16[7] memory a) private pure returns (uint16[] memory o) {
        o = new uint16[](7);
        for (uint256 i = 0; i < 7; i++) o[i] = a[i];
    }

    function drawTraits(Rng.R memory rng) internal pure returns (Traits memory t) {
        t.form = pick(rng, dyn16(wForm()));
        // anatomy per form (ranges keep continuous variety inside each silhouette)
        t.cx = 44 + rng.rInt(13);
        t.cy = 50 + rng.rInt(9);
        t.rw = 25 + rng.rInt(9);
        t.rh = 29 + rng.rInt(11);
        t.amp = 19 + rng.rInt(7);
        t.peak = rng.rInt(9) - 4;
        t.pamp = 6 + rng.rInt(4);
        if (t.form == 0) { t.rw = 30 + rng.rInt(9); t.amp = 20 + rng.rInt(7); }
        else if (t.form == 1) { t.rw = 22 + rng.rInt(5); t.rh = 30 + rng.rInt(11); }
        else if (t.form == 2) { t.peak = -(8 + rng.rInt(7)); t.rw = 25 + rng.rInt(9); }
        else if (t.form == 3) { t.peak = 8 + rng.rInt(7); t.rw = 25 + rng.rInt(9); }
        else if (t.form == 4) { t.amp = 14 + rng.rInt(4); t.rw = 27 + rng.rInt(8); }
        else if (t.form == 5) { t.rh = 38 + rng.rInt(7); t.rw = 24 + rng.rInt(7); t.amp = 20 + rng.rInt(7); }
        else if (t.form == 6) { t.rw = 20 + rng.rInt(5); t.pamp = 12 + rng.rInt(5); t.rh = 34 + rng.rInt(9); }
        else if (t.form == 7) { t.amp = 12 + rng.rInt(4); t.cy = 55 + rng.rInt(4); t.rh = 26 + rng.rInt(7); }
        else if (t.form == 8) { t.x2mode = 1; t.x2amp = 8 + rng.rInt(5); t.x2dx = 10 + rng.rInt(5); }
        else if (t.form == 9) { t.x2mode = 2; t.x2amp = 10 + rng.rInt(5); }
        else if (t.form == 10) {
            int256 pv = 12 + rng.rInt(5);
            t.peak = rng.rInt(2) != 0 ? pv : -pv;
            t.cx = rng.rInt(2) != 0 ? 38 + rng.rInt(5) : 52 + rng.rInt(5);
        }
        else if (t.form == 11) { t.x2mode = 3; t.x2amp = 8 + rng.rInt(5); }
        else if (t.form == 12) { t.rw = 36 + rng.rInt(5); t.amp = 26 + rng.rInt(5); t.rh = 34 + rng.rInt(7); }
        else if (t.form == 13) { t.rw = 18 + rng.rInt(4); t.pamp = 14 + rng.rInt(5); t.rh = 38 + rng.rInt(7); t.amp = 16 + rng.rInt(5); }
        else if (t.form == 14) { t.cy = 44 + rng.rInt(3); t.rh = 40 + rng.rInt(5); }
        else if (t.form == 15) { t.amp = 10 + rng.rInt(4); }
        t.jawY = t.cy + 22 + rng.rInt(8);
        t.sLdx = -(8 + rng.rInt(6));
        t.sLdy = -(4 + rng.rInt(6));
        t.sLr = 7 + rng.rInt(4);
        t.sLd = 13 + rng.rInt(9);
        t.sRdx = 7 + rng.rInt(6);
        t.sRdy = -(3 + rng.rInt(7));
        t.sRr = 6 + rng.rInt(5);
        t.sRd = 13 + rng.rInt(9);
        t.nas = 4 + rng.rInt(4);
        t.lineW = pick(rng, dyn9(wLine()));
        t.tear = pick(rng, dyn8(wTear()));
        t.spike = pick(rng, dyn9(wSpike()));
        t.eyes = pick(rng, dyn25(wEye()));
        t.eyeR = 6 + rng.rInt(3);
        t.treat = pick(rng, dyn12(wTreat()));
        t.mouth = pick(rng, dyn16(wMouth()));
        t.pink = pick(rng, dyn8(wPink()));
        t.mosh = pick(rng, dyn7(wMosh()));
    }

    /// bump: A * ((1e4-d2)/1e4)^2 * 100
    function bump100(int256 x, int256 y, int256 cx, int256 cy, int256 rw, int256 rh, int256 A)
        internal
        pure
        returns (int256)
    {
        int256 nx = ((x - cx) * 100) / rw;
        int256 ny = ((y - cy) * 100) / rh;
        int256 d2 = nx * nx + ny * ny;
        if (d2 >= 10000) return 0;
        int256 q = 10000 - d2;
        return (A * q * q) / 1000000;
    }

    /// flat-top head mass: full amplitude plateau, steep linear falloff
    function bumpFlat100(int256 x, int256 y, int256 cx, int256 cy, int256 rw, int256 rh, int256 A)
        internal
        pure
        returns (int256)
    {
        int256 nx = ((x - cx) * 100) / rw;
        int256 ny = ((y - cy) * 100) / rh;
        int256 d2 = nx * nx + ny * ny;
        if (d2 >= 10000) return 0;
        int256 q = d2 < 4200 ? int256(10000) : ((10000 - d2) * 10000) / 5800;
        return (A * q) / 100;
    }

    /// heightfield in centi-units; x,y in units
    function heightAt(Traits memory t, int256[51] memory noiseCols, int256 x, int256 y)
        internal
        pure
        returns (int256)
    {
        int256 b = bumpFlat100(x, y, t.cx, t.cy, t.rw, t.rh, t.amp);
        b += bump100(x, y, t.cx + t.peak, t.cy - t.rh + 6, 14, 16, t.pamp);
        b += bumpFlat100(x, y, t.cx + t.peak / 2, t.cy + 18, t.rw + 5, 14, t.amp >> 1);
        b -= bump100(x, y, t.cx + t.peak / 3, t.cy + 7, 4, 6, t.nas);
        // form modifiers: twin peak / horns / crater
        if (t.x2mode == 1) {
            b += bump100(x, y, t.cx - t.x2dx, t.cy - t.rh + 7, 10, 14, t.x2amp);
            b += bump100(x, y, t.cx + t.x2dx, t.cy - t.rh + 7, 10, 14, t.x2amp);
        } else if (t.x2mode == 2) {
            b += bump100(x, y, t.cx - t.rw + 4, t.cy - t.rh + 10, 5, 12, t.x2amp);
            b += bump100(x, y, t.cx + t.rw - 4, t.cy - t.rh + 10, 5, 12, t.x2amp);
        } else if (t.x2mode == 3) {
            b -= bump100(x, y, t.cx + t.peak / 2, t.cy - t.rh + 8, 9, 10, t.x2amp);
        }
        if (y > t.jawY) {
            int256 f = Num.max(0, 1400 - (y - t.jawY) * 100);
            b = (b * f) / 1400;
        }
        if (b < -400) b = -400;
        int256 col = Num.max(0, Num.min(50, x >> 1));
        return b + noiseCols[uint256(col)];
    }

    /// inside-socket test (line gaps at the eyes)
    function inSocket(Traits memory t, int256 x, int256 y, uint256 which) internal pure returns (bool) {
        int256 dx = which == 1 ? t.sRdx : t.sLdx;
        int256 dy = which == 1 ? t.sRdy : t.sLdy;
        int256 r = which == 1 ? t.sRr : t.sLr;
        int256 nx = ((x - (t.cx + dx)) * 100) / (r + 1);
        int256 ny = ((y - (t.cy + dy)) * 100) / Num.max(2, r - 1);
        return nx * nx + ny * ny < 10000;
    }

    function sigilSVG(uint256 ward, int256 cx, int256 cy, string memory fill) internal pure returns (string memory) {
        if (ward == 1) {
            Geom.Pt[] memory p = new Geom.Pt[](6);
            p[0] = Geom.Pt(-3, 1);
            p[1] = Geom.Pt(0, -3);
            p[2] = Geom.Pt(3, 1);
            p[3] = Geom.Pt(3, 3);
            p[4] = Geom.Pt(0, -1);
            p[5] = Geom.Pt(-3, 3);
            return Geom.poly(Geom.offsetPts(p, cx, cy), fill);
        } else if (ward == 2) {
            bytes memory s;
            for (int256 y = -3; y <= 3; y += 3) {
                Geom.Pt[] memory p = new Geom.Pt[](4);
                p[0] = Geom.Pt(-3, y - 1);
                p[1] = Geom.Pt(3, y - 1);
                p[2] = Geom.Pt(3, y);
                p[3] = Geom.Pt(-3, y);
                s = abi.encodePacked(s, Geom.poly(Geom.offsetPts(p, cx, cy), fill));
            }
            return string(s);
        } else {
            Geom.Pt[] memory p = new Geom.Pt[](4);
            p[0] = Geom.Pt(0, -3);
            p[1] = Geom.Pt(3, 0);
            p[2] = Geom.Pt(0, 3);
            p[3] = Geom.Pt(-3, 0);
            return Geom.poly(Geom.offsetPts(p, cx, cy), fill);
        }
    }

    function blockMarkSVG(uint256 blockId, int256 cx, int256 cy, Rng.R memory rng, string memory fill)
        internal
        pure
        returns (string memory)
    {
        if (blockId == 1) return Geom.rect(cx - 1, cy - 1, 2, 2, fill);
        if (blockId == 2) return Geom.rect(cx - 3, cy - 1, 6, 2, fill);
        if (blockId == 3) {
            return string(abi.encodePacked(Geom.rect(cx - 3, cy - 1, 2, 2, fill), Geom.rect(cx + 1, cy - 1, 2, 2, fill)));
        }
        if (blockId == 4) {
            Geom.Pt[] memory p = new Geom.Pt[](3);
            p[0] = Geom.Pt(-2, 2);
            p[1] = Geom.Pt(0, -3);
            p[2] = Geom.Pt(2, 2);
            return Geom.poly(Geom.offsetPts(p, cx, cy), fill);
        }
        if (blockId == 5) {
            Geom.Pt[] memory p = new Geom.Pt[](4);
            p[0] = Geom.Pt(-2, -2);
            p[1] = Geom.Pt(2, -2);
            p[2] = Geom.Pt(2, 2);
            p[3] = Geom.Pt(-2, 2);
            return Geom.poly(Geom.offsetPts(p, cx, cy), fill);
        }
        if (blockId == 6) return Geom.xmark(cx, cy, 2, 1, fill, rng);
        return "";
    }
}
