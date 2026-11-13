/* =====================================================================
   AFTERKIN: NASCIDOS DA RUÍNA — CARREGADOR DE SPRITES
   ---------------------------------------------------------------------
   Lê o dicionário de js/sprites.js e prepara um canvas por registro.
   Regras rígidas:
     • o recorte é EXATAMENTE o retângulo do dicionário (nada é aparado,
       nada é fatiado automaticamente) → o pivô do dicionário vale como está;
     • 'limpar:true' só apaga pixels de peças VIZINHAS que invadem o
       retângulo (componentes que tocam a borda e não são a peça principal);
     • folha "civis": fecha os buracos que a remoção de fundo abriu em áreas
       brancas (neve, paredes claras) — a cor original ainda está no arquivo.
   A máscara de alfa (para oclusão por pixel) só existe quando o navegador
   permite ler os pixels. Abrindo via file:// os PNGs avulsos não permitem;
   nesse caso a oclusão usa a caixa do sprite.
   ===================================================================== */
(function(){
'use strict';
const SHEETS={construcoes:{src:'assets/folha_construcoes.png',haze:32,cut:96,fillHoles:false},
              civis:{src:'assets/folha_civis.png',haze:0,cut:1,fillHoles:true}};
const AVULSO={haze:32,cut:96,fillHoles:false};   // PNGs avulsos antigos: mesmo tratamento da folha 1

function dilate(m,w,h,r){const t=new Uint8Array(w*h),o=new Uint8Array(w*h);
  for(let y=0;y<h;y++){let run=-1e9;for(let x=0;x<w;x++){if(m[y*w+x])run=x;t[y*w+x]=x-run<=r?1:0}run=1e9;for(let x=w-1;x>=0;x--){if(m[y*w+x])run=x;if(run-x<=r)t[y*w+x]=1}}
  for(let x=0;x<w;x++){let run=-1e9;for(let y=0;y<h;y++){if(t[y*w+x])run=y;o[y*w+x]=y-run<=r?1:0}run=1e9;for(let y=h-1;y>=0;y--){if(t[y*w+x])run=y;if(run-y<=r)o[y*w+x]=1}}
  return o}
function erode(m,w,h,r){const inv=new Uint8Array(w*h);for(let i=0;i<w*h;i++)inv[i]=m[i]?0:1;const d=dilate(inv,w,h,r);for(let i=0;i<w*h;i++)d[i]=d[i]?0:1;return d}
function label(m,w,h){const lab=new Int32Array(w*h),comps=[null],st=new Int32Array(w*h);
  for(let i=0;i<w*h;i++){if(!m[i]||lab[i])continue;const id=comps.length;let sp=0;const c={n:0,border:false};st[sp++]=i;lab[i]=id;
    while(sp){const p=st[--sp],x=p%w,y=(p-x)/w;c.n++;if(x===0||y===0||x===w-1||y===h-1)c.border=true;
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=w||ny>=h)continue;const q=ny*w+nx;if(m[q]&&!lab[q]){lab[q]=id;st[sp++]=q}}}
    comps.push(c)}
  return {lab,comps}}
/* pixels SEM pré-multiplicação (o canvas 2D zera o RGB de pixels transparentes) */
function rawPixels(img){const w=img.naturalWidth,h=img.naturalHeight,cv=document.createElement('canvas');
  const gl=cv.getContext('webgl',{premultipliedAlpha:false});if(!gl)return null;
  const tex=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,tex);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,false);gl.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL,gl.NONE);
  gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,img);const fb=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,tex,0);
  const out=new Uint8Array(w*h*4);gl.readPixels(0,0,w,h,gl.RGBA,gl.UNSIGNED_BYTE,out);const l=gl.getExtension('WEBGL_lose_context');if(l)l.loseContext();return {w,h,data:out}}

