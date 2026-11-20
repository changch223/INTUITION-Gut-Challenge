const P=[.1,.25,.42,.6],ADD=[3,5,7,10],MUL=[0,1.5,2,3],PICKS=7,STAGES=6,STR=1.5,TGT=[18,34,56,80,145,240],EG=1.25;
const BOSSES=['fog','crush','short','shaky'];
const BOSSN={fog:['濃霧','其中一張牌完全蓋住，翻開才知道分數和危險度'],crush:['重壓','爆炸時，這關目前的分數砍半（前面各關不受影響）'],short:['急迫','這關少 2 手'],shaky:['不穩','每張牌爆炸率 +10%']};
const DIFF=[['入門','標準規則'],['進階','目標分數 ×1.15'],['老手','每關少 1 手'],['專家','開局沒有保命符和道具'],['大師','每張牌爆炸率 +5%'],['傳說','商店貴 $1，過關基本獎勵只剩 $2']];
const BL={add:['加碼','加分牌的分數 +25%，可以重複買',4,1,'任何打法'],snow:['滾雪球','倍數牌的倍率 +0.5，可以重複買',6,1,'高危險大倍數'],cool:['穩手','危險 1 格的牌絕對不會爆',5,0,'安全連中'],gamb:['賭徒','危險 4 格的牌獎勵變 1.5 倍',5,0,'高危險大倍數'],hot:['連勝體質','連中加成上限從 2 倍提高到 3 倍（連中 8 次）',6,0,'安全連中'],grit:['不屈','爆炸時連中減半（無條件進位），不會歸零',5,0,'安全連中'],hand:['多一手','每關多 1 手，可以重複買',6,1,'任何打法'],eye:['千里眼','每關開始時送 1 個透視',5,0,'魔王關'],bank:['利息','過關時每持有 $5 多拿 $1，最多 $3',4,0,'越早買越好'],defuse:['拆彈','每關第一次爆炸無效',7,0,'高危險大倍數']};
const SHOP={peek:['透視',3],roll:['重抽',2],dbl:['雙倍',3],shield:['保命符',4]};
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function seedOf(){let h=2166136261;for(let i=0;i<arguments.length;i++){h^=arguments[i];h=Math.imul(h,16777619);h^=h>>>13}return h>>>0}
const BOSS6=['fog','shaky','crush'],BOSSE=['short','fog','shaky','crush'];
const bossOf=s=>s%2!==0?'':s<=STAGES?BOSS6[s/2-1]:BOSSE[(s/2-4)%4];
const MODS={heat:['加溫','連中加成翻倍：每連中一次得分 +50%（上限不變）'],calm:['平靜','不會出現危險 4 格的牌'],wild:['狂野','倍數牌的出現率加倍'],lean:['精簡','少 1 手，但過關基本獎勵 +$3'],rich:['豐收','剩下的每一手換 $2'],small:['穩賺','危險 1 格的牌分數 ×2'],fuse:['短引信','每張牌爆炸率 +8%，加分牌分數 ×1.4'],gold:['淘金','每選中一張牌 +$1']};
const MODK=Object.keys(MODS);
const modAt=(seed,s)=>bossOf(s)?'':MODK[seedOf(seed,s,99)%MODK.length];
const modOf=G=>modAt(G.seed,G.stage);
function nice(x){if(x<100)return Math.round(x);const p=Math.pow(10,Math.floor(Math.log10(x))-1);return Math.round(x/p)*p}
function targetAt(s,lv){const t=s<=STAGES?TGT[s-1]:TGT[STAGES-1]*Math.pow(EG,s-STAGES);return nice(t*(lv>=1?1.15:1))}
const DAILY_TM=1.3;
const targetOf=(G,s)=>nice(targetAt(s,G.lv)*(G.tm||1));
const target=G=>targetOf(G,G.stage);
const stretch=G=>nice(target(G)*STR);
const maxPicks=G=>Math.max(1,PICKS+(G.bl.hand||0)-(G.lv>=2?1:0));
const stagePicks=G=>Math.max(1,maxPicks(G)-(bossOf(G.stage)==='short'?2:0)-(modOf(G)==='lean'?1:0));
const price=(G,n)=>n+(G.lv>=5?1:0);
const canClear=G=>G.value>=target(G)&&G.picks<G.sp;
function newG(seed,lv){lv=lv||0;const G={ver:6,seed:seed,lv:lv,stage:1,value:0,picks:0,sp:0,idx:0,rr:0,srr:0,streak:0,coins:0,shield:lv>=3?0:1,inv:lv>=3?{peek:0,roll:0,dbl:0}:{peek:1,roll:1,dbl:0},bl:{},dbl:false,peek:false,defused:false,adUsed:false,marks:[],total:0,pair:null,offer:null,phase:'play',endless:false};G.picks=G.sp=stagePicks(G);return G}
const smult=G=>Math.min(1+(modOf(G)==='heat'?.5:.25)*G.streak,G.bl.hot?3:2);
function genPair(G){const r=mulberry(seedOf(G.seed,G.stage,G.idx,G.rr));
  const md=modOf(G),top=md==='calm'?3:4,d1=1+Math.floor(r()*top);let d2=1+Math.floor(r()*(top-1));if(d2>=d1)d2++;
  const sc=(1+.3*(G.stage-1))*(1+.25*(G.bl.add||0)),bs=bossOf(G.stage),dp=(G.lv>=4?.05:0)+(bs==='shaky'?.1:0)+(md==='fuse'?.08:0);
  const mk=d=>{const u=r(),tm=r(),b=r(),c={d:d,p:Math.round((P[d-1]+dp)*100)/100};
    if(d===1&&G.bl.cool)c.p=0;
    if(tm<(md==='wild'?.56:.28)&&d>1&&G.value>=4){c.op='×';c.n=MUL[d-1]+.5*(G.bl.snow||0);if(d===4&&G.bl.gamb)c.n*=1.5}
    else{c.op='+';c.n=Math.max(1,Math.round(ADD[d-1]*sc*(.75+.6*u)*(md==='fuse'?1.4:1)*(md==='small'&&d===1?2:1)));if(d===4&&G.bl.gamb)c.n=Math.round(c.n*1.5)}
    c.boom=b<c.p;return c};
  const a=mk(d1),b=mk(d2),f=r()<.5?0:1;
  if(bs==='fog')[a,b][f].fog=true;
  return[a,b]}
