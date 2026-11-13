/* =====================================================================
   AFTERKIN: NASCIDOS DA RUÍNA — GRID ISOMÉTRICO, AUTOTILE DE RUAS E TRANSIÇÕES ORGÂNICAS
   ---------------------------------------------------------------------
   GRID
     Mundo em tiles quadrados de 64 unidades. A tela é a projeção 2:1:
        tela.x = (x − y)·0.5      tela.y = (x + y)·0.25
     O chão é desenhado com a matriz afim (0.5, 0.25, −0.5, 0.25): cada
     textura quadrada de tiles.jpg vira um losango 64×32 sem distorção de
     pixel-art. Por isso o encaixe é exato: vizinhos compartilham arestas.

   SOBRE AS PEÇAS DE RUA DA FOLHA
     As peças rua_reta / rua_T / rua_curva / rotatoria da folha
     "construcoes" estão desenhadas em vista frontal (faixas horizontais),
     não em 2:1. Colocadas no grid elas ficariam tortas e com emendas. Por
     isso a malha viária usa os tiles de tiles.jpg (que são vista de cima,
     corretos para a matriz isométrica) com autotile, e as peças isométricas
     de verdade da folha (estacionamentos, viadutos, pontes) entram como
     estruturas sobre o grid, encaixadas por snapFootprint().

   AUTOTILE (bitmask de 4 vizinhos: N=1, L=2, S=4, O=8)
     Para cada tile de asfalto olhamos os vizinhos. Asfalto encostado em
     calçada recebe o tile de meio-fio da direção certa (20/21 = calçada ao
     norte, 22 = a oeste, 23 = a leste; sul = 20 espelhado). Faixas
     amarelas só onde a via é reta (máscara N+S ou L+O), nunca dentro do
     cruzamento. Tiles direcionais nunca são espelhados aleatoriamente.

   TRANSIÇÕES SEM LINHA RETA
     Antes, a borda entre materiais era um degradê LINEAR → linha reta
     visível em cada tile. Agora:
       • cada material tem PRIORIDADE (grama > folhas > terra > cascalho >
         calçada > asfalto). Só o material mais "invasivo" avança sobre o
         vizinho — grama cobre o meio-fio, nunca o contrário;
       • a borda tem contorno de RUÍDO (fbm ao longo da aresta, contínuo
         entre tiles vizinhos) e um DEGRADÊ LARGO (~40% do tile): a textura
         vizinha dissolve suavemente, sem pontilhado nem corte;
       • uma camada de cor média (1 px por tile, ampliada com filtro
         bilinear) cria um gradiente contínuo de cor entre materiais;
       • cantos diagonais recebem uma "mancha" de canto para não sobrar o
         dente quadrado onde duas bordas se encontram.
   ===================================================================== */
