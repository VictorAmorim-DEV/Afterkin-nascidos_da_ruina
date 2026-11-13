/* =====================================================================
   AFTERKIN: NASCIDOS DA RUÍNA — ILUMINAÇÃO 2D COM MÁSCARA DE LUZ
   ---------------------------------------------------------------------
   Pipeline por quadro (só roda quando a luz ambiente não é dia pleno ou
   há luzes acesas):

   1. LIGHT BUFFER (canvas fora da tela, meia resolução)
      preenchido com a COR AMBIENTE da hora do dia (noite = azul escuro).

   2. LUZES ADITIVAS ('lighter') desenhadas no PLANO DO CHÃO:
      o contexto recebe a mesma câmera do jogo + a matriz isométrica
      (0.5, 0.25, −0.5, 0.25). Assim um gradiente radial circular no mundo
      vira automaticamente uma elipse 2:1 na tela, sem matemática extra.
      Cada luz é recortada por um POLÍGONO DE VISIBILIDADE calculado contra
      os footprints dos prédios (ray casting). Resultado: os prédios
      projetam sombra própria da lanterna/poste, coerente com o mapa.
      Penumbra barata: o polígono é desenhado 3× com a origem levemente
      deslocada e 1/3 de intensidade cada.

   3. FACHADAS: o chão iluminado não acende a parede de um prédio (a
      parede fica "em cima" de chão que está na sombra dele). Então, para
      cada prédio cuja face visível (sul: y = y1, leste: x = x1) está
      voltada para a luz, desenhamos a SILHUETA do sprite (máscara branca
      com degradê vertical: mais forte na base) com intensidade
      proporcional à distância e ao ângulo. As sombras pintadas no sprite
      continuam valendo, porque a luz MULTIPLICA o pixel original — o que
      já era escuro continua mais escuro que o resto.

   4. COMPOSIÇÃO: o buffer é aplicado sobre a cena com 'multiply'.
      Depois, brilhos (lâmpadas, fogueira) com 'lighter' por cima, para
      que a fonte de luz pareça emitir luz e não só clarear o chão.

   Coerência com as sombras pintadas nas folhas:
     As folhas têm sombra pintada caindo para a direita/baixo (sol vindo
     de cima-esquerda). Não desenhamos sombra procedural extra para essas
     peças; só uma faixa de oclusão de contato (AO) rente ao footprint,
     que "cola" o prédio ao chão. A luz direcional do dia é a do próprio
     desenho — o sistema só escurece/colore por hora e acrescenta luzes
     locais.
   ===================================================================== */
