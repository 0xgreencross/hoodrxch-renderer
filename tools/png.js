const { chromium } = require('playwright'); const fs=require('fs');
(async()=>{ const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1100,height:560}});
 const files=process.argv.slice(2); let html='<body style="margin:0;background:#222;display:flex;gap:8px;flex-wrap:wrap">';
 for(const f of files){ const svg=fs.readFileSync(f,'utf8'); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64'); html+='<div><img width=512 height=512 src="'+d+'"><br><img width=128 height=128 src="'+d+'"><img width=64 height=64 src="'+d+'"><img width=32 height=32 src="'+d+'"></div>'; }
 await p.setContent(html); await p.screenshot({path:'out/preview.png',fullPage:true}); await b.close(); })();
