// ---------------------------------------------------------------------------
// Genesis (MaskGeometry.sol). Round 10 — SIGNAL WRAITH.
// A completely different construction: no blocks, no checkers, no cartoon
// shapes. The whole image is a field of horizontal signal lines; a skull-form
// heightfield displaces them upward, so the figure exists only as a
// disturbance in the signal — a shroud draped over the scan. Eye sockets dent
// the field and burn as the only solid fills. Lines tear, spike and
// double-expose in pink. All integer fixed-point math (centi-units) so the
// Solidity port is bit-exact.
// ---------------------------------------------------------------------------
const PINK='#FF3EB5', WHITE='#FFFFFF';
// glow shades: luminance falloff toward the black ground (no filters onchain)
const GLOW_P1='#8A2263', GLOW_P2='#471132', GLOW_W1='#8A8A8A', GLOW_W2='#474747';
const FORM_NAMES=['BROAD','LEAN','SPIRE','SKEW L','SKEW R','SUNKEN','TOWERING','HOLLOW'];
const LINE_NAMES=['FINE','MID','HEAVY'];
const TEAR_NAMES=['CLEAN','TORN','SHREDDED'];
const SPIKE_NAMES=['NONE','FEW','STORM'];
const EYE_NAMES=['X','BROKEN X','SMEARED X','VISOR','SPLIT VISOR','X + SLIT','X + VOID','HOLLOW','DOUBLE X'];
const TREAT_NAMES=['RAW','ECHO GLOW','CHROMATIC','RIPPLE','FULL SIGNAL'];
const MOUTH_NAMES=['NONE','GASH','GRIN','SEWN'];
const PINKAMT_NAMES=['NONE','ECHO','BLEED'];
const MOSH_NAMES=['NONE','SHIFTS','HEAVY'];
const WARD_NAMES=['','CHEVRON','THREE BARS','DIAMOND'];

// traits: continuous anatomy parameters + named buckets
function drawTraits(rng){
  const t={};
  // skull mass
  t.cx = 44+rng.int(13);              // face centre x
  t.cy = 50+rng.int(9);               // face centre y
  t.rw = 24+rng.int(15);              // dome radius x
  t.rh = 28+rng.int(13);              // dome radius y
  t.amp = 18+rng.int(10);              // dome amplitude (units of lift)
  t.peak = rng.int(17)-8;             // crown peak skew
  t.pamp = 5+rng.int(6);              // peak amplitude
  t.jawY = t.cy+22+rng.int(8);        // mass fades below this
  // sockets (asymmetric)
  t.sLdx=-(8+rng.int(6)); t.sLdy=-(4+rng.int(6)); t.sLr=7+rng.int(4); t.sLd=13+rng.int(9);
  t.sRdx=  7+rng.int(6);  t.sRdy=-(3+rng.int(7)); t.sRr=6+rng.int(5); t.sRd=13+rng.int(9);
  t.nas = 4+rng.int(4);               // nasal dent
  // line field
  t.lineW=rng.int(3);                 // 0 fine 1 mid 2 heavy
  const te=rng.int(100); t.tear = te<35?0 : te<78?1 : 2;
  const sp=rng.int(100); t.spike = sp<30?0 : sp<80?1 : 2;
  const ey=rng.int(100);
  t.eyes = ey<26?0 : ey<38?1 : ey<46?2 : ey<62?3 : ey<70?4 : ey<82?5 : ey<90?6 : ey<96?7 : 8;
  t.eyeR = 6+rng.int(3);
  const tr=rng.int(100); t.treat = tr<15?0 : tr<40?1 : tr<60?2 : tr<75?3 : 4;
  const mo=rng.int(100); t.mouth = mo<22?0 : 1+((mo-22)%3);
  const p=rng.int(100); t.pink = p<30?0 : p<78?1 : 2;
  const g=rng.int(100); t.mosh = g<38?0 : g<78?1 : 2;
  // named form bucket (for rarity/metadata only)
  t.form = t.rw>=33 ? 0 : (t.rw<=27 ? 1 : (t.pamp>=12 ? 2 : (t.peak<=-4 ? 3 : (t.peak>=4 ? 4 : (t.amp<=15 ? 5 : (t.rh>=36 ? 6 : 7))))));
  return t;
}
// heightfield in centi-units. x,y in units. Integer math only.
// bump: A * ((1e4-d2)/1e4)^2 * 100  where d2 = (dx*100/rw)^2+(dy*100/rh)^2
function bump100(x,y,cx,cy,rw,rh,A){
  const nx=Math.trunc(((x-cx)*100)/rw), ny=Math.trunc(((y-cy)*100)/rh);
  const d2=nx*nx+ny*ny;
  if(d2>=10000) return 0;
  const q=10000-d2;                          // 0..1e4
  return Math.trunc(A*q*q/1000000);          // ≤ A*100
}
// flat-top head mass: full amplitude plateau, steep linear falloff at the edge
function bumpFlat100(x,y,cx,cy,rw,rh,A){
  const nx=Math.trunc(((x-cx)*100)/rw), ny=Math.trunc(((y-cy)*100)/rh);
  const d2=nx*nx+ny*ny;
  if(d2>=10000) return 0;
  const q = d2<4200 ? 10000 : Math.trunc((10000-d2)*10000/5800);
  return Math.trunc(A*q/100);
}
function heightAt(t,noiseCols,x,y,noSock){
  let b=bumpFlat100(x,y,t.cx,t.cy,t.rw,t.rh,t.amp);
  b+=bump100(x,y,t.cx+t.peak,t.cy-t.rh+6,14,16,t.pamp);
  b+=bumpFlat100(x,y,t.cx+((t.peak/2)|0),t.cy+18,t.rw+5,14,(t.amp>>1));
  b-=bump100(x,y,t.cx+((t.peak/3)|0),t.cy+7,4,6,t.nas);
  if(y>t.jawY){ const f=Math.max(0,1400-(y-t.jawY)*100); b=Math.trunc(b*f/1400); }
  if(b<-400) b=-400;
  const col=Math.max(0,Math.min(50,(x>>1)));
  return b+noiseCols[col];
}
// inside-socket test (for line gaps at the eyes)
function inSocket(t,x,y,which){
  const dx=which?t.sRdx:t.sLdx, dy=which?t.sRdy:t.sLdy, r=which?t.sRr:t.sLr;
  const nx=Math.trunc(((x-(t.cx+dx))*100)/(r+1)), ny=Math.trunc(((y-(t.cy+dy))*100)/Math.max(2,r-1));
  return nx*nx+ny*ny<10000;
}
function sigilSVG(ward,cx,cy,rng,fill){
  const J=(pts)=>offsetPts(pts,cx,cy); let s='';
  if(ward===1) s+=poly(J([[-3,1],[0,-3],[3,1],[3,3],[0,-1],[-3,3]]),fill);
  else if(ward===2){ for(let y=-3;y<=3;y+=3) s+=poly(J([[-3,y-1],[3,y-1],[3,y],[-3,y]]),fill); }
  else s+=poly(J([[0,-3],[3,0],[0,3],[-3,0]]),fill);
  return s;
}
function blockMarkSVG(block,cx,cy,rng,fill){
  switch(block){
    case 1: return rect(cx-1,cy-1,2,2,fill);
    case 2: return rect(cx-3,cy-1,6,2,fill);
    case 3: return rect(cx-3,cy-1,2,2,fill)+rect(cx+1,cy-1,2,2,fill);
    case 4: return poly(offsetPts([[-2,2],[0,-3],[2,2]],cx,cy),fill);
    case 5: return poly(offsetPts([[-2,-2],[2,-2],[2,2],[-2,2]],cx,cy),fill);
    case 6: return xmark(cx,cy,2,1,fill,rng);
  }
  return '';
}

