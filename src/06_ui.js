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
    refresh(); });
  c.addEventListener('click',e=>{ const p=e.target.dataset.p; if(!p) return;
    if(p==='random'){ S=defaultState(1+Math.floor(Math.random()*666)); }
    if(p==='reset'){ S=defaultState(S.tokenId); }
    if(p==='regen'){ S.genesisHash=bytesToHex(keccak256(concatBytes(hexToBytes(S.genesisHash),u8(1)))); }
    syncControls(); refresh(); });
}
function syncControls(){ for(const f of FIELDS){ const el=document.querySelector('[data-k="'+f[0]+'"]'); if(!el) continue; if(f[1]==='b') el.checked=!!S[f[0]]; else el.value=S[f[0]]; } }
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
  let t='<h2 style="color:var(--mute)">RARITY (666 GENESIS, demo genesisHash)</h2><table><tr><th>Trait</th><th>Value</th><th>Count</th><th>%</th><th></th></tr>';
  for(const k in counts){ const ent=Object.entries(counts[k]).sort((a,b)=>b[1]-a[1]); for(const [n,c] of ent) t+='<tr><td>'+k+'</td><td>'+n+'</td><td>'+c+'</td><td>'+(c/6.66).toFixed(1)+'</td><td><span class="bar" style="width:'+(c/2)+'px"></span></td></tr>'; }
  document.getElementById('rarity').innerHTML=t+'</table>';
}
document.querySelectorAll('header button').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('header button').forEach(x=>x.classList.toggle('on',x===b));
  document.querySelectorAll('.tab').forEach(t=>t.classList.toggle('on',t.id===b.dataset.tab));
  if(b.dataset.tab==='gallery'&&!document.getElementById('gal').children.length) drawGallery();
  if(b.dataset.tab==='review'&&!document.getElementById('sheet').children.length) drawReview();
  if(b.dataset.tab==='evo'&&!document.getElementById('evoKills').children.length) drawEvo();
}));
document.getElementById('reviewGo').addEventListener('click',drawReview);
function drawEvo(){
  const id=225; let h='';
  for(const k of [0,1,10,25,50,75,100]){ const st=defaultState(id); st.kills=k; const svg=renderSVG(st);
    h+='<div class="e">'+svgImg(svg,150)+'<span>'+k+' KILLS · '+TIER_NAMES[tierForKills(k)]+'</span></div>'; }
  document.getElementById('evoKills').innerHTML=h;
  let h2='';
  const seq=[[0,3,'GENESIS'],[1,2,'EXHUMED · DEATH 1'],[2,1,'EXHUMED · DEATH 2']];
  for(const [d,seals,label] of seq){ const st=defaultState(id); st.deaths=d; st.sealsRemaining=seals; st.kills=25; const svg=renderSVG(st);
    h2+='<div class="e">'+svgImg(svg,150)+'<span>'+label+'</span></div>'; }
  h2+='<div class="e" style="color:var(--red)">COFFINED / TERMINAL — next build step</div>';
  document.getElementById('evoDeaths').innerHTML=h2;
}
document.getElementById('ver').textContent='renderer v'+RENDERER_VERSION+' · schema v'+SCHEMA_VERSION;
buildControls(); refresh();
</script>
</body>
</html>
