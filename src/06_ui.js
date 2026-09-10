// ---------------------------------------------------------------------------
// Workbench UI
// ---------------------------------------------------------------------------
const FIELDS=[
 ['tokenId','n',1,666],['wardId','n',1,3],['blockId','n',1,6],['genesisHash','t'],
 ['lifeState','s',LIFE],['exposureState','s',EXPO],['sealsRemaining','n',0,3],['kills','n',0,65535],['deaths','n',0,3],
 ['marked','b'],['markedByTokenId','n',0,666],['purgeDeadline','n',0,4294967295],['hunterSelected','b'],['witsecApplies','b'],['laidLow','b'],['buyerProtected','b'],
 ['savesReceived','n',0,65535],['forcedPurges','n',0,65535],['currentKillStreak','n',0,65535],
 ['latestAwardSeasonId','n',0,9999],['latestSeasonRank','n',0,666],['latestSeasonBadgeFlags','n',0,3],['territoryAchievementCount','n',0,9999],
 ['transferLocked','b'],['displayMode','s',['PLAIN','STATS']],['flicker','b']];
let S=defaultState(1);
function buildControls(){
  const c=document.getElementById('controls'); let h='<h2>STATE</h2>';
  for(const f of FIELDS){ const [k,ty]=f; let inp='';
    if(ty==='n') inp='<input type="number" data-k="'+k+'" min="'+f[2]+'" max="'+f[3]+'" value="'+S[k]+'">';
    else if(ty==='t') inp='<input type="text" data-k="'+k+'" value="'+S[k]+'">';
    else if(ty==='b') inp='<input type="checkbox" data-k="'+k+'"'+(S[k]?' checked':'')+'>';
    else inp='<select data-k="'+k+'">'+f[2].map((n,i)=>'<option value="'+i+'"'+(S[k]===i?' selected':'')+'>'+n+'</option>').join('')+'</select>';
    h+='<div class="row"><label>'+k+'</label>'+inp+'</div>'; }
  h+='<h2>PRESETS</h2><div class="row"><button data-p="random">Random token</button><button data-p="reset">Reset</button><button data-p="regen">Regen hash</button></div>';
  h+='<h2>TRAITS</h2><pre id="traits"></pre>';
  c.innerHTML=h;
  c.addEventListener('input',e=>{ const k=e.target.dataset.k; if(!k) return; const f=FIELDS.find(x=>x[0]===k);
    if(f[1]==='b') S[k]=e.target.checked; else if(f[1]==='t') S[k]=e.target.value; else S[k]=Number(e.target.value);
    if(k==='tokenId') S.genesisHash=demoGenesisHash(S.tokenId);
    coerce(k); syncControls(); refresh(); });
  c.addEventListener('click',e=>{ const p=e.target.dataset.p; if(!p) return;
    if(p==='random'){ S=defaultState(1+Math.floor(Math.random()*666)); }
    if(p==='reset'){ S=defaultState(S.tokenId); }
    if(p==='regen'){ S.genesisHash=bytesToHex(keccak256(concatBytes(hexToBytes(S.genesisHash),u8(1)))); }
    syncControls(); refresh(); });
}
function syncControls(){ for(const f of FIELDS){ const el=document.querySelector('[data-k="'+f[0]+'"]'); if(!el) continue; if(f[1]==='b') el.checked=!!S[f[0]]; else el.value=S[f[0]]; } }
// keep companion fields consistent so single control changes produce legal states
// (the renderer itself still diagnoses impossible states — this is UI convenience only)
function coerce(k){
  if(k==='lifeState'){
    if(S.lifeState===0){ S.marked=false; if(S.exposureState===5||S.exposureState===6) S.exposureState=1; if(S.deaths>2) S.deaths=2; S.sealsRemaining=3-S.deaths; }
    if(S.lifeState===1){ S.marked=true; S.witsecApplies=false; S.laidLow=false; if(S.exposureState===2||S.exposureState===3||S.exposureState===5||S.exposureState===6) S.exposureState=1; if(S.deaths>2) S.deaths=2; S.sealsRemaining=3-S.deaths; if(!S.markedByTokenId) S.markedByTokenId=66; if(!S.purgeDeadline) S.purgeDeadline=1790000000; }
    if(S.lifeState===2){ S.exposureState=5; if(S.deaths<1) S.deaths=1; if(S.deaths>2) S.deaths=2; S.sealsRemaining=3-S.deaths; S.marked=false; S.hunterSelected=false; S.witsecApplies=false; S.laidLow=false; S.buyerProtected=false; }
    if(S.lifeState===3){ S.exposureState=6; S.deaths=3; S.sealsRemaining=0; S.marked=false; S.hunterSelected=false; S.witsecApplies=false; S.laidLow=false; S.buyerProtected=false; }
  }
  if(k==='marked'){ if(S.marked){ coerceTo(1); } else if(S.lifeState===1){ S.lifeState=0; S.markedByTokenId=0; S.purgeDeadline=0; } }
  if(k==='deaths'){ if(S.lifeState===3){ S.deaths=3; } else { if(S.deaths>2) S.deaths=2; S.sealsRemaining=3-S.deaths; if(S.deaths===0&&S.exposureState===5){ S.exposureState=1; S.lifeState=0; } } }
  if(k==='sealsRemaining'){ if(S.lifeState===3){ S.sealsRemaining=0; } else { if(S.sealsRemaining<1) S.sealsRemaining=1; S.deaths=3-S.sealsRemaining; } }
  if(k==='witsecApplies'&&S.witsecApplies){ S.laidLow=false; S.buyerProtected=false; S.marked=false; if(S.lifeState===1) S.lifeState=0; S.exposureState=3; }
  if(k==='laidLow'&&S.laidLow){ S.witsecApplies=false; S.buyerProtected=false; S.marked=false; if(S.lifeState===1) S.lifeState=0; S.exposureState=2; }
  if(k==='buyerProtected'&&S.buyerProtected){ S.witsecApplies=false; S.laidLow=false; S.exposureState=4; }
  if((k==='witsecApplies'||k==='laidLow'||k==='buyerProtected')&&!S[k]){ if(!S.witsecApplies&&!S.laidLow&&!S.buyerProtected&&S.exposureState>=2&&S.exposureState<=4) S.exposureState=1; }
  if(k==='latestSeasonBadgeFlags'){ if(S.latestSeasonBadgeFlags===2) S.latestSeasonBadgeFlags=3;
    if(S.latestSeasonBadgeFlags===0){ S.latestSeasonRank=0; S.latestAwardSeasonId=0; }
    else { if(!S.latestAwardSeasonId) S.latestAwardSeasonId=1; S.latestSeasonRank=S.latestSeasonBadgeFlags===3?2:7; } }
  if(k==='latestSeasonRank'){ if(S.latestSeasonRank===0){ S.latestSeasonBadgeFlags=0; S.latestAwardSeasonId=0; }
    else { if(!S.latestAwardSeasonId) S.latestAwardSeasonId=1; S.latestSeasonBadgeFlags = S.latestSeasonRank<=5?3 : S.latestSeasonRank<=10?1 : 0; if(S.latestSeasonBadgeFlags===0){ S.latestSeasonRank=0; S.latestAwardSeasonId=0; } } }
}
function coerceTo(ls){ S.lifeState=ls; coerce('lifeState'); }
// previews use <img data:> so that <defs> ids never collide between inline SVGs
function svgImg(svg,px){ return '<img class="sq" width="'+px+'" height="'+px+'" src="data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(svg)))+'">'; }
function svgTag(svg,px,cls){ return '<div class="'+(cls||'')+'" style="width:'+px+'px;height:'+px+'px">'+svgImg(svg,px)+'</div>'; }
function refresh(){
  const svg=renderSVG(S); const v=document.getElementById('views'); let h='';
  for(const bg of ['black','white']){ for(const px of [512,128,64,32]) h+='<div class="view '+bg+'">'+svgTag(svg,px)+'<span>'+px+'</span></div>';
    h+='<div class="view '+bg+'">'+svgTag(svg,256,'circ')+'<span>PFP</span></div>'; }
  v.innerHTML=h;
  const json=renderMetadata(S);
  document.getElementById('json').textContent=JSON.stringify(JSON.parse(json),(k,val)=>k==='image'?val.slice(0,60)+'…':val,1);
  document.getElementById('size').innerHTML='SVG '+new Blob([svg]).size+' bytes · JSON '+new Blob([json]).size+' bytes · status '+resolveStatus(S)+' · tier '+TIER_NAMES[tierForKills(S.kills)]+' · hash '+stateHash(S).slice(0,18);
  document.getElementById('svgsrc').textContent=svg;
  const errs=validate(S); document.getElementById('traits').textContent=(errs.length?'DIAGNOSTIC '+errs.join(' ')+'\n':'')+JSON.stringify(errs.length?{}:traitNames(S),null,1);
}
// Review sheet: 24 tokens at 256/64/32
function drawReview(){
  const seed=Number(document.getElementById('reviewSeed').value)||1; const sh=document.getElementById('sheet'); let h='';
  const r=new Rng(concatBytes(strBytes('REVIEW'),word(seed)));
  for(let i=0;i<24;i++){ const id=1+(r.byte()*256+r.byte())%666; const st=defaultState(id); const svg=renderSVG(st); const tn=traitNames(st);
    h+='<div class="tok">'+svgTag(svg,256,'big')+svgTag(svg,64,'mid')+svgTag(svg,32,'sm')+'<div class="meta">#'+id+' W'+st.wardId+' B'+st.blockId+'<br>'+Object.values(tn).join('<br>')+'</div></div>'; }
  sh.innerHTML=h;
}
// Gallery 666 + rarity
function drawGallery(){
  const gal=document.getElementById('gal'); const counts={form:{},lines:{},tear:{},spikes:{},eyes:{},treatment:{},mouth:{},pink:{},mosh:{},sigil:{}}; let h='';
  for(let id=1;id<=666;id++){ const st=defaultState(id); const svg=renderSVG(st); const tn=traitNames(st);
    for(const k in tn) counts[k][tn[k]]=(counts[k][tn[k]]||0)+1;
    h+='<div class="cell">'+svgImg(svg,64)+'<span>#'+id+'</span></div>'; }
  gal.innerHTML=h;
  const TIER_LOOKUP={form:[FORM_NAMES,FORM_TIER],lines:[LINE_NAMES,LINE_TIER],tear:[TEAR_NAMES,TEAR_TIER],spikes:[SPIKE_NAMES,SPIKE_TIER],eyes:[EYE_NAMES,EYE_TIER],treatment:[TREAT_NAMES,TREAT_TIER],mouth:[MOUTH_NAMES,MOUTH_TIER],pink:[PINKAMT_NAMES,PINK_TIER],mosh:[MOSH_NAMES,MOSH_TIER]};
  const TIER_COL=['#777','#d8d8d8','#7ec8ff','#CCFF00','#FF3EB5','#FF2A2A'];
  let t='<h2 style="color:var(--mute)">RARITY (666 GENESIS, demo genesisHash) — tiers: COMMON &lt; UNCOMMON &lt; RARE &lt; ULTRA RARE &lt; LEGENDARY &lt; EPIC</h2><table><tr><th>Trait</th><th>Value</th><th>Tier</th><th>Count</th><th>%</th><th></th></tr>';
  for(const k in counts){ const ent=Object.entries(counts[k]).sort((a,b)=>b[1]-a[1]);
    for(const [n,c] of ent){ let tierTxt='—';
      if(TIER_LOOKUP[k]){ const idx=TIER_LOOKUP[k][0].indexOf(n); if(idx>=0){ const ti=TIER_LOOKUP[k][1][idx]; tierTxt='<span style="color:'+TIER_COL[ti]+'">'+RARITY_NAMES[ti]+'</span>'; } }
      t+='<tr><td>'+k+'</td><td>'+n+'</td><td>'+tierTxt+'</td><td>'+c+'</td><td>'+(c/6.66).toFixed(1)+'</td><td><span class="bar" style="width:'+(c/2)+'px"></span></td></tr>'; } }
  document.getElementById('rarity').innerHTML=t+'</table>';
}
document.querySelectorAll('header button').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('header button').forEach(x=>x.classList.toggle('on',x===b));
  document.querySelectorAll('.tab').forEach(t=>t.classList.toggle('on',t.id===b.dataset.tab));
  if(b.dataset.tab==='gallery'&&!document.getElementById('gal').children.length) drawGallery();
  if(b.dataset.tab==='review'&&!document.getElementById('sheet').children.length) drawReview();
  if(b.dataset.tab==='evo'&&!document.getElementById('evoKills').children.length) drawEvo();
  if(b.dataset.tab==='fx'&&!document.getElementById('fxGrid').children.length) drawFx();
  if(b.dataset.tab==='banner') drawBanner();
}));
document.getElementById('reviewGo').addEventListener('click',drawReview);
function drawEvo(){
  const id=225; let h='';
  for(const k of [0,1,2,3,4,5,7]){ const st=defaultState(id); st.kills=k; const svg=renderSVG(st);
    h+='<div class="e">'+svgImg(svg,150)+'<span>'+k+' KILLS · '+TIER_NAMES[tierForKills(k)]+'</span></div>'; }
  document.getElementById('evoKills').innerHTML=h;
  let h2='';
  const seq=[
    [{},'GENESIS'],
    [{lifeState:2,exposureState:5,deaths:1,sealsRemaining:2},'COFFINED · DEATH 1'],
    [{deaths:1,sealsRemaining:2},'EXHUMED · DEATH 1'],
    [{lifeState:2,exposureState:5,deaths:2,sealsRemaining:1},'COFFINED · DEATH 2'],
    [{deaths:2,sealsRemaining:1},'EXHUMED · DEATH 2'],
    [{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0},'TERMINAL · DEATH 3']];
  for(const [patch,label] of seq){ const st=Object.assign(defaultState(id),{kills:25},patch); const svg=renderSVG(st);
    h2+='<div class="e">'+svgImg(svg,150)+'<span>'+label+'</span></div>'; }
  document.getElementById('evoDeaths').innerHTML=h2;
  let h3='';
  const stx=[
    [{marked:true,lifeState:1,markedByTokenId:66,purgeDeadline:1790000000},'MARKED'],
    [{hunterSelected:true},'HUNTER SELECTED'],
    [{witsecApplies:true,exposureState:3},'WITSEC'],
    [{laidLow:true,exposureState:2},'LAY LOW'],
    [{buyerProtected:true,exposureState:4},'BUYER PROTECTED'],
    [{displayMode:1,kills:25,deaths:1,sealsRemaining:2,currentKillStreak:4},'STATS MODE']];
  for(const [patch,label] of stx){ const st=Object.assign(defaultState(id),patch); const svg=renderSVG(st);
    h3+='<div class="e">'+svgImg(svg,150)+'<span>'+label+'</span></div>'; }
  const el=document.getElementById('evoStatus'); if(el) el.innerHTML=h3;
}
// ---------------------------------------------------------------------------
// Fixtures FX-001..FX-030 — the canonical review set + differential-test input
// ---------------------------------------------------------------------------
const FIXTURES=[
 ['FX-001','GENESIS BASELINE',1,{}],
 ['FX-002','FIRST BLOOD',2,{kills:1}],
 ['FX-003','RISING THREAT',3,{kills:2}],
 ['FX-004','SAVAGE',4,{kills:3}],
 ['FX-005','EXECUTIONER',5,{kills:4}],
 ['FX-006','DEATH DEALER',6,{kills:5}],
 ['FX-007','REAPER',7,{kills:7}],
 ['FX-008','HUNTER SELECTED',8,{hunterSelected:true}],
 ['FX-009','MARKED',9,{lifeState:1,marked:true,markedByTokenId:66,purgeDeadline:1790000000}],
 ['FX-010','MARKED REAPER',10,{lifeState:1,marked:true,markedByTokenId:13,purgeDeadline:1790000000,kills:18}],
 ['FX-011','WITSEC',11,{witsecApplies:true,exposureState:3}],
 ['FX-012','LAY LOW',12,{laidLow:true,exposureState:2}],
 ['FX-013','BUYER PROTECTED',13,{buyerProtected:true,exposureState:4}],
 ['FX-014','COFFINED DEATH 1',14,{lifeState:2,exposureState:5,deaths:1,sealsRemaining:2}],
 ['FX-015','COFFINED DEATH 2',15,{lifeState:2,exposureState:5,deaths:2,sealsRemaining:1,kills:3}],
 ['FX-016','TERMINAL COFFIN',16,{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0}],
 ['FX-017','TERMINAL REAPER',17,{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0,kills:18}],
 ['FX-018','EXHUMED SCARRED',18,{deaths:2,sealsRemaining:1,kills:10}],
 ['FX-019','SAVED FIVE TIMES',19,{savesReceived:5,savesGiven:3}],
 ['FX-020','ENFORCER',20,{forcedPurges:10}],
 ['FX-021','STREAK FIVE',21,{currentKillStreak:5,kills:9}],
 ['FX-022','SEASON TOP 10',22,{latestSeasonBadgeFlags:1,latestSeasonRank:7,latestAwardSeasonId:1}],
 ['FX-023','SEASON TOP 5',23,{latestSeasonBadgeFlags:3,latestSeasonRank:2,latestAwardSeasonId:2}],
 ['FX-024','WARLORD',24,{territoryAchievementCount:6,kills:8}],
 ['FX-025','STATS MODE',25,{displayMode:1,kills:6,deaths:1,sealsRemaining:2,currentKillStreak:3}],
 ['FX-026','FLICKER',26,{flicker:true,kills:10}],
 ['FX-027','FULL DECORATION',27,{kills:7,deaths:1,sealsRemaining:2,forcedPurges:6,savesReceived:3,latestSeasonBadgeFlags:3,latestSeasonRank:1,latestAwardSeasonId:1,territoryAchievementCount:4,currentKillStreak:5}],
 ['FX-028','DIAG SEAL MISMATCH',28,{sealsRemaining:0}],
 ['FX-029','DIAG DOUBLE SHIELD',29,{witsecApplies:true,laidLow:true,exposureState:3}],
 ['FX-030','DIAG MARKED TERMINAL',30,{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0,marked:true}]];