function deltaOf(G,c){const base=c.op==='+'?c.n:G.value*(c.n-1);return Math.round(base*smult(G)*(G.dbl?2:1))}
function pickCard(G,i){const c=G.pair[i];let ev;
  if(c.boom){
    if(G.bl.defuse&&!G.defused){G.defused=true;ev={kind:'defuse'}}
    else if(G.shield>0){G.shield--;ev={kind:'shield'}}
    else{const s0=G.streak;G.streak=G.bl.grit?Math.ceil(s0/2):0;let lost=0;if(bossOf(G.stage)==='crush'){lost=Math.floor(G.value/2);G.value-=lost}G.picks--;ev={kind:'boom',lost:lost,s0:s0,s1:G.streak}}
  }else{const d=deltaOf(G,c);G.value+=d;G.streak++;G.picks--;if(modOf(G)==='gold')G.coins++;ev={kind:'safe',delta:d}}
  G.dbl=false;G.peek=false;G.idx++;G.rr=0;return ev}
function rewardParts(G){const md=modOf(G),a=[['基本',(G.lv>=5?2:3)+(md==='lean'?3:0)],['剩 '+G.picks+' 手',G.picks*(md==='rich'?2:1)]];if(G.value>=stretch(G))a.push(['超標',3]);if(G.bl.bank){const x=Math.min(3,Math.floor(G.coins/5));if(x)a.push(['利息',x])}return a}
function reward(G){return rewardParts(G).reduce((s,p)=>s+p[1],0)}
function clearStage(G){G.lastParts=rewardParts(G);const rw=reward(G);G.marks.push(G.value>=stretch(G)?2:1);G.coins+=rw;G.total+=G.value;G.phase=(!G.endless&&G.stage>=STAGES)?'win':'shop';return rw}
function failStage(G){G.marks.push(0);G.total+=G.value;G.phase='over'}
function nextStage(G){G.stage++;G.value=0;G.picks=G.sp=stagePicks(G);G.idx=0;G.rr=0;G.srr=0;G.defused=false;G.dbl=false;G.peek=false;if(G.bl.eye)G.inv.peek++;G.phase='play';G.pair=genPair(G)}
function shopOffer(G){const r=mulberry(seedOf(G.seed,77,G.stage,G.srr)),full=Object.keys(G.bl).length>=5;
  const pool=Object.keys(BL).filter(k=>G.bl[k]?BL[k][3]:!full);
  for(let i=pool.length-1;i>0;i--){const j=Math.floor(r()*(i+1)),t=pool[i];pool[i]=pool[j];pool[j]=t}
  return pool.slice(0,3)}
function buyBless(G,k){const b=BL[k];if(!b||G.coins<price(G,b[2]))return false;if(!G.bl[k]&&Object.keys(G.bl).length>=5)return false;if(G.bl[k]&&!b[3])return false;G.coins-=price(G,b[2]);G.bl[k]=(G.bl[k]||0)+1;return true}
function buyItem(G,k){const s=SHOP[k];if(!s||G.coins<price(G,s[1]))return false;G.coins-=price(G,s[1]);if(k==='shield')G.shield++;else G.inv[k]++;return true}
