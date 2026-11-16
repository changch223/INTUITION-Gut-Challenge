// 平衡模擬（自由練習）。用法：osascript -l JavaScript balance-sim.js <此資料夾的絕對路徑> [TGT;EG 或 -] [難度清單 如 0,1,2] [局數]
// 也可改成 Node：把 ObjC/$.NSString 讀檔換成 fs.readFileSync，把 run(argv) 換成 process.argv。
ObjC.import('Foundation');
function run(argv){
const dir=argv[0];let src=$.NSString.stringWithContentsOfFileEncodingError(dir+'/core.js',4,null).js;
if(argv[1]&&argv[1]!=='-'){const g=argv[1].split(';');src=src.replace(/TGT=\[[^\]]*\]/,'TGT=['+g[0]+']').replace(/EG=[0-9.]+/,'EG='+g[1])}
if(argv[4]){const m=argv[4].split(';');src=src.replace(/MUL=\[[^\]]*\]/,'MUL=['+m[0]+']').replace('tm<.28','tm<'+m[1])}
const C=new Function(src+';return {STAGES,BL,newG,genPair,pickCard,deltaOf,target,canClear,clearStage,nextStage,shopOffer,buyBless,targetAt}')();
const N=+(argv[3]||8000),LV=(argv[2]||'0').split(',').map(Number);
function choose(G,pol){const a=G.pair;if(pol==='safe')return a[0].d<a[1].d?0:1;if(pol==='risky')return a[0].d>a[1].d?0:1;
  const ev=c=>c.fog?0.66*C.deltaOf(G,{op:'+',n:6*(1+.3*(G.stage-1))}):(1-c.p)*C.deltaOf(G,c);return ev(a[0])>=ev(a[1])?0:1}
function sim(pol,shop,lv){const reach=[],clr=[];let all=0,deep=0;
  for(let n=0;n<N;n++){const G=C.newG((Math.random()*2147483647)|0,lv);G.pair=C.genPair(G);
    for(;;){reach[G.stage-1]=(reach[G.stage-1]||0)+1;
      while(G.picks>0&&!C.canClear(G)){C.pickCard(G,choose(G,pol));G.pair=C.genPair(G)}
      if(!C.canClear(G))break;
      clr[G.stage-1]=(clr[G.stage-1]||0)+1;C.clearStage(G);
      if(G.phase==='win'){all++;G.endless=true}
      if(G.stage>=30)break;
      if(shop){const of=C.shopOffer(G).sort((x,y)=>C.BL[x][2]-C.BL[y][2]);for(const k of of)C.buyBless(G,k)}
      C.nextStage(G)}
    deep+=G.stage-1}
  return{rate:reach.slice(0,12).map((r,i)=>Math.round((clr[i]||0)/r*100)),all:Math.round(all/N*1000)/10,deep:Math.round(deep/N*10)/10}}
const out=['T='+JSON.stringify([1,2,3,4,5,6,7,8,9,10].map(s=>C.targetAt(s,0)))];
for(const lv of LV){const R=lv===0?[sim('safe',0,0),sim('risky',0,0),sim('ev',0,0),sim('ev',1,0)]:[sim('ev',1,lv)];
  out.push('LV'+lv+' SIM='+JSON.stringify([0,1,2,3,4,5,6,7,8,9,10,11].map(i=>R.map(r=>r.rate[i])))+' ALL='+JSON.stringify(R.map(r=>r.all))+' DEEP='+JSON.stringify(R.map(r=>r.deep)))}
return out.join('\n')}
