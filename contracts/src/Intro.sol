// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Num} from "./Num.sol";

/// @notice CONSTRUCTION INTRO helpers — byte-identical mirrors of the JS
/// reveal machinery (src/05_render.js). Every base attribute stays the
/// finished art; reveals hide-then-show via one-shot discrete display
/// animates, so non-SMIL renderers see the final PFP.
/// All times are integer CENTISECONDS (1.42s == 142).
library Intro {
    /// JS T2(x): "(Math.round(x*100)/100)+'s'" — trims trailing zeros.
    /// 200 -> "2s", 250 -> "2.5s", 142 -> "1.42s", 5 -> "0.05s"
    function secs(int256 cs) internal pure returns (string memory) {
        int256 n = cs / 100;
        int256 fr = cs % 100;
        if (fr == 0) return string(abi.encodePacked(Num.itoa(n), "s"));
        if (fr % 10 == 0) return string(abi.encodePacked(Num.itoa(n), ".", Num.itoa(fr / 10), "s"));
        if (fr < 10) return string(abi.encodePacked(Num.itoa(n), ".0", Num.itoa(fr), "s"));
        return string(abi.encodePacked(Num.itoa(n), ".", Num.itoa(fr), "s"));
    }

    /// JS kt4(num/den): round to 4 decimals, trim trailing zeros.
    /// 0 -> "0", 1 -> "1", 5500/10000 -> "0.55", 667/10000 -> "0.0667"
    function kt4(int256 num, int256 den) internal pure returns (string memory) {
        int256 v = Num.jsRound(num * 10000, den);
        if (v == 0) return "0";
        if (v == 10000) return "1";
        // strip trailing zeros of the 4-digit fraction
        uint256 digits = 4;
        while (v % 10 == 0) {
            v /= 10;
            digits--;
        }
        bytes memory frac = new bytes(digits);
        int256 u = v;
        for (uint256 i = digits; i > 0; i--) {
            frac[i - 1] = bytes1(uint8(48 + uint256(u % 10)));
            u /= 10;
        }
        return string(abi.encodePacked("0.", frac));
    }

    /// reveal(content, tSec): one-shot discrete display switch at tSec
    /// (dur = 2*tSec trick). Empty content or t<=0.01s passes through.
    function reveal(string memory content, int256 tCs) internal pure returns (string memory) {
        if (bytes(content).length == 0 || tCs <= 1) return content;
        return string(
            abi.encodePacked(
                '<g><animate attributeName="display" values="none;inline" calcMode="discrete" dur="',
                secs(2 * tCs), '" repeatCount="1"/>', content, "</g>"
            )
        );
    }

    // cyberpunk ignition rhythms at tEyes = 1.0s — the full animate tags are
    // state-independent, extracted verbatim from the JS reference output
    function flickL(string memory content) internal pure returns (string memory) {
        if (bytes(content).length == 0) return content;
        return string(
            abi.encodePacked(
                '<g><animate attributeName="display" values="none;inline;none;inline;none;inline;none;inline;none;inline;none;inline;none;inline" keyTimes="0;0.7092;0.7305;0.7447;0.766;0.7801;0.8014;0.8156;0.844;0.8582;0.8794;0.8936;0.922;0.9645" calcMode="discrete" dur="1.41s" repeatCount="1"/>',
                content, "</g>"
            )
        );
    }

    function flickR(string memory content) internal pure returns (string memory) {
        if (bytes(content).length == 0) return content;
        return string(
            abi.encodePacked(
                '<g><animate attributeName="display" values="none;inline;none;inline;none;inline;none;inline;none;inline;none;inline;none;inline" keyTimes="0;0.7183;0.7324;0.7535;0.7676;0.7887;0.8169;0.831;0.8592;0.8803;0.9014;0.9225;0.9366;0.9648" calcMode="discrete" dur="1.42s" repeatCount="1"/>',
                content, "</g>"
            )
        );
    }

    /// glitch stutter ghost at tMouth = 1.42s, gdur 0.15 (constant keyTimes)
    function ghost(string memory content, int256 dx, int256 dy) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<g display="none"><animate attributeName="display" values="none;inline;none;inline;none" keyTimes="0;0.914;0.9299;0.9522;0.9745" calcMode="discrete" dur="1.57s" repeatCount="1"/><g transform="translate(',
                Num.itoa(dx), " ", Num.itoa(dy), ')">', content, "</g></g>"
            )
        );
    }
}
