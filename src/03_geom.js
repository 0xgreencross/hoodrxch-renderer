// ---------------------------------------------------------------------------
// Geometry primitives. Logical 100-unit grid → ×10 px. Integer output only.
// (Glitch.sol / SVGBuilder.sol equivalents.)
// ---------------------------------------------------------------------------
const U = 10; // px per unit
function jitterPts(pts, rng, amp){ // amp 1 or 2 units
  const o=[]; for(const p of pts){ let jx=rng.jit(), jy=rng.jit(); if(amp===1){ jx=Math.max(-1,Math.min(1,jx)); jy=Math.max(-1,Math.min(1,jy)); } o.push([p[0]+jx,p[1]+jy]); } return o;
}
function offsetPts(pts,dx,dy){ return pts.map(p=>[p[0]+dx,p[1]+dy]); }
function mirrorPts(pts,cx){ return pts.map(p=>[2*cx-p[0],p[1]]); }
// closed polygon path, relative integer commands, px
function pathD(pts){
  let d='M'+(pts[0][0]*U)+' '+(pts[0][1]*U);
  for(let i=1;i<pts.length;i++){ const dx=(pts[i][0]-pts[i-1][0])*U, dy=(pts[i][1]-pts[i-1][1])*U;
    if(dy===0) d+='h'+dx; else if(dx===0) d+='v'+dy; else d+='l'+dx+' '+dy; }
  return d+'z';
}
function poly(pts,fill,extra){ return '<path d="'+pathD(pts)+'" fill="'+fill+'"'+(extra||'')+'/>'; }
function rect(x,y,w,h,fill){ return '<rect x="'+x*U+'" y="'+y*U+'" width="'+w*U+'" height="'+h*U+'" fill="'+fill+'"/>'; }
// crude-clean stroked polyline: each segment gets a width from the 3-value set;
// segments are grouped by width into ≤3 paths. closed=true joins last→first.
function strokeLine(pts,rng,color,closed,scale){
  const groups={}; const n=closed?pts.length:pts.length-1;
  for(let i=0;i<n;i++){ const a=pts[i], b=pts[(i+1)%pts.length]; const w=rng.sw()*(scale||1);
    (groups[w]=groups[w]||[]).push('M'+(a[0]*U)+' '+(a[1]*U)+'l'+((b[0]-a[0])*U)+' '+((b[1]-a[1])*U)); }
  let s=''; for(const w of Object.keys(groups).sort((a,b)=>a-b)) s+='<path d="'+groups[w].join('')+'" fill="none" stroke="'+color+'" stroke-width="'+w+'" stroke-linecap="square"/>';
  return s;
}
function thickLine(pts,color,w){ let d=''; for(let i=0;i<pts.length-1;i++){ const a=pts[i],b=pts[i+1]; d+='M'+(a[0]*U)+' '+(a[1]*U)+'l'+((b[0]-a[0])*U)+' '+((b[1]-a[1])*U); } return '<path d="'+d+'" fill="none" stroke="'+color+'" stroke-width="'+w+'" stroke-linecap="square"/>'; }
// solid drip: a tapered polygon hanging from (x,y) of length len (units)
function drip(x,y,len,w,fill,rng){ const pts=[[x-w,y],[x+w,y],[x+w,y+len-2],[x,y+len],[x-w,y+len-2]]; return poly(jitterPts(pts,rng,1),fill); }
// displacement slice of group #id: band [y,y+h) shifted dx units. idx numbers the clipPath.
function slice(id,idx,y,h,dx,groundFill){
  return '<clipPath id="c'+idx+'"><rect x="0" y="'+(y*U)+'" width="1000" height="'+(h*U)+'"/></clipPath>'
       + '<g clip-path="url(#c'+idx+')"><rect width="1000" height="1000" fill="'+groundFill+'"/><use href="#'+id+'" transform="translate('+(dx*U)+' 0)"/></g>';
}
// X mark centred at (cx,cy), half-size r, bar width b (units)
function xmark(cx,cy,r,b,fill,rng){
  const a=[[cx-r,cy-r+b],[cx-r+b,cy-r],[cx+r,cy+r-b],[cx+r-b,cy+r]];
  const c=[[cx+r-b,cy-r],[cx+r,cy-r+b],[cx-r+b,cy+r],[cx-r,cy+r-b]];
  return poly(jitterPts(a,rng,1),fill)+poly(jitterPts(c,rng,1),fill);
}
