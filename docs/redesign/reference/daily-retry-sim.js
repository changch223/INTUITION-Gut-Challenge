// 今日挑戰重打模擬（會記住翻過的牌）。用法：osascript -l JavaScript daily-retry-sim.js <此資料夾的絕對路徑> <目標倍率 如 1.3> <記憶率 0~1> [天數]
ObjC.import('Foundation');
function run(argv){
const dir=argv[0];const src=$.NSString.stringWithContentsOfFileEncodingError(dir+'/core.js',4,null).js;
const C=new Function(src+';return {BL,newG,genPair,pickCard,deltaOf,target,canClear,clearStage,nextStage,shopOffer,buyBless}')();
const TM=+argv[1],REC=+argv[2],N=+(argv[3]||3000),MAXA=6;
function play(seed,mem){const G=C.newG(seed,0);G.tm=TM;G.pair=C.genPair(G);
  for(;;){
    while(G.picks>0&&!C.canClear(G)){const a=G.pair,key=G.stage+':'+G.idx;const m=mem[key]||{};
      const pr=(c,i)=>m[i]===undefined?(c.fog?.34:c.p):(m[i]?1:0);
      const ev=(c,i)=>(1-pr(c,i))*(c.fog?C.deltaOf(G,{op:'+',n:6*(1+.3*(G.stage-1))}):C.deltaOf(G,c));
      const i=ev(a[0],0)>=ev(a[1],1)?0:1;const boom=a[i].boom;
      if(Math.random()<REC){mem[key]=mem[key]||{};mem[key][i]=boom}
      C.pickCard(G,i);G.pair=C.genPair(G)}
    if(!C.canClear(G))return false;
    C.clearStage(G);if(G.phase==='win')return true;
    const of=C.shopOffer(G).sort((x,y)=>C.BL[x][2]-C.BL[y][2]);for(const k of of)C.buyBless(G,k);
    C.nextStage(G)}}
const by=new Array(MAXA).fill(0);
for(let n=0;n<N;n++){const seed=(Math.random()*2147483647)|0,mem={};for(let a=0;a<MAXA;a++){if(play(seed,mem)){by[a]++;break}}}
let c=0;return 'TM='+TM+' REC='+REC+' cum%='+by.map(x=>{c+=x;return Math.round(c/N*100)}).join(',')}
