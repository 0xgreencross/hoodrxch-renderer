const { chromium } = require('playwright');
(async()=>{
  const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1500,height:1000}});
  p.on('pageerror',e=>console.log('PAGEERROR',e.message)); p.on('console',m=>{ if(m.type()==='error') console.log('CONSOLE',m.text()); });
  await p.goto('file:///home/user/hoodrxch/reference-renderer/index.html');
  const tab=process.argv[2]||'wb';
  if(tab!=='wb'){ await p.click('button[data-tab="'+tab+'"]'); await p.waitForTimeout(6000); }
  await p.screenshot({path:'/home/user/hoodrxch/shot_'+tab+'.png',fullPage:process.argv[3]==='full'});
  await b.close();
})();
