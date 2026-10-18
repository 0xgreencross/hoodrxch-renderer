// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Integer formatting + JS-compatible arithmetic helpers.
library Num {
    /// decimal string of a signed integer (JS Number → string for integers)
    function itoa(int256 v) internal pure returns (string memory s) {
        unchecked {
            if (v == 0) return "0";
            bool neg = v < 0;
            uint256 u = neg ? uint256(-v) : uint256(v);
            uint256 n = neg ? 1 : 0;
            for (uint256 t = u; t != 0; t /= 10) n++;
            s = new string(n);
            assembly ("memory-safe") {
                let p := add(add(s, 32), n)
                for { let x := u } gt(x, 0) { x := div(x, 10) } {
                    p := sub(p, 1)
                    mstore8(p, add(48, mod(x, 10)))
                }
                if neg { mstore8(sub(p, 1), 45) }
            }
        }
    }

    function utoa(uint256 v) internal pure returns (string memory) {
        return itoa(int256(v));
    }

    /// JS Math.round(a/b) for b>0: floor((a + b/2)/b), half rounds toward +inf
    function jsRound(int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            return floorDiv(a + b / 2, b);
        }
    }

    /// floor division (JS Math.floor(a/b)), b>0
    function floorDiv(int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            int256 q = a / b; // truncates toward zero
            if (a % b != 0 && ((a < 0) != (b < 0))) q -= 1;
            return q;
        }
    }

    /// JS Math.trunc(a/b) / `(a/b)|0`: Solidity native int division
    function truncDiv(int256 a, int256 b) internal pure returns (int256) {
        return a / b;
    }

    /// integer sqrt (Babylonian, floor) — mirrors the JS isqrt used for path
    /// arc lengths (dash centre-anchoring); identical for all n >= 0
    function isqrt(int256 n) internal pure returns (int256) {
        unchecked {
            if (n < 2) return n;
            int256 x = n;
            int256 y = (n + 1) / 2;
            while (y < x) {
                x = y;
                y = (y + n / y) / 2;
            }
            return x;
        }
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
        uint256 len = data.length;
        uint256 full = len - (len % 3); // whole triples only; the tail is exact below
        bytes memory result = new bytes(4 * ((len + 2) / 3));
        uint256 j;
        assembly ("memory-safe") {
            // +1 (not +32): mload here reads the table byte into its LOW byte,
            // which is what mstore8 writes.
            let tbl := add(table, 1)
            let src := add(data, 32)
            let dst := add(result, 32)
            let end := add(src, full)
            for {} lt(src, end) { src := add(src, 3) } {
                let word := shr(232, mload(src)) // the next three bytes
                mstore8(dst, mload(add(tbl, and(shr(18, word), 63))))
                mstore8(add(dst, 1), mload(add(tbl, and(shr(12, word), 63))))
                mstore8(add(dst, 2), mload(add(tbl, and(shr(6, word), 63))))
                mstore8(add(dst, 3), mload(add(tbl, and(word, 63))))
                dst := add(dst, 4)
            }
            j := sub(dst, add(result, 32))
        }
        uint256 i = full;
        if (len - i == 1) {
            uint256 triple = uint256(uint8(data[i])) << 16;
            result[j++] = table[(triple >> 18) & 63];
            result[j++] = table[(triple >> 12) & 63];
            result[j++] = "=";
            result[j++] = "=";
        } else if (len - i == 2) {
            uint256 triple = (uint256(uint8(data[i])) << 16) | (uint256(uint8(data[i + 1])) << 8);
            result[j++] = table[(triple >> 18) & 63];
            result[j++] = table[(triple >> 12) & 63];
            result[j++] = table[(triple >> 6) & 63];
            result[j++] = "=";
        }
        return string(result);
    }
}
