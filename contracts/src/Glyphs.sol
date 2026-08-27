// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Num} from "./Num.sol";
import {Buf} from "./Buf.sol";

/// @notice 5×7 block-glyph font. Mirrors src/02_glyphs.js exactly:
/// only glyphs actually used are emitted into <defs>, in first-use order.
library Glyphs {
    using Buf for Buf.B;

    struct Used {
        uint256 seen; // bitmap by char code
        bytes order; // chars in first-use order
        uint256 n;
    }

    function newUsed() internal pure returns (Used memory u) {
        u.order = new bytes(64);
    }

    function addUsed(Used memory u, bytes1 ch) internal pure {
        uint256 bit = uint256(1) << uint8(ch);
        if (u.seen & bit != 0) return;
        u.seen |= bit;
        u.order[u.n++] = ch;
    }

    /// row bitmaps, one byte per row (bit 4-x set = filled cell), rows top→down
    function rowsOf(bytes1 ch) internal pure returns (uint8[7] memory r, bool ok) {
        ok = true;
        uint8 c = uint8(ch);
        if (c == uint8(bytes1("A"))) return ([0x0e, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11], true);
        if (c == uint8(bytes1("B"))) return ([0x1e, 0x11, 0x11, 0x1e, 0x11, 0x11, 0x1e], true);
        if (c == uint8(bytes1("C"))) return ([0x0f, 0x10, 0x10, 0x10, 0x10, 0x10, 0x0f], true);
        if (c == uint8(bytes1("D"))) return ([0x1e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1e], true);
        if (c == uint8(bytes1("E"))) return ([0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x1f], true);
        if (c == uint8(bytes1("F"))) return ([0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x10], true);
        if (c == uint8(bytes1("G"))) return ([0x0f, 0x10, 0x10, 0x17, 0x11, 0x11, 0x0f], true);
        if (c == uint8(bytes1("H"))) return ([0x11, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11], true);
        if (c == uint8(bytes1("I"))) return ([0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1f], true);
        if (c == uint8(bytes1("J"))) return ([0x07, 0x01, 0x01, 0x01, 0x01, 0x11, 0x0e], true);
        if (c == uint8(bytes1("K"))) return ([0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11], true);
        if (c == uint8(bytes1("L"))) return ([0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1f], true);
        if (c == uint8(bytes1("M"))) return ([0x11, 0x1b, 0x15, 0x15, 0x11, 0x11, 0x11], true);
        if (c == uint8(bytes1("N"))) return ([0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11], true);
        if (c == uint8(bytes1("O"))) return ([0x0e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e], true);
        if (c == uint8(bytes1("P"))) return ([0x1e, 0x11, 0x11, 0x1e, 0x10, 0x10, 0x10], true);
        if (c == uint8(bytes1("Q"))) return ([0x0e, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0d], true);
        if (c == uint8(bytes1("R"))) return ([0x1e, 0x11, 0x11, 0x1e, 0x14, 0x12, 0x11], true);
        if (c == uint8(bytes1("S"))) return ([0x0f, 0x10, 0x10, 0x0e, 0x01, 0x01, 0x1e], true);
        if (c == uint8(bytes1("T"))) return ([0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04], true);
        if (c == uint8(bytes1("U"))) return ([0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e], true);
        if (c == uint8(bytes1("V"))) return ([0x11, 0x11, 0x11, 0x11, 0x11, 0x0a, 0x04], true);
        if (c == uint8(bytes1("W"))) return ([0x11, 0x11, 0x11, 0x15, 0x15, 0x1b, 0x11], true);
        if (c == uint8(bytes1("X"))) return ([0x11, 0x11, 0x0a, 0x04, 0x0a, 0x11, 0x11], true);
        if (c == uint8(bytes1("Y"))) return ([0x11, 0x11, 0x0a, 0x04, 0x04, 0x04, 0x04], true);
        if (c == uint8(bytes1("Z"))) return ([0x1f, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1f], true);
        if (c == uint8(bytes1("0"))) return ([0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e], true);
        if (c == uint8(bytes1("1"))) return ([0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e], true);
        if (c == uint8(bytes1("2"))) return ([0x0e, 0x11, 0x01, 0x06, 0x08, 0x10, 0x1f], true);
        if (c == uint8(bytes1("3"))) return ([0x1e, 0x01, 0x01, 0x0e, 0x01, 0x01, 0x1e], true);
        if (c == uint8(bytes1("4"))) return ([0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02], true);
        if (c == uint8(bytes1("5"))) return ([0x1f, 0x10, 0x10, 0x1e, 0x01, 0x01, 0x1e], true);
        if (c == uint8(bytes1("6"))) return ([0x0e, 0x10, 0x10, 0x1e, 0x11, 0x11, 0x0e], true);
        if (c == uint8(bytes1("7"))) return ([0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08], true);
        if (c == uint8(bytes1("8"))) return ([0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e], true);
        if (c == uint8(bytes1("9"))) return ([0x0e, 0x11, 0x11, 0x0f, 0x01, 0x01, 0x0e], true);
        if (c == uint8(bytes1("#"))) return ([0x0a, 0x0a, 0x1f, 0x0a, 0x1f, 0x0a, 0x0a], true);
        if (c == uint8(bytes1("/"))) return ([0x01, 0x02, 0x02, 0x04, 0x08, 0x08, 0x10], true);
        if (c == uint8(bytes1("."))) return ([0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0c], true);
        if (c == uint8(bytes1(":"))) return ([0x00, 0x0c, 0x0c, 0x00, 0x0c, 0x0c, 0x00], true);
        if (c == uint8(bytes1("-"))) return ([0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0x00], true);
        ok = false;
    }

    function glyphId(bytes1 ch) internal pure returns (string memory) {
        if (ch == "#") return "gNum";
        if (ch == "/") return "gSla";
        if (ch == ".") return "gDot";
        if (ch == ":") return "gCol";
        if (ch == "-") return "gDsh";
        return string(abi.encodePacked("g", ch));
    }

    /// bitmap → path, runs per row (identical output to JS glyphPath)
    function glyphPath(uint8[7] memory r) internal pure returns (string memory) {
        Buf.B memory b = Buf.init(512);
        for (uint256 y = 0; y < 7; y++) {
            uint256 x = 0;
            while (x < 5) {
                if ((r[y] >> (4 - x)) & 1 == 1) {
                    uint256 w = 1;
                    while (x + w < 5 && ((r[y] >> (4 - (x + w))) & 1 == 1)) w++;
                    b.app(
                        abi.encodePacked(
                            "M", Num.utoa(x), " ", Num.utoa(y), "h", Num.utoa(w), "v1h-", Num.utoa(w), "z"
                        )
                    );
                    x += w;
                } else {
                    x++;
                }
            }
        }
        return b.fin();
    }

    /// place a string; size = px per cell; advance 6 cells; spaces skipped
    function text(
        string memory str,
        int256 x,
        int256 y,
        int256 size,
        string memory fill,
        Used memory used
    ) internal pure returns (string memory) {
        bytes memory s = bytes(str);
        Buf.B memory b = Buf.init(160 * s.length + 64);
        for (uint256 i = 0; i < s.length; i++) {
            bytes1 ch = s[i];
            if (ch == " ") continue;
            (, bool ok) = rowsOf(ch);
            if (!ok) continue;
            addUsed(used, ch);
            b.app(
                abi.encodePacked(
                    '<use href="#',
                    glyphId(ch),
                    '" transform="translate(',
                    Num.itoa(x + int256(i) * 6 * size),
                    " ",
                    Num.itoa(y),
                    ") scale(",
                    Num.itoa(size),
                    ')" fill="',
                    fill,
                    '"/>'
                )
            );
        }
        return b.fin();
    }

    function glyphDefs(Used memory used) internal pure returns (string memory) {
        Buf.B memory b = Buf.init(768 * used.n + 64);
        for (uint256 i = 0; i < used.n; i++) {
            bytes1 ch = used.order[i];
            (uint8[7] memory r,) = rowsOf(ch);
            b.app(abi.encodePacked('<path id="', glyphId(ch), '" d="', glyphPath(r), '"/>'));
        }
        return b.fin();
    }
}
