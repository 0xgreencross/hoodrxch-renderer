// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Integer formatting + JS-compatible arithmetic helpers.
library Num {
    /// decimal string of a signed integer (JS Number → string for integers)
    function itoa(int256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        bool neg = v < 0;
        uint256 u = neg ? uint256(-v) : uint256(v);
        bytes memory tmp = new bytes(78);
        uint256 i = 78;
        while (u != 0) {
            unchecked {
                i--;
                tmp[i] = bytes1(uint8(48 + (u % 10)));
                u /= 10;
            }
        }
        uint256 n = 78 - i + (neg ? 1 : 0);
        bytes memory out = new bytes(n);
        uint256 p = 0;
        if (neg) out[p++] = "-";
        for (uint256 j = i; j < 78; j++) out[p++] = tmp[j];
        return string(out);
    }

    function utoa(uint256 v) internal pure returns (string memory) {
        return itoa(int256(v));
    }

    /// JS Math.round(a/b) for b>0: floor((a + b/2)/b), half rounds toward +inf
    function jsRound(int256 a, int256 b) internal pure returns (int256) {
        return floorDiv(a + b / 2, b);
    }

    /// floor division (JS Math.floor(a/b)), b>0
    function floorDiv(int256 a, int256 b) internal pure returns (int256) {
        int256 q = a / b; // truncates toward zero
        if (a % b != 0 && ((a < 0) != (b < 0))) q -= 1;
        return q;
    }

    /// JS Math.trunc(a/b) / `(a/b)|0`: Solidity native int division
    function truncDiv(int256 a, int256 b) internal pure returns (int256) {
        return a / b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    function sign(int256 a) internal pure returns (int256) {
        return a > 0 ? int256(1) : (a < 0 ? int256(-1) : int256(0));
    }

    /// uppercase hex (no 0x) of the top `n` bytes of a bytes32
    function hexUpper(bytes32 h, uint256 n) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789ABCDEF";
        bytes memory out = new bytes(n * 2);
        for (uint256 i = 0; i < n; i++) {
            uint8 b = uint8(h[i]);
            out[i * 2] = alphabet[b >> 4];
            out[i * 2 + 1] = alphabet[b & 0x0f];
        }
        return string(out);
    }

    /// lowercase 0x-prefixed hex of a bytes32
    function hex0x(bytes32 h) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory out = new bytes(66);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i = 0; i < 32; i++) {
            uint8 b = uint8(h[i]);
            out[2 + i * 2] = alphabet[b >> 4];
            out[3 + i * 2] = alphabet[b & 0x0f];
        }
        return string(out);
    }

    /// standard base64 with padding (JS btoa)
    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        uint256 i = 0;
        uint256 j = 0;
        while (i + 3 <= data.length) {
            uint256 a_ = uint8(data[i]);
            uint256 b_ = uint8(data[i + 1]);
            uint256 c_ = uint8(data[i + 2]);
            uint256 triple = (a_ << 16) | (b_ << 8) | c_;
            result[j++] = table[(triple >> 18) & 63];
            result[j++] = table[(triple >> 12) & 63];
            result[j++] = table[(triple >> 6) & 63];
            result[j++] = table[triple & 63];
            i += 3;
        }
        if (data.length - i == 1) {
            uint256 a2 = uint8(data[i]);
            uint256 triple = a2 << 16;
            result[j++] = table[(triple >> 18) & 63];
            result[j++] = table[(triple >> 12) & 63];
            result[j++] = "=";
            result[j++] = "=";
        } else if (data.length - i == 2) {
            uint256 a3 = uint8(data[i]);
            uint256 b3 = uint8(data[i + 1]);
            uint256 triple = (a3 << 16) | (b3 << 8);
            result[j++] = table[(triple >> 18) & 63];
            result[j++] = table[(triple >> 12) & 63];
            result[j++] = table[(triple >> 6) & 63];
            result[j++] = "=";
        }
        return string(result);
    }
}
