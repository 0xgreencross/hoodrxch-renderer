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
    }

    function drawTraits(Rng.R memory rng) internal pure returns (Traits memory t) {
        t.cx = 44 + rng.rInt(13);
        t.cy = 50 + rng.rInt(9);
        t.rw = 24 + rng.rInt(15);
        t.rh = 28 + rng.rInt(13);
        t.amp = 18 + rng.rInt(10);
        t.peak = rng.rInt(17) - 8;
        t.pamp = 5 + rng.rInt(6);
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
        t.lineW = rng.rInt(3);
        int256 te = rng.rInt(100);
        t.tear = te < 35 ? int256(0) : (te < 78 ? int256(1) : int256(2));
        int256 sp = rng.rInt(100);
        t.spike = sp < 30 ? int256(0) : (sp < 80 ? int256(1) : int256(2));
        int256 ey = rng.rInt(100);
        t.eyes = ey < 26
            ? int256(0)
            : ey < 38
                ? int256(1)
                : ey < 46 ? int256(2) : ey < 62 ? int256(3) : ey < 70 ? int256(4) : ey < 82 ? int256(5) : ey < 90 ? int256(6) : ey < 96 ? int256(7) : int256(8);
        t.eyeR = 6 + rng.rInt(3);
        int256 tr = rng.rInt(100);
        t.treat = tr < 15 ? int256(0) : tr < 40 ? int256(1) : tr < 60 ? int256(2) : tr < 75 ? int256(3) : int256(4);
        int256 mo = rng.rInt(100);
        t.mouth = mo < 22 ? int256(0) : 1 + ((mo - 22) % 3);
        int256 p = rng.rInt(100);
        t.pink = p < 30 ? int256(0) : (p < 78 ? int256(1) : int256(2));
        int256 g = rng.rInt(100);
        t.mosh = g < 38 ? int256(0) : (g < 78 ? int256(1) : int256(2));
        t.form = t.rw >= 33
            ? int256(0)
            : (
                t.rw <= 27
                    ? int256(1)
                    : (
                        t.pamp >= 12
                            ? int256(2)
                            : (t.peak <= -4 ? int256(3) : (t.peak >= 4 ? int256(4) : (t.amp <= 15 ? int256(5) : (t.rh >= 36 ? int256(6) : int256(7)))))
                    )
            );
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
