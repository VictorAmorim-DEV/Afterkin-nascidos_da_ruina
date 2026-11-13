/* =====================================================================
   AFTERKIN: NASCIDOS DA RUÍNA — ORDENAÇÃO DE PROFUNDIDADE ISOMÉTRICA (Y-SORT / Z-ORDER)
   ---------------------------------------------------------------------
   Por que (x+y) de um ponto não basta:
     Um prédio de 7×5 tiles e um personagem são comparados por UM ponto
     cada. Se o personagem está ao lado do prédio, mas o ponto-base do
     prédio fica "à frente" do dele, o prédio é desenhado por cima mesmo
     com o personagem estando na calçada da frente. Daí o bug de perspectiva.

   A solução clássica (ordenação topológica por footprint):
     Cada item tem um FOOTPRINT no chão (retângulo no mundo: x0..x1, y0..y1)
     e uma CAIXA DE TELA (sx0..sx1, sy0..sy1). Só importa a ordem entre itens
     cujas caixas de tela se sobrepõem. Para esses pares:

        A fica atrás de B  ⇔  A.x1 ≤ B.x0   ou   A.y1 ≤ B.y0
        (a câmera olha de +x/+y: menor x ou menor y = mais longe)

     Se os footprints se interpenetram (nenhuma das regras decide), usamos
     o centro (x+y) como desempate. Monta-se um grafo "A antes de B" e
     faz-se uma ordenação topológica (DFS). Ciclos (raros, por footprints
     mal configurados) são quebrados sem travar.

   Custo: um hash espacial na tela limita as comparações a vizinhos.
   Com 300–600 itens visíveis fica em ~1 ms por quadro.
   ===================================================================== */