(function(){
'use strict';
const TILE=64;
const ASPH=new Set([14,15,16,17,20,21,22,23]);
const SIDEWALK=new Set([12,13,28]);
const DIRECTIONAL=new Set([16,17,18,19,20,21,22,23,29,31]);
// prioridade de invasão de borda
function prio(t){
  if(t===0||t===1||t===2||t===3||t===7)return 6;   // grama
  if(t===4||t===5)return 5;                        // grama seca / folhas
  if(t===6||t===8||t===9||t===11||t===38||t===30||t===36)return 4; // terra
  if(t===10||t===37)return 3;                      // cascalho / entulho
  if(t===12||t===13||t===28||t===35||t===39)return 2; // calçada / piso
  if(ASPH.has(t)||t===18||t===19)return 1;         // asfalto
  return 0}                                        // água, madeira: sem borda
const noBlend=(a,b)=>{const pa=prio(a),pb=prio(b);if(!pa||!pb)return true;
  if(a===18||a===19||b===18||b===19)return true;               // faixa de pedestre
  if(pa<=2&&pb<=2)return true;                                  // asfalto ↔ calçada: o meio-fio resolve
  return false};

/* ---------- hash e ruído determinísticos ---------- */
const H=(x,y)=>{let n=Math.sin(x*127.1+y*311.7)*43758.5453;return n-Math.floor(n)};
const N1=x=>{const i=Math.floor(x),f=x-i,u=f*f*(3-2*f);return H(i,7.3)*(1-u)+H(i+1,7.3)*u};
const fbm=x=>N1(x)*.55+N1(x*2.3+5)*.28+N1(x*5.1+11)*.17;
// ruído PERIÓDICO (período p na rede inteira): a borda do tile k termina
// exatamente onde a do tile k+1 começa, e o ciclo de 4 variantes fecha sem emenda
const NP=(x,p)=>{const i=Math.floor(x),f=x-i,u=f*f*(3-2*f),a=((i%p)+p)%p,b=(((i+1)%p)+p)%p;return H(a,3.1)*(1-u)+H(b,3.1)*u};
const fbmP=x=>NP(x*2,8)*.6+NP(x*6+.5,24)*.4;

/* ---------- AUTOTILE: roda uma vez depois de gerar o mapa ----------
   TO: {chave:tile}, TF: {chave:bits} (1 = espelhar X, 2 = espelhar Y, 4 = fixo)
   W,H em tiles; key(x,y) */
function autotileRoads(TO,TF,W,Hh,key){
  const at=(x,y)=>TO[key(x,y)];
  const isA=t=>t!==undefined&&ASPH.has(t),isS=t=>t!==undefined&&SIDEWALK.has(t);
  const out=[];
  for(const k in TO){const t=TO[k];if(!ASPH.has(t))continue;
    const y=Math.floor(k/1000),x=k%1000;
    const n=at(x,y-1),e=at(x+1,y),s=at(x,y+1),w=at(x-1,y);
    const road=(isA(n)?1:0)|(isA(e)?2:0)|(isA(s)?4:0)|(isA(w)?8:0);
    const walk=(isS(n)?1:0)|(isS(e)?2:0)|(isS(s)?4:0)|(isS(w)?8:0);
    let nt=t,f=0;
    if(t===16||t===17){ // faixa amarela: só em trecho reto
      const straightH=(road&10)===10&&!(road&5),straightV=(road&5)===5&&!(road&10);
      if(t===16&&!straightH)nt=14;if(t===17&&!straightV)nt=14}
    else if(walk){ // meio-fio na direção da calçada
      if(walk&1){nt=H(x,y)<.5?20:21;f=4}
      else if(walk&4){nt=H(x,y)<.5?20:21;f=2|4}
      else if(walk&8){nt=22;f=4}
      else if(walk&2){nt=23;f=4}}
    out.push([k,nt,f])}
  for(const [k,nt,f] of out){TO[k]=nt;if(f)TF[k]=f}
  // marca os direcionais restantes como "não espelhar"
  for(const k in TO)if(DIRECTIONAL.has(TO[k])&&TF[k]===undefined)TF[k]=4;
}

/* ---------- máscaras de borda orgânica ----------
   Desenhadas em espaço de TEXTURA (64×64) antes da matriz isométrica.
   side: 0=N 1=L 2=S 3=O  — a borda fica do lado do vizinho invasor. */
const MASK={},CORNER={};
const sstep=(a,b,x)=>{const t=Math.min(1,Math.max(0,(x-a)/(b-a)));return t*t*(3-2*t)};
function edgeMask(side,v){const k=side*8+v;if(MASK[k])return MASK[k];
  const S=64,c=document.createElement('canvas');c.width=c.height=S;const g=c.getContext('2d'),id=g.createImageData(S,S),d=id.data;
  for(let y=0;y<S;y++)for(let x=0;x<S;x++){
    // u = posição ao longo da aresta, dist = distância até a aresta (0..1)
    const u=(side===0||side===2?x:y)/S,dist=(side===0?y:side===1?S-1-x:side===2?S-1-y:x)/S;
    // contorno orgânico (ruído contínuo entre tiles) + DEGRADÊ LARGO (40% do tile)
    // no lugar do corte pontilhado: a textura vizinha "dissolve" suavemente
    const reach=.18+.30*fbmP(v+u);
    const a=1-sstep(reach-.18,reach+.22,dist);
    d[(y*S+x)*4+3]=a*255;d[(y*S+x)*4]=d[(y*S+x)*4+1]=d[(y*S+x)*4+2]=255}
  g.putImageData(id,0,0);return MASK[k]=c}
function cornerMask(corner,v){const k=corner*8+v;if(CORNER[k])return CORNER[k];
  // corner: 0=NO 1=NE 2=SE 3=SO
  const S=64,c=document.createElement('canvas');c.width=c.height=S;const g=c.getContext('2d'),id=g.createImageData(S,S),d=id.data;
  const cx=corner===1||corner===2?S:0,cy=corner>=2?S:0;
  for(let y=0;y<S;y++)for(let x=0;x<S;x++){const r=Math.hypot(x-cx,y-cy)/S,ang=Math.atan2(y-cy,x-cx);
    const reach=.22+.16*fbm(ang*4+v*9.7),a=1-sstep(reach-.14,reach+.2,r);
    d[(y*S+x)*4+3]=a*255;d[(y*S+x)*4]=d[(y*S+x)*4+1]=d[(y*S+x)*4+2]=255}
  g.putImageData(id,0,0);return CORNER[k]=c}

/* textura do material vizinho recortada pela máscara (cache por material×máscara) */
const TEX={};
function maskedTex(tilesImg,src,t,mask,key){const k=t+'|'+key;if(TEX[k])return TEX[k];
  const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');
  g.drawImage(tilesImg,src[0],src[1],128,src[2],0,0,64,64);g.globalCompositeOperation='destination-in';g.drawImage(mask,0,0);return TEX[k]=c}

/**
 * Desenha as bordas orgânicas de um tile. Chamado dentro da passada do
 * chão, com o contexto JÁ na matriz isométrica (unidades de mundo).
 * tileAt(x,y) → id do tile;  srcOf(t) → [sx, sy, sh] em tiles.jpg
 */
function drawEdges(ctx,tilesImg,tileAt,srcOf,tx,ty,t){
  const pt=prio(t);if(!pt)return;
  const NB=[[0,-1],[1,0],[0,1],[-1,0]];let sides=0;
  // invade quem tem prioridade maior; empate entre materiais diferentes → decide o id (nunca os dois lados)
  const wins=nt=>{const pn=prio(nt);return pn>pt||(pn===pt&&nt>t)};
  for(let q=0;q<4;q++){const nt=tileAt(tx+NB[q][0],ty+NB[q][1]);if(nt===undefined||nt===t||noBlend(t,nt)||!wins(nt))continue;
    sides|=1<<q;const v=((q===0||q===2?tx:ty)%4+4)%4; // variante = posição ao longo da aresta → contínuo
    ctx.drawImage(maskedTex(tilesImg,srcOf(nt),nt,edgeMask(q,v),'e'+q+v),tx*TILE,ty*TILE,TILE,TILE)}
  // cantos: vizinho diagonal invasor sem bordas ortogonais que o cubram
  const DG=[[-1,-1,1|8],[1,-1,1|2],[1,1,4|2],[-1,1,4|8]];
  for(let c=0;c<4;c++){const [dx,dy,need]=DG[c];if(sides&need)continue;const nt=tileAt(tx+dx,ty+dy);
    if(nt===undefined||nt===t||noBlend(t,nt)||!wins(nt))continue;const v=Math.floor(H(tx*7+c,ty*3)*4);
    ctx.drawImage(maskedTex(tilesImg,srcOf(nt),nt,cornerMask(c,v),'c'+c+v),tx*TILE,ty*TILE,TILE,TILE)}
}

/* ---------- GRADIENTE DE MESCLA (camada de cor média) ----------
   Custo: 1 canvas de 125×102 px montado uma vez por mundo + 1 drawImage
   por quadro. Cada pixel = cor média do tile (pré-calculada de tiles.jpg).
   Esticada com suavização bilinear, vira um gradiente contínuo de um tile
   para o outro. Só tem alfa onde dois MATERIAIS diferentes se encontram;
   no meio de um gramado ou de uma rua a textura fica intacta. Asfalto,
   faixas, água e madeira ficam de fora (o meio-fio continua nítido). */
const AVG=[[82,86,56],[80,84,54],[85,85,57],[88,87,61],[119,97,77],[92,76,60],[76,68,64],[82,81,55],[108,88,76],[105,89,75],[105,97,90],[162,133,110],[132,122,113],[152,141,132],[74,73,79],[78,77,75],[78,74,71],[81,77,75],[118,113,111],[108,104,103],[90,85,84],[93,89,87],[89,85,84],[90,85,84],[33,54,66],[72,80,81],[146,129,115],[143,146,155],[91,88,86],[69,62,57],[66,61,53],[76,71,70],[97,78,67],[86,69,59],[124,122,110],[144,129,117],[88,58,51],[107,93,84],[75,66,61],[120,110,104]];
// classe de material: variações do mesmo material não contam como fronteira
const CLS=t=>t===0||t===1||t===2||t===3||t===7?1:t===4||t===5?2:t===6||t===8||t===9||t===38||t===30||t===36?3:t===11?4:t===10||t===37?5:t===12||t===13||t===28||t===35||t===39?6:t===26?7:0;
function buildBlendLayer(tileAt,W,Hh,strength=.34){
  const c=document.createElement('canvas');c.width=W;c.height=Hh;const g=c.getContext('2d'),id=g.createImageData(W,Hh),d=id.data;
  const cls=new Uint8Array(W*Hh),tt=new Uint8Array(W*Hh);
  for(let y=0;y<Hh;y++)for(let x=0;x<W;x++){const t=tileAt(x,y);tt[y*W+x]=t;cls[y*W+x]=CLS(t)}
  for(let y=0;y<Hh;y++)for(let x=0;x<W;x++){const i=y*W+x,k=cls[i],col=AVG[tt[i]]||[0,0,0];
    d[i*4]=col[0];d[i*4+1]=col[1];d[i*4+2]=col[2];if(!k){d[i*4+3]=0;continue}
    let edge=0;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){if(!dx&&!dy)continue;const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=W||ny>=Hh)continue;const nk=cls[ny*W+nx];if(nk&&nk!==k){edge=1;break}}
    d[i*4+3]=edge?strength*255:0}
  g.putImageData(id,0,0);return c}