function build(name,def,img,raw,cfg){
  const [rx,ry,rw,rh]=def.r,cv=document.createElement('canvas');cv.width=rw;cv.height=rh;
  const g=cv.getContext('2d',{willReadFrequently:true});let id=null;
  if(raw){id=g.createImageData(rw,rh);const s=raw.data,o=id.data;
    for(let y=0;y<rh;y++){const sy=ry+y;if(sy<0||sy>=raw.h)continue;for(let x=0;x<rw;x++){const sx=rx+x;if(sx<0||sx>=raw.w)continue;const si=(sy*raw.w+sx)*4,oi=(y*rw+x)*4;o[oi]=s[si];o[oi+1]=s[si+1];o[oi+2]=s[si+2];o[oi+3]=s[si+3]}}}
  else{g.drawImage(img,rx,ry,rw,rh,0,0,rw,rh);try{id=g.getImageData(0,0,rw,rh)}catch(e){id=null}}
  let alpha=null;
  if(id){const d=id.data,N=rw*rh;
    if(cfg&&def.limpar){
      if(cfg.haze)for(let i=0;i<N;i++)if(d[i*4+3]<cfg.haze)d[i*4+3]=0;
      if(cfg.fillHoles){const m=new Uint8Array(N);for(let i=0;i<N;i++)m[i]=d[i*4+3]>0?1:0;const closed=erode(dilate(m,rw,rh,3),rw,rh,3);
        const out=new Uint8Array(N),st=new Int32Array(N);let sp=0;const push=p=>{if(!closed[p]&&!out[p]){out[p]=1;st[sp++]=p}};
        for(let x=0;x<rw;x++){push(x);push((rh-1)*rw+x)}for(let y=0;y<rh;y++){push(y*rw);push(y*rw+rw-1)}
        while(sp){const p=st[--sp],x=p%rw,y=(p-x)/rw;if(x>0)push(p-1);if(x<rw-1)push(p+1);if(y>0)push(p-rw);if(y<rh-1)push(p+rw)}
        const hole=new Uint8Array(N);for(let i=0;i<N;i++)hole[i]=!m[i]&&!out[i]?1:0;const L=label(hole,rw,rh);for(let i=0;i<N;i++){const l=L.lab[i];if(l&&L.comps[l].n<=1800)d[i*4+3]=255}}
      const solid=new Uint8Array(N);for(let i=0;i<N;i++)solid[i]=d[i*4+3]>=cfg.cut?1:0;
      const {lab,comps}=label(solid,rw,rh);let big=1;for(let i=2;i<comps.length;i++)if(comps[i].n>comps[big].n)big=i;
      const keepC=new Uint8Array(comps.length);for(let i=1;i<comps.length;i++)if(i===big||(!comps[i].border&&comps[i].n>=12))keepC[i]=1;
      const keep=new Uint8Array(N);for(let i=0;i<N;i++)keep[i]=keepC[lab[i]];const halo=dilate(keep,rw,rh,2);
      for(let i=0;i<N;i++)if(!halo[i])d[i*4+3]=0;
      // borda do retângulo: esmaece 6px onde a arte da própria peça encosta (sem corte seco)
      for(let y=0;y<rh;y++)for(let x=0;x<rw;x++){const e=Math.min(x,y,rw-1-x,rh-1-y);if(e<6){const i=(y*rw+x)*4+3;d[i]=d[i]*e/6}}}
    g.putImageData(id,0,0);alpha=new Uint8Array(rw*rh);for(let i=0;i<rw*rh;i++)alpha[i]=id.data[i*4+3]}
  // ampliação nítida: peças com escala entre 2,4 e 3,9 ganham uma cópia 2× SEM suavização
  // (cada pixel vira 2×2); o motor desenha essa cópia com escala/2 e suavização.
  // Resultado: bordas firmes em vez do borrão de uma ampliação bilinear de 4–5×.
  let hi=null;if(def.escala>=2.4&&def.escala<3.95){hi=document.createElement('canvas');hi.width=rw*2;hi.height=rh*2;const hg=hi.getContext('2d');hg.imageSmoothingEnabled=false;hg.drawImage(cv,0,0,rw*2,rh*2)}
  return Object.assign({},def,{name,canvas:cv,hi,alpha,w:rw,h:rh,litCache:{},silCache:null})}

/** carrega tudo e chama onReady(SPR) */
function load(onReady){
  const D=window.AFTERKIN_SPRITES,SPR={},imgs={},srcs=new Set();
  for(const n in D.sprites)srcs.add(D.sprites[n].fonte);
  let pending=srcs.size;
  for(const f of srcs){const im=new Image();const key=f.startsWith('folha:')?f.slice(6):null;
    im.onload=()=>{imgs[f]=im;if(--pending===0)finish()};im.onerror=()=>{console.warn('Falha ao carregar',f);if(--pending===0)finish()};
    im.src=key?((window.AFTERKIN_SHEETS_DATA&&window.AFTERKIN_SHEETS_DATA[key])||SHEETS[key].src):((window.AFTERKIN_OBJ_DATA&&window.AFTERKIN_OBJ_DATA[f])||f)}
  function finish(){
    const raws={};for(const k in SHEETS){const f='folha:'+k;if(SHEETS[k].fillHoles&&imgs[f]){try{raws[f]=rawPixels(imgs[f])}catch(e){raws[f]=null}}}
    for(const n in D.sprites){const def=D.sprites[n],im=imgs[def.fonte];if(!im)continue;const key=def.fonte.startsWith('folha:')?def.fonte.slice(6):null;
      try{SPR[n]=build(n,def,im,raws[def.fonte]||null,key?SHEETS[key]:AVULSO)}catch(e){console.warn('Sprite',n,e)}}
    onReady(SPR)}
}
const byCat=(SPR,cat)=>Object.keys(SPR).filter(k=>SPR[k].cat===cat);
window.AfterkinAtlas={load,byCat};
})();
