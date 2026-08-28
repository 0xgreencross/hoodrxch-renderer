// ---------------------------------------------------------------------------
// Genesis (MaskGeometry.sol). Round 10 — SIGNAL WRAITH.
// A completely different construction: no blocks, no checkers, no cartoon
// shapes. The whole image is a field of horizontal signal lines; a skull-form
// heightfield displaces them upward, so the figure exists only as a
// disturbance in the signal — a shroud draped over the scan. Eye sockets dent
// the field and burn as the only solid fills. Lines tear, spike and
// double-expose in pink. All integer fixed-point math (centi-units) so the
// Solidity port is bit-exact.
//
// TRAIT ENGINE V2 — 110 values across 9 traits, six rarity tiers:
// COMMON > UNCOMMON > RARE > ULTRA RARE > LEGENDARY > EPIC (rarest, ~5‰).
// Every value is drawn from a per-mille weight table with a two-byte roll.
// ---------------------------------------------------------------------------
const PINK='#FF3EB5', WHITE='#FFFFFF';

// tier names for the rarity UI/docs (index into TIER_OF tables below)
const RARITY_NAMES=['COMMON','UNCOMMON','RARE','ULTRA RARE','LEGENDARY','EPIC'];

const FORM_NAMES=['BROAD','LEAN','SKEW L','SKEW R','HOLLOW','TOWERING','SPIRE','SUNKEN',
 'TWIN PEAK','HORNED','TILTED','CRATER','COLOSSUS','NEEDLE','WRAITH TALL','PHANTOM'];
const FORM_W=[195,185,95,95,90,80,55,55,30,30,28,25,12,12,8,5];
const FORM_TIER=[0,0,0,0,0,0,1,1,2,2,2,2,3,3,4,5];

const LINE_NAMES=['FINE','MID','HEAVY','DENSE','SPARSE','DASHED','DUAL WEIGHT','BARCODE','NO SIGNAL'];
const LINE_W=[240,260,210,90,90,55,35,15,5];
const LINE_TIER=[0,0,0,1,1,2,3,4,5];

const TEAR_NAMES=['CLEAN','TORN','SHREDDED','RIPPED EDGE','MOTH EATEN','SPLIT FIELD','VAPOR','CENSORED'];
const TEAR_W=[330,330,150,90,50,30,15,5];
const TEAR_TIER=[0,0,1,1,2,3,4,5];

const SPIKE_NAMES=['NONE','FEW','STORM','NEEDLES','SEISMIC','PULSE TRAIN','LIGHTNING','EARTHQUAKE','FLATLINE SCAR'];
const SPIKE_W=[300,330,130,90,50,45,35,15,5];
const SPIKE_TIER=[0,0,1,1,2,2,3,4,5];

const EYE_NAMES=['X','BROKEN X','SMEARED X','VISOR','SPLIT VISOR','X + SLIT','X + VOID','HOLLOW','DOUBLE X',
 'SLIT','GLITCH BAR','PIXEL STORM','CROSSHAIR','TRIPLE SLIT','VOID RING','NAILED X','BINARY',
 'TARGET','SPIRAL','WEEPING X','SPLIT PAIR','BURNING X','STAR','DEAD LIGHT','ALL SEEING'];
const EYE_W=[155,100,55,100,45,95,45,40,30,50,45,40,30,28,27,25,25,12,12,12,9,5,5,5,5];
const EYE_TIER=[0,0,1,0,1,0,1,1,2,1,1,1,2,2,2,2,2,3,3,3,3,4,4,4,5];

const TREAT_NAMES=['RAW','ECHO GLOW','CHROMATIC','RIPPLE','FULL SIGNAL',
 'STATIC','CROSS FLARE','HALO EYES','SMEAR TRAIL','INVERTED','PRISM','GOD RAYS'];
const TREAT_W=[190,240,190,90,120,60,35,25,25,12,8,5];
const TREAT_TIER=[0,0,0,1,0,1,2,3,3,4,4,5];

const MOUTH_NAMES=['NONE','GASH','GRIN','SEWN','WIRE','STITCHED GRIN','DOUBLE GASH','SIDE SMIRK',
 'ZIPPER','SNARL','DRIP','SCREAM','FANGS','HOWL','MUZZLE','GLITCH MOUTH'];
const MOUTH_W=[200,165,160,128,60,55,50,45,32,30,28,14,13,8,7,5];
const MOUTH_TIER=[0,0,0,0,1,1,1,1,2,2,2,3,3,4,4,5];

const PINKAMT_NAMES=['NONE','ECHO','BLEED','FLOOD','WHITE ECHO','INVERSION','TRICHROME','HEARTBEAT'];
const PINK_W=[320,350,150,80,50,30,15,5];
const PINK_TIER=[0,0,1,2,2,3,4,5];

