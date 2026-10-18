// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RenderStateV1} from "../src/RenderState.sol";
import {Mask} from "../src/Mask.sol";
import {Rng} from "../src/Rng.sol";
import {GenesisLib} from "../src/GenesisLib.sol";
import {Differential} from "./Differential.t.sol";

/// The two identity rules the game's engineering review asked for:
///   1. the ART INDEX seeds the wraith; the token ID is display only
///   2. one death, one scar, forever — a later death never moves an earlier one
contract IdentityTest is Differential {
    function traitsOf(RenderStateV1 memory s) internal pure returns (Mask.Traits memory) {
        return Mask.drawTraits(Rng.init(GenesisLib.genesisSeed(s.genesisHash, s.artIndex)));
    }

    function test_ArtIndexSeedsTheWraith() public pure {
        RenderStateV1 memory worn = defaultState(42); // token 42 ...
        worn.artIndex = 7; // ... wearing art index 7
        worn.genesisHash = bytes32(0xe8792248150c64de2fab29c85f74156ad79a659e3d3ccbc7b4a6c8587e68f6ca);
        RenderStateV1 memory native = defaultState(7);

        Mask.Traits memory a = traitsOf(worn);
        Mask.Traits memory b = traitsOf(native);
        assertEq(a.form, b.form, "form");
        assertEq(a.lineW, b.lineW, "lineW");
        assertEq(a.tear, b.tear, "tear");
        assertEq(a.spike, b.spike, "spike");
        assertEq(a.eyes, b.eyes, "eyes");
        assertEq(a.treat, b.treat, "treat");
        assertEq(a.mouth, b.mouth, "mouth");
        assertEq(a.pink, b.pink, "pink");
        assertEq(a.mosh, b.mosh, "mosh");

        // and the token ID genuinely does not reach the art
        Mask.Traits memory own = traitsOf(defaultState(42));
        assertTrue(
            own.form != a.form || own.eyes != a.eyes || own.mouth != a.mouth || own.mosh != a.mosh,
            "art index 42 and 7 must not coincide, or this test proves nothing"
        );
    }

    function contains(string memory hay, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i = 0; i + n.length <= h.length; i++) {
            uint256 k = 0;
            while (k < n.length && h[i + k] == n[k]) k++;
            if (k == n.length) return true;
        }
        return false;
    }

    /// The scar drawn for the first death must appear, byte for byte, in the
    /// render taken after the second death. Under the old running-total seed it
    /// did not: every death re-rolled the whole history.
    function test_EarlierScarsNeverMove() public view {
        string memory oneDeath = r.renderSVG(state_FX_034(), 0);
        string memory twoDeaths = r.renderSVG(state_FX_035(), 0);

        // the scar band: the only stroke-width="4" white path in the figure
        string memory scar = firstScar(oneDeath);
        assertTrue(bytes(scar).length > 0, "no scar found in the one-death render");
        assertTrue(contains(twoDeaths, scar), "the second death moved the first scar");
    }

    function firstScar(string memory svg) internal pure returns (string memory) {
        bytes memory b = bytes(svg);
        bytes memory tail = bytes('" stroke="#FFFFFF" stroke-width="4" fill="none"/>');
        for (uint256 i = 0; i + 8 < b.length; i++) {
            if (b[i] == "<" && b[i + 1] == "p" && b[i + 2] == "a" && b[i + 3] == "t" && b[i + 4] == "h") {
                for (uint256 j = i; j + tail.length <= b.length; j++) {
                    uint256 k = 0;
                    while (k < tail.length && b[j + k] == tail[k]) k++;
                    if (k == tail.length) {
                        bytes memory out = new bytes(j + tail.length - i);
                        for (uint256 m = 0; m < out.length; m++) out[m] = b[i + m];
                        return string(out);
                    }
                    if (b[j] == ">") break; // this element ended without the scar tail
                }
            }
        }
        return "";
    }
}
