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
import {Glyphs} from "./Glyphs.sol";

/// @notice Coffin compositions, status overlays, HUD, stats band, flicker.
/// Mirrors the corresponding blocks of src/05_render.js byte-for-byte.
library StatusLib {
    using Buf for Buf.B;
    using Rng for Rng.R;

    function coffinPts() internal pure returns (Geom.Pt[] memory p) {
        p = new Geom.Pt[](6);
        p[0] = Geom.Pt(43, 28);
        p[1] = Geom.Pt(57, 28);
        p[2] = Geom.Pt(64, 42);
        p[3] = Geom.Pt(58, 82);
        p[4] = Geom.Pt(42, 82);
        p[5] = Geom.Pt(36, 42);
    }

    function inCoffin(int256 x, int256 y, int256 pad) internal pure returns (bool) {
        Geom.Pt[] memory P = coffinPts();
        int256 cx = 50;
        int256 cy = 54;
        for (uint256 i = 0; i < 6; i++) {
            Geom.Pt memory a = P[i];
            Geom.Pt memory b = P[(i + 1) % 6];
            int256 ax = a.x + Num.sign(a.x - cx) * pad;
            int256 ay = a.y + Num.sign(a.y - cy) * pad;
            int256 bx = b.x + Num.sign(b.x - cx) * pad;
            int256 by = b.y + Num.sign(b.y - cy) * pad;
            if ((bx - ax) * (y - ay) - (by - ay) * (x - ax) < 0) return false;
        }
        return true;
    }

    /// full coffin SVG (COFFINED / TERMINAL_COFFIN)
    function coffinSVG(RenderStateV1 memory s) public pure returns (string memory) {
        bool terminal = s.lifeState == 3;
        Rng.R memory rng = Rng.init(GenesisLib.genesisSeed(s.genesisHash, s.tokenId));
        Mask.Traits memory t = Mask.drawTraits(rng);
        Buf.B memory f = Buf.init(24000);
        int256 swv = t.lineW <= 2 ? (t.lineW == 0 ? int256(3) : t.lineW == 1 ? int256(4) : int256(6)) : int256(4);
        for (uint256 li = 0; li < 47; li++) {
            int256 y = 4 + int256(li) * 2;
            Buf.B memory d = Buf.init(1024);
            bool pen = false;
            int256 px = 0;
            int256 breakLeft = 0;
            for (int256 xi = 0; xi <= 33; xi++) {
                int256 x = xi * 3;
                bool gap = false;
                if (inCoffin(x, y, 2)) gap = true;
                if (breakLeft > 0) {
                    breakLeft--;
                    gap = true;
                } else if (rng.rInt(1000) < (terminal ? int256(60) : int256(22))) {
                    breakLeft = 1 + rng.rInt(5);
                    gap = true;
                }
                if (gap) {
                    pen = false;
                    continue;
                }
                int256 X = x * 10;
                if (!pen) {
                    d.app(abi.encodePacked("M", Num.itoa(X), " ", Num.itoa(y * 10)));
                    pen = true;
                } else {
                    d.app(abi.encodePacked("h", Num.itoa(X - px)));
                }
                px = X;
            }
            if (d.len > 0) {
                f.app(
                    abi.encodePacked(
                        '<path d="', d.fin(), '" fill="none" stroke="', T.ACID, '" stroke-width="', Num.itoa(swv), '"/>'
                    )
                );
            }
        }
        // white specks
        {
            Buf.B memory d = Buf.init(800);
            int256 n = 8 + rng.rInt(10);
            for (int256 i = 0; i < n; i++) {
                int256 x = rng.rInt(100);
                int256 y = rng.rInt(100);
                d.app(abi.encodePacked("M", Num.itoa(x * 10), " ", Num.itoa(y * 10), "h10v10h-10z"));
            }
            f.app(abi.encodePacked('<path d="', d.fin(), '" fill="', T.WHITE, '"/>'));
        }
        // coffin outline + nails
        f.app(
            abi.encodePacked(
                '<path d="',
                Geom.pathD(Geom.jitterPts(coffinPts(), rng, 1)),
                '" fill="none" stroke="',
                T.WHITE,
                '" stroke-width="6"/>'
            )
        );
        {
            Geom.Pt[] memory P = coffinPts();
            for (uint256 i = 0; i < 6; i++) {
                f.app(Geom.rect(P[i].x - 1, P[i].y - 1, 2, 2, T.WHITE));
            }
        }
        // eyes survive the grave (not terminal)
        if (!terminal) {
            f.app(GenesisLib.eyeGlyph(t.eyes, 0, 46, 42, 4, T.PINK, rng));
            f.app(GenesisLib.eyeGlyph(t.eyes, 1, 54, 42, 4, T.PINK, rng));
        }
        // seal pips inside the coffin
        for (uint256 i = 0; i < 3; i++) {
            int256 x = 43 + int256(i) * 5;
            int256 y = 72;
            if (i < s.sealsRemaining) {
                f.app(Geom.rect(x, y, 3, 3, T.ACID));
            } else {
                string memory pc = terminal ? T.RED : T.PINK;
                f.app(
                    abi.encodePacked(
                        '<path d="M',
                        Num.itoa(x * 10),
                        " ",
                        Num.itoa(y * 10),
                        'h30v30h-30z" fill="none" stroke="',
                        pc,
                        '" stroke-width="3"/>'
                    )
                );
                f.app(Geom.xmark(x + 1, y + 1, 2, 1, pc, rng));
            }
        }
        if (terminal) {
            Geom.Pt[] memory p1 = new Geom.Pt[](4);
            p1[0] = Geom.Pt(40, 33);
            p1[1] = Geom.Pt(44, 32);
            p1[2] = Geom.Pt(60, 79);
            p1[3] = Geom.Pt(56, 80);
            f.app(Geom.poly(p1, T.RED));
            Geom.Pt[] memory p2 = new Geom.Pt[](4);
            p2[0] = Geom.Pt(56, 32);
            p2[1] = Geom.Pt(60, 33);
            p2[2] = Geom.Pt(44, 80);
            p2[3] = Geom.Pt(40, 79);
            f.app(Geom.poly(p2, T.RED));
        }
        if (terminal) {
            f.app(abi.encodePacked('<path d="M0 540h1000" fill="none" stroke="', T.RED, '" stroke-width="5"/>'));
        } else {
            f.app(
                abi.encodePacked(
                    '<path d="M0 540h140l15 -70 15 140 15 -70h815" fill="none" stroke="',
                    T.WHITE,
                    '" stroke-width="5"/>'
                )
            );
        }
        f.app(Mask.sigilSVG(s.wardId, 8, 8, T.ACID));
        f.app(Mask.blockMarkSVG(s.blockId, 90, 93, rng, T.ACID));
        // death slices
        Buf.B memory body = Buf.init(28000);
        body.app(abi.encodePacked('<rect width="1000" height="1000" fill="', T.BLACK, '"/><use href="#f"/>'));
        {
            uint256 nd = s.deaths > 0 ? s.deaths : 1;
            Rng.R memory drng = Rng.init(GenesisLib.damageSeed(s.genesisHash, s.tokenId, s.deaths > 0 ? s.deaths : 1));
            uint256 ci = 0;
            for (uint256 k = 0; k < nd; k++) {
                int256 y = 20 + drng.rInt(56);
                int256 h = 2 + drng.rInt(4);
                int256 base = 4 + drng.rInt(7);
                int256 dx = drng.rInt(2) != 0 ? base : -base;
                ci++;
                body.app(Geom.slice(ci, y, h, dx, T.BLACK));
            }
        }
        body.app(flickerSVG(s));
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"><defs><g id="f">',
                f.fin(),
                "</g></defs>",
                body.fin(),
                "</svg>"
            )
        );
    }

    // --- overlays -----------------------------------------------------------

    function markedOverlay(T.Gen memory g) internal pure returns (string memory) {
        Buf.B memory o = Buf.init(4096);
        o.app(
            abi.encodePacked(
                '<path d="M30 120V30H120M880 30H970V120M970 880V970H880M120 970H30V880" fill="none" stroke="',
                T.RED,
                '" stroke-width="14"/>'
            )
        );
        {
            int256 cx = g.t.cx;
            int256 cy = g.t.cy - 2;
            int256 R = g.t.rh + 12;
            o.app(GenesisLib.octRing(cx, cy, R, 10, T.RED));
            o.app(
                abi.encodePacked(
                    '<path d="M0 ', Num.itoa(cy * 10), "H", Num.itoa((cx - R) * 10),
                    "M", Num.itoa((cx + R) * 10), " ", Num.itoa(cy * 10), "H1000M",
                    Num.itoa(cx * 10), " 0V", Num.itoa(Num.max(0, cy - R) * 10),
                    "M", Num.itoa(cx * 10), " ", Num.itoa((cy + R) * 10),
                    'V1000" stroke="', T.RED, '" stroke-width="6" fill="none"/>'
                )
            );
            Geom.Pt[] memory p = new Geom.Pt[](3);
            p[0] = Geom.Pt(cx - 5, cy - R + 3); p[1] = Geom.Pt(cx + 5, cy - R + 3); p[2] = Geom.Pt(cx, cy - R + 11);
            o.app(Geom.poly(p, T.RED));
            p[0] = Geom.Pt(cx - 5, cy + R - 3); p[1] = Geom.Pt(cx + 5, cy + R - 3); p[2] = Geom.Pt(cx, cy + R - 11);
            o.app(Geom.poly(p, T.RED));
            p[0] = Geom.Pt(cx - R + 3, cy - 5); p[1] = Geom.Pt(cx - R + 3, cy + 5); p[2] = Geom.Pt(cx - R + 11, cy);
            o.app(Geom.poly(p, T.RED));
            p[0] = Geom.Pt(cx + R - 3, cy - 5); p[1] = Geom.Pt(cx + R - 3, cy + 5); p[2] = Geom.Pt(cx + R - 11, cy);
            o.app(Geom.poly(p, T.RED));
        }
        for (uint256 i = 0; i < 8; i++) {
            o.app(Geom.rect(33 + int256(i) * 4, 2, 2, 3, T.RED));
        }
        return o.fin();
    }

    function witsecOverlay(T.Gen memory g) internal pure returns (string memory) {
        int256 y;
        int256 x0;
        int256 x1;
        {
            int256 lx = g.eyeScreen[0][0];
            int256 ly = g.eyeScreen[0][1];
            int256 lr = g.eyeScreen[0][2];
            int256 rx2 = g.eyeScreen[1][0];
            int256 ry2 = g.eyeScreen[1][1];
            int256 rr2 = g.eyeScreen[1][2];
            y = Num.min(ly, ry2) - 8;
            x0 = Num.max(0, lx - lr - 8);
            x1 = Num.min(100, rx2 + rr2 + 8);
        }
        Buf.B memory o = Buf.init(62000);
        o.app(abi.encodePacked('<g shape-rendering="crispEdges">', Geom.rect(x0, y, x1 - x0, 22, T.BLACK)));
        int256[3] memory band = [y, x0, x1];
        for (uint256 f = 0; f < 6; f++) {
            witsecFrame(o, g, band, f);
        }
        o.app(bytes("</g>"));
        return o.fin();
    }

    /// one SMIL frame of the witsec static band, appended into o
    function witsecFrame(Buf.B memory o, T.Gen memory g, int256[3] memory b, uint256 f) private pure {
        bytes memory v;
        for (uint256 k = 0; k < 6; k++) {
            v = abi.encodePacked(v, k > 0 ? ";" : "", k == f ? "inline" : "none");
        }
        o.app(
            abi.encodePacked(
                '<g display="', f > 0 ? "none" : "inline",
                '"><animate attributeName="display" values="', v,
                '" calcMode="discrete" dur="0.72s" repeatCount="indefinite"/>'
            )
        );
        for (int256 ys = b[0]; ys < b[0] + 22; ys += 2) {
            for (int256 x = b[1]; x < b[2]; x += 2) {
                int256 n = g.rng.rInt(100);
                if (n >= 44 && n < 92) {
                    o.app(
                        abi.encodePacked(
                            '<rect x="', Num.itoa(x * 10), '" y="', Num.itoa(ys * 10),
                            '" width="21" height="21" fill="', n < 86 ? T.WHITE : T.ACID, '"/>'
                        )
                    );
                }
            }
        }
        o.app(bytes("</g>"));
    }

    function layLowOverlay(T.Gen memory g) internal pure returns (string memory) {
        Mask.Traits memory t = g.t;
        Buf.B memory o = Buf.init(2048);
        int256 x0 = t.cx - t.rw - 9;
        int256 w = 2 * t.rw + 18;
        for (int256 y = t.cy - t.rh - 4; y < t.cy + 24; y += 7) {
            o.app(Geom.rect(x0, y, w, 3, T.BLACK));
        }
        Geom.Pt[] memory p = new Geom.Pt[](3);
        p[0] = Geom.Pt(t.cx - 4, t.cy - t.rh - 9);
        p[1] = Geom.Pt(t.cx + 4, t.cy - t.rh - 9);
        p[2] = Geom.Pt(t.cx, t.cy - t.rh - 5);
        o.app(Geom.poly(p, T.ACID));
        return o.fin();
    }

    /// one SMIL frame of the collapsing echo: display-flip group + ring (dash "" = solid)
    function echoFrame(int256 cx, int256 cy, int256 r, int256 w, string memory dash, uint256 f)
        private
        pure
        returns (string memory)
    {
        bytes memory v;
        for (uint256 k = 0; k < 4; k++) {
            v = abi.encodePacked(v, k > 0 ? ";" : "", k == f ? "inline" : "none");
        }
        string memory ring;
        if (bytes(dash).length == 0) ring = GenesisLib.octRing(cx, cy, r, w, T.ACID);
        else ring = octRingDash(cx, cy, r, w, dash);
        return string(
            abi.encodePacked(
                '<g display="', f > 0 ? "none" : "inline",
                '"><animate attributeName="display" values="', v,
                '" calcMode="discrete" dur="0.6s" repeatCount="indefinite"/>',
                ring,
                "</g>"
            )
        );
    }

    /// octagon ring with dasharray — the collapsing echo's dissolve steps
    function octRingDash(int256 cx, int256 cy, int256 r, int256 w, string memory dash)
        private
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
            abi.encodePacked(
                '<path d="', Geom.pathD(pts), '" fill="none" stroke="', T.ACID,
                '" stroke-width="', Num.itoa(w), '" stroke-dasharray="', dash, '"/>'
            )
        );
    }

    function buyerOverlay(T.Gen memory g) internal pure returns (string memory) {
        Mask.Traits memory t = g.t;
        int256 cx = t.cx;
        int256 cy = t.cy - 2;
        int256 R = t.rh + 16;
        Buf.B memory o = Buf.init(8000);
        o.app(GenesisLib.octRing(cx, cy, R, 12, T.ACID));
        // echo wave collapses inward: born at the shield, dissolving toward the face
        o.app(echoFrame(cx, cy, R - 3, 4, "", 0));
        o.app(echoFrame(cx, cy, R - 11, 3, "24 10", 1));
        o.app(echoFrame(cx, cy, R - 19, 3, "14 16", 2));
        o.app(echoFrame(cx, cy, R - 27, 2, "8 22", 3));
        o.app(padlockSeal(cx, cy + R - 4));
        return o.fin();
    }

    /// acid padlock clasped at (bx,by): shackle, octagonal body, black keyhole
    function padlockSeal(int256 bx, int256 by) private pure returns (string memory) {
        Buf.B memory o = Buf.init(1400);
        o.app(
            abi.encodePacked(
                '<path d="M', Num.itoa((bx - 5) * 10), " ", Num.itoa((by - 6) * 10),
                "V", Num.itoa((by - 12) * 10), "L", Num.itoa((bx - 3) * 10), " ", Num.itoa((by - 14) * 10),
                "H", Num.itoa((bx + 3) * 10), "L", Num.itoa((bx + 5) * 10), " ", Num.itoa((by - 12) * 10),
                "V", Num.itoa((by - 6) * 10), '" stroke="', T.ACID, '" stroke-width="16" fill="none"/>'
            )
        );
        Geom.Pt[] memory p = new Geom.Pt[](8);
        p[0] = Geom.Pt(bx - 9, by - 4);
        p[1] = Geom.Pt(bx - 6, by - 7);
        p[2] = Geom.Pt(bx + 6, by - 7);
        p[3] = Geom.Pt(bx + 9, by - 4);
        p[4] = Geom.Pt(bx + 9, by + 4);
        p[5] = Geom.Pt(bx + 6, by + 7);
        p[6] = Geom.Pt(bx - 6, by + 7);
        p[7] = Geom.Pt(bx - 9, by + 4);
        o.app(Geom.poly(p, T.ACID));
        Geom.Pt[] memory q = new Geom.Pt[](4);
        q[0] = Geom.Pt(bx - 2, by - 2);
        q[1] = Geom.Pt(bx, by - 4);
        q[2] = Geom.Pt(bx + 2, by - 2);
        q[3] = Geom.Pt(bx, by);
        o.app(Geom.poly(q, T.BLACK));
        o.app(Geom.rect(bx - 1, by - 1, 2, 5, T.BLACK));
        return o.fin();
    }

    function hunterOverlay(T.Gen memory g) internal pure returns (string memory) {
        Mask.Traits memory t = g.t;
        int256 hx = t.cx;
        int256 hy = t.cy - 4;
        int256 rr = t.rw + 12;
        return string(
            abi.encodePacked(
                '<path d="M',
                Num.itoa(hx * 10),
                " ",
                Num.itoa((hy - rr - 4) * 10),
                "v40M",
                Num.itoa(hx * 10),
                " ",
                Num.itoa((hy + rr) * 10),
                "v40M",
                Num.itoa((hx - rr - 4) * 10),
                " ",
                Num.itoa(hy * 10),
                "h40M",
                Num.itoa((hx + rr) * 10),
                " ",
                Num.itoa(hy * 10),
                'h40" stroke="',
                T.WHITE,
                '" stroke-width="4" fill="none"/>'
            )
        );
    }

    function sealHud(RenderStateV1 memory s) internal pure returns (string memory) {
        Buf.B memory o = Buf.init(1200);
        for (uint256 i = 0; i < 3; i++) {
            int256 x = 85 + int256(i) * 4;
            int256 y = 5;
            if (i < s.sealsRemaining) {
                o.app(Geom.rect(x, y, 3, 3, T.ACID));
            } else {
                o.app(
                    abi.encodePacked(
                        '<path d="M',
                        Num.itoa(x * 10),
                        " ",
                        Num.itoa(y * 10),
                        'h30v30h-30z" fill="none" stroke="',
                        T.PINK,
                        '" stroke-width="3"/>',
                        '<path d="M',
                        Num.itoa(x * 10),
                        " ",
                        Num.itoa((y + 3) * 10),
                        'l30 -30" stroke="',
                        T.PINK,
                        '" stroke-width="3" fill="none"/>'
                    )
                );
            }
        }
        return o.fin();
    }

    function seasonChips(RenderStateV1 memory s, Glyphs.Used memory used) internal pure returns (string memory) {
        if (s.latestSeasonBadgeFlags & 1 == 0) return "";
        Buf.B memory o = Buf.init(3000);
        o.app(Glyphs.text(string(abi.encodePacked("S", Num.utoa(s.latestAwardSeasonId))), 62, 632, 4, T.ACID, used));
        o.app(
            abi.encodePacked(
                '<rect x="60" y="672" width="104" height="60" fill="none" stroke="', T.WHITE, '" stroke-width="4"/>'
            )
        );
        o.app(Glyphs.text("10", 76, 682, 6, T.WHITE, used));
        if (s.latestSeasonBadgeFlags & 2 != 0) {
            o.app(
                abi.encodePacked(
                    '<rect x="60" y="744" width="104" height="60" fill="none" stroke="', T.PINK, '" stroke-width="4"/>'
                )
            );
            o.app(Glyphs.text("5", 94, 754, 6, T.PINK, used));
        }
        return o.fin();
    }

    function territoryHud(RenderStateV1 memory s) internal pure returns (string memory) {
        Buf.B memory o = Buf.init(1200);
        uint256 n = s.territoryAchievementCount < 12 ? s.territoryAchievementCount : 12;
        for (uint256 i = 0; i < n; i++) {
            o.app(Geom.rect(95, 84 - int256(i) * 3, 3, 2, T.ACID));
        }
        return o.fin();
    }

    function kdText(RenderStateV1 memory s) internal pure returns (string memory) {
        if (s.deaths == 0) return s.kills == 0 ? "UNTESTED" : "UNDEFEATED";
        uint256 n = (s.kills * 10) / s.deaths;
        return string(abi.encodePacked(Num.utoa(n / 10), ".", Num.utoa(n % 10)));
    }

    function tierName(uint256 tier) internal pure returns (string memory) {
        if (tier == 0) return "NONE";
        if (tier == 1) return "FIRST BLOOD";
        if (tier == 2) return "RISING THREAT";
        if (tier == 3) return "SAVAGE";
        if (tier == 4) return "EXECUTIONER";
        if (tier == 5) return "DEATH DEALER";
        return "REAPER";
    }

    function statsBand(RenderStateV1 memory s, Glyphs.Used memory used) internal pure returns (string memory) {
        uint256 tier = GenesisLib.tierForKills(s.kills);
        Buf.B memory o = Buf.init(8000);
        o.app(
            abi.encodePacked(
                '<rect x="0" y="880" width="1000" height="120" fill="',
                T.BLACK,
                '"/><path d="M0 880h1000" stroke="',
                T.ACID,
                '" stroke-width="3"/>'
            )
        );
        string memory l1 = string(
            abi.encodePacked(
                "K ",
                Num.utoa(s.kills),
                " / D ",
                Num.utoa(s.deaths),
                " / KD ",
                kdText(s),
                " / STK ",
                Num.utoa(s.currentKillStreak)
            )
        );
        string memory l2 = string(
            abi.encodePacked(tierName(tier), " / W", Num.utoa(s.wardId), " B", Num.utoa(s.blockId))
        );
        if (s.latestSeasonRank != 0) {
            l2 = string(
                abi.encodePacked(
                    l2, " / S", Num.utoa(s.latestAwardSeasonId), " RANK ", Num.utoa(s.latestSeasonRank)
                )
            );
        }
        o.app(Glyphs.text(l1, 24, 896, 5, T.ACID, used));
        o.app(Glyphs.text(l2, 24, 946, 5, T.WHITE, used));
        return o.fin();
    }

    function flickerSVG(RenderStateV1 memory s) internal pure returns (string memory) {
        if (!s.flicker) return "";
        return string(
            abi.encodePacked(
                '<rect x="0" y="-8" width="1000" height="6" fill="',
                T.WHITE,
                '"><animate attributeName="y" values="-8;1000;-8" dur="7s" repeatCount="indefinite"/></rect>',
                '<rect x="0" y="-4" width="1000" height="3" fill="',
                T.PINK,
                '"><animate attributeName="y" values="1000;-4;1000" dur="11s" repeatCount="indefinite"/></rect>'
            )
        );
    }
}
