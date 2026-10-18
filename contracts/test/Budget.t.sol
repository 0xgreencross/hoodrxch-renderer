// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RenderStateV1} from "../src/RenderState.sol";
import {Differential} from "./Differential.t.sol";

/// tokenURI feasibility against the game's certification ceiling
/// ("the lower of 45M gas or 80% of the lowest certified limit", KNOWN_BLOCKERS).
/// Profile 0 CANONICAL_STATIC is the profile tokenURI is meant to serve.
contract BudgetTest is Differential {
    function row(RenderStateV1 memory s, string memory nm) internal view {
        uint256 g0 = gasleft();
        string memory st = r.renderMetadata(s, 0);
        uint256 gS = g0 - gasleft();
        g0 = gasleft();
        string memory an = r.renderMetadata(s, 1);
        uint256 gA = g0 - gasleft();
        console.log(nm);
        console.log("   static   bytes", bytes(st).length, gS);
        console.log("   animated bytes", bytes(an).length, gA);
    }

    /// Profile 4 MARKETPLACE publishes the still as `image` and the animation
    /// as `animation_url`, so it pays for both renders in one call. Measured,
    /// not estimated, because this is the number that decides whether
    /// tokenURI can serve it directly or only an indexer can.
    function rowMarket(RenderStateV1 memory s, string memory nm) internal view {
        uint256 g0 = gasleft();
        string memory m = r.renderMetadata(s, 4);
        uint256 gM = g0 - gasleft();
        console.log(nm);
        console.log("   market   bytes", bytes(m).length, gM);
    }

    function test_Budget() public view {
        console.log("name / payload bytes / gas");
        row(state_FX_001(), "FX_001 ALIVE");
        row(state_FX_011(), "FX_011 WITSEC");
        row(state_FX_020(), "FX_020 heaviest records");
        row(state_FX_025(), "FX_025 STATS band");
        row(state_FX_026(), "FX_026 FLICKER");
        row(state_FX_031(), "FX_031 BARCODE");
        row(state_FX_032(), "FX_032 NO SIGNAL");
        row(state_FX_016(), "FX_016 TERMINAL");
        console.log("-- profile 4 MARKETPLACE (still + animation in one call) --");
        rowMarket(state_FX_001(), "FX_001 ALIVE");
        rowMarket(state_FX_037(), "FX_037 PURGED");
        rowMarket(state_FX_016(), "FX_016 TERMINAL");
        rowMarket(state_FX_044(), "FX_044 TERMINAL + crest");
    }
}
