const { chromium } = require('playwright'); const fs=require('fs');
const ctx=require('./render_cli.js');
const modes=[['A','CROWN BEACON — floats above the peak'],['B','THIRD-EYE BRAND — stamped in the forehead'],['C','EDGE MEDALLION — rank chip, right edge'],['D','SIGNAL WATERMARK — the lines themselves form it']];
(async()=>{
  let html='<body style="margin:0;background:#15202b;padding:16px;font-family:sans-serif;color:#8899a6">';
  for(const [m,label] of modes){
    html+='<div style="margin-bottom:18px"><div style="font-size:13px;margin-bottom:6px;color:#e7e9ea">'+m+' — '+label+'</div><div style="display:flex;gap:10px;align-items:center">';
    for(const kills of [1,10,25,50,75,100]){
      const st=Object.assign(ctx.defaultState(225),{kills,_glyphMode:m});
      const svg=ctx.renderSVG(st); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
      html+='<img width=150 height=150 src="'+d+'">';
    }
    for(const kills of [25,100]){
      const st=Object.assign(ctx.defaultState(225),{kills,_glyphMode:m});
      const svg=ctx.renderSVG(st); const d='data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64');
      html+='<img width=48 height=48 style="border-radius:50%" src="'+d+'"><img width=32 height=32 style="border-radius:50%" src="'+d+'">';
    }
    html+='</div></div>';
  }
  html+='<div style="font-size:12px">each row: tiers 1/10/25/50/75/100 at 150px · then SAVAGE + REAPER at 48/32px circular</div>';
  const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1240,height:800},deviceScaleFactor:2});
  await p.setContent(html); await p.screenshot({path:'out/glyph_options.png',fullPage:true}); await b.close();
})();
