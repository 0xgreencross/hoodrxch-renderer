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
  for(const k of [0,1,10,25,50,75,100]){ const st=defaultState(id); st.kills=k; const svg=renderSVG(st);
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
 ['FX-003','RISING THREAT',3,{kills:10}],
 ['FX-004','SAVAGE',4,{kills:25}],
 ['FX-005','EXECUTIONER',5,{kills:50}],
 ['FX-006','DEATH DEALER',6,{kills:75}],
 ['FX-007','REAPER',7,{kills:100}],
 ['FX-008','HUNTER SELECTED',8,{hunterSelected:true}],
 ['FX-009','MARKED',9,{lifeState:1,marked:true,markedByTokenId:66,purgeDeadline:1790000000}],
 ['FX-010','MARKED REAPER',10,{lifeState:1,marked:true,markedByTokenId:13,purgeDeadline:1790000000,kills:100}],
 ['FX-011','WITSEC',11,{witsecApplies:true,exposureState:3}],
 ['FX-012','LAY LOW',12,{laidLow:true,exposureState:2}],
 ['FX-013','BUYER PROTECTED',13,{buyerProtected:true,exposureState:4}],
 ['FX-014','COFFINED DEATH 1',14,{lifeState:2,exposureState:5,deaths:1,sealsRemaining:2}],
 ['FX-015','COFFINED DEATH 2',15,{lifeState:2,exposureState:5,deaths:2,sealsRemaining:1,kills:25}],
 ['FX-016','TERMINAL COFFIN',16,{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0}],
 ['FX-017','TERMINAL REAPER',17,{lifeState:3,exposureState:6,deaths:3,sealsRemaining:0,kills:100}],
 ['FX-018','EXHUMED SCARRED',18,{deaths:2,sealsRemaining:1,kills:30}],
 ['FX-019','SAVED FIVE TIMES',19,{savesReceived:5,savesGiven:3}],
 ['FX-020','ENFORCER',20,{forcedPurges:10}],
 ['FX-021','STREAK SEVEN',21,{currentKillStreak:7,kills:12}],
 ['FX-022','SEASON TOP 10',22,{latestSeasonBadgeFlags:1,latestSeasonRank:7,latestAwardSeasonId:1}],
 ['FX-023','SEASON TOP 5',23,{latestSeasonBadgeFlags:3,latestSeasonRank:2,latestAwardSeasonId:2}],
 ['FX-024','WARLORD',24,{territoryAchievementCount:6,kills:50}],
 ['FX-025','STATS MODE',25,{displayMode:1,kills:25,deaths:1,sealsRemaining:2,currentKillStreak:3}],
 ['FX-026','FLICKER',26,{flicker:true,kills:10}],
 ['FX-027','FULL DECORATION',27,{kills:75,deaths:1,sealsRemaining:2,forcedPurges:6,savesReceived:3,latestSeasonBadgeFlags:3,latestSeasonRank:1,latestAwardSeasonId:1,territoryAchievementCount:4,currentKillStreak:5}],
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
document.getElementById('ver').textContent='renderer v'+RENDERER_VERSION+' · schema v'+SCHEMA_VERSION;
buildControls(); refresh();
</script>
</body>
</html>
