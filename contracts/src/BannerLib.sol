// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RenderStateV1} from "./RenderState.sol";
import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";
import {Rng} from "./Rng.sol";
import {Mask} from "./Mask.sol";
import {T} from "./Types.sol";
import {GenesisLib} from "./GenesisLib.sol";
import {StatusLib} from "./StatusLib.sol";
import {Glyphs} from "./Glyphs.sol";

/// @notice 3000×1000 banner — byte-identical to JS renderBanner().
library BannerLib {
    using Buf for Buf.B;
    using Rng for Rng.R;

    /// `innerContent` = the token SVG stripped of its <svg> wrapper;
    /// `nErrs` = validate(s).length; `status` = resolveStatus(s) string.
    function banner(
        RenderStateV1 memory s,
        string memory innerContent,
        uint256 nErrs,
        string memory status,
        bool statusRed,
        bool isAlive
    ) public pure returns (string memory) {
        Glyphs.Used memory used = Glyphs.newUsed();
        Rng.R memory rng =
            Rng.init(abi.encodePacked(GenesisLib.genesisSeed(s.genesisHash, s.tokenId), "BNR"));
        Mask.Traits memory t = Mask.drawTraits(Rng.init(GenesisLib.genesisSeed(s.genesisHash, s.tokenId)));
        int256 swv = t.lineW == 0 ? int256(3) : t.lineW == 1 ? int256(4) : int256(6);
        Buf.B memory body = Buf.init(48000);
        body.app(abi.encodePacked('<rect width="3000" height="1000" fill="', T.BLACK, '"/>'));
        for (uint256 li = 0; li < 47; li++) {
            int256 y = (4 + int256(li) * 2) * 10;
            Buf.B memory d = Buf.init(1600);
            bool pen = false;
            int256 px = 1000;
            int256 breakLeft = 0;
            for (int256 xi = 0; xi <= 66; xi++) {
                int256 X = 1000 + xi * 30;
                bool gap = false;
                if (breakLeft > 0) {
                    breakLeft--;
                    gap = true;
                } else if (rng.rInt(1000) < 30) {
                    breakLeft = 1 + rng.rInt(5);
                    gap = true;
                }
                if (y > 290 && y < 660 && X > 1180 && X < 2720) gap = true;
                if (gap) {
                    pen = false;
                    continue;
                }
                if (!pen) {
                    d.app(abi.encodePacked("M", Num.itoa(X), " ", Num.itoa(y)));
                    pen = true;
                } else {
                    d.app(abi.encodePacked("h", Num.itoa(X - px)));
                }
                px = X;
            }
            if (d.len > 0) {
                body.app(
                    abi.encodePacked(
                        '<path d="', d.fin(), '" fill="none" stroke="', T.ACID, '" stroke-width="', Num.itoa(swv), '"/>'
                    )
                );
            }
        }
        {
            Buf.B memory d = Buf.init(1400);
            int256 n = 16 + rng.rInt(12);
            for (int256 i = 0; i < n; i++) {
                int256 x = 1000 + rng.rInt(2000);
                int256 y = rng.rInt(1000);
                d.app(abi.encodePacked("M", Num.itoa(x), " ", Num.itoa(y), "h10v10h-10z"));
            }
            body.app(abi.encodePacked('<path d="', d.fin(), '" fill="', T.WHITE, '"/>'));
        }
        {
            uint256 tier = GenesisLib.tierForKills(s.kills);
            body.app(Glyphs.text("HOODRXCH", 1220, 330, 15, T.ACID, used));
            string memory sub;
            if (nErrs > 0) {
                sub = "INVALID STATE";
            } else {
                sub = string(
                    abi.encodePacked(
                        "#", Num.utoa(s.tokenId), " / WARD 0", Num.utoa(s.wardId), " / BLOCK 0", Num.utoa(s.blockId)
                    )
                );
                if (tier > 0) sub = string(abi.encodePacked(sub, " / ", StatusLib.tierName(tier)));
            }
            body.app(Glyphs.text(sub, 1224, 510, 6, nErrs > 0 ? T.RED : T.WHITE, used));
            if (nErrs == 0 && !isAlive) {
                body.app(Glyphs.text(status, 1224, 580, 6, statusRed ? T.RED : T.PINK, used));
            }
        }
        for (uint256 i = 0; i < 3; i++) {
            int256 x = 2800 + int256(i) * 50;
            int256 y = 60;
            if (i < s.sealsRemaining) {
                body.app(
                    abi.encodePacked(
                        '<rect x="', Num.itoa(x), '" y="', Num.itoa(y), '" width="34" height="34" fill="', T.ACID, '"/>'
                    )
                );
            } else {
                body.app(
                    abi.encodePacked(
                        '<rect x="',
                        Num.itoa(x),
                        '" y="',
                        Num.itoa(y),
                        '" width="34" height="34" fill="none" stroke="',
                        T.PINK,
                        '" stroke-width="4"/><path d="M',
                        Num.itoa(x),
                        " ",
                        Num.itoa(y + 34),
                        'l34 -34" stroke="',
                        T.PINK,
                        '" stroke-width="4" fill="none"/>'
                    )
                );
            }
        }
        if (s.kills > 0) {
            uint256 n = s.kills < 20 ? s.kills : 20;
            for (uint256 i = 0; i < n; i++) {
                body.app(
                    abi.encodePacked(
                        '<rect x="',
                        Num.utoa(2800 + (i % 10) * 14),
                        '" y="',
                        Num.utoa(130 + (i / 10) * 30),
                        '" width="8" height="20" fill="',
                        T.PINK,
                        '"/>'
                    )
                );
            }
        }
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3000 1000"><defs>',
                Glyphs.glyphDefs(used),
                "</defs>",
                body.fin(),
                '<svg x="0" y="0" width="1000" height="1000" viewBox="0 0 1000 1000">',
                innerContent,
                "</svg>",
                '<path d="M1000 0v1000" stroke="',
                T.ACID,
                '" stroke-width="3"/></svg>'
            )
        );
    }
}
