// node render_cli.js tokenId [json-state-overrides] → writes out/<id>.svg and prints byte size
const fs=require('fs'); const src=fs.readFileSync('reference-renderer/index.html','utf8');
const js=src.slice(src.indexOf("'use strict';"), src.indexOf('// Workbench UI'));
const vm=require('vm'); const ctx={console,TextEncoder,btoa:(s)=>Buffer.from(s,'binary').toString('base64'),unescape:(s)=>s,encodeURIComponent:(s)=>s}; vm.createContext(ctx); vm.runInContext(js,ctx);
module.exports=ctx;
if(require.main===module){ const id=Number(process.argv[2]||1); const st=Object.assign(ctx.defaultState(id),JSON.parse(process.argv[3]||'{}')); const svg=ctx.renderSVG(st); fs.mkdirSync('out',{recursive:true}); fs.writeFileSync('out/'+id+'.svg',svg); console.log(id,Buffer.byteLength(svg),'bytes',ctx.resolveStatus(st)); }
