// Generates contracts/test/Differential.t.sol with expected keccak hashes
// computed by the JS reference renderer (the design source of truth).
const fs = require('fs');
const path = require('path');
process.chdir(__dirname);
const ctx = require('./render_cli.js');

const FIXTURES = [
 ['FX_001', 1, {}],
 ['FX_002', 2, {kills: 1}],
 ['FX_003', 3, {kills: 2}],
 ['FX_004', 4, {kills: 3}],
 ['FX_005', 5, {kills: 4}],
 ['FX_006', 6, {kills: 5}],
 ['FX_007', 7, {kills: 7}],
 ['FX_008', 8, {hunterSelected: true}],
 ['FX_009', 9, {lifeState: 1, marked: true, markedByTokenId: 66, purgeDeadline: 1790000000}],
 ['FX_010', 10, {lifeState: 1, marked: true, markedByTokenId: 13, purgeDeadline: 1790000000, kills: 18}],
 ['FX_011', 11, {witsecApplies: true, exposureState: 3}],
 ['FX_012', 12, {laidLow: true, exposureState: 2}],
 ['FX_013', 13, {buyerProtected: true, exposureState: 4}],
 ['FX_014', 14, {lifeState: 2, exposureState: 5, deaths: 1, sealsRemaining: 2}],
 ['FX_015', 15, {lifeState: 2, exposureState: 5, deaths: 2, sealsRemaining: 1, kills: 3}],
 ['FX_016', 16, {lifeState: 3, exposureState: 6, deaths: 3, sealsRemaining: 0}],
 ['FX_017', 17, {lifeState: 3, exposureState: 6, deaths: 3, sealsRemaining: 0, kills: 18}],
 ['FX_018', 18, {deaths: 2, sealsRemaining: 1, kills: 10}],
 ['FX_019', 19, {savesReceived: 5, savesGiven: 3}],
 ['FX_020', 20, {forcedPurges: 10}],
 ['FX_021', 21, {currentKillStreak: 5, kills: 9}],
 ['FX_022', 22, {latestSeasonBadgeFlags: 1, latestSeasonRank: 7, latestAwardSeasonId: 1}],
 ['FX_023', 23, {latestSeasonBadgeFlags: 3, latestSeasonRank: 2, latestAwardSeasonId: 2}],
 ['FX_024', 24, {territoryAchievementCount: 6, kills: 8}],
 ['FX_025', 25, {displayMode: 1, kills: 6, deaths: 1, sealsRemaining: 2, currentKillStreak: 3}],  // 6 kills = DEATH DEALER (upper bound; 7 is Reaper)
 ['FX_026', 26, {flicker: true, kills: 10}],
 ['FX_027', 27, {kills: 7, deaths: 1, sealsRemaining: 2, forcedPurges: 6, savesReceived: 3, latestSeasonBadgeFlags: 3, latestSeasonRank: 1, latestAwardSeasonId: 1, territoryAchievementCount: 4, currentKillStreak: 5}],
 ['FX_028', 28, {sealsRemaining: 0}],
 ['FX_029', 29, {witsecApplies: true, laidLow: true, exposureState: 3}],
 ['FX_030', 30, {lifeState: 3, exposureState: 6, deaths: 3, sealsRemaining: 0, marked: true}],
 ['FX_031', 46, {kills: 18}],   // BARCODE — breathing widths
 ['FX_032', 54, {kills: 5}],    // NO SIGNAL — dual-band + hood clip
 // IDENTITY: art index seeds the wraith, token ID is display only (handoff test).
 ['FX_033', 42, {artIndex: 7}],  // token 42 wearing art index 7
 // SCAR IMMUTABILITY: same token, one more death each time. Scar k is bound to
 // death k, so FX_034's single scar must survive untouched into FX_035/FX_036.
 ['FX_034', 61, {deaths: 1, sealsRemaining: 2}],
 ['FX_035', 61, {deaths: 2, sealsRemaining: 1}],
 ['FX_036', 61, {lifeState: 3, exposureState: 6, deaths: 3, sealsRemaining: 0}],
];
const BANNER_SET = new Set(['FX_001', 'FX_007', 'FX_009', 'FX_016', 'FX_028']);

const h = (str) => ctx.bytesToHex(ctx.keccak256(ctx.strBytes(str)));

