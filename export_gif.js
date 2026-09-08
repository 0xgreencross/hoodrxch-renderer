// HOODRXCH GIF exporter — the CONSTRUCTED PFP in a perfect seamless loop.
// Captures exactly one full loop period starting well after every intro
// reveal has landed (t0=8s); the conveyor wrap is pixel-exact, so the GIF's
// own restart IS the loop wrap — truly seamless, no construction replay.
// Pass {"intro":true} to instead include the construction once + tailCycles
// loop periods (the wraith rebuilds itself on each GIF restart).
//
// usage: NODE_PATH=<playwright root> node export_gif.js <tokenId> [jsonState] [opts]
// opts (JSON): {size:500, fps:20, circle:false, out:"out.gif",
//               intro:false, tailCycles:4, introSec:6.2}
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const ctx = require('./render_cli.js');

function loopPeriod(st) {
  // exact loop period of the field for this token (seconds)
  const g = ctx.buildGenesis(Object.assign({}, st));
  const t = g.traits;
  const dash6 = t.tear === 6; // VAPOR rows carry 7-cycle dash phase
  if (t.lineW === 8) {
    // sky 60px @0.075s/px, fig 20px; 7-cycle phase when VAPOR
    return dash6 ? 31.5 : 4.5;
  }
  const stepD = t.lineW === 3 ? 10 : t.lineW === 4 ? 40 : 20;
  const cycD = t.lineW === 6 ? stepD * 2 : stepD;
  const base = cycD * 0.075;
  return (t.lineW === 5 || dash6) ? 7 * base : base;
}

async function main() {
  const tokenId = Number(process.argv[2] || 94);
  const patch = JSON.parse(process.argv[3] || '{}');
  const opts = Object.assign(
    { size: 500, fps: 20, circle: false, out: null, intro: false, tailCycles: 4, introSec: 6.2 },
    JSON.parse(process.argv[4] || '{}')
  );
  const st = Object.assign(ctx.defaultState(tokenId), patch);
  const svg = ctx.renderSVG(st);
  const status = ctx.resolveStatus(st);
  const coffin = status === 'COFFINED' || status === 'TERMINAL';
  const period = coffin ? 2.8 : loopPeriod(st);
  // loop-only (default): capture ONE period from t0=8s — after every reveal —
  // so the GIF restart lands exactly on the wrap. period*fps must be integer
  // for a clean splice (true for all styles at the default 20fps).
  const withIntro = opts.intro && !coffin;
  const t0 = withIntro ? 0 : (coffin ? 0 : 8);
  const total = withIntro ? opts.introSec + Math.max(1, opts.tailCycles) * period : period;
  const nFrames = Math.round(total * opts.fps);
  if (!withIntro && Math.abs(period * opts.fps - nFrames) > 1e-9) {
    console.warn(`WARNING: period ${period}s x ${opts.fps}fps is not integer — splice will jitter; pick an fps that divides the period.`);
  }
  console.log(`token #${tokenId} ${status} · period ${period}s · mode ${withIntro ? 'intro+loop' : 'seamless loop-only'} · ${nFrames} frames @${opts.fps}fps · ${opts.size}px`);

  const dir = fs.mkdtempSync('/tmp/hgif_');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: opts.size, height: opts.size } });
  await page.setContent(
    '<body style="margin:0;background:#000">' +
      svg.replace('<svg ', `<svg width="${opts.size}" height="${opts.size}" `) +
      '</body>'
  );
  await page.evaluate(() => document.querySelector('svg').pauseAnimations());
  for (let i = 0; i < nFrames; i++) {
    const t = t0 + i / opts.fps;
    await page.evaluate((tt) => { document.querySelector('svg').setCurrentTime(tt); }, t);
    await page.screenshot({ path: path.join(dir, 'f' + String(i).padStart(4, '0') + '.png') });
    if (i % 50 === 0) console.log(`  frame ${i}/${nFrames}`);
  }
  await browser.close();

  const out = opts.out || `hoodrxch_${tokenId}${opts.circle ? '_circle' : ''}.gif`;
  const py = `
from PIL import Image, ImageDraw
import glob
files=sorted(glob.glob('${dir}/f*.png'))
S=${opts.size}
frames=[]
mask=None
if ${opts.circle ? 'True' : 'False'}:
    mask=Image.new('L',(S,S),0)
    ImageDraw.Draw(mask).ellipse((0,0,S-1,S-1),fill=255)
for fp in files:
    im=Image.open(fp).convert('RGB')
    if mask is not None:
        bg=Image.new('RGB',(S,S),(0,0,0))
        bg.paste(im,(0,0),mask)
        im=bg
    frames.append(im.quantize(colors=64,dither=Image.NONE))
frames[0].save('${out}',save_all=True,append_images=frames[1:],duration=${Math.round(1000 / opts.fps)},loop=0,optimize=True)
import os
print('wrote ${out}', os.path.getsize('${out}'),'bytes')
`;
  fs.writeFileSync('/tmp/hgif_asm.py', py);
  const { execSync } = require('child_process');
  console.log(execSync('python3 /tmp/hgif_asm.py', { cwd: process.cwd() }).toString());
  fs.rmSync(dir, { recursive: true, force: true });
}
main().catch((e) => { console.error(e); process.exit(1); });