function fxState(fx){ return Object.assign(defaultState(fx[2]),fx[3]); }
function drawFx(){
  let h=''; let bytes=0;
  for(const fx of FIXTURES){ const st=fxState(fx); const svg=renderSVG(st); bytes+=svg.length;
    const errs=validate(st);
    h+='<div class="f">'+svgImg(svg,190)+'<div>'+fx[0]+' · '+fx[1]+(errs.length?' <span class="warn">'+errs.join(' ')+'</span>':'')+'<br><span style="color:var(--mute)">'+svg.length+' B · '+stateHash(st).slice(0,14)+'</span></div></div>'; }
  document.getElementById('fxGrid').innerHTML=h;
  document.getElementById('fxSummary').textContent=FIXTURES.length+' fixtures · '+bytes+' bytes total · mean '+Math.round(bytes/FIXTURES.length)+' B per SVG';
}
document.getElementById('exportFx').addEventListener('click',e=>{
  const out=FIXTURES.map(fx=>{ const st=fxState(fx); return {id:fx[0],name:fx[1],tokenId:fx[2],patch:fx[3],state:st,errors:validate(st),stateHash:stateHash(st),svgBytes:renderSVG(st).length}; });
  const blob=JSON.stringify({rendererVersion:RENDERER_VERSION,schemaVersion:SCHEMA_VERSION,fixtures:out},null,1);
  e.target.href='data:application/json;base64,'+btoa(unescape(encodeURIComponent(blob)));
  e.target.download='fixtures.json';
});
function drawBanner(){
  const states=[S,Object.assign(defaultState(S.tokenId),{kills:100}),Object.assign(defaultState(S.tokenId),{lifeState:1,marked:true,markedByTokenId:66,purgeDeadline:1790000000}),Object.assign(defaultState(S.tokenId),{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0})];
  const labels=['CURRENT WORKBENCH STATE','REAPER','MARKED','TERMINAL'];
  let h='';
  for(let i=0;i<states.length;i++){ const svg=renderBanner(states[i]);
    h+='<div style="margin-bottom:14px"><div style="color:var(--mute);font-size:10px;margin-bottom:4px">'+labels[i]+' · '+new Blob([svg]).size+' bytes</div><img style="width:100%;max-width:1500px;display:block" src="data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(svg)))+'"></div>'; }
  document.getElementById('bannerOut').innerHTML=h;
}
// ---------------------------------------------------------------------------
// CURATE — trait compatibility curation. Bypasses the seed system (TRAIT_OV
// forces trait values while burning the blessed rng stream) and guides a
// pairwise sweep of every trait-value pair. Verdicts autosave to localStorage
// and export as JSON so the rules can be implemented in the trait engine.
// Philosophy: everything is compatible until banned — hunt the bans, then
// "ALLOW REST OF AXIS PAIR" to close each axis pair fast.
// ---------------------------------------------------------------------------
const CUR_AXES=[
 ['form',FORM_NAMES],['lineW',LINE_NAMES],['tear',TEAR_NAMES],['spike',SPIKE_NAMES],
 ['eyes',EYE_NAMES],['treat',TREAT_NAMES],['mouth',MOUTH_NAMES],['pink',PINKAMT_NAMES],['mosh',MOSH_NAMES]];
const CUR_KEY='hoodrxch_curation_v1';
let CUR={version:1,verdicts:{}};
try{ const raw=localStorage.getItem(CUR_KEY); if(raw) CUR=JSON.parse(raw); }catch(e){}
let curPairIdx=0, curReroll=0, curFree=false, curFreeOv={};
const CUR_QUEUE=[]; // [axisIdxA, axisIdxB] for all axis pairs
for(let i=0;i<CUR_AXES.length;i++) for(let j=i+1;j<CUR_AXES.length;j++) CUR_QUEUE.push([i,j]);
function curKey(ai,va,bi,vb){ return CUR_AXES[ai][0]+':'+va+'|'+CUR_AXES[bi][0]+':'+vb; }
function curPairsOf(q){ const [ai,bi]=CUR_QUEUE[q]; const out=[];
  for(let a=0;a<CUR_AXES[ai][1].length;a++) for(let b=0;b<CUR_AXES[bi][1].length;b++) out.push([ai,a,bi,b]);
  return out; }
function curTotals(){ let total=0,done=0;
  for(let q=0;q<CUR_QUEUE.length;q++){ const ps=curPairsOf(q); total+=ps.length;
    for(const [ai,a,bi,b] of ps) if(CUR.verdicts[curKey(ai,a,bi,b)]) done++; }
  return [done,total]; }
function curNextUndone(from){
  for(let s2=0;s2<CUR_QUEUE.length;s2++){ const q=(from+s2)%CUR_QUEUE.length;
    for(const [ai,a,bi,b] of curPairsOf(q)) if(!CUR.verdicts[curKey(ai,a,bi,b)]) return [q,ai,a,bi,b]; }
  return null; }
let curCur=null; // [q, ai, va, bi, vb]
function curSave(){ try{ localStorage.setItem(CUR_KEY,JSON.stringify(CUR)); }catch(e){} }
function curRenderOv(ov,seedId){ TRAIT_OV=ov; try{ return renderSVG(defaultState(seedId)); } finally{ TRAIT_OV=null; } }
function curSeeds(){ const base=(curCur?curCur[0]*131+curCur[2]*17+curCur[4]*7:0)+curReroll*97;
  return [1+(base*53%666),1+((base*53+167)%666),1+((base*53+331)%666),1+((base*53+499)%666)]; }
function curVerdict(v){
  if(curFree) return;
  if(!curCur) return;
  const [q,ai,va,bi,vb]=curCur;
  const k=curKey(ai,va,bi,vb);
  const rec={v,seed:curSeeds()[0]};
  if(v==='warn'){ const note=prompt('Condition / note for this combo:'); if(note===null) return; rec.note=note; }
  CUR.verdicts[k]=rec; curSave();
  const nxt=curNextUndone(q); curCur=nxt?[nxt[0],nxt[1],nxt[2],nxt[3],nxt[4]]:null; curReroll=0;
  drawCurate();
}
function curBulkAllow(){
  if(curFree||!curCur) return;
  const q=curCur[0]; let n=0;
  for(const [ai,a,bi,b] of curPairsOf(q)){ const k=curKey(ai,a,bi,b);
    if(!CUR.verdicts[k]){ CUR.verdicts[k]={v:'ok',bulk:1}; n++; } }
  curSave();
  const nxt=curNextUndone(q+1); curCur=nxt?[nxt[0],nxt[1],nxt[2],nxt[3],nxt[4]]:null; curReroll=0;
  drawCurate();
}
function curJump(q){ const nxt=curNextUndone(q); curCur=nxt?[nxt[0],nxt[1],nxt[2],nxt[3],nxt[4]]:null; curReroll=0; drawCurate(); }
function drawCurate(){
  const el=document.getElementById('curateUI');
  if(!curCur&&!curFree){ const nxt=curNextUndone(curPairIdx); if(nxt) curCur=[nxt[0],nxt[1],nxt[2],nxt[3],nxt[4]]; }
  const [done,total]=curTotals();
  let h='<div class="row" style="flex-wrap:wrap;gap:8px;align-items:center">';
  h+='<button id="curModeG" '+(curFree?'':'class="on" ')+'style="'+(curFree?'':'background:var(--acid);color:#000')+'">GUIDED SWEEP</button>';
  h+='<button id="curModeF" '+(curFree?'style="background:var(--acid);color:#000"':'')+'>FREE COMPOSE</button>';
  h+='<span style="color:var(--mute)">progress '+done+' / '+total+' pairs ('+(total?(done*100/total).toFixed(1):0)+'%)</span>';
  h+='<a class="btn" id="curExport" href="#">Export rules JSON</a>';
  h+='<label class="btn" style="cursor:pointer">Import<input type="file" id="curImport" style="display:none"></label>';
  h+='<button id="curWipe">Wipe all</button></div>';
  if(curFree){
    h+='<div class="row" style="flex-wrap:wrap;gap:6px;margin-top:8px">';
    for(let i=0;i<CUR_AXES.length;i++){ const [k,names]=CUR_AXES[i];
      h+='<label style="display:flex;flex-direction:column;font-size:10px;color:var(--mute)">'+k
        +'<select data-cf="'+k+'"><option value="">— natural —</option>'
        +names.map((n,vi)=>'<option value="'+vi+'"'+(curFreeOv[k]===vi?' selected':'')+'>'+vi+' '+n+'</option>').join('')+'</select></label>'; }
    h+='<label style="display:flex;flex-direction:column;font-size:10px;color:var(--mute)">seed token<input type="number" id="curFreeSeed" min="1" max="666" value="'+(curFreeOv.__seed||94)+'" style="width:70px"></label>';
    h+='</div><div id="curFreeOut" style="margin-top:10px;display:flex;gap:16px;flex-wrap:wrap"></div>';
    el.innerHTML=h;
    const ov={}; for(const [k] of CUR_AXES) if(curFreeOv[k]!=null) ov[k]=curFreeOv[k];
    const seed=curFreeOv.__seed||94;
    const svg=curRenderOv(ov,seed);
    TRAIT_OV=ov; let tn; try{ tn=traitNames(defaultState(seed)); } finally{ TRAIT_OV=null; }
    document.getElementById('curFreeOut').innerHTML=svgTag(svg,420)+svgTag(svg,300,'circ')
      +'<pre style="font-size:10px">'+JSON.stringify(tn,null,1)+'</pre>';
  } else if(curCur){
    const [q,ai,va,bi,vb]=curCur; const [axA,namesA]=CUR_AXES[ai]; const [axB,namesB]=CUR_AXES[bi];
    const ps=curPairsOf(q); let qd=0; for(const [xai,a,xbi,b] of ps) if(CUR.verdicts[curKey(xai,a,xbi,b)]) qd++;
    h+='<div style="margin-top:10px;font-size:15px;color:var(--acid)">'+axA.toUpperCase()+' <b>'+namesA[va]+'</b> × '+axB.toUpperCase()+' <b>'+namesB[vb]+'</b></div>';
    h+='<div style="color:var(--mute);font-size:11px;margin:2px 0 8px">axis pair '+(q+1)+'/'+CUR_QUEUE.length+' — '+qd+'/'+ps.length+' judged in this pair · 4 seeds shown, only the pinned pair is forced</div>';
    h+='<div class="row" style="gap:8px;flex-wrap:wrap">'
      +'<button id="curOk" style="background:var(--acid);color:#000">ALLOW (A)</button>'
      +'<button id="curBan" style="background:#FF2A2A;color:#fff">NEVER MIX (X)</button>'
      +'<button id="curWarn">FLAG+NOTE (W)</button>'
      +'<button id="curReroll">REROLL SEEDS (R)</button>'
      +'<button id="curBulk">ALLOW REST OF AXIS PAIR (Z)</button>'
      +'<select id="curJumpSel">'+CUR_QUEUE.map((p,i)=>'<option value="'+i+'"'+(i===q?' selected':'')+'>'+CUR_AXES[p[0]][0]+' × '+CUR_AXES[p[1]][0]+'</option>').join('')+'</select>'
      +'</div>';
    h+='<div id="curGrid" style="margin-top:10px;display:flex;gap:10px;flex-wrap:wrap"></div>';
    el.innerHTML=h;
    const ov={}; ov[axA]=va; ov[axB]=vb;
    let gh='';
    for(const sd of curSeeds()){ const svg=curRenderOv(ov,sd); gh+='<div>'+svgTag(svg,230)+'<div style="color:var(--mute);font-size:10px;text-align:center">seed #'+sd+'</div></div>'; }
    document.getElementById('curGrid').innerHTML=gh;
  } else {
    h+='<div style="margin-top:14px;color:var(--acid);font-size:15px">EVERY PAIR CURATED. Export the rules JSON and hand it over.</div>';
    el.innerHTML=h;
  }
  // wire events
  const on=(id,fn)=>{ const b=document.getElementById(id); if(b) b.addEventListener('click',fn); };
  on('curModeG',()=>{ curFree=false; drawCurate(); });
  on('curModeF',()=>{ curFree=true; drawCurate(); });
  on('curOk',()=>curVerdict('ok')); on('curBan',()=>curVerdict('ban')); on('curWarn',()=>curVerdict('warn'));
  on('curReroll',()=>{ curReroll++; drawCurate(); });
  on('curBulk',curBulkAllow);
  on('curWipe',()=>{ if(confirm('Wipe ALL curation verdicts?')){ CUR={version:1,verdicts:{}}; curSave(); curCur=null; drawCurate(); } });
  const js=document.getElementById('curJumpSel'); if(js) js.addEventListener('change',e=>curJump(Number(e.target.value)));
  const ex=document.getElementById('curExport'); if(ex) ex.addEventListener('click',e=>{
    const blob=JSON.stringify(Object.assign({},CUR,{exported:new Date().toISOString(),axes:CUR_AXES.map(a=>[a[0],a[1].length])}),null,1);
    e.target.href='data:application/json;base64,'+btoa(unescape(encodeURIComponent(blob)));
    e.target.download='hoodrxch_trait_rules.json'; });
  const im=document.getElementById('curImport'); if(im) im.addEventListener('change',e=>{
    const f=e.target.files[0]; if(!f) return; const rd=new FileReader();
    rd.onload=()=>{ try{ const j=JSON.parse(rd.result); if(j.verdicts){ CUR=j; curSave(); curCur=null; drawCurate(); } }catch(err){ alert('bad JSON'); } };
    rd.readAsText(f); });
  const co=el.querySelectorAll('[data-cf]'); co.forEach(sel=>sel.addEventListener('change',e=>{
    const k=e.target.dataset.cf; const v=e.target.value; if(v==='') delete curFreeOv[k]; else curFreeOv[k]=Number(v); drawCurate(); }));
  const fsd=document.getElementById('curFreeSeed'); if(fsd) fsd.addEventListener('change',e=>{ curFreeOv.__seed=Math.max(1,Math.min(666,Number(e.target.value)||94)); drawCurate(); });
}
document.addEventListener('keydown',e=>{
  const tab=document.getElementById('curate'); if(!tab||!tab.classList.contains('on')||curFree) return;
  if(e.target.tagName==='INPUT'||e.target.tagName==='SELECT'||e.target.tagName==='TEXTAREA') return;
  if(e.key==='a'||e.key==='A') curVerdict('ok');
  else if(e.key==='x'||e.key==='X') curVerdict('ban');
  else if(e.key==='w'||e.key==='W') curVerdict('warn');
  else if(e.key==='r'||e.key==='R'){ curReroll++; drawCurate(); }
  else if(e.key==='z'||e.key==='Z') curBulkAllow();
});
document.querySelector('header button[data-tab="curate"]').addEventListener('click',()=>{ drawCurate(); });
document.getElementById('ver').textContent='renderer v'+RENDERER_VERSION+' · schema v'+SCHEMA_VERSION;
buildControls(); refresh();
</script>
</body>
</html>
