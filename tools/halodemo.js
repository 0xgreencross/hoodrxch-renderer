const { chromium } = require('playwright'); const fs=require('fs');
const ctx=require('./render_cli.js');
(async()=>{
  let html='<body style="margin:0;background:#15202b;padding:16px;font-family:sans-serif;color:#8899a6">';
  for(const id of [225,54]){
    html+='<div style="margin-bottom:16px;display:flex;gap:10px;align-items:center">';
    for(const kills of [0,1,10,25,50,75,100]){
      const st=Object.assign(ctx.defaultState(id),{kills});
      const svg=ctx.renderSVG(st); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
      html+='<img width=150 height=150 src="'+d+'">';
    }
    html+='</div><div style="display:flex;gap:10px;margin-bottom:20px">';
    for(const kills of [1,10,25,50,75,100]){
      const st=Object.assign(ctx.defaultState(id),{kills});
      const svg=ctx.renderSVG(st); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
      html+='<img width=48 height=48 style="border-radius:50%" src="'+d+'"><img width=32 height=32 style="border-radius:50%" src="'+d+'">';
    }
    html+='</div>';
  }
  html+='<div style="font-size:12px">two tokens · tiers 0-100 at 150px, then tiers 1-100 at 48/32px circular</div>';
  const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1240,height:700},deviceScaleFactor:2});
  await p.setContent(html); await p.screenshot({path:'out/halo_ladder.png',fullPage:true}); await b.close();
})();
