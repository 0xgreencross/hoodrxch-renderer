const { chromium } = require('playwright'); const fs=require('fs');
(async()=>{ const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1240,height:260},deviceScaleFactor:2});
 let html='<body style="margin:0;background:#15202b;padding:14px;font-family:sans-serif"><div style="display:flex;gap:16px">';
 for(const id of process.argv.slice(2)){ const svg=fs.readFileSync('out/'+id+'.svg','utf8'); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
  html+='<div style="display:flex;flex-direction:column;align-items:center;gap:8px;color:#8899a6;font-size:11px"><img width=96 height=96 style="border-radius:50%" src="'+d+'"><img width=48 height=48 style="border-radius:50%" src="'+d+'"><img width=32 height=32 style="border-radius:50%" src="'+d+'"><span>#'+id+'</span></div>'; }
 html+='</div><div style="color:#8899a6;font-size:12px;margin-top:8px">X avatar simulation — 96 / 48 / 32 px circular on timeline background</div>';
 await p.setContent(html); await p.screenshot({path:'out/pfp_strip.png',fullPage:true}); await b.close(); })();