const MOSH_NAMES=['NONE','SHIFTS','HEAVY','TEARDROP','CORRUPTED','SPLIT','MELTDOWN'];
const MOSH_W=[360,330,160,80,50,15,5];
const MOSH_TIER=[0,0,1,2,3,4,5];

const WARD_NAMES=['','CHEVRON','THREE BARS','DIAMOND'];

// weighted pick: two-byte per-mille roll against a cumulative table
function pick(rng,W){
  let r=rng.r1000(); for(let i=0;i<W.length;i++){ r-=W[i]; if(r<0) return i; }
  return W.length-1;
}

// traits: form-driven anatomy + weighted buckets
function drawTraits(rng){
  const t={};
  t.form=pick(rng,FORM_W);
  // anatomy per form (ranges keep continuous variety inside each silhouette)
  t.cx=44+rng.int(13); t.cy=50+rng.int(9);
  t.rw=25+rng.int(9); t.rh=29+rng.int(11); t.amp=19+rng.int(7);
  t.peak=rng.int(9)-4; t.pamp=6+rng.int(4);
  t.x2mode=0; t.x2amp=0; t.x2dx=0;
  switch(t.form){
    case 0: t.rw=30+rng.int(9); t.amp=20+rng.int(7); break;                    // BROAD
    case 1: t.rw=22+rng.int(5); t.rh=30+rng.int(11); break;                    // LEAN
    case 2: t.peak=-(8+rng.int(7)); t.rw=25+rng.int(9); break;                 // SKEW L
    case 3: t.peak=8+rng.int(7); t.rw=25+rng.int(9); break;                    // SKEW R
    case 4: t.amp=14+rng.int(4); t.rw=27+rng.int(8); break;                    // HOLLOW
    case 5: t.rh=38+rng.int(7); t.rw=24+rng.int(7); t.amp=20+rng.int(7); break;// TOWERING
    case 6: t.rw=20+rng.int(5); t.pamp=12+rng.int(5); t.rh=34+rng.int(9); break;// SPIRE
    case 7: t.amp=12+rng.int(4); t.cy=55+rng.int(4); t.rh=26+rng.int(7); break;// SUNKEN
    case 8: t.x2mode=1; t.x2amp=8+rng.int(5); t.x2dx=10+rng.int(5); break;     // TWIN PEAK
    case 9: t.x2mode=2; t.x2amp=10+rng.int(5); break;                          // HORNED
    case 10: t.peak=(12+rng.int(5))*(rng.int(2)?1:-1); t.cx=rng.int(2)?38+rng.int(5):52+rng.int(5); break; // TILTED
    case 11: t.x2mode=3; t.x2amp=8+rng.int(5); break;                          // CRATER
    case 12: t.rw=36+rng.int(5); t.amp=26+rng.int(5); t.rh=34+rng.int(7); break;// COLOSSUS
    case 13: t.rw=18+rng.int(4); t.pamp=14+rng.int(5); t.rh=38+rng.int(7); t.amp=16+rng.int(5); break; // NEEDLE
    case 14: t.cy=44+rng.int(3); t.rh=40+rng.int(5); break;                    // WRAITH TALL
    case 15: t.amp=10+rng.int(4); break;                                       // PHANTOM
  }
  t.jawY=t.cy+22+rng.int(8);
  // sockets (asymmetric)
  t.sLdx=-(8+rng.int(6)); t.sLdy=-(4+rng.int(6)); t.sLr=7+rng.int(4); t.sLd=13+rng.int(9);
  t.sRdx=  7+rng.int(6);  t.sRdy=-(3+rng.int(7)); t.sRr=6+rng.int(5); t.sRd=13+rng.int(9);
  t.nas = 4+rng.int(4);
  // field + surface buckets
  t.lineW=pick(rng,LINE_W);
  t.tear=pick(rng,TEAR_W);
  t.spike=pick(rng,SPIKE_W);
  t.eyes=pick(rng,EYE_W);
  t.eyeR=6+rng.int(3);
  t.treat=pick(rng,TREAT_W);
  t.mouth=pick(rng,MOUTH_W);
  t.pink=pick(rng,PINK_W);
  t.mosh=pick(rng,MOSH_W);
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
  // form modifiers: twin peak / horns / crater
  if(t.x2mode===1){ b+=bump100(x,y,t.cx-t.x2dx,t.cy-t.rh+7,10,14,t.x2amp); b+=bump100(x,y,t.cx+t.x2dx,t.cy-t.rh+7,10,14,t.x2amp); }
  else if(t.x2mode===2){ b+=bump100(x,y,t.cx-t.rw+4,t.cy-t.rh+10,5,12,t.x2amp); b+=bump100(x,y,t.cx+t.rw-4,t.cy-t.rh+10,5,12,t.x2amp); }
  else if(t.x2mode===3){ b-=bump100(x,y,t.cx+((t.peak/2)|0),t.cy-t.rh+8,9,10,t.x2amp); }
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