/** desenha a camada (contexto já na matriz isométrica, unidades de mundo).
    Só o retângulo de tiles visível (+2 de margem) é amostrado: custo ~constante
    e pequeno, independente do tamanho do mapa. Filtro bilinear padrão. */
function drawBlendLayer(ctx,layer,tx0,ty0,tx1,ty1){
  tx0=Math.max(0,tx0-2);ty0=Math.max(0,ty0-2);tx1=Math.min(layer.width,tx1+2);ty1=Math.min(layer.height,ty1+2);
  const w=tx1-tx0,h=ty1-ty0;if(w<=0||h<=0)return;
  const s=ctx.imageSmoothingEnabled;ctx.imageSmoothingEnabled=true;
  ctx.drawImage(layer,tx0,ty0,w,h,tx0*TILE,ty0*TILE,w*TILE,h*TILE);ctx.imageSmoothingEnabled=s}

/* ---------- utilidades do grid ---------- */
const toScreen=(x,y)=>[(x-y)*.5,(x+y)*.25];
const toWorld=(sx,sy)=>[sx+2*sy,2*sy-sx];
const tileOf=(x,y)=>[Math.floor(x/TILE),Math.floor(y/TILE)];
/** alinha um footprint A×B ao grid: canto frontal no vértice de tile mais próximo */
function snapFootprint(x1,y1,A,B){const X1=Math.round(x1/TILE)*TILE,Y1=Math.round(y1/TILE)*TILE;return {x0:X1-A,y0:Y1-B,x1:X1,y1:Y1}}

window.AfterkinTerrain={TILE,autotileRoads,drawEdges,buildBlendLayer,drawBlendLayer,prio,noBlend,toScreen,toWorld,tileOf,snapFootprint,DIRECTIONAL};
})();