// --- KILL-TIER GLYPHS: one unmistakable silhouette per tier ---
// T1 slash blade · T2 twin chevrons · T3 trident · T4 axe diamond · T5 crown · T6 scythe
function tierGlyphPolys(tier){
  switch(tier){
    case 1: return [[[-1,-8],[3,-8],[1,8],[-3,8]]];
    case 2: return [[[-7,-1],[0,-7],[7,-1],[7,3],[0,-3],[-7,3]],[[-7,7],[0,1],[7,7],[7,11],[0,5],[-7,11]]];
    case 3: return [[[-7,-8],[-5,-8],[-4,2],[-8,2]],[[-1,-10],[1,-10],[2,2],[-2,2]],[[5,-8],[7,-8],[8,2],[4,2]],[[-9,2],[9,2],[9,5],[-9,5]]];
    case 4: return [[[0,-10],[6,-3],[3,9],[-3,9],[-6,-3]],[[-1,-5],[1,-5],[1,4],[-1,4]]];
    case 5: return [[[-9,5],[-9,0],[-6,-7],[-3,0],[0,-9],[3,0],[6,-7],[9,0],[9,5]],[[-9,7],[9,7],[9,10],[-9,10]]];
    case 6: return [[[-8,-6],[-2,-10],[5,-9],[9,-4],[7,-3],[3,-6],[-2,-6],[-6,-3],[-7,1]],[[-3,-4],[1,-4],[-3,10],[-7,10]]];
  }
  return [];
}
// draw a tier glyph at (cx,cy), unit scale k/10 (k=10 → 1:1), solid fill
function tierGlyphSVG(tier,cx,cy,k,fill){
  let s2=''; for(const pts of tierGlyphPolys(tier)) s2+=poly(pts.map(p=>[cx+Math.round(p[0]*k/10),cy+Math.round(p[1]*k/10)]),fill);
  return s2;
}
// the tier-4 diamond carries a black slit; handle via draw order (second poly is the slit)