(function(){
'use strict';
const EPS=0.01;

/** a deve ser desenhado antes de b? (+1 = sim, −1 = não, 0 = indiferente) */
function compare(a,b){
  const aBehind=(a.x1<=b.x0+EPS)||(a.y1<=b.y0+EPS);
  const bBehind=(b.x1<=a.x0+EPS)||(b.y1<=a.y0+EPS);
  if(aBehind&&!bBehind)return 1;
  if(bBehind&&!aBehind)return -1;
  // ambos ou nenhum: footprints em diagonal ou interpenetrados → centro
  const ca=a.x0+a.x1+a.y0+a.y1,cb=b.x0+b.x1+b.y0+b.y1;
  if(ca!==cb)return ca<cb?1:-1;
  return (a.bias||0)<=(b.bias||0)?1:-1; // desempate fixo (ex.: portão sobre cerca)
}

const CELL=160;
/** items: [{x0,y0,x1,y1, sx0,sy0,sx1,sy1, draw, bias?}] → array ordenado */
function sort(items){
  const n=items.length;if(n<2)return items;
  // 1) hash espacial pelas caixas de tela
  const grid=new Map();
  for(let i=0;i<n;i++){const it=items[i];it._i=i;it._deps=null;it._mark=0;
    const cx0=Math.floor(it.sx0/CELL),cx1=Math.floor(it.sx1/CELL),cy0=Math.floor(it.sy0/CELL),cy1=Math.floor(it.sy1/CELL);
    for(let cy=cy0;cy<=cy1;cy++)for(let cx=cx0;cx<=cx1;cx++){const k=cx*73856093^cy*19349663;let c=grid.get(k);if(!c){c=[];grid.set(k,c)}c.push(i)}}
  // 2) arestas "a antes de b" só para pares que se sobrepõem na tela
  const seen=new Uint32Array(n);let stamp=0;
  for(const cell of grid.values()){
    for(let p=0;p<cell.length;p++){const ia=cell[p],a=items[ia];stamp++;
      for(let q=p+1;q<cell.length;q++){const ib=cell[q];if(ib===ia||seen[ib]===stamp)continue;seen[ib]=stamp;
        const b=items[ib];
        if(a.sx1<=b.sx0||b.sx1<=a.sx0||a.sy1<=b.sy0||b.sy1<=a.sy0)continue;
        const r=compare(a,b);
        if(r>0)(b._deps||(b._deps=[])).push(a);else (a._deps||(a._deps=[])).push(b);}}}
  // 3) ordenação topológica (DFS iterativo; 1 = visitando, 2 = pronto)
  const out=[];
  // ordem inicial estável pelo centro → resultado determinístico e com poucas trocas
  const order=items.slice().sort((a,b)=>(a.x0+a.x1+a.y0+a.y1)-(b.x0+b.x1+b.y0+b.y1));
  const stack=[];
  for(const root of order){if(root._mark)continue;stack.push(root,0);
    while(stack.length){const k=stack.pop(),node=stack.pop();
      if(k===0){if(node._mark)continue;node._mark=1;stack.push(node,1);
        const d=node._deps;if(d)for(let j=d.length-1;j>=0;j--)if(!d[j]._mark)stack.push(d[j],0)}
      else if(node._mark===1){node._mark=2;out.push(node)}}}
  return out;
}

/* ---------- modo alternativo: Y puro do pivô ----------
   Ordena só pela profundidade do PONTO DE CONTATO (x1 + y1 = Y de tela do pé).
   Funciona para objetos pequenos (personagem, poste, árvore); para prédios
   com base grande ele erra quando o personagem está ao lado da fachada
   leste/sul — por isso o padrão é sort() (base inteira). F4 alterna. */
function sortY(items){return items.slice().sort((a,b)=>(a.x1+a.y1)-(b.x1+b.y1)||(a.bias||0)-(b.bias||0))}

/* ---------- construtores de itens ---------- */
const PXf=(x,y)=>(x-y)*0.5,PYf=(x,y)=>(x+y)*0.25;
/** footprint retangular + caixa de tela do sprite desenhado */
function spriteItem(fp,dx,dy,dw,dh,draw,extra){
  return Object.assign({x0:fp.x0,y0:fp.y0,x1:fp.x1,y1:fp.y1,sx0:dx,sy0:dy,sx1:dx+dw,sy1:dy+dh,draw},extra||{})}
/** objeto pequeno (personagem, poste, árvore): footprint = ponto ± r */
function pointItem(x,y,r,sx0,sy0,sx1,sy1,draw,extra){
  return Object.assign({x0:x-r,y0:y-r,x1:x+r,y1:y+r,sx0,sy0,sx1,sy1,draw},extra||{})}
/** segmento (cerca, varal): footprint fino ao longo do segmento */
function segItem(ax,ay,bx,by,h,draw,extra){
  const x0=Math.min(ax,bx),x1=Math.max(ax,bx),y0=Math.min(ay,by),y1=Math.max(ay,by),t=2;
  const pxs=[PXf(ax,ay),PXf(bx,by)],pys=[PYf(ax,ay),PYf(bx,by)];
  return Object.assign({x0:x0-t,y0:y0-t,x1:x1+t,y1:y1+t,sx0:Math.min(...pxs)-6,sx1:Math.max(...pxs)+6,sy0:Math.min(...pys)-h,sy1:Math.max(...pys)+6,draw},extra||{})}

/* ---------- oclusão: personagem atrás de prédio/árvore ----------
   Depois de ordenar, todo oclusor desenhado DEPOIS do jogador cuja
   silhueta cobre o tronco dele recebe fadeTarget (ex.: 0.35). O alfa
   real (it.obj.fade) é interpolado no tempo pelo jogo. O teste é por
   pixel quando a peça tem máscara de alfa (sprites do atlas). */
function occluders(sorted,playerItem,px,py){
  const res=[];let after=false;
  for(const it of sorted){
    if(it===playerItem){after=true;continue}
    if(!after||!it.occluder)continue;
    if(px<it.sx0||px>it.sx1||py<it.sy0||py>it.sy1)continue;
    if(it.alphaAt&&it.alphaAt(px,py)<60)continue;
    res.push(it)}
  return res}

window.AfterkinDepth={sort,sortY,compare,spriteItem,pointItem,segItem,occluders};
})();
