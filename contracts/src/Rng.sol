// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Deterministic byte-stream RNG.
/// pool = keccak256(seed); byte i of pool; rehash pool on exhaustion.
/// Byte-for-byte identical to the JS reference `class Rng`.
library Rng {
    struct R {
        bytes32 pool;
        uint256 i;
    }

    function init(bytes memory seed) internal pure returns (R memory r) {
        r.pool = keccak256(seed);
        r.i = 0;
    }

    function nextByte(R memory r) internal pure returns (uint8) {
        if (r.i == 32) {
            r.pool = keccak256(abi.encodePacked(r.pool));
            r.i = 0;
        }
        uint8 b = uint8(r.pool[r.i]);
        unchecked {
            r.i++;
        }
        return b;
    }

    /// uniform-ish int in [0,n)
    function rInt(R memory r, uint256 n) internal pure returns (int256) {
        return int256(uint256(nextByte(r)) % n);
    }

    /// jitter in [-2..2]: {-2,-1,-1,0,0,0,1,1,2}[byte % 9]
    function jit(R memory r) internal pure returns (int256) {
        int8[9] memory t = [int8(-2), -1, -1, 0, 0, 0, 1, 1, 2];
        return int256(t[uint256(nextByte(r)) % 9]);
    }
}
