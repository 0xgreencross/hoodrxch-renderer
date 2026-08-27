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
  const noiseCols=[]; { let n=0; for(let c=0;c<=50;c++){ n+=(rng.int(3)-1)*12; if(n>150)n=150; if(n<-150)n=-150; noiseCols.push(n); } }
  // spike map: line index -> [xIndex, amplitude px]
  const spikes={}; { const nS=[0,1+rng.int(2),3+rng.int(3)][t.spike];
    for(let i=0;i<nS;i++){ const li=rng.int(47); (spikes[li]=spikes[li]||[]).push([rng.int(34),(25+rng.int(25))*(rng.int(3)?1:-1)]); } }
  const mw=9+rng.int(5), mouthY=t.cy+13+rng.int(3);
  const STEP=3;
  // build every line path (displaced, torn, spiked)
  const linesD=[];
  for(let li=0;li<47;li++){
    const baseY=4+li*2; let d=''; let pen=false; let px=0,py=0; let breakLeft=0; let maxH=0;
    for(let xi=0;xi<=33;xi++){
      const x=xi*STEP;
      const h=heightAt(t,noiseCols,x,baseY);
      if(h>maxH) maxH=h;
      let ypx=baseY*10-Math.round(h/10);
      if(spikes[li]) for(const [sx,amp] of spikes[li]) if(sx===xi) ypx+=amp;
      // gaps: eye sockets, mouth, tears
      let gap=false;
      { const yv=baseY-Math.round(heightAt(t,noiseCols,x,baseY,true)/100); if(inSocket(t,x,yv,0)||inSocket(t,x,yv,1)) gap=true; }
      if(t.mouth>0 && baseY>=mouthY-1 && baseY<=mouthY+4 && Math.abs(x-t.cx)<mw) gap=true;
      if(breakLeft>0){ breakLeft--; gap=true; }
      else { const inFig=h>300; const p0=[3,12,26][t.tear]+(inFig?[3,10,16][t.tear]:0);
        if(rng.int(1000)<p0){ breakLeft=1+rng.int(5); gap=true; } }
      if(gap){ pen=false; continue; }
      const X=x*10;
      if(!pen){ d+='M'+X+' '+ypx; pen=true; }
      else { const dy=ypx-py; d+= dy===0 ? 'h'+(X-px) : 'l'+(X-px)+' '+dy; }
      px=X; py=ypx;
    }
    linesD.push({d,maxH,baseY});
  }
  const sw=[3,4,6][t.lineW];
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
  // pink echo pass: genesis trait, plus forced echo of figure lines at tier>=6
  { let e=''; const dx=(2+rng.int(3))*U, dy=(1+rng.int(2))*U;
    if(t.pink>0){ const k=t.pink===2?4+rng.int(3):2+rng.int(2); for(let i=0;i<k;i++){ const li=rng.int(47); if(linesD[li].d) e+='<path d="'+linesD[li].d+'"/>'; } }
    if(tier>=6) for(const L of figLines.slice(0,8)) e+='<path d="'+L.d+'"/>';
    if(e) f+='<g fill="none" stroke="'+PINK+'" stroke-width="'+sw+'" transform="translate('+dx+' '+dy+')">'+e+'</g>'; }
  // the signal field, grouped by colour role
  { let gA='',gP='',gW='';
    for(const L of linesD){ if(!L.d) continue;
      let col='A';
      if(isFig.has(L)){
        if(whiteFig) col='W';
        else if(pinkFigAll) col='P';
        else if(pinkFigUpper && L.baseY<t.cy) col='P';
        else if(pinkCrest6 && crest6.has(L)) col='P';
        if(!whiteFig && crest.has(L)) col='W';
      }
      if(col==='A') gA+='<path d="'+L.d+'"/>'; else if(col==='P') gP+='<path d="'+L.d+'"/>'; else gW+='<path d="'+L.d+'"/>';
    }
    const bgw = tier>=5? Math.max(2,sw-1) : sw;
    if(gA) f+='<g fill="none" stroke="'+ACID+'" stroke-width="'+bgw+'">'+gA+'</g>';
    if(gP) f+='<g fill="none" stroke="'+PINK+'" stroke-width="'+sw+'">'+gP+'</g>';
    if(gW) f+='<g fill="none" stroke="'+WHITE+'" stroke-width="'+sw+'">'+gW+'</g>'; }
  // --- THE EYES — the signature. Weighted archetypes + trait-driven treatments.
  const rB=t.eyeR;
  const eyePos=[[t.cx-(11+rng.int(4)),t.cy+t.sLdy,rB,0],[t.cx+(11+rng.int(4)),t.cy+t.sRdy,Math.max(5,rB+rng.int(4)-1),1]];
  const glyph=(st,side,cx,cy,r,fill)=>eyeGlyph(st,side,cx,cy,r,fill,rng);
  const drawEyes=(fill,ox,oy)=>{
    let e='';
    if(t.eyes===3){ // continuous visor: one blade across both sockets
      const [lx,ly,lr]=eyePos[0], [rx2,ry2,rr2]=eyePos[1];
      const dispL=Math.round(heightAt(t,noiseCols,lx,ly,true)/100);
      const vy=ly-((dispL/3)|0)+2;
      e+=poly(offsetPts([[lx-lr,vy+2],[rx2+rr2,vy],[rx2+rr2,vy+5],[lx-lr,vy+7]],ox,oy),fill);
      return e; }
    for(const [ex,ey2,r,side] of eyePos){
      const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100);
      e+=glyph(t.eyes,side,ex+ox,ey2-((disp/3)|0)+2+oy,r,fill);
    }
    return e;
  };
  // treatments (trait, escalated by kill tier: 10+ at least ECHO GLOW, 50+ FULL SIGNAL)
  { const base=t.treat; t.treat = tier>=4 ? 4 : (tier>=2 ? Math.max(1,base) : base); }
  if(t.treat===1||t.treat===4){ f+=drawEyes(PINK,3,2); f+=drawEyes(ACID,-2,-2); }
  else if(t.treat===2||(t.mosh>0&&t.treat===0)) f+=drawEyes(PINK,2,2);
  if(t.treat===3||t.treat===4){ // ripple rings: the field reacting to the stare
    for(const [ex,ey2,r,side] of eyePos){
      if(t.eyes===6&&side) continue; if(t.eyes===7) continue;
      const disp=Math.round(heightAt(t,noiseCols,ex,ey2,true)/100); const cyp=ey2-((disp/3)|0)+2;
      for(let k=1;k<=(t.treat===4?1:2);k++){ const rr=r+3+k*4;
        const oct=[[ex-rr,cyp],[ex-(rr*7/10|0),cyp-(rr*7/10|0)],[ex,cyp-rr],[ex+(rr*7/10|0),cyp-(rr*7/10|0)],[ex+rr,cyp],[ex+(rr*7/10|0),cyp+(rr*7/10|0)],[ex,cyp+rr],[ex-(rr*7/10|0),cyp+(rr*7/10|0)]];
        f+='<path d="'+pathD(oct)+'" fill="none" stroke="'+(k===1?ACID:PINK)+'" stroke-width="3"/>'; } } }
  f+=drawEyes(ACID,0,0);
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
  if(t.mouth===2){ for(let x=t.cx-mw+2;x<t.cx+mw-1;x+=4){ const disp=Math.round(heightAt(t,noiseCols,x,mouthY,true)/100); f+=rect(x,mouthY-((disp/3)|0)+2,2,5,ACID); } }
  else if(t.mouth===3){ for(let i=-1;i<=1;i++){ const x=t.cx+i*6; const disp=Math.round(heightAt(t,noiseCols,x,mouthY,true)/100); f+=xmark(x,mouthY-((disp/3)|0)+3,2,1,ACID,rng); } }
  else if(t.mouth===1&&t.pink>0){ const disp=Math.round(heightAt(t,noiseCols,t.cx,mouthY,true)/100); f+=rect(t.cx-mw+2,mouthY-((disp/3)|0)+3,mw,1,PINK); }
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
  if(t.mosh>0){ const n=t.mosh===2?4+rng.int(2):2+rng.int(2);
    for(let i=0;i<n;i++) slices.push({y:6+rng.int(84),h:2+rng.int(5),dx:(2+rng.int(7))*(rng.int(2)?1:-1)}); }
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
  const sw=[3,4,6][t.lineW];
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
  // the warrant slash: one red band corner to corner — condemned
  o+=poly([[0,100],[0,93],[93,0],[100,0],[100,7],[7,100]],RED);
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
  const sw=[3,4,6][t.lineW];
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
