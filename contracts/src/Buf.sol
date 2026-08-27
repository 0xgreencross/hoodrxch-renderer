// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Appendable byte buffer. Preallocate once, append in place.
/// Mirrors the JS renderer's string accumulation without O(n^2) copies.
library Buf {
    struct B {
        bytes data; // backing store, length = capacity
        uint256 len; // bytes written
    }

    function init(uint256 cap) internal pure returns (B memory b) {
        b.data = new bytes(cap);
        b.len = 0;
    }

    function app(B memory b, bytes memory s) internal pure {
        bytes memory d = b.data;
        uint256 l = b.len;
        // +31: the word-wise copy may scribble up to 31 bytes past the end
        require(l + s.length + 31 <= d.length, "buf overflow");
        assembly ("memory-safe") {
            let src := add(s, 32)
            let dst := add(add(d, 32), l)
            let n := mload(s)
            for { let i := 0 } lt(i, n) { i := add(i, 32) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
        b.len = l + s.length;
    }

    function app(B memory b, string memory s) internal pure {
        app(b, bytes(s));
    }

    function fin(B memory b) internal pure returns (string memory) {
        bytes memory d = b.data;
        uint256 l = b.len;
        assembly ("memory-safe") {
            mstore(d, l)
        }
        return string(d);
    }
}
