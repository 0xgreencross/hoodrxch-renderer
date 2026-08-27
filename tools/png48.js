const { chromium } = require('playwright'); const fs=require('fs');
(async()=>{ const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1180,height:660}});
 const files=process.argv.slice(2); let html='<body style="margin:0;background:#15202b;display:flex;gap:10px;flex-wrap:wrap;align-items:flex-start;padding:8px">';
 for(const f of files){ const svg=fs.readFileSync(f,'utf8'); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
  html+='<div style="display:flex;flex-direction:column;gap:6px"><img width=512 height=512 src="'+d+'"><div style="display:flex;gap:8px;align-items:center"><img width=128 height=128 src="'+d+'"><img width=64 height=64 src="'+d+'"><img width=48 height=48 style="border-radius:50%" src="'+d+'"><img width=32 height=32 style="border-radius:50%" src="'+d+'"></div></div>'; }
 await p.setContent(html); await p.screenshot({path:'out/preview48.png',fullPage:true}); await b.close(); })();