(function(){
'use strict';
const ISX=0.5,ISY=0.25;

/* ---------- luz ambiente por hora do dia (minutos 0..1440) ---------- */
const AMB=[ // [minuto, r, g, b]
  [0,   26, 32, 60],[270, 30, 36, 66],[330, 92, 80,110],[375,190,150,140],
  [420,236,222,205],[480,255,255,255],[1050,255,250,240],[1110,245,190,150],
  [1160,150,105,120],[1210, 58, 54, 92],[1270, 30, 36, 66],[1440,26,32,60]];
function ambientAt(min){
  for(let i=0;i<AMB.length-1;i++){const a=AMB[i],b=AMB[i+1];if(min>=a[0]&&min<=b[0]){const t=(min-a[0])/(b[0]-a[0]),s=t*t*(3-2*t);
    return [a[1]+(b[1]-a[1])*s,a[2]+(b[2]-a[2])*s,a[3]+(b[3]-a[3])*s]}}
  return [255,255,255]}
const isFullDay=c=>c[0]>252&&c[1]>252&&c[2]>252;

/* ---------- polígono de visibilidade (ray casting) ----------
   origem (ox,oy), raio R, segmentos [[ax,ay,bx,by],...]
   cone opcional {dir, half} em radianos. Devolve [[x,y],...] no mundo. */
function raySeg(ox,oy,dx,dy,s){
  const sx=s[2]-s[0],sy=s[3]-s[1],den=dx*sy-dy*sx;if(Math.abs(den)<1e-9)return Infinity;
  const t=((s[0]-ox)*sy-(s[1]-oy)*sx)/den,u=((s[0]-ox)*dy-(s[1]-oy)*dx)/den;
  return t>0&&u>=0&&u<=1?t:Infinity}
function visibility(ox,oy,R,segs,cone){
  const angs=[];
  const ARC=cone?Math.max(10,Math.round(cone.half*2/0.07)):56;
  if(cone){for(let i=0;i<=ARC;i++)angs.push(cone.dir-cone.half+cone.half*2*i/ARC)}
  else for(let i=0;i<ARC;i++)angs.push(i/ARC*Math.PI*2);
  for(const s of segs)for(const [px,py] of [[s[0],s[1]],[s[2],s[3]]]){
    const a=Math.atan2(py-oy,px-ox);
    for(const e of [-0.0004,0,0.0004]){let aa=a+e;
      if(cone){let d=Math.atan2(Math.sin(aa-cone.dir),Math.cos(aa-cone.dir));if(Math.abs(d)>cone.half)continue;aa=cone.dir+d}
      angs.push(aa)}}
  if(cone){angs.sort((p,q)=>Math.atan2(Math.sin(p-cone.dir),Math.cos(p-cone.dir))-Math.atan2(Math.sin(q-cone.dir),Math.cos(q-cone.dir)))}
  else angs.sort((p,q)=>((p%6.2832)+6.2832)%6.2832-((q%6.2832)+6.2832)%6.2832);
  const pts=cone?[[ox,oy]]:[];
  for(const a of angs){const dx=Math.cos(a),dy=Math.sin(a);let t=R;
    for(const s of segs){const h=raySeg(ox,oy,dx,dy,s);if(h<t)t=h}
    pts.push([ox+dx*t,oy+dy*t])}
  return pts}
function rectSegs(r){return [[r.x0,r.y0,r.x1,r.y0],[r.x1,r.y0,r.x1,r.y1],[r.x1,r.y1,r.x0,r.y1],[r.x0,r.y1,r.x0,r.y0]]}
function distRect(x,y,r){const dx=Math.max(r.x0-x,0,x-r.x1),dy=Math.max(r.y0-y,0,y-r.y1);return Math.hypot(dx,dy)}

/* ---------- máscara de fachada (silhueta + degradê vertical) ----------
   Gerada uma vez por (peça, cor). Branco opaco na base, some no topo. */
function litMask(p,col){
  const key=col.join(',');if(p.litCache[key])return p.litCache[key];
  const c=document.createElement('canvas');c.width=p.w;c.height=p.h;const g=c.getContext('2d');
  g.drawImage(p.canvas,0,0);g.globalCompositeOperation='source-in';
  // queda pela ALTURA ABSOLUTA (px da folha acima da base): luz de poste/lanterna
  // ilumina térreo e 1º andar; telhado e andares altos ficam no escuro
  // alturas em METROS convertidas para px do recorte (escala real do dicionário)
  const VPM=(window.AFTERKIN_SPRITES&&AFTERKIN_SPRITES.VPM)||30.3,ay=p.pivo?p.pivo[1]:p.ay,pm=VPM/(p.escala||1);
  const top=Math.max(0,ay-7*pm),gr=g.createLinearGradient(0,ay,0,top),k=(ay-top)||1,st=(m,a)=>gr.addColorStop(Math.min(1,m*pm/k),`rgba(${col[0]},${col[1]},${col[2]},${a})`);
  st(0,1);st(1.3,.8);st(3.2,.4);st(7,0);
  g.fillStyle=gr;g.fillRect(0,0,p.w,p.h);return p.litCache[key]=c}

/* silhueta pura (alfa da peça) para recortar a luz do chão de cima do prédio */
function silMask(p){if(p.silCache)return p.silCache;const c=document.createElement('canvas');c.width=p.w;c.height=p.h;const g=c.getContext('2d');g.drawImage(p.canvas,0,0);g.globalCompositeOperation='source-in';g.fillStyle='#000';g.fillRect(0,0,p.w,p.h);return p.silCache=c}

/* luz que chega a um ponto do chão (para personagens), com sombra dos prédios */
function lightAt(x,y,ambient,lights,occluders){
  let r=ambient[0],gg=ambient[1],b=ambient[2];
  for(const L of lights){const dx=x-L.x,dy=y-L.y,d=Math.hypot(dx,dy);if(d>=L.r)continue;
    if(L.cone){const a=Math.atan2(dy,dx),da=Math.abs(Math.atan2(Math.sin(a-L.cone.dir),Math.cos(a-L.cone.dir)));if(da>L.cone.half&&d>24)continue}
    let blocked=false;for(const o of occluders){if(distRect(L.x,L.y,o)>L.r)continue;for(const s of rectSegs(o)){const t=raySeg(L.x,L.y,dx/(d||1),dy/(d||1),s);if(t<d-2){blocked=true;break}}if(blocked)break}
    if(blocked)continue;
    const t=d/L.r,k=L.i*(t<.35?1-t/.35*.4:.6*(1-(t-.35)/.65));r+=L.col[0]*k;gg+=L.col[1]*k;b+=L.col[2]*k}
  return [Math.min(255,r),Math.min(255,gg),Math.min(255,b)]}

function create(){
  const cv=document.createElement('canvas'),g=cv.getContext('2d');let RES=0.5;
  const tmp=document.createElement('canvas'),tg=tmp.getContext('2d');
  const glows=[];
  /**
   * render(opts)
   *  ctx        : contexto principal (já com a cena desenhada)
   *  cam        : {cx, cy, sc}  — mesmo usado pelo jogo (centro em px de tela iso, escala)
   *  ambient    : [r,g,b]
   *  lights     : [{x,y,r,col:[r,g,b],i, cone?:{dir,half}, glowZ?, glow?}]
   *  occluders  : [{x0,y0,x1,y1}]   footprints que bloqueiam luz
   *  facades    : [{fp:{x0..}, spr, dx,dy,dw,dh}]  prédios do atlas visíveis
   *  actors     : [{x,y,r, sx0,sy0,sx1,sy1, draw(ctx)}]  personagens (draw = só o sprite)
   */
  function render(o){
    const {ctx,cam,ambient,lights,occluders,facades}=o,actors=o.actors||[],segsX=o.segs||[],cortesX=o.cortes||[],paredes=o.paredes||[],interiores=o.interiores||[],manchas=o.manchas||[],brilhos=o.brilhos||[];
    if(isFullDay(ambient)&&!lights.length&&!interiores.length)return false;
    const W=ctx.canvas.width,H=ctx.canvas.height,w=Math.max(1,Math.round(W*RES)),h=Math.max(1,Math.round(H*RES));
    if(cv.width!==w||cv.height!==h){cv.width=w;cv.height=h}
    g.setTransform(1,0,0,1,0,0);g.globalCompositeOperation='source-over';g.globalAlpha=1;
    g.fillStyle=`rgb(${ambient[0]|0},${ambient[1]|0},${ambient[2]|0})`;g.fillRect(0,0,w,h);
    const view=()=>{g.setTransform(1,0,0,1,0,0);g.scale(RES,RES);g.translate(Math.round(W/2),Math.round(H/2));g.scale(cam.sc,cam.sc);g.translate(-cam.cx,-cam.cy)};
    // INTERIOR: dentro de um edifício o ambiente é bem mais escuro (só entra luz pelas aberturas)
    if(interiores.length){view();const k=.3;g.fillStyle=`rgb(${ambient[0]*k|0},${ambient[1]*k+2|0},${ambient[2]*k+6|0})`;for(const P of interiores){g.beginPath();g.moveTo(P[0][0],P[0][1]);for(const q of P)g.lineTo(q[0],q[1]);g.closePath();g.fill()}}
    g.globalCompositeOperation='lighter';
    // feixes de sol pelas janelas e portas abertas (no plano do chão)
    if(manchas.length){view();for(const m of manchas){const gr=g.createLinearGradient(m.g0[0],m.g0[1],m.g1[0],m.g1[1]),c=m.col;gr.addColorStop(0,`rgba(${c[0]},${c[1]},${c[2]},${m.i})`);gr.addColorStop(1,`rgba(${c[0]},${c[1]},${c[2]},0)`);
      g.fillStyle=gr;g.beginPath();g.moveTo(m.poly[0][0],m.poly[0][1]);for(const q of m.poly)g.lineTo(q[0],q[1]);g.closePath();g.fill()}}
    const _view=()=>{g.setTransform(1,0,0,1,0,0);g.scale(RES,RES);g.translate(Math.round(W/2),Math.round(H/2));g.scale(cam.sc,cam.sc);g.translate(-cam.cx,-cam.cy)};
    glows.length=0;
    for(const L of lights){
      // footprints ao alcance desta luz
      const segs=[];let inside=false;
      for(const s of segsX){const mx=(s[0]+s[2])/2,my=(s[1]+s[3])/2,hl=Math.hypot(s[2]-s[0],s[3]-s[1])/2;if(Math.hypot(mx-L.x,my-L.y)-hl<=L.r)segs.push(s)}
      for(const r of occluders){if(distRect(L.x,L.y,r)>L.r)continue;if(L.x>r.x0&&L.x<r.x1&&L.y>r.y0&&L.y<r.y1){inside=true;break}for(const s of rectSegs(r))segs.push(s)}
      if(inside)continue;
      view();g.transform(ISX,ISY,-ISX,ISY,0,0);
      const jit=L.cone||segs.length>48?[[0,0]]:[[0,0],[7,4],[-5,7]];
      for(const [jx,jy] of jit){
        const poly=visibility(L.x+jx,L.y+jy,L.r,segs,L.cone);if(poly.length<3)continue;
        const gr=g.createRadialGradient(L.x,L.y,0,L.x,L.y,L.r),k=L.i/jit.length,c=L.col;
        gr.addColorStop(0,`rgba(${c[0]},${c[1]},${c[2]},${k})`);gr.addColorStop(.35,`rgba(${c[0]},${c[1]},${c[2]},${k*.6})`);gr.addColorStop(1,`rgba(${c[0]},${c[1]},${c[2]},0)`);
        g.fillStyle=gr;g.beginPath();g.moveTo(poly[0][0],poly[0][1]);for(let i=1;i<poly.length;i++)g.lineTo(poly[i][0],poly[i][1]);g.closePath();g.fill()}
      if(L.glow)glows.push(L)}
    // PASSE 2 — recorta a luz do chão de cima das silhuetas dos prédios:
    // o teto de um prédio alto não pode acender só porque, na TELA, ele fica
    // em cima de um chão iluminado. 'destination-out' abre um buraco; o fundo
    // ambiente é devolvido no fim com 'destination-over'.
    view();g.globalCompositeOperation='destination-out';
    g.fillStyle='#000';for(const P of cortesX){g.beginPath();g.moveTo(P[0][0],P[0][1]);for(const q of P)g.lineTo(q[0],q[1]);g.closePath();g.fill()}
    for(const f of facades){const r=f.fp,P=(x,y)=>[(x-y)*ISX,(x+y)*ISY],L0=P(r.x0,r.y1),F=P(r.x1,r.y1),R0=P(r.x1,r.y0),top=f.dy-10;
      // só o que está ACIMA das arestas frontais (paredes/telhado); quintal e calçada
      // pintados à frente do footprint continuam recebendo a luz do chão
      g.save();g.beginPath();g.moveTo(L0[0],L0[1]);g.lineTo(F[0],F[1]);g.lineTo(R0[0],R0[1]);g.lineTo(R0[0],top);g.lineTo(L0[0],top);g.closePath();g.clip();
      g.drawImage(silMask(f.spr),f.dx,f.dy,f.dw,f.dh);g.restore()}
    // PASSE 3 — luz de fachada (só nas paredes voltadas para cada fonte)
    g.globalCompositeOperation='lighter';
    for(const L of lights){
      // fachadas voltadas para esta luz
      view();
      for(const f of facades){const r=f.fp,d=distRect(L.x,L.y,r);if(d>L.r*.95)continue;
        // faces visíveis pela câmera: SUL (aresta y = y1) e LESTE (aresta x = x1).
        // Cada face só recebe luz se a fonte está do lado de fora dela.
        const faces=[];
        if(L.y>r.y1)faces.push([Math.min(1,(L.y-r.y1)/60),r.x0,r.y1,r.x1,r.y1]);
        if(L.x>r.x1)faces.push([Math.min(1,(L.x-r.x1)/60),r.x1,r.y1,r.x1,r.y0]);
        if(!faces.length)continue;
        let cone=1;
        if(L.cone){const cx=Math.max(r.x0,Math.min(L.x,r.x1)),cy=Math.max(r.y0,Math.min(L.y,r.y1));const a=Math.atan2(cy-L.y,cx-L.x),da=Math.abs(Math.atan2(Math.sin(a-L.cone.dir),Math.cos(a-L.cone.dir)));if(da>L.cone.half+.25)continue;cone=da>L.cone.half?1-(da-L.cone.half)/.25:1}
        const fall=Math.pow(1-d/L.r,1.6)*cone*L.i*.9;if(fall<.02)continue;
        const mask=litMask(f.spr,L.col);
        for(const [w,ax,ay,bx,by] of faces){
          // recorte = a parede: quadrilátero que sobe da aresta do footprint até o topo do sprite.
          // Chão pintado dentro do sprite (quadra, quintal) à frente da aresta fica de fora.
          const pax=(ax-ay)*ISX,pay=(ax+ay)*ISY,pbx=(bx-by)*ISX,pby=(bx+by)*ISY,up=f.dh+40;
          g.save();g.beginPath();g.moveTo(pax,pay+2);g.lineTo(pbx,pby+2);g.lineTo(pbx,pby-up);g.lineTo(pax,pay-up);g.closePath();g.clip();
          g.globalAlpha=Math.min(1,fall*w);g.drawImage(mask,f.dx,f.dy,f.dw,f.dh);g.restore()}}
    }
    // PASSE 3b — faces de parede geradas em código (casas): degradê vertical
    view();
    for(const L of lights)for(const w of paredes){const mx=(w.a[0]+w.b[0])/2,my=(w.a[1]+w.b[1])/2,dx=L.x-mx,dy=L.y-my;
      if(dx*w.n[0]+dy*w.n[1]<=0)continue;const ex=Math.max(Math.min(L.x,Math.max(w.a[0],w.b[0])),Math.min(w.a[0],w.b[0])),ey=Math.max(Math.min(L.y,Math.max(w.a[1],w.b[1])),Math.min(w.a[1],w.b[1])),d=Math.hypot(L.x-ex,L.y-ey);if(d>L.r)continue;
      let cone=1;if(L.cone){const a=Math.atan2(ey-L.y,ex-L.x),da=Math.abs(Math.atan2(Math.sin(a-L.cone.dir),Math.cos(a-L.cone.dir)));if(da>L.cone.half+.3)continue;cone=da>L.cone.half?1-(da-L.cone.half)/.3:1}
      const k=Math.pow(1-d/L.r,1.5)*cone*L.i*.85;if(k<.02)continue;const b0=w.poly[0],gr=g.createLinearGradient(0,b0[1],0,b0[1]-w.h),c=L.col;
      gr.addColorStop(0,`rgba(${c[0]},${c[1]},${c[2]},${k})`);gr.addColorStop(.5,`rgba(${c[0]},${c[1]},${c[2]},${k*.45})`);gr.addColorStop(1,`rgba(${c[0]},${c[1]},${c[2]},${k*.08})`);
      g.fillStyle=gr;g.beginPath();g.moveTo(w.poly[0][0],w.poly[0][1]);for(const q of w.poly)g.lineTo(q[0],q[1]);g.closePath();g.fill()}
    // PASSE 4 — personagens à FRENTE de um prédio: a silhueta deles recebe a
    // luz que chega aos pés (com sombra), não a luz do prédio atrás deles.
    view();
    for(const a of actors){
      let over=false;
      for(const f of facades){if(a.sx1<f.dx||a.sx0>f.dx+f.dw||a.sy1<f.dy||a.sy0>f.dy+f.dh)continue;
        const r=f.fp;if(a.x+a.r<=r.x0||a.y+a.r<=r.y0)continue; // atrás do prédio: o prédio já cobre
        over=true;break}
      if(!over)continue;
      const c=lightAt(a.x,a.y,ambient,lights,occluders);
      // silhueta do personagem tingida com a cor da luz local
      const bw=Math.ceil((a.sx1-a.sx0)*cam.sc*RES)+4,bh=Math.ceil((a.sy1-a.sy0)*cam.sc*RES)+4;
      if(tmp.width<bw)tmp.width=bw;if(tmp.height<bh)tmp.height=bh;
      tg.setTransform(1,0,0,1,0,0);tg.globalCompositeOperation='source-over';tg.clearRect(0,0,tmp.width,tmp.height);
      tg.setTransform(cam.sc*RES,0,0,cam.sc*RES,-a.sx0*cam.sc*RES+2,-a.sy0*cam.sc*RES+2);a.draw(tg);
      tg.setTransform(1,0,0,1,0,0);tg.globalCompositeOperation='source-in';tg.fillStyle=`rgb(${c[0]|0},${c[1]|0},${c[2]|0})`;tg.fillRect(0,0,bw,bh);
      g.globalCompositeOperation='destination-out';g.drawImage(tmp,0,0,bw,bh,a.sx0-2/(cam.sc*RES),a.sy0-2/(cam.sc*RES),bw/(cam.sc*RES),bh/(cam.sc*RES));
      g.globalCompositeOperation='lighter';g.drawImage(tmp,0,0,bw,bh,a.sx0-2/(cam.sc*RES),a.sy0-2/(cam.sc*RES),bw/(cam.sc*RES),bh/(cam.sc*RES))}
    // devolve o ambiente embaixo de tudo que foi recortado
    g.setTransform(1,0,0,1,0,0);g.globalCompositeOperation='destination-over';g.fillStyle=`rgb(${ambient[0]|0},${ambient[1]|0},${ambient[2]|0})`;g.fillRect(0,0,w,h);
    // composição
    ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.globalCompositeOperation='multiply';ctx.imageSmoothingEnabled=true;ctx.drawImage(cv,0,0,W,H);
    // brilho das fontes
    ctx.globalCompositeOperation='lighter';ctx.translate(Math.round(W/2),Math.round(H/2));ctx.scale(cam.sc,cam.sc);ctx.translate(-cam.cx,-cam.cy);
    const night=1-Math.min(1,(ambient[0]+ambient[1]+ambient[2])/600);
    for(const B of brilhos){const gr=ctx.createRadialGradient(B.x,B.y,0,B.x,B.y,B.R),c=B.col;gr.addColorStop(0,`rgba(${c[0]},${c[1]},${c[2]},${.7*night*B.i})`);gr.addColorStop(1,'rgba(0,0,0,0)');ctx.fillStyle=gr;ctx.fillRect(B.x-B.R,B.y-B.R,B.R*2,B.R*2)}
    for(const L of glows){const px=(L.x-L.y)*ISX,py=(L.x+L.y)*ISY-(L.glowZ||0),R=L.glow,c=L.col;
      const gr=ctx.createRadialGradient(px,py,0,px,py,R);gr.addColorStop(0,`rgba(${c[0]},${c[1]},${c[2]},${.85*night*L.i})`);gr.addColorStop(.25,`rgba(${c[0]},${c[1]},${c[2]},${.3*night*L.i})`);gr.addColorStop(1,'rgba(0,0,0,0)');
      ctx.fillStyle=gr;ctx.fillRect(px-R,py-R,R*2,R*2)}
    ctx.restore();return true}
  return {render,canvas:cv,setRes:r=>{RES=r}}}

window.AfterkinLight={create,ambientAt,visibility,isFullDay};
})();