const BOOL_FIELDS = new Set(['hunterSelected','transferLocked','marked','witsecApplies','laidLow','buyerProtected','flicker']);

let fns = '';
let calls = '';
fs.mkdirSync('contracts/js_expected', {recursive: true});
for (const [name, id, patch] of FIXTURES) {
  // artIndex drives the demo genesis hash exactly as it drives production's
  const st = Object.assign(ctx.defaultState(id, patch.artIndex), patch);
  const svg = ctx.renderSVG(st);
  const meta = ctx.renderMetadata(st);
  const sh = ctx.stateHash(st);
  // PROFILE 0 CANONICAL_STATIC / 2 STATS — the gas-viable, SMIL-free renders
  const svg0 = ctx.renderSVG(st, 0);
  const svg2 = ctx.renderSVG(st, 2);
  const meta0 = ctx.renderMetadata(st, 0);
  if (/<animate/.test(svg0) || /<animate/.test(svg2)) throw new Error(name + ': static profile still emits SMIL');
  fs.writeFileSync('contracts/js_expected/' + name + '.svg', svg);
  fs.writeFileSync('contracts/js_expected/' + name + '.json', meta);
  fs.writeFileSync('contracts/js_expected/' + name + '.static.svg', svg0);
  fs.writeFileSync('contracts/js_expected/' + name + '.stats.svg', svg2);
  fs.writeFileSync('contracts/js_expected/' + name + '.static.json', meta0);
  let sets = '';
  for (const [k, v] of Object.entries(patch)) {
    sets += `        s.${k} = ${v};\n`;
  }
  if (patch.artIndex !== undefined) sets += `        s.genesisHash = bytes32(${st.genesisHash});\n`;
  fns += `    function state_${name}() internal pure returns (RenderStateV1 memory s) {\n        s = defaultState(${id});\n${sets}    }\n\n`;
  fns += `    function test_${name}() public view {\n`;
  fns += `        RenderStateV1 memory s = state_${name}();\n`;
  fns += `        assertEq(r.stateHash(s), bytes32(${sh}), "stateHash");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderSVG(s))), bytes32(${h(svg)}), "svg");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderMetadata(s))), bytes32(${h(meta)}), "metadata");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderSVG(s, 0))), bytes32(${h(svg0)}), "svg-static");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderSVG(s, 2))), bytes32(${h(svg2)}), "svg-stats");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderMetadata(s, 0))), bytes32(${h(meta0)}), "metadata-static");\n`;
  fns += `        assertEq(keccak256(bytes(r.renderSVG(s, 1))), bytes32(${h(svg)}), "svg-profile1-default");\n`;
  if (BANNER_SET.has(name)) {
    const ban = ctx.renderBanner(st);
    fs.writeFileSync('contracts/js_expected/' + name + '.banner.svg', ban);
    fns += `        assertEq(keccak256(bytes(r.renderBanner(s))), bytes32(${h(ban)}), "banner");\n`;
  }
  fns += `    }\n\n`;
}

const sol = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// AUTO-GENERATED by tools/gen_difftest.js — do not edit by hand.
// Expected hashes come from the JS reference renderer over FX-001..FX-030.

import {Test} from "forge-std/Test.sol";
import {RenderStateV1} from "../src/RenderState.sol";
import {HOODRXCHRenderer} from "../src/HOODRXCHRenderer.sol";

contract Differential is Test {
    HOODRXCHRenderer internal r;

    function setUp() public {
        r = new HOODRXCHRenderer();
    }

    function defaultState(uint256 tokenId) internal pure returns (RenderStateV1 memory s) {
        s.schemaVersion = 1;
        s.tokenId = tokenId;
        s.artIndex = tokenId;
        s.wardId = ((tokenId - 1) % 3) + 1;
        s.blockId = (((tokenId - 1) / 3) % 6) + 1;
        s.genesisHash = keccak256(abi.encodePacked("HOODRXCH_GENESIS_V1", tokenId));
        s.warId = 1;
        s.campaignId = 1;
        s.seasonId = 1;
        s.activeBlockId = 1;
        s.exposureState = 1;
        s.sealsRemaining = 3;
        s.historicalStateCount = 1;
    }

${fns}}
`;
fs.writeFileSync('contracts/test/Differential.t.sol', sol);
console.log('wrote Differential.t.sol with', FIXTURES.length, 'fixtures');
