// ---------------------------------------------------------------------------
// RenderStateV1 (handoff §13.2) + displayMode/flicker (open item O-2)
// ---------------------------------------------------------------------------
const LIFE=['ALIVE','MARKED','COFFINED','TERMINAL_COFFIN'];
const EXPO=['NOT_APPLICABLE','ON_THE_STREET','LAY_LOW','WITSEC','BUYER_PROTECTED','COFFINED','TERMINAL'];
const TIER_NAMES=['NONE','FIRST BLOOD','RISING THREAT','SAVAGE','EXECUTIONER','DEATH DEALER','REAPER'];
const TIER_MIN=[0,1,10,25,50,75,100];
const PHASES=['REGISTRATION','SELECTION','RESCUE','EXECUTION','FINALISATION','ARMISTICE'];
function tierForKills(k){ if(k>=100)return 6; if(k>=75)return 5; if(k>=50)return 4; if(k>=25)return 3; if(k>=10)return 2; if(k>=1)return 1; return 0; }
function defaultState(tokenId){
  tokenId=tokenId||1;
  const wardId=((tokenId-1)%3)+1, blockId=(Math.floor((tokenId-1)/3)%6)+1; // demo assignment only; WardRegistry is canonical
  return {schemaVersion:1,tokenId,artIndex:tokenId,wardId,blockId,genesisHash:demoGenesisHash(tokenId),
    warId:1,campaignId:1,seasonId:1,activeBlockId:1,warPhase:0,
    lifeState:0,exposureState:1,sealsRemaining:3,hunterSelected:false,transferLocked:false,transferLockUntil:0,
    marked:false,markedByTokenId:0,markedByWardId:0,purgeDeadline:0,
    witsecCredits:0,witsecApplies:false,laidLow:false,buyerProtected:false,
    kills:0,deaths:0,forcedPurges:0,savesGiven:0,savesReceived:0,currentKillStreak:0,longestKillStreak:0,terminalKills:0,
    lifetimeKillTier:0,latestAwardSeasonId:0,latestSeasonRank:0,latestSeasonBadgeFlags:0,seasonAwardCount:0,territoryAchievementCount:0,
    deathRecordCount:0,historicalStateCount:1,
    displayMode:0,flicker:false};
}
// Impossible states (STATE_TO_LAYER_MAP §5). Returns array of codes.
function validate(s){
  const e=[]; const prot=(s.witsecApplies?1:0)+(s.laidLow?1:0)+(s.buyerProtected?1:0);
  const T=s.lifeState===3, C=s.lifeState===2, M=s.lifeState===1||s.marked;
  if(T&&(prot>0||s.hunterSelected||s.marked)) e.push('E01');
  if(C&&(prot>0||s.hunterSelected||s.marked)) e.push('E02');
  if(M&&(s.witsecApplies||s.laidLow)) e.push('E03');
  if(s.sealsRemaining===0&&!T) e.push('E04');
  if((s.deaths>=3&&!T)||(T&&s.deaths<3)) e.push('E05');
  if(s.sealsRemaining+Math.min(s.deaths,3)!==3) e.push('E06');
  if((s.latestSeasonBadgeFlags&2)&&!(s.latestSeasonBadgeFlags&1)) e.push('E07');
  if(prot>1) e.push('E08');
  if(s.marked!==(s.lifeState===1)) e.push('E09');
  const exC=s.exposureState===5, exT=s.exposureState===6;
  if((exT&&!T)||(T&&!exT)||(exC&&!C)||(C&&!exC)) e.push('E10');
  if(s.wardId<1||s.wardId>3||s.blockId<1||s.blockId>6||s.tokenId<1||s.tokenId>666||s.schemaVersion!==1) e.push('E11');
  if(s.latestSeasonBadgeFlags!==0&&(s.latestSeasonRank===0||s.latestAwardSeasonId===0)) e.push('E12');
  if(s.latestSeasonRank>=1&&s.latestSeasonRank<=5&&s.latestSeasonBadgeFlags!==3) e.push('E12');
  if(s.latestSeasonRank>=6&&s.latestSeasonRank<=10&&s.latestSeasonBadgeFlags!==1) e.push('E12');
  return [...new Set(e)];
}
// stateHash over material fields (map §6) — abi.encode, every field a 32-byte word.
function stateHash(s){
  const f=[s.schemaVersion,s.tokenId,s.artIndex,s.wardId,s.blockId];
  let b=concatBytes(...f.map(word), hexToBytes(s.genesisHash));
  const rest=[s.seasonId,s.lifeState,s.exposureState,s.sealsRemaining,s.hunterSelected?1:0,s.transferLocked?1:0,s.marked?1:0,s.markedByTokenId,s.purgeDeadline,
    s.witsecApplies?1:0,s.laidLow?1:0,s.buyerProtected?1:0,s.kills,s.deaths,s.forcedPurges,s.savesReceived,s.currentKillStreak,
    s.latestAwardSeasonId,s.latestSeasonRank,s.latestSeasonBadgeFlags,s.territoryAchievementCount,s.displayMode];
  b=concatBytes(b,...rest.map(word));
  return bytesToHex(keccak256(b));
}
function resolveStatus(s){
  if(s.lifeState===3) return 'TERMINAL';
  if(s.lifeState===2) return 'COFFINED';
  if(s.lifeState===1||s.marked) return 'MARKED';
  if(s.witsecApplies) return 'WITSEC';
  if(s.buyerProtected) return 'BUYER_PROTECTED';
  if(s.laidLow) return 'LAY_LOW';
  if(s.hunterSelected) return 'HUNTER_SELECTED';
  return 'ALIVE';
}
// ---------------------------------------------------------------------------
// Diagnostic SVG
// ---------------------------------------------------------------------------
function diagnosticSVG(s,errs){
  const used=new Set(); let body='';
  body+=text('INVALID STATE',74,380,11,RED,used);
  body+=text(errs.join(' '),110,520,10,RED,used);
  body+=text('#'+String(s.tokenId),110,620,10,RED,used);
  body+=text(stateHash(s).slice(2,18).toUpperCase(),110,710,8,RED,used);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"><defs>'+glyphDefs(used)+'</defs><rect width="1000" height="1000" fill="'+BLACK+'"/><rect x="20" y="20" width="960" height="960" fill="none" stroke="'+RED+'" stroke-width="24"/>'+body+'</svg>';
}
// ---------------------------------------------------------------------------
// Eye glyphs (shared by the live figure and the coffin compositions).
// One X arm: quad from centre toward (dx,dy); used to build broken/half arms.
// ---------------------------------------------------------------------------
function eyeArm(cx,cy,dx,dy,r,b,fill){ return poly([[cx-b*dy/2|0 || cx, cy+b*dx/2|0 || cy],[cx+(b*dy/2|0),cy-(b*dx/2|0)],[cx+dx*r+(b*dy/2|0),cy+dy*r-(b*dx/2|0)],[cx+dx*r-(b*dy/2|0),cy+dy*r+(b*dx/2|0)]],fill); }
// octagon ring (stroke) centred at cx,cy — shared by eyes/treatments/mouths
function octRing(cx,cy,r,w,color){
  const q=(r*7/10)|0;
  const pts=[[cx-r,cy],[cx-q,cy-q],[cx,cy-r],[cx+q,cy-q],[cx+r,cy],[cx+q,cy+q],[cx,cy+r],[cx-q,cy+q]];
  return '<path d="'+pathD(pts)+'" fill="none" stroke="'+color+'" stroke-width="'+w+'"/>';
}
function octFill(cx,cy,r,fill){
  const q=(r*7/10)|0;
  return poly([[cx-r,cy],[cx-q,cy-q],[cx,cy-r],[cx+q,cy-q],[cx+r,cy],[cx+q,cy+q],[cx,cy+r],[cx-q,cy+q]],fill);
}
function eyeGlyph(st,side,cx,cy,r,fill,rng){
  let e='';
  const X=(rr,bb)=>xmark(cx,cy,rr,bb,fill,rng);
  switch(st){
    case 0: e+=X(r,3); break;
    case 1: { const arms=[[1,-1],[-1,1],[-1,-1],[1,1]]; const skip=side?0:2;
      for(let k=0;k<4;k++){ if(k===skip) continue; e+=eyeArm(cx,cy,arms[k][0],arms[k][1],r,3,fill); }
      e+=eyeArm(cx,cy,arms[skip][0],arms[skip][1],(r>>1),3,fill); break; }
    case 2: e+=X(r,3); e+=rect(side?cx+2:cx-r-5,cy-1,r+3,2,fill); break;
    case 3: e+=rect(cx-r-1,cy-1,2*r+2,4,fill); break; // visor (standalone: one blade per eye)
    case 4: e+=rect(cx-r,cy-((r/2)|0),2*r,3,fill); e+=rect(cx-r+2,cy+2,2*r-2,3,fill); break;
    case 5: if(side) e+=rect(cx-r,cy-1,2*r,4,fill); else e+=X(r,3); break;
    case 6: if(!side) e+=X(r,3); break; // right eye = pure void
    case 7: break;                       // hollow: both void
    case 8: e+=X(side?(r>>1)+1:r+1,3); break;
    case 9: e+=rect(cx-r,cy-1,2*r,2,fill); break; // SLIT
    case 10: e+=rect(cx-1,cy-r,3,2*r,fill); e+=rect(cx+1,cy-2,r+2,3,fill); break; // GLITCH BAR
    case 11: for(let i=0;i<5;i++) e+=rect(cx-r+rng.int(2*r),cy-r+rng.int(2*r),2,2,fill); break; // PIXEL STORM
    case 12: e+=X(r,3); e+=rect(cx-1,cy-r-4,2,3,fill)+rect(cx-1,cy+r+1,2,3,fill)+rect(cx-r-4,cy-1,3,2,fill)+rect(cx+r+1,cy-1,3,2,fill); break; // CROSSHAIR
    case 13: e+=rect(cx-r,cy-4,2*r,2,fill)+rect(cx-r,cy-1,2*r,2,fill)+rect(cx-r,cy+2,2*r,2,fill); break; // TRIPLE SLIT
    case 14: e+=octRing(cx,cy,r,9,fill); break; // VOID RING
    case 15: e+=X(r,3); e+=rect(cx-1,cy-3,2,6,WHITE)+rect(cx-3,cy-1,6,2,WHITE); break; // NAILED X
    case 16: if(side) e+=octRing(cx,cy,r-1,9,fill); else e+=rect(cx-1,cy-r,3,2*r,fill); break; // BINARY (1|0)
    case 17: e+=octRing(cx,cy,r+1,10,fill); e+=rect(cx-2,cy-2,3,3,fill); break; // TARGET
    case 18: { // SPIRAL: square spiral inward
      let d='M'+((cx-r)*U)+' '+((cy-r)*U);
      const dirs=[[1,0],[0,1],[-1,0],[0,-1]];
      for(let k=0;k<7;k++){ const len=k<3?2*r:2*r-3*((k-1)>>1); if(len<2) break;
        const dxy=dirs[k%4]; d+= dxy[0]!==0 ? 'h'+(dxy[0]*len*U) : 'v'+(dxy[1]*len*U); }
      e+='<path d="'+d+'" fill="none" stroke="'+fill+'" stroke-width="6"/>'; break; }
    case 19: e+=X(r,3); e+=rect(cx+1,cy+r,2,7+rng.int(4),fill); break; // WEEPING X
    case 20: if(side) e+=octRing(cx,cy,r,9,fill); else e+=X(r,3); break; // SPLIT PAIR
    case 21: e+=xmark(cx+2,cy+2,r,3,PINK,rng); e+=X(r,3); e+=xmark(cx,cy,(r>>1),2,WHITE,rng); break; // BURNING X
    case 22: e+=poly(offsetPts([[0,-r-1],[2,-2],[r+1,0],[2,2],[0,r+1],[-2,2],[-r-1,0],[-2,-2]],cx,cy),fill); break; // STAR
    case 23: e+=octFill(cx,cy,r,fill); break; // DEAD LIGHT
    // 24 ALL SEEING handled at drawEyes level
  }
  return e;
}
// ---------------------------------------------------------------------------
// Genesis figure. Returns {defs, figure, traits, hoodPts}
// ---------------------------------------------------------------------------
function buildGenesis(sState){
  const s=sState;
  const rng=new Rng(genesisSeed(s.genesisHash,s.tokenId));
  const t=drawTraits(rng);
  // column noise: a smooth random walk shared by every line (organic wobble)
  const noiseAmp = t.form===15 ? 24 : 12; // PHANTOM: the figure barely holds together
  const noiseCols=[]; { let n=0; for(let c=0;c<=50;c++){ n+=(rng.int(3)-1)*noiseAmp; if(n>150)n=150; if(n<-150)n=-150; noiseCols.push(n); } }
  // --- FIELD LINE LIST per LINES style ---
  const lines=[]; // {y, w, dash?, figOnly?}
  if(t.lineW<=2){ const w=[3,4,6][t.lineW]; for(let li=0;li<47;li++) lines.push({y:4+li*2,w}); }
  else if(t.lineW===3){ for(let li=0;li<93;li++) lines.push({y:4+li,w:2}); }                    // DENSE
  else if(t.lineW===4){ for(let li=0;li<24;li++) lines.push({y:4+li*4,w:5}); }                  // SPARSE
  else if(t.lineW===5){ for(let li=0;li<47;li++) lines.push({y:4+li*2,w:4,dash:1}); }           // DASHED
  else if(t.lineW===6){ for(let li=0;li<47;li++) lines.push({y:4+li*2,w:li%2?6:2}); }           // DUAL WEIGHT
  else if(t.lineW===7){ for(let li=0;li<47;li++) lines.push({y:4+li*2,w:[2,4,7][rng.int(3)]}); }// BARCODE
  else { for(let li=0;li<16;li++) lines.push({y:4+li*6,w:3});                                   // NO SIGNAL
         for(let li=0;li<47;li++) lines.push({y:4+li*2,w:3,figOnly:1}); }
  // --- SPIKE STYLE pre-draws (deterministic order) ---
  const spikes={}; let pulseLi=-1,pulseAmp=0, flatLi=-1, quake=null, lightning=false;
  {
    const addSpikes=(n,ampFn)=>{ for(let i=0;i<n;i++){ const li=rng.int(lines.length); (spikes[li]=spikes[li]||[]).push([rng.int(34),ampFn()]); } };
    if(t.spike===1) addSpikes(1+rng.int(2),()=> (25+rng.int(25))*(rng.int(3)?1:-1));
    else if(t.spike===2) addSpikes(3+rng.int(3),()=> (25+rng.int(25))*(rng.int(3)?1:-1));
    else if(t.spike===3) addSpikes(8+rng.int(4),()=> -(8+rng.int(8)));                    // NEEDLES
    else if(t.spike===4) addSpikes(1,()=> (60+rng.int(31))*(rng.int(3)?1:-1));            // SEISMIC
    else if(t.spike===5){ pulseLi=rng.int(lines.length); pulseAmp=18+rng.int(10); }       // PULSE TRAIN
    else if(t.spike===6) lightning=true;                                                  // LIGHTNING
    else if(t.spike===7){ quake=[]; for(let i=0;i<13;i++) quake.push(rng.int(17)-8); }    // EARTHQUAKE
    else if(t.spike===8){ const target=25+rng.int(50); flatLi=0;                          // FLATLINE SCAR
      for(let li=0;li<lines.length;li++){ if(lines[li].y>=target){ flatLi=li; break; } } }
  }
  // --- TEAR STYLE pre-draws ---
  let moth=null, splitY=-1, censor=null;
  if(t.tear===4){ moth=[]; const nB=3+rng.int(3); for(let i=0;i<nB;i++) moth.push([rng.int(100),4+rng.int(90),5+rng.int(4)]); }
  else if(t.tear===5) splitY=14+rng.int(66);
  else if(t.tear===7){ censor=[]; for(let i=0;i<3;i++) censor.push([rng.int(70),rng.int(80),12+rng.int(14),8+rng.int(8)]); }
  const mw=9+rng.int(5), mouthY=t.cy+13+rng.int(3);
  const STEP=3;
  // mouth gap band height per type (rows below mouthY-1)
  const mouthGapLo = t.mouth>0 ? mouthY-1 : 0;
  const mouthGapHi = t.mouth===11||t.mouth===13 ? mouthY+8 : (t.mouth===4 ? mouthY+2 : (t.mouth===14||t.mouth===15 ? mouthY+6 : mouthY+4));
  // --- BUILD EVERY LINE PATH (displaced, torn, spiked) ---
  const linesD=[];
  for(let li=0;li<lines.length;li++){
    const L=lines[li]; const baseY=L.y;
    if(li===flatLi){ linesD.push({d:'',maxH:0,baseY,w:L.w}); continue; } // drawn as the scar below
    let d=''; let pen=false; let px=0,py=0; let breakLeft=0; let maxH=0;
    for(let xi=0;xi<=33;xi++){
      const x=xi*STEP;
      const h=heightAt(t,noiseCols,x,baseY);
      if(h>maxH) maxH=h;
      let ypx=baseY*10-Math.round(h/10);
      if(spikes[li]) for(const [sx,amp] of spikes[li]) if(sx===xi) ypx+=amp;
      if(li===pulseLi && xi%6<3) ypx-=pulseAmp;
      if(quake) ypx+=quake[(xi+li*3)%13];
      // gaps: figure-only lines, eye sockets, mouth, tear styles
      let gap=false;
      if(L.figOnly && h<=300) gap=true;
      { const yv=baseY-Math.round(heightAt(t,noiseCols,x,baseY,true)/100); if(inSocket(t,x,yv,0)||inSocket(t,x,yv,1)) gap=true; }
      if(t.mouth>0 && baseY>=mouthGapLo && baseY<=mouthGapHi && Math.abs(x-t.cx)<mw) gap=true;
      if(L.dash && (xi+baseY)%7<2) gap=true;
      if(moth){ for(const [bx,by,r] of moth){ const ddx=x-bx, ddy=baseY-by; if(ddx*ddx+ddy*ddy<r*r) gap=true; } }
      if(splitY>=0 && baseY>=splitY && baseY<splitY+5) gap=true;
      if(censor){ for(const [cx0,cy0,cw,ch] of censor){ if(x>=cx0&&x<cx0+cw&&baseY>=cy0&&baseY<cy0+ch) gap=true; } }
      if(breakLeft>0){ breakLeft--; gap=true; }
      else { const inFig=h>300;
        let p0;
        if(t.tear<=2) p0=[3,12,26][t.tear]+(inFig?[3,10,16][t.tear]:0);
        else if(t.tear===3) p0=(xi<6||xi>27)?45:4;                          // RIPPED EDGE
        else if(t.tear===6) p0=Math.max(3,Math.trunc((92-baseY)*13/10));    // VAPOR
        else p0=t.tear===4?4:6;                                             // MOTH/SPLIT/CENSORED base
        if(rng.int(1000)<p0){ breakLeft=1+rng.int(5); gap=true; } }
      if(gap){ pen=false; continue; }
      const X=x*10;
      if(!pen){ d+='M'+X+' '+ypx; pen=true; }
      else { const dy=ypx-py; d+= dy===0 ? 'h'+(X-px) : 'l'+(X-px)+' '+dy; }
      px=X; py=ypx;
    }
    linesD.push({d,maxH,baseY,w:L.w});
  }
  const sw=Math.max(3,Math.min(6,lines[0].w)); // reference width for echoes/marks
  let defs='';
  let f='';
  // white specks, faint
  { let d=''; const n=12+rng.int(16); for(let i=0;i<n;i++){ const x=rng.int(100), y=rng.int(100); d+='M'+(x*U)+' '+(y*U)+'h'+U+'v'+U+'h-'+U+'z'; } f+='<path d="'+d+'" fill="'+WHITE+'"/>'; }
  // --- KILL-TIER COLOUR LADDER (handoff §9.3): the figure's own signal
  // changes colour as kills accumulate. acid → pink → white, role-shifted.
  const tier=tierForKills(sState.kills);
  const figLines=linesD.filter(L=>L.d&&L.maxH>800).sort((a,b)=>a.baseY-b.baseY);
  const isFig=new Set(figLines);
  const crestN = tier>=5?4 : tier>=4?2 : tier>=3?1 : 0;
  const crest=new Set(figLines.slice(0,crestN));
  const pinkFigAll = tier>=4, pinkFigUpper = tier===3, pinkCrest6 = tier===2;
  const crest6=new Set(figLines.slice(0,6));
  const whiteFig = tier>=6;
  const invert = t.pink===5; // INVERSION: the figure runs pink from genesis
  // echo passes: genesis PINK trait styles, plus forced echo of figure lines at tier>=6
  { const dx=(2+rng.int(3))*U, dy=(1+rng.int(2))*U;
    let e='', e2='';
    if(t.pink===1||t.pink===2||t.pink===3){
      const k=t.pink===3?8+rng.int(3):(t.pink===2?4+rng.int(3):2+rng.int(2));
      for(let i=0;i<k;i++){ const li=rng.int(lines.length); if(linesD[li].d) e+='<path d="'+linesD[li].d+'"/>'; } }
    else if(t.pink===4){ const k=3+rng.int(2); // WHITE ECHO
      for(let i=0;i<k;i++){ const li=rng.int(lines.length); if(linesD[li].d) e2+='<path d="'+linesD[li].d+'"/>'; } }
    else if(t.pink===6){ // TRICHROME: pink pass + white counter-pass
      let k=3+rng.int(2); for(let i=0;i<k;i++){ const li=rng.int(lines.length); if(linesD[li].d) e+='<path d="'+linesD[li].d+'"/>'; }
      k=2+rng.int(2); for(let i=0;i<k;i++){ const li=rng.int(lines.length); if(linesD[li].d) e2+='<path d="'+linesD[li].d+'"/>'; } }
    if(tier>=6) for(const L of figLines.slice(0,8)) e+='<path d="'+L.d+'"/>';
    if(e) f+='<g fill="none" stroke="'+PINK+'" stroke-width="'+sw+'" transform="translate('+dx+' '+dy+')">'+e+'</g>';
    if(e2) f+='<g fill="none" stroke="'+WHITE+'" stroke-width="'+sw+'" transform="translate('+(-dx)+' '+dy+')">'+e2+'</g>'; }
  // the signal field, grouped by (colour role, stroke width)
  { const groups={};
    for(const L of linesD){ if(!L.d) continue;
      let col='A';
      if(isFig.has(L)){
        if(invert) col='P';
        if(whiteFig) col='W';
        else if(pinkFigAll) col='P';
        else if(pinkFigUpper && L.baseY<t.cy) col='P';
        else if(pinkCrest6 && crest6.has(L)) col='P';
        if(!whiteFig && crest.has(L)) col='W';
      }
      const key=col+'|'+L.w;
      (groups[key]=groups[key]||[]).push(L.d);
    }
    for(const col of ['A','P','W']){
      for(let w=2;w<=7;w++){
        const g2=groups[col+'|'+w]; if(!g2) continue;
        const stroke = col==='A'?ACID : col==='P'?PINK : WHITE;
        const wOut = (col==='A'&&tier>=5) ? Math.max(2,w-1) : w;
        f+='<g fill="none" stroke="'+stroke+'" stroke-width="'+wOut+'">';
        for(const d of g2) f+='<path d="'+d+'"/>';
        f+='</g>';
      }
    } }
  // FLATLINE SCAR: one perfect white line cutting through everything
  if(flatLi>=0) f+='<path d="M0 '+(lines[flatLi].y*U)+'h1000" fill="none" stroke="'+WHITE+'" stroke-width="6"/>';
  // LIGHTNING: one jagged bolt across the field
  if(lightning){ let d='M0 '+((20+rng.int(60))*U); let ly=0;
    for(let x=8;x<=100;x+=8){ const ny=(10+rng.int(80)); d+='L'+(x*U)+' '+(ny*U); ly=ny; }
    f+='<path d="'+d+'" fill="none" stroke="'+PINK+'" stroke-width="6"/>'
     +'<path d="'+d+'" fill="none" stroke="'+WHITE+'" stroke-width="3"/>'; }
  // HEARTBEAT: a single pink pulse line — the signal refuses to die
  if(t.pink===7){ const hy=(20+rng.int(60))*U; const bx=(10+rng.int(60))*U;
    f+='<path d="M0 '+hy+'h'+bx+'l15 -70 15 140 15 -70h'+(1000-bx-45)+'" fill="none" stroke="'+PINK+'" stroke-width="6"/>'; }
  // --- THE EYES — the signature. Weighted archetypes + trait-driven treatments.
  const rB=t.eyeR;
  const eyePos=[[t.cx-(11+rng.int(4)),t.cy+t.sLdy,rB,0],[t.cx+(11+rng.int(4)),t.cy+t.sRdy,Math.max(5,rB+rng.int(4)-1),1]];
  const glyph=(st,side,cx,cy,r,fill)=>eyeGlyph(st,side,cx,cy,r,fill,rng);
  // screen-space eye centres (used by several treatments)
  const eyeScr=eyePos.map(([ex,ey2,r,side])=>{ const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100); return [ex,ey2-((disp/3)|0)+2,r,side]; });
  const drawEyes=(fill,ox,oy)=>{
    let e='';
    if(t.eyes===3){ // continuous visor: one blade across both sockets
      const [lx,ly,lr]=eyePos[0], [rx2,ry2,rr2]=eyePos[1];
      const dispL=Math.round(heightAt(t,noiseCols,lx,ly,true)/100);
      const vy=ly-((dispL/3)|0)+2;
      e+=poly(offsetPts([[lx-lr,vy+2],[rx2+rr2,vy],[rx2+rr2,vy+5],[lx-lr,vy+7]],ox,oy),fill);
      return e; }
    if(t.eyes===24){ // ALL SEEING: hollow sockets + the third eye above
      for(const [ex,cyp,r] of eyeScr) e+=octRing(ex+ox,cyp+oy,r-1,9,fill);
      const mx=((eyeScr[0][0]+eyeScr[1][0])/2)|0;
      const ty=Math.min(eyeScr[0][1],eyeScr[1][1])-t.eyeR-7;
      e+=xmark(mx+ox,ty+oy,t.eyeR+2,3,fill,rng);
      return e; }
    for(const [ex,ey2,r,side] of eyePos){
      const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100);
      e+=glyph(t.eyes,side,ex+ox,ey2-((disp/3)|0)+2+oy,r,fill);
    }
    return e;
  };
  // treatments (trait, escalated by kill tier: 10+ at least ECHO GLOW, 50+ FULL
  // SIGNAL — special treatments 5+ are never overridden by the ladder)
  { const base=t.treat; if(base<=4) t.treat = tier>=4 ? 4 : (tier>=2 ? Math.max(1,base) : base); }
  let mainFill=ACID;
  if(t.treat===1||t.treat===4){ f+=drawEyes(PINK,3,2); f+=drawEyes(ACID,-2,-2); }
  else if(t.treat===2||(t.mosh>0&&t.treat===0)) f+=drawEyes(PINK,2,2);
  if(t.treat===3||t.treat===4){ // ripple rings: the field reacting to the stare
    for(const [ex,ey2,r,side] of eyePos){
      if(t.eyes===6&&side) continue; if(t.eyes===7) continue;
      const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100); const cyp=ey2-((disp/3)|0)+2;
      for(let k=1;k<=(t.treat===4?1:2);k++){ const rr=r+3+k*4;
        const oct=[[ex-rr,cyp],[ex-(rr*7/10|0),cyp-(rr*7/10|0)],[ex,cyp-rr],[ex+(rr*7/10|0),cyp-(rr*7/10|0)],[ex+rr,cyp],[ex+(rr*7/10|0),cyp+(rr*7/10|0)],[ex,cyp+rr],[ex-(rr*7/10|0),cyp+(rr*7/10|0)]];
        f+='<path d="'+pathD(oct)+'" fill="none" stroke="'+(k===1?ACID:PINK)+'" stroke-width="5"/>'; } } }
  else if(t.treat===5){ // STATIC: white interference specks around the stare
    const n=10+rng.int(6); const x0=eyeScr[0][0]-10, x1=eyeScr[1][0]+10;
    let d=''; for(let i=0;i<n;i++){ const x=x0+rng.int(Math.max(4,x1-x0)); const y=Math.min(eyeScr[0][1],eyeScr[1][1])-8+rng.int(16); d+='M'+(x*U)+' '+(y*U)+'h'+U+'v'+U+'h-'+U+'z'; }
    f+='<path d="'+d+'" fill="'+WHITE+'"/>'; }
  else if(t.treat===6){ // CROSS FLARE: rays off each eye
    for(const [ex,cyp,r] of eyeScr){
      f+=rect(ex-1,cyp-r-8,2,6,ACID)+rect(ex-1,cyp+r+2,2,6,ACID)+rect(ex-r-8,cyp-1,6,2,ACID)+rect(ex+r+2,cyp-1,6,2,ACID);
      f+=rect(ex-1,cyp-r-10,2,2,PINK)+rect(ex-1,cyp+r+8,2,2,PINK); } }
  else if(t.treat===7){ for(const [ex,cyp,r] of eyeScr) f+=octRing(ex,cyp,r+5,5,WHITE); } // HALO EYES
  else if(t.treat===8){ f+=drawEyes(PINK,8,0); f+=drawEyes(WHITE,4,0); } // SMEAR TRAIL
  else if(t.treat===9){ // INVERTED: knockout — black glyphs on solid acid patches
    for(const [ex,cyp,r] of eyeScr) f+=rect(ex-r-3,cyp-r+1,2*r+6,2*r-1,ACID);
    mainFill=BLACK; }
  else if(t.treat===10){ f+=drawEyes(PINK,4,3); f+=drawEyes(WHITE,-4,-3); } // PRISM
  else if(t.treat===11){ // GOD RAYS: the stare reaches the edge of the signal
    for(const [ex,cyp] of eyeScr){
      f+='<path d="M'+(ex*U)+' '+(cyp*U)+'L0 0M'+(ex*U)+' '+(cyp*U)+'L1000 0M'+(ex*U)+' '+(cyp*U)+'L'+(ex>50?1000:0)+' '+(cyp*U-300)+'" fill="none" stroke="'+ACID+'" stroke-width="4"/>'; } }
  f+=drawEyes(mainFill,0,0);
  // hunter marks: kill notches above the left eye (1 per kill, capped at 9)
  if(sState.kills>0){ const n=Math.min(9,sState.kills); const [lx,ly]=eyePos[0];
    const disp=Math.round(heightAt(t,noiseCols,lx,ly,true)/100); const ny2=ly-((disp/3)|0)-t.eyeR-5;
    for(let i=0;i<n;i++) f+=rect(lx-t.eyeR+i*3,ny2,2,3,PINK); }
  // forced-purge tallies: white ticks along the hem
  if(sState.forcedPurges>0){ const n=Math.min(10,sState.forcedPurges);
    for(let i=0;i<n;i++) f+=rect(8+i*4,95,2,3,WHITE); }
  // survival stitches: pink x per purged warrant survived (max 5), low left
  if(sState.savesReceived>0){ const n=Math.min(5,sState.savesReceived);
    for(let i=0;i<n;i++) f+=xmark(8+i*6,88,2,1,PINK,rng); }
  // death damage: permanent scar bands + exposed bone lines (survives exhumation)
  if(sState.deaths>0){ const drng=new Rng(damageSeed(s.genesisHash,s.tokenId,sState.deaths));
    for(let k2=0;k2<sState.deaths;k2++){
      const sy2=t.cy-14+drng.int(26);
      f+='<path d="M'+((t.cx-t.rw+2)*U)+' '+(sy2*U)+'l'+((t.rw-4+drng.int(8))*U)+' '+((drng.int(5)-2)*U)+'" stroke="'+WHITE+'" stroke-width="4" fill="none"/>';
    } }
  // mouth details on the gap
  if(t.mouth>0){
    const dispM=Math.round(heightAt(t,noiseCols,t.cx,mouthY,true)/100);
    const my=mouthY-((dispM/3)|0)+2; // displaced mouth baseline (units)
    switch(t.mouth){
      case 1: if(t.pink>0) f+=rect(t.cx-mw+2,my+1,mw,1,PINK); break; // GASH
      case 2: for(let x=t.cx-mw+2;x<t.cx+mw-1;x+=4){ const disp=Math.round(heightAt(t,noiseCols,x,mouthY,true)/100); f+=rect(x,mouthY-((disp/3)|0)+2,2,5,ACID); } break; // GRIN
      case 3: for(let i=-1;i<=1;i++){ const x=t.cx+i*6; const disp=Math.round(heightAt(t,noiseCols,x,mouthY,true)/100); f+=xmark(x,mouthY-((disp/3)|0)+3,2,1,ACID,rng); } break; // SEWN
      case 4: f+=rect(t.cx-mw+2,my+1,2*mw-4,1,WHITE); break; // WIRE
      case 5: for(let x=t.cx-mw+2,i=0;x<t.cx+mw-1;x+=4,i++){ if(i%2===0) f+=rect(x,my,2,5,ACID); else f+=xmark(x+1,my+2,2,1,PINK,rng); } break; // STITCHED GRIN
      case 6: f+=rect(t.cx-mw+2,my,2*mw-4,2,ACID)+rect(t.cx-mw+3,my+3,2*mw-6,2,PINK); break; // DOUBLE GASH
      case 7: f+=rect(t.cx,my+1,mw,2,ACID)+rect(t.cx+mw-2,my-2,2,3,ACID); break; // SIDE SMIRK
      case 8: { f+=rect(t.cx-mw+2,my+1,2*mw-4,1,WHITE); for(let x=t.cx-mw+3;x<t.cx+mw-2;x+=3) f+=rect(x,my-1,1,5,WHITE); break; } // ZIPPER
      case 9: f+=poly(offsetPts([[-mw+2,3],[mw-2,-2],[mw-2,0],[-mw+2,5]],t.cx,my),ACID); break; // SNARL
      case 10: f+=rect(t.cx-mw+2,my,2*mw-4,2,ACID)+drip(t.cx-2,my+2,6+rng.int(4),1,PINK,rng)+drip(t.cx+4,my+2,4+rng.int(3),1,PINK,rng); break; // DRIP
      case 11: for(let x=t.cx-mw+2;x<t.cx+mw-1;x+=3){ const hh=5+rng.int(5); f+=rect(x,my,2,hh,ACID); } break; // SCREAM
      case 12: { f+=rect(t.cx-mw+2,my,2*mw-4,2,ACID); f+=poly(offsetPts([[-4,2],[-1,2],[-2,7]],t.cx,my),WHITE)+poly(offsetPts([[2,2],[5,2],[4,7]],t.cx,my),WHITE); break; } // FANGS
      case 13: f+=octRing(t.cx,my+3,5,4,ACID); break; // HOWL
      case 14: f+=rect(t.cx-mw,my-2,2*mw,7,BLACK)+'<rect x="'+((t.cx-mw)*U)+'" y="'+((my-2)*U)+'" width="'+(2*mw*U)+'" height="70" fill="none" stroke="'+ACID+'" stroke-width="5"/>'+rect(t.cx-4,my-1,1,5,ACID)+rect(t.cx,my-1,1,5,ACID)+rect(t.cx+4,my-1,1,5,ACID); break; // MUZZLE
      case 15: f+=rect(t.cx-mw+1,my-1,mw+3,2,ACID)+rect(t.cx-mw+4,my+2,mw+3,2,PINK)+rect(t.cx-mw-1,my+5,mw+3,2,WHITE); break; // GLITCH MOUTH
    }
  }
  // ward sigil above the crown; block mark at the hem
  f+=sigilSVG(s.wardId,8,8,rng,ACID);
  f+=blockMarkSVG(s.blockId,90,93,rng,ACID);
  // mosh: slice shifts
  // --- KILL-TIER HALO: a corona over the crest, one signature per tier ---
  // T1 single arc · T2 double · T3 triple broken · T4 arc + ticks · T5 corona rays · T6 full ring
  if(tier>0){
    // crest profile: topmost visual point of the figure per column (px)
    const crest=[];
    for(let xi=0;xi<=33;xi++){ const x=xi*STEP; let best=100000;
      for(let li=0;li<47;li++){ const baseY=4+li*2; const h=heightAt(t,noiseCols,x,baseY);
        if(h>300){ const vy=baseY*10-Math.round(h/10); if(vy<best) best=vy; } }
      crest.push(best===100000?-1:best); }
    const gcol = tier>=4 ? WHITE : PINK;
    const arcPath=(off)=>{ let d='',pen=false;
      for(let xi=0;xi<=33;xi++){ const c=crest[xi];
        if(c<0){ pen=false; continue; }
        const X=xi*STEP*10, Y=c-off*10;
        if(Y<20){ pen=false; continue; }
        if(!pen){ d+='M'+X+' '+Y; pen=true; } else d+='L'+X+' '+Y; }
      return d; };
    const nArcs = tier===1?1 : tier===2?2 : tier===3?3 : tier>=5?2 : 1;
    for(let k=0;k<nArcs;k++){
      let d=arcPath(5+k*3);
      if(tier===3&&k===2){ // outermost arc broken: re-emit with gaps
        d=''; let pen=false; for(let xi=0;xi<=33;xi++){ const c=crest[xi];
          if(c<0||xi%5===0){ pen=false; continue; } const X=xi*STEP*10, Y=c-110;
          if(Y<20){ pen=false; continue; }
          if(!pen){ d+='M'+X+' '+Y; pen=true; } else d+='L'+X+' '+Y; } }
      if(d) f+='<path d="'+d+'" fill="none" stroke="'+gcol+'" stroke-width="'+(tier>=4?5:4)+'"/>';
    }
    if(tier>=4){ // radiating ticks along the arc
      for(let xi=1;xi<33;xi+=3){ const c=crest[xi]; if(c<0) continue; const X=xi*STEP*10, Y=c-50;
        if(Y>60) f+='<path d="M'+X+' '+(Y-10)+'V'+Math.max(20,Y-10-(tier>=5?50:30))+'" stroke="'+gcol+'" stroke-width="4" fill="none"/>'; } }
    if(tier>=5){ // corona rays: triangles between the ticks
      for(let xi=2;xi<33;xi+=4){ const c=crest[xi]; if(c<0) continue; const X=xi*STEP, Y=Math.round(c/10)-9;
        if(Y>7) f+=poly([[X-1,Y],[X+1,Y],[X,Math.max(3,Y-4)]],PINK); } }
    if(tier>=6){ // REAPER: the complete ring, white with a pink echo
      const rcx=t.cx*10, rcy=(t.cy-2)*10;
      const rx=Math.min((t.rw+16)*10,rcx-20,1000-rcx-20), ry=Math.min((t.rh+((t.amp/2)|0)+12)*10,rcy-20);
      f+='<ellipse cx="'+(rcx+8)+'" cy="'+(rcy+6)+'" rx="'+rx+'" ry="'+ry+'" fill="none" stroke="'+PINK+'" stroke-width="4"/>';
      f+='<ellipse cx="'+rcx+'" cy="'+rcy+'" rx="'+rx+'" ry="'+ry+'" fill="none" stroke="'+WHITE+'" stroke-width="5"/>';
    }
  }
  const slices=[];
  if(t.mosh===1||t.mosh===2){ const n=t.mosh===2?4+rng.int(2):2+rng.int(2);
    for(let i=0;i<n;i++) slices.push({y:6+rng.int(84),h:2+rng.int(5),dx:(2+rng.int(7))*(rng.int(2)?1:-1)}); }
  else if(t.mosh===3){ slices.push({y:6+rng.int(70),h:8+rng.int(5),dx:(12+rng.int(7))*(rng.int(2)?1:-1)}); } // TEARDROP
  else if(t.mosh===4){ const n=8+rng.int(3); // CORRUPTED
    for(let i=0;i<n;i++) slices.push({y:4+rng.int(88),h:2+rng.int(3),dx:(3+rng.int(7))*(rng.int(2)?1:-1)}); }
  else if(t.mosh===5){ const d5=6+rng.int(4); const sgn=rng.int(2)?1:-1; // SPLIT
    slices.push({y:4,h:46,dx:d5*sgn}); slices.push({y:50,h:46,dx:-d5*sgn}); }
  else if(t.mosh===6){ // MELTDOWN: one smear band + corruption
    slices.push({y:30+rng.int(40),h:6+rng.int(5),smear:1});
    for(let i=0;i<3;i++) slices.push({y:6+rng.int(84),h:2+rng.int(4),dx:(4+rng.int(7))*(rng.int(2)?1:-1)}); }
  if(sState.deaths>0){ const drng=new Rng(damageSeed(s.genesisHash,s.tokenId,sState.deaths));
    for(let k2=0;k2<sState.deaths;k2++) slices.push({y:t.cy-16+drng.int(30),h:3+drng.int(4),dx:(5+drng.int(8))*(drng.int(2)?1:-1)});
  }
  // screen-space eye anchors (units) for status overlays
  const eyeScreen=eyePos.map(([ex,ey2,r])=>{ const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100); return [ex,ey2-((disp/3)|0)+2,r]; });
  return {defs,figure:f,traits:t,slices,rng,eyeScreen};
}
function traitNames(s){ const t=drawTraits(new Rng(genesisSeed(s.genesisHash,s.tokenId))); return {form:FORM_NAMES[t.form],lines:LINE_NAMES[t.lineW],tear:TEAR_NAMES[t.tear],spikes:SPIKE_NAMES[t.spike],eyes:EYE_NAMES[t.eyes],treatment:TREAT_NAMES[t.treat],mouth:MOUTH_NAMES[t.mouth],pink:PINKAMT_NAMES[t.pink],mosh:MOSH_NAMES[t.mosh],sigil:WARD_NAMES[s.wardId]}; }
// ---------------------------------------------------------------------------
// COFFIN COMPOSITIONS (lifeState COFFINED / TERMINAL_COFFIN).
// The signal flatlines. The field goes still and undisturbed; the wraith is
// gone — only a coffin-shaped void remains where the signal refuses to run.
// COFFINED keeps a residual heartbeat blip and pink ember eyes (revivable).
// TERMINAL is the only other legal use of red: flat red line, red planks,
// three red broken seals. Identity persists: sigil, block mark, eye archetype.
// ---------------------------------------------------------------------------
const COFFIN_PTS=[[43,28],[57,28],[64,42],[58,82],[42,82],[36,42]];
function inCoffin(x,y,pad){
  // convex test against the hexagon expanded by `pad` units from its centroid
  const cx=50,cy=54;
  for(let i=0;i<6;i++){
    const a=COFFIN_PTS[i], b=COFFIN_PTS[(i+1)%6];
    const ax=a[0]+Math.sign(a[0]-cx)*pad, ay=a[1]+Math.sign(a[1]-cy)*pad;
    const bx=b[0]+Math.sign(b[0]-cx)*pad, by=b[1]+Math.sign(b[1]-cy)*pad;
    if((bx-ax)*(y-ay)-(by-ay)*(x-ax)<0) return false;
  }
  return true;
}
function buildCoffinSVG(s){
  const terminal=s.lifeState===3;
  const rng=new Rng(genesisSeed(s.genesisHash,s.tokenId));
  const t=drawTraits(rng);
  const C=terminal?RED:WHITE;
  let f='';
  // the still field: flat lines, torn, silent around the void
  const sw=t.lineW<=2?[3,4,6][t.lineW]:4;
  for(let li=0;li<47;li++){
    const y=4+li*2; let d='',pen=false,px=0,breakLeft=0;
    for(let xi=0;xi<=33;xi++){
      const x=xi*3; let gap=false;
      if(inCoffin(x,y,2)) gap=true;
      if(breakLeft>0){ breakLeft--; gap=true; }
      else if(rng.int(1000)<(terminal?60:22)){ breakLeft=1+rng.int(5); gap=true; }
      if(gap){ pen=false; continue; }
      const X=x*U;
      if(!pen){ d+='M'+X+' '+(y*U); pen=true; } else d+='h'+(X-px);
      px=X;
    }
    if(d) f+='<path d="'+d+'" fill="none" stroke="'+ACID+'" stroke-width="'+sw+'"/>';
  }
  // white specks
  { let d=''; const n=8+rng.int(10); for(let i=0;i<n;i++){ const x=rng.int(100), y=rng.int(100); d+='M'+(x*U)+' '+(y*U)+'h'+U+'v'+U+'h-'+U+'z'; } f+='<path d="'+d+'" fill="'+WHITE+'"/>'; }
  // the coffin void outline (structure stays white; red is reserved for the verdict)
  f+='<path d="'+pathD(jitterPts(COFFIN_PTS,rng,1))+'" fill="none" stroke="'+WHITE+'" stroke-width="6"/>';
  // nail ticks at the vertices
  for(const [vx,vy] of COFFIN_PTS) f+=rect(vx-1,vy-1,2,2,WHITE);
  // eyes: the archetype survives the grave
  if(!terminal){
    f+=eyeGlyph(t.eyes,0,46,42,4,PINK,rng);
    f+=eyeGlyph(t.eyes,1,54,42,4,PINK,rng);
  }
  // seal pips inside the coffin
  for(let i=0;i<3;i++){ const x=43+i*5, y=72;
    if(i<s.sealsRemaining) f+=rect(x,y,3,3,ACID);
    else { f+='<path d="M'+(x*U)+' '+(y*U)+'h30v30h-30z" fill="none" stroke="'+(terminal?RED:PINK)+'" stroke-width="3"/>'+xmark(x+1,y+1,2,1,terminal?RED:PINK,rng); }
  }
  // terminal: nailed shut — two clean red planks across the void
  if(terminal){
    f+=poly([[40,33],[44,32],[60,79],[56,80]],RED);
    f+=poly([[56,32],[60,33],[44,80],[40,79]],RED);
  }
  // the line itself: flat red for terminal; white with one residual blip while seals remain
  if(terminal) f+='<path d="M0 540h1000" fill="none" stroke="'+RED+'" stroke-width="5"/>';
  else f+='<path d="M0 540h140l15 -70 15 140 15 -70h815" fill="none" stroke="'+WHITE+'" stroke-width="5"/>';
  // identity marks
  f+=sigilSVG(s.wardId,8,8,rng,ACID);
  f+=blockMarkSVG(s.blockId,90,93,rng,ACID);
  // death scars displace the stillness too
  const slices=[];
  { const drng=new Rng(damageSeed(s.genesisHash,s.tokenId,s.deaths||1));
    for(let k=0;k<Math.max(1,s.deaths);k++) slices.push({y:20+drng.int(56),h:2+drng.int(4),dx:(4+drng.int(7))*(drng.int(2)?1:-1)}); }
  let defs='<g id="f">'+f+'</g>', body='<rect width="1000" height="1000" fill="'+BLACK+'"/><use href="#f"/>';
  let ci=0; for(const sl of slices){ ++ci; body+=slice('f',ci,sl.y,sl.h,sl.dx,BLACK); }
  body+=flickerSVG(s);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"><defs>'+defs+'</defs>'+body+'</svg>';
}
// ---------------------------------------------------------------------------
// STATUS OVERLAYS + HUD (z7+). Precedence handled in renderSVG; overlays sit
// above mosh slices so danger/protection stays legible even when the figure
// glitches. Red appears ONLY in the MARKED overlay (and TERMINAL/diagnostic).
// ---------------------------------------------------------------------------
function markedOverlay(g,rng){
  const t=g.traits; let o='';
  // corner brackets
  const L=9;
  o+='<path d="M30 '+((3+L)*U)+'V30H'+((3+L)*U)+'M'+(1000-30-L*U)+' 30H970V'+((3+L)*U)+'M970 '+(1000-30-L*U)+'V970H'+(1000-30-L*U)+'M'+((3+L)*U)+' 970H30V'+(1000-30-L*U)+'" fill="none" stroke="'+RED+'" stroke-width="14"/>';
  // the warrant lock: red scope ring + full-bleed hairlines + chevrons closing in
  { const cx=t.cx, cy=t.cy-2, R=t.rh+12;
    o+=octRing(cx,cy,R,10,RED);
    o+='<path d="M0 '+(cy*U)+'H'+((cx-R)*U)+'M'+((cx+R)*U)+' '+(cy*U)+'H1000M'+(cx*U)+' 0V'+(Math.max(0,cy-R)*U)+'M'+(cx*U)+' '+((cy+R)*U)+'V1000" stroke="'+RED+'" stroke-width="6" fill="none"/>';
    o+=poly([[cx-5,cy-R+3],[cx+5,cy-R+3],[cx,cy-R+11]],RED);
    o+=poly([[cx-5,cy+R-3],[cx+5,cy+R-3],[cx,cy+R-11]],RED);
    o+=poly([[cx-R+3,cy-5],[cx-R+3,cy+5],[cx-R+11,cy]],RED);
    o+=poly([[cx+R-3,cy-5],[cx+R-3,cy+5],[cx+R-11,cy]],RED); }
  // warrant strip: purge countdown ticks along the crown edge
  for(let i=0;i<8;i++) o+=rect(33+i*4,2,2,3,RED);
  return o;
}
function witsecOverlay(g,rng){
  // witness protection: the eyes are redacted
  const [[lx,ly,lr],[rx2,ry2,rr2]]=g.eyeScreen; let o='';
  const y=Math.min(ly,ry2)-5, x0=lx-lr-4, x1=rx2+rr2+4;
  o+=rect(x0,y,x1-x0,9,WHITE);
  o+=rect(x0+3,y+11,((x1-x0)>>1),3,WHITE);
  o+=rect(x0+((x1-x0)>>1)+6,y+11,((x1-x0)>>2),3,WHITE);
  return o;
}
function layLowOverlay(g,rng){
  // gone dark: blinds close over the figure
  const t=g.traits; let o='';
  const x0=t.cx-t.rw-9, w=2*t.rw+18;
  for(let y=t.cy-t.rh-4;y<t.cy+24;y+=7) o+=rect(x0,y,w,3,BLACK);
  o+=poly([[t.cx-4,t.cy-t.rh-9],[t.cx+4,t.cy-t.rh-9],[t.cx,t.cy-t.rh-5]],ACID);
  return o;
}
function buyerOverlay(g,rng){
  // in escrow: an acid holding frame
  let o='<rect x="60" y="60" width="880" height="880" fill="none" stroke="'+ACID+'" stroke-width="5"/>';
  o+=poly([[50,2],[53,5],[50,8],[47,5]],ACID);
  return o;
}
function hunterOverlay(g,rng){
  // volunteered hunter: quiet white sight ticks
  const t=g.traits; const hx=t.cx, hy=t.cy-4, rr=t.rw+12; let o='';
  o+='<path d="M'+(hx*U)+' '+((hy-rr-4)*U)+'v'+(4*U)+'M'+(hx*U)+' '+((hy+rr)*U)+'v'+(4*U)+'M'+((hx-rr-4)*U)+' '+(hy*U)+'h'+(4*U)+'M'+((hx+rr)*U)+' '+(hy*U)+'h'+(4*U)+'" stroke="'+WHITE+'" stroke-width="4" fill="none"/>';
  return o;
}
// seals HUD: three pips top-right — acid intact, pink broken
function sealHud(s,rng){
  let o='';
  for(let i=0;i<3;i++){ const x=85+i*4, y=5;
    if(i<s.sealsRemaining) o+=rect(x,y,3,3,ACID);
    else o+='<path d="M'+(x*U)+' '+(y*U)+'h30v30h-30z" fill="none" stroke="'+PINK+'" stroke-width="3"/>'+'<path d="M'+(x*U)+' '+((y+3)*U)+'l30 -30" stroke="'+PINK+'" stroke-width="3" fill="none"/>';
  }
  return o;
}
// latest season badges: SLOT B (top 10, white) + SLOT C (top 5, pink)
function seasonChips(s,used){
  let o=''; if(!(s.latestSeasonBadgeFlags&1)) return o;
  o+=text('S'+s.latestAwardSeasonId,62,632,4,ACID,used);
  o+='<rect x="60" y="672" width="104" height="60" fill="none" stroke="'+WHITE+'" stroke-width="4"/>'+text('10',76,682,6,WHITE,used);
  if(s.latestSeasonBadgeFlags&2) o+='<rect x="60" y="744" width="104" height="60" fill="none" stroke="'+PINK+'" stroke-width="4"/>'+text('5',94,754,6,PINK,used);
  return o;
}
// territory achievements: acid tick ladder up the right edge (cap 12)
function territoryHud(s){
  let o=''; const n=Math.min(12,s.territoryAchievementCount);
  for(let i=0;i<n;i++) o+=rect(95,84-i*3,3,2,ACID);
  return o;
}
// STATS display mode: a data band across the hem
function statsBand(s,used){
  const tier=tierForKills(s.kills);
  let o='<rect x="0" y="880" width="1000" height="120" fill="'+BLACK+'"/><path d="M0 880h1000" stroke="'+ACID+'" stroke-width="3"/>';
  const l1='K '+s.kills+' / D '+s.deaths+' / KD '+kdText(s)+' / STK '+s.currentKillStreak;
  let l2=TIER_NAMES[tier]+' / W'+s.wardId+' B'+s.blockId+(s.latestSeasonRank?' / S'+s.latestAwardSeasonId+' RANK '+s.latestSeasonRank:'');
  o+=text(l1,24,896,5,ACID,used);
  o+=text(l2,24,946,5,WHITE,used);
  return o;
}
// flicker: SMIL scanline sweep + a pink echo tracer (deterministic, loops)
function flickerSVG(s){
  if(!s.flicker) return '';
  return '<rect x="0" y="-8" width="1000" height="6" fill="'+WHITE+'"><animate attributeName="y" values="-8;1000;-8" dur="7s" repeatCount="indefinite"/></rect>'
       + '<rect x="0" y="-4" width="1000" height="3" fill="'+PINK+'"><animate attributeName="y" values="1000;-4;1000" dur="11s" repeatCount="indefinite"/></rect>';
}
// ---------------------------------------------------------------------------
// renderSVG — composition per STATE_TO_LAYER_MAP z-order
// ---------------------------------------------------------------------------
function renderSVG(s){
  const errs=validate(s); if(errs.length) return diagnosticSVG(s,errs);
  const status=resolveStatus(s);
  if(status==='TERMINAL'||status==='COFFINED') return buildCoffinSVG(s);
  const g=buildGenesis(s);
  const used=new Set();
  let defs=g.defs, body='';
  // z0 ground
  body+='<rect width="1000" height="1000" fill="'+BLACK+'"/>';
  // figure group (z1–z6)
  defs+='<g id="f">'+g.figure+'</g>';
  body+='<use href="#f"/>';
  let ci=0; for(const sl of g.slices){ ++ci;
    if(sl.move) body+='<clipPath id="c'+ci+'"><rect x="'+(sl.x*U)+'" y="'+(sl.y*U)+'" width="'+(sl.w*U)+'" height="'+(sl.h*U)+'"/></clipPath><g clip-path="url(#c'+ci+')"><use href="#f" transform="translate('+(sl.dx*U)+' '+(sl.dy*U)+')"/></g>';
    else if(sl.smear) body+='<clipPath id="c'+ci+'"><rect x="0" y="'+(sl.y*U)+'" width="1000" height="'+(sl.h*U)+'"/></clipPath><g clip-path="url(#c'+ci+')"><rect width="1000" height="1000" fill="'+BLACK+'"/><use href="#f" transform="translate(-500 0) scale(2 1)"/></g>';
    else body+=slice('f',ci,sl.y,sl.h,sl.dx,BLACK); }
  // z7: status overlays, precedence MARKED > WITSEC/LAY_LOW/BUYER > HUNTER
  if(status==='MARKED') body+=markedOverlay(g,g.rng);
  else if(status==='WITSEC') body+=witsecOverlay(g,g.rng);
  else if(status==='LAY_LOW') body+=layLowOverlay(g,g.rng);
  else if(status==='BUYER_PROTECTED') body+=buyerOverlay(g,g.rng);
  else if(status==='HUNTER_SELECTED') body+=hunterOverlay(g,g.rng);
  // z8: persistent HUD — seals, latest season badges, territory ladder
  body+=sealHud(s,g.rng);
  body+=seasonChips(s,used);
  body+=territoryHud(s);
  // z9: STATS display mode band
  if(s.displayMode===1) body+=statsBand(s,used);
  // z10: flicker
  body+=flickerSVG(s);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"><defs>'+defs+glyphDefs(used)+'</defs>'+body+'</svg>';
}
// ---------------------------------------------------------------------------
// renderBanner — 3000×1000 X-banner. The token's own render (any state) sits
// at the left; its signal field continues across the full width; the name and
// campaign line run in block glyphs. Nested <svg> keeps ids self-contained.
// ---------------------------------------------------------------------------
function renderBanner(s){
  const errs=validate(s);
  const inner=renderSVG(s);
  const used=new Set();
  const rng=new Rng(concatBytes(genesisSeed(s.genesisHash,s.tokenId),strBytes('BNR')));
  const t=drawTraits(new Rng(genesisSeed(s.genesisHash,s.tokenId)));
  const sw=t.lineW<=2?[3,4,6][t.lineW]:4;
  let body='<rect width="3000" height="1000" fill="'+BLACK+'"/>';
  // the signal continues past the portrait
  for(let li=0;li<47;li++){
    const y=(4+li*2)*U; let d='',pen=false,px=1000,breakLeft=0;
    for(let xi=0;xi<=66;xi++){
      const X=1000+xi*30; let gap=false;
      if(breakLeft>0){ breakLeft--; gap=true; }
      else if(rng.int(1000)<30){ breakLeft=1+rng.int(5); gap=true; }
      // clear a window for the wordmark and campaign lines
      if(y>290&&y<660&&X>1180&&X<2720) gap=true;
      if(gap){ pen=false; continue; }
      if(!pen){ d+='M'+X+' '+y; pen=true; } else d+='h'+(X-px);
      px=X;
    }
    if(d) body+='<path d="'+d+'" fill="none" stroke="'+ACID+'" stroke-width="'+sw+'"/>';
  }
  // white specks on the wide field
  { let d=''; const n=16+rng.int(12); for(let i=0;i<n;i++){ const x=1000+rng.int(2000), y=rng.int(1000); d+='M'+x+' '+y+'h10v10h-10z'; } body+='<path d="'+d+'" fill="'+WHITE+'"/>'; }
  // wordmark + campaign line
  const tier=tierForKills(s.kills), status=resolveStatus(s);
  body+=text('HOODRXCH',1220,330,15,ACID,used);
  const sub=errs.length?'INVALID STATE':'#'+s.tokenId+' / WARD 0'+s.wardId+' / BLOCK 0'+s.blockId+(tier>0?' / '+TIER_NAMES[tier]:'');
  body+=text(sub,1224,510,6,errs.length?RED:WHITE,used);
  if(!errs.length&&status!=='ALIVE') body+=text(status.replace(/_/g,' '),1224,580,6,(status==='MARKED'||status==='TERMINAL')?RED:PINK,used);
  // right block: seals + kill tally, banner-scaled
  for(let i=0;i<3;i++){ const x=2800+i*50, y=60;
    if(i<s.sealsRemaining) body+='<rect x="'+x+'" y="'+y+'" width="34" height="34" fill="'+ACID+'"/>';
    else body+='<rect x="'+x+'" y="'+y+'" width="34" height="34" fill="none" stroke="'+PINK+'" stroke-width="4"/><path d="M'+x+' '+(y+34)+'l34 -34" stroke="'+PINK+'" stroke-width="4" fill="none"/>';
  }
  if(s.kills>0){ const n=Math.min(20,s.kills);
    for(let i=0;i<n;i++) body+='<rect x="'+(2800+(i%10)*14)+'" y="'+(130+((i/10)|0)*30)+'" width="8" height="20" fill="'+PINK+'"/>'; }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3000 1000"><defs>'+glyphDefs(used)+'</defs>'+body
    +'<svg x="0" y="0" width="1000" height="1000" viewBox="0 0 1000 1000">'+inner.replace(/^<svg[^>]*>/,'').replace(/<\/svg>$/,'')+'</svg>'
    +'<path d="M1000 0v1000" stroke="'+ACID+'" stroke-width="3"/></svg>';
}
function kdText(s){ if(s.deaths===0) return s.kills===0?'UNTESTED':'UNDEFEATED'; return (Math.floor(s.kills*10/s.deaths)/10).toFixed(1); }
function renderMetadata(s){
  const svg=renderSVG(s); const tier=tierForKills(s.kills);
  const a=(t,v)=>({trait_type:t,value:v});
  const attrs=[a('Token ID',s.tokenId),a('Ward','WARD 0'+s.wardId),a('Block','BLOCK 0'+s.blockId),a('Art Index',s.artIndex),
    a('Life State',LIFE[s.lifeState]),a('Exposure State',EXPO[s.exposureState]),a('Seals Remaining',s.sealsRemaining),
    a('Kills',s.kills),a('Deaths',s.deaths),a('K/D',kdText(s)),a('Forced Purges',s.forcedPurges),a('Saves Given',s.savesGiven),a('Saves Received',s.savesReceived),
    a('Current Kill Streak',s.currentKillStreak),a('Longest Kill Streak',s.longestKillStreak),a('Terminal Kills',s.terminalKills),
    a('Lifetime Kill Tier',TIER_NAMES[tier]),a('Latest Season',s.latestAwardSeasonId),a('Latest Season Rank',s.latestSeasonRank),
    a('Season Top 10',(s.latestSeasonBadgeFlags&1)?'YES':'NO'),a('Season Top 5',(s.latestSeasonBadgeFlags&2)?'YES':'NO'),a('Season Award Count',s.seasonAwardCount),
    a('Territory Achievements',s.territoryAchievementCount),a('Current War',s.warId),a('Current Campaign',s.campaignId),a('Current Season',s.seasonId),a('War Phase',PHASES[s.warPhase]||String(s.warPhase)),
    a('WITSEC Credits',s.witsecCredits),a('WITSEC Applies',s.witsecApplies?'YES':'NO'),a('Lay Low',s.laidLow?'YES':'NO'),a('Buyer Protected',s.buyerProtected?'YES':'NO'),a('Hunter Selected',s.hunterSelected?'YES':'NO'),
    a('Marked By Token ID',s.markedByTokenId),a('Purge Deadline',s.purgeDeadline),a('Transfer Locked',s.transferLocked?'YES':'NO'),a('Transfer Lock Expiry',s.transferLockUntil),
    a('Historical State Count',s.historicalStateCount),a('Display Mode',s.displayMode?'STATS':'PLAIN'),a('Canonical Game State',LIFE[s.lifeState]),
    a('Renderer Version',RENDERER_VERSION),a('Render-State Schema Version',SCHEMA_VERSION),a('State Hash',stateHash(s))];
  const tn=traitNames(s); for(const k in tn) attrs.push(a('Genesis '+k[0].toUpperCase()+k.slice(1),tn[k]));
  return JSON.stringify({name:'HOODRXCH #'+s.tokenId,description:'A persistent onchain HOODRXCH mask. Fully generative, fully onchain.',image:'data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(svg))),attributes:attrs});
}
