// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console2} from "forge-std/Test.sol";
import {RenderStateV1} from "../src/RenderState.sol";
import {HOODRXCHRenderer} from "../src/HOODRXCHRenderer.sol";

contract Gas is Test {
    HOODRXCHRenderer internal r;
    function setUp() public { r = new HOODRXCHRenderer(); }
    function defaultState(uint256 tokenId) internal pure returns (RenderStateV1 memory s) {
        s.schemaVersion=1; s.tokenId=tokenId; s.artIndex=tokenId;
        s.wardId=((tokenId-1)%3)+1; s.blockId=(((tokenId-1)/3)%6)+1;
        s.genesisHash=keccak256(abi.encodePacked("HOODRXCH_GENESIS_V1", tokenId));
        s.warId=1; s.campaignId=1; s.seasonId=1; s.activeBlockId=1;
        s.exposureState=1; s.sealsRemaining=3; s.historicalStateCount=1;
    }
    function report(string memory label, RenderStateV1 memory s) internal view {
        uint256 g0 = gasleft();
        string memory svg = r.renderSVG(s);
        uint256 g1 = gasleft();
        string memory meta = r.renderMetadata(s);
        uint256 g2 = gasleft();
        console2.log(label, g0 - g1, g1 - g2, bytes(svg).length);
        meta;
    }
    function test_gas_report() public view {
        console2.log("fixture | renderSVG gas | renderMetadata gas | svg bytes");
        RenderStateV1 memory s = defaultState(1);
        report("GENESIS ", s);
        s = defaultState(7); s.kills = 100;
        report("REAPER  ", s);
        s = defaultState(9); s.lifeState=1; s.marked=true; s.markedByTokenId=66; s.purgeDeadline=1790000000;
        report("MARKED  ", s);
        s = defaultState(14); s.lifeState=2; s.exposureState=5; s.deaths=1; s.sealsRemaining=2;
        report("COFFINED", s);
        s = defaultState(16); s.lifeState=3; s.exposureState=6; s.deaths=3; s.sealsRemaining=0;
        report("TERMINAL", s);
        s = defaultState(25); s.displayMode=1; s.kills=25; s.deaths=1; s.sealsRemaining=2; s.currentKillStreak=3;
        report("STATS   ", s);
        s = defaultState(28); s.sealsRemaining=0;
        report("DIAG    ", s);
        s = defaultState(1);
        uint256 g0 = gasleft();
        string memory ban = r.renderBanner(s);
        console2.log("BANNER  ", g0 - gasleft(), 0, bytes(ban).length);
    }
}
