// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";

/// @notice Geometry primitives — logical 100-unit grid → ×10 px, integer only.
/// Mirrors src/03_geom.js (only the functions the renderer calls).
library Geom {
    using Buf for Buf.B;
    using Rng for Rng.R;

    int256 internal constant U = 10;

    struct Pt {
        int256 x;
        int256 y;
    }

    function jitterPts(Pt[] memory pts, Rng.R memory rng, int256 amp) internal pure returns (Pt[] memory o) {
        o = new Pt[](pts.length);
        for (uint256 i = 0; i < pts.length; i++) {
            int256 jx = rng.jit();
            int256 jy = rng.jit();
            if (amp == 1) {
                jx = Num.max(-1, Num.min(1, jx));
                jy = Num.max(-1, Num.min(1, jy));
            }
            o[i] = Pt(pts[i].x + jx, pts[i].y + jy);
        }
    }

    function offsetPts(Pt[] memory pts, int256 dx, int256 dy) internal pure returns (Pt[] memory o) {
        o = new Pt[](pts.length);
        for (uint256 i = 0; i < pts.length; i++) {
            o[i] = Pt(pts[i].x + dx, pts[i].y + dy);
        }
    }

    /// closed polygon path, relative integer commands, px
    function pathD(Pt[] memory pts) internal pure returns (string memory) {
        Buf.B memory b = Buf.init(48 + pts.length * 32);
        b.app(abi.encodePacked("M", Num.itoa(pts[0].x * U), " ", Num.itoa(pts[0].y * U)));
        for (uint256 i = 1; i < pts.length; i++) {
            int256 dx = (pts[i].x - pts[i - 1].x) * U;
            int256 dy = (pts[i].y - pts[i - 1].y) * U;
            if (dy == 0) b.app(abi.encodePacked("h", Num.itoa(dx)));
            else if (dx == 0) b.app(abi.encodePacked("v", Num.itoa(dy)));
            else b.app(abi.encodePacked("l", Num.itoa(dx), " ", Num.itoa(dy)));
        }
        b.app(bytes("z"));
        return b.fin();
    }

    function poly(Pt[] memory pts, string memory fill) internal pure returns (string memory) {
        return string(abi.encodePacked('<path d="', pathD(pts), '" fill="', fill, '"/>'));
    }

    function rect(int256 x, int256 y, int256 w, int256 h, string memory fill)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<rect x="',
                Num.itoa(x * U),
                '" y="',
                Num.itoa(y * U),
                '" width="',
                Num.itoa(w * U),
                '" height="',
                Num.itoa(h * U),
                '" fill="',
                fill,
                '"/>'
            )
        );
    }

    /// X mark centred at (cx,cy), half-size r, bar width b (units)
    function jpoly(Pt[] memory pts, Rng.R memory rng, string memory fill) private pure returns (string memory) {
        return poly(jitterPts(pts, rng, 1), fill);
    }

    function xmarkA(int256 cx, int256 cy, int256 r, int256 b) private pure returns (Pt[] memory a) {
        a = new Pt[](4);
        a[0].x = cx - r;
        a[0].y = cy - r + b;
        a[1].x = cx - r + b;
        a[1].y = cy - r;
        a[2].x = cx + r;
        a[2].y = cy + r - b;
        a[3].x = cx + r - b;
        a[3].y = cy + r;
    }

    function xmarkC(int256 cx, int256 cy, int256 r, int256 b) private pure returns (Pt[] memory c) {
        c = new Pt[](4);
        c[0].x = cx + r - b;
        c[0].y = cy - r;
        c[1].x = cx + r;
        c[1].y = cy - r + b;
        c[2].x = cx - r + b;
        c[2].y = cy + r;
        c[3].x = cx - r;
        c[3].y = cy + r - b;
    }

    function xmark(int256 cx, int256 cy, int256 r, int256 b, string memory fill, Rng.R memory rng)
        internal
        pure
        returns (string memory)
    {
        string memory s1 = jpoly(xmarkA(cx, cy, r, b), rng, fill);
        string memory s2 = jpoly(xmarkC(cx, cy, r, b), rng, fill);
        return string(abi.encodePacked(s1, s2));
    }

    /// solid drip: a tapered polygon hanging from (x,y) of length len (units)
    function drip(int256 x, int256 y, int256 len, int256 w, string memory fill, Rng.R memory rng)
        internal
        pure
        returns (string memory)
    {
        Pt[] memory pts = new Pt[](5);
        pts[0] = Pt(x - w, y);
        pts[1] = Pt(x + w, y);
        pts[2] = Pt(x + w, y + len - 2);
        pts[3] = Pt(x, y + len);
        pts[4] = Pt(x - w, y + len - 2);
        return poly(jitterPts(pts, rng, 1), fill);
    }

    /// displacement slice of group #f: band [y,y+h) shifted dx units
    function slice(uint256 idx, int256 y, int256 h, int256 dx, string memory groundFill)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<clipPath id="c',
                Num.utoa(idx),
                '"><rect x="0" y="',
                Num.itoa(y * U),
                '" width="1000" height="',
                Num.itoa(h * U),
                '"/></clipPath><g clip-path="url(#c',
                Num.utoa(idx),
                ')"><rect width="1000" height="1000" fill="',
                groundFill,
                '"/><use href="#f" transform="translate(',
                Num.itoa(dx * U),
                ' 0)"/></g>'
            )
        );
    }
}
