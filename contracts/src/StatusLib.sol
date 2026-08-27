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
        int256 swv = t.lineW == 0 ? int256(3) : t.lineW == 1 ? int256(4) : int256(6);
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
        g;
        Buf.B memory o = Buf.init(2048);
        o.app(
            abi.encodePacked(
                '<path d="M30 120V30H120M880 30H970V120M970 880V970H880M120 970H30V880" fill="none" stroke="',
                T.RED,
                '" stroke-width="14"/>'
            )
        );
        Geom.Pt[] memory p = new Geom.Pt[](6);
        p[0] = Geom.Pt(0, 100);
        p[1] = Geom.Pt(0, 93);
        p[2] = Geom.Pt(93, 0);
        p[3] = Geom.Pt(100, 0);
        p[4] = Geom.Pt(100, 7);
        p[5] = Geom.Pt(7, 100);
        o.app(Geom.poly(p, T.RED));
        for (uint256 i = 0; i < 8; i++) {
            o.app(Geom.rect(33 + int256(i) * 4, 2, 2, 3, T.RED));
        }
        return o.fin();
    }

    function witsecOverlay(T.Gen memory g) internal pure returns (string memory) {
        int256 lx = g.eyeScreen[0][0];
        int256 ly = g.eyeScreen[0][1];
        int256 lr = g.eyeScreen[0][2];
        int256 rx2 = g.eyeScreen[1][0];
        int256 ry2 = g.eyeScreen[1][1];
        int256 rr2 = g.eyeScreen[1][2];
        int256 y = Num.min(ly, ry2) - 5;
        int256 x0 = lx - lr - 4;
        int256 x1 = rx2 + rr2 + 4;
        return string(
            abi.encodePacked(
                Geom.rect(x0, y, x1 - x0, 9, T.WHITE),
                Geom.rect(x0 + 3, y + 11, (x1 - x0) >> 1, 3, T.WHITE),
                Geom.rect(x0 + ((x1 - x0) >> 1) + 6, y + 11, (x1 - x0) >> 2, 3, T.WHITE)
            )
        );
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

    function buyerOverlay() internal pure returns (string memory) {
        Geom.Pt[] memory p = new Geom.Pt[](4);
        p[0] = Geom.Pt(50, 2);
        p[1] = Geom.Pt(53, 5);
        p[2] = Geom.Pt(50, 8);
        p[3] = Geom.Pt(47, 5);
        return string(
            abi.encodePacked(
                '<rect x="60" y="60" width="880" height="880" fill="none" stroke="',
                T.ACID,
                '" stroke-width="5"/>',
                Geom.poly(p, T.ACID)
            )
        );
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
