/* =====================================================================
   AFTERKIN: NASCIDOS DA RUÍNA — DICIONÁRIO DE SPRITES (escala real)
   ---------------------------------------------------------------------
   UM registro por elemento desenhável. Nada é fatiado automaticamente:
   cada retângulo foi definido à mão e conferido para não cortar arte.

   Campos:
     fonte   'folha:construcoes' | 'folha:civis' | caminho do PNG
     r       [x, y, largura, altura]  retângulo EXATO na imagem de origem (px)
     pivo    [x, y]  ponto de contato com o chão, relativo ao retângulo (px).
             É o vértice inferior da base — o "pé" do prédio / a roda do carro.
             TODO posicionamento e TODA ordenação usam este ponto.
     base    [A, B]  meias-larguras da base na tela, em px do recorte:
             A = do pivô até o canto esquerdo, B = até o canto direito.
             No mundo: largura no eixo X = 2·escala·A, no eixo Y = 2·escala·B.
     escala  FATOR DE ESCALA INDIVIDUAL (px de tela por px da imagem, zoom 1).
             Ajuste aqui para deixar cada objeto na proporção do personagem.
     ref     referência real usada para calibrar a escala (pé-direito,
             porta, comprimento do veículo, altura total)
     cat     categoria (house, tower, row, rural, camp, vehicle, veg, prop...)
     solido  bloqueia passagem (colisão = base)
     flat    peça de chão: desenhada antes de tudo, sem ordenação
     limpar  remove pedaços de peças vizinhas que invadem o retângulo

   Escala real:
     Personagem = 1,75 m = 53 px de tela → VPM = 30,3 px por metro (vertical).
     Na projeção 2:1, 1 m no chão = METRO = VPM / 0,6124 = 49,5 unidades.
     Tile = 64 unidades = 1,29 m.
     As folhas foram desenhadas com escalas diferentes peça a peça, então
     cada registro tem a SUA escala, medida na arte: altura entre andares
     (2,8 m residencial, 3,0–3,5 m comercial), portas (2,1 m), rodas (0,7 m).
     Veículos: escala = (comprimento + largura)·0,5·METRO / largura do recorte.
     Para conferir: abra escala_debug.html (personagem e régua de 1 m ao lado).
   ===================================================================== */
window.AFTERKIN_SPRITES={
VPM:30.3, METRO:49.48, TILE:64,
// personagens: quadros de 160×160, pivô nos pés
personagens:{quadro:160, pivo:[80,149], escala:0.5, alturaM:1.75},
sprites:{
  casa_cinza:        {fonte:'folha:construcoes', r:[8,38,205,172], pivo:[136,177], base:[136,68], escala:3, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  casa_creme:        {fonte:'folha:construcoes', r:[168,40,252,180], pivo:[154,185], base:[154,97], escala:3, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  casa_tijolo:       {fonte:'folha:construcoes', r:[398,28,165,210], pivo:[98,215], base:[98,66], escala:3.4, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  casa_verde:        {fonte:'folha:construcoes', r:[545,40,240,205], pivo:[67,210], base:[67,162], escala:3, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  galpao_pequeno:    {fonte:'folha:construcoes', r:[10,196,96,52], pivo:[33,51.5], base:[32,61], escala:3.5, ref:'altura 3,5 m', cat:'prop', solido:true, loot:'camp', limpar:true},
  igreja:            {fonte:'folha:construcoes', r:[752,4,215,262], pivo:[86,267], base:[86,128], escala:3.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  hospital:          {fonte:'folha:construcoes', r:[962,18,302,252], pivo:[120,255], base:[120,163], escala:4.2, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'pharmacy', limpar:true},
  delegacia:         {fonte:'folha:construcoes', r:[1248,38,284,236], pivo:[139,237], base:[139,142], escala:3.4, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  predio_tijolo:     {fonte:'folha:construcoes', r:[8,214,222,210], pivo:[99,215], base:[98,122], escala:3.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  mercado:           {fonte:'folha:construcoes', r:[214,232,274,214], pivo:[129,219], base:[126,144], escala:3.6, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  posto:             {fonte:'folha:construcoes', r:[466,252,228,200], pivo:[118,199], base:[118,109], escala:2, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  oficina:           {fonte:'folha:construcoes', r:[690,222,222,236], pivo:[123,237], base:[115,98], escala:1.9, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  armazem:           {fonte:'folha:construcoes', r:[880,238,196,206], pivo:[62,200], base:[62,133], escala:2.4, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  banco:             {fonte:'folha:construcoes', r:[1070,240,192,206], pivo:[133,211], base:[133,58], escala:3.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  escola:            {fonte:'folha:construcoes', r:[1240,255,292,238], pivo:[108,240], base:[108,167], escala:3.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  cortico:           {fonte:'folha:construcoes', r:[4,418,292,262], pivo:[158,267], base:[156,132], escala:2.8, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  torre_residencial: {fonte:'folha:construcoes', r:[288,425,252,292], pivo:[164,283], base:[150,88], escala:3.4, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  fabrica:           {fonte:'folha:construcoes', r:[518,445,288,222], pivo:[161,227], base:[160,125], escala:3.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  onibus:            {fonte:'folha:construcoes', r:[774,458,152,94], pivo:[80,99], base:[26.4,121.7], escala:2.44, ref:'comprimento 12 m', cat:'vehicle', solido:true, limpar:true},
  carro_marrom:      {fonte:'folha:construcoes', r:[928,452,100,66], pivo:[40,71], base:[28.1,67.9], escala:1.675, ref:'comprimento 4,6 m', cat:'vehicle', solido:true, limpar:true},
  carro_cinza:       {fonte:'folha:construcoes', r:[1040,452,74,46], pivo:[27,46.5], base:[20,50], escala:2.226, ref:'comprimento 4,5 m', cat:'vehicle', solido:true, limpar:true},
  carro_vermelho:    {fonte:'folha:construcoes', r:[1116,462,80,50], pivo:[29,51], base:[21.4,54.6], escala:2.083, ref:'comprimento 4,6 m', cat:'vehicle', solido:true, limpar:true},
  taxi:              {fonte:'folha:construcoes', r:[822,538,106,60], pivo:[36,64], base:[28.9,73.1], escala:1.625, ref:'comprimento 4,8 m', cat:'vehicle', solido:true, limpar:true},
  carro_branco:      {fonte:'folha:construcoes', r:[950,514,84,56], pivo:[29,55.5], base:[22.5,57.5], escala:1.979, ref:'comprimento 4,6 m', cat:'vehicle', solido:true, limpar:true},
  jipe_verde:        {fonte:'folha:construcoes', r:[1036,496,78,48], pivo:[35,50], base:[22.7,51.3], escala:2.073, ref:'comprimento 4,3 m', cat:'vehicle', solido:true, limpar:true},
  onibus_escolar:    {fonte:'folha:construcoes', r:[1116,486,158,96], pivo:[44,99], base:[28.5,125.5], escala:2.169, ref:'comprimento 11 m', cat:'vehicle', solido:true, limpar:true},
  caminhao_tanque:   {fonte:'folha:construcoes', r:[816,580,144,84], pivo:[54,86], base:[28,112], escala:2.209, ref:'comprimento 10 m', cat:'vehicle', solido:true, limpar:true},
  caminhao_militar:  {fonte:'folha:construcoes', r:[966,548,148,86], pivo:[63,88], base:[34.3,109.7], escala:1.804, ref:'comprimento 8 m', cat:'vehicle', solido:true, limpar:true},
  lote_cercado:      {fonte:'folha:construcoes', r:[1260,500,272,156], pivo:[171,157], base:[169,97], escala:3.4, ref:'altura 30 m', cat:'yard', solido:true, limpar:true},
  estacionamento:    {fonte:'folha:construcoes', r:[1045,562,378,184], pivo:[193,186], base:[191,181], escala:3.4, ref:'altura 40 m', cat:'flat', solido:false, flat:true, limpar:true},
  estac_pequeno:     {fonte:'folha:construcoes', r:[4,654,188,100], pivo:[138,105], base:[136,49], escala:3.4, ref:'altura 22 m', cat:'flat', solido:false, flat:true, limpar:true},
  estac_arvores:     {fonte:'folha:construcoes', r:[84,676,326,196], pivo:[118,201], base:[118,204], escala:3.4, ref:'altura 34 m', cat:'flat', solido:false, flat:true, limpar:true},
  viaduto_longo:     {fonte:'folha:construcoes', r:[548,636,354,254], pivo:[227,254.5], base:[123,118], escala:3.4, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  portao_ruina:      {fonte:'folha:construcoes', r:[726,644,130,92], pivo:[111,91], base:[108,15], escala:2.1, ref:'altura 3 m', cat:'prop', solido:true, limpar:true},
  patio_ruina:       {fonte:'folha:construcoes', r:[414,692,280,136], pivo:[184,138], base:[182,93], escala:3.4, ref:'altura 24 m', cat:'yard', solido:true, limpar:true},
  viaduto_largo:     {fonte:'folha:construcoes', r:[874,645,340,230], pivo:[110,235], base:[97,206], escala:3.4, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  ponte_trelica:     {fonte:'folha:construcoes', r:[1160,656,372,246], pivo:[187,246], base:[183,182], escala:3.4, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  rua_curva:         {fonte:'folha:construcoes', r:[4,894,128,116], pivo:[90,119], base:[78,35], escala:3.4, ref:'altura 12 m', cat:'road2d', solido:false, flat:true, limpar:true},
  rua_reta:          {fonte:'folha:construcoes', r:[139,888,120,122], pivo:[57,125], base:[55,60], escala:3.4, ref:'altura 12 m', cat:'road2d', solido:false, flat:true, limpar:true},
  rua_T:             {fonte:'folha:construcoes', r:[263,830,400,182], pivo:[205,184], base:[203,191], escala:3.4, ref:'altura 30 m', cat:'road2d', solido:false, flat:true, limpar:true},
  rua_faixa:         {fonte:'folha:construcoes', r:[672,858,278,152], pivo:[133,156], base:[131,142], escala:3.4, ref:'altura 24 m', cat:'road2d', solido:false, flat:true, limpar:true},
  rotatoria:         {fonte:'folha:construcoes', r:[952,922,166,90], pivo:[70,93], base:[64,95], escala:3.4, ref:'altura 20 m', cat:'road2d', solido:false, flat:true, limpar:true},
  torre_vigia:       {fonte:'folha:construcoes', r:[894,780,60,108], pivo:[28,113], base:[28,31], escala:2.55, ref:'altura 8 m', cat:'prop', solido:true, limpar:true},
  guarita:           {fonte:'folha:construcoes', r:[1168,898,50,80], pivo:[24,79.5], base:[22,22], escala:1.05, ref:'altura 2,8 m', cat:'prop', solido:true, limpar:true},
  cerca_madeira:     {fonte:'folha:construcoes', r:[786,888,160,52], pivo:[80,54], base:[78,77], escala:1.5, ref:'altura 2 m', cat:'prop', solido:true, limpar:true},
  cerca_tabuas:      {fonte:'folha:construcoes', r:[1290,806,158,106], pivo:[13,105.5], base:[12,141], escala:1.5, ref:'altura 2,5 m', cat:'prop', solido:true, limpar:true},
  cacamba:           {fonte:'folha:construcoes', r:[1228,916,96,66], pivo:[21,65.5], base:[16,72], escala:1.7, ref:'altura 4 m', cat:'prop', solido:true, limpar:true},
  sobrado_branco:    {fonte:'folha:civis', r:[0,12,225,145], pivo:[152,150], base:[152,72], escala:4.5, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  igreja_madeira:    {fonte:'folha:civis', r:[176,40,170,166], pivo:[90,171], base:[90,79], escala:5, ref:'andar 2,8 m · porta 2,1 m', cat:'rural', solido:true, loot:'house', limpar:true},
  casa_rural:        {fonte:'folha:civis', r:[288,18,180,112], pivo:[58,117], base:[58,120], escala:4.8, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  casa_vitoriana:    {fonte:'folha:civis', r:[440,50,175,120], pivo:[85,125], base:[85,89], escala:4.4, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  predio_tijolo_4:   {fonte:'folha:civis', r:[605,44,140,156], pivo:[70,134], base:[53,50], escala:4.5, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  predio_branco:     {fonte:'folha:civis', r:[735,46,150,180], pivo:[57,185], base:[57,84], escala:4.5, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  pinheiros:         {fonte:'folha:civis', r:[0,180,115,150], pivo:[33,151.5], base:[33,80], escala:3, ref:'altura 14 m', cat:'prop', solido:true, limpar:true},
  celeiro:           {fonte:'folha:civis', r:[165,140,242,182], pivo:[73,187], base:[73,168], escala:3.8, ref:'andar 2,8 m · porta 2,1 m', cat:'rural', solido:true, loot:'camp', limpar:true},
  cata_vento:        {fonte:'folha:civis', r:[92,195,90,145], pivo:[43,150], base:[43,46], escala:2.6, ref:'altura 12 m', cat:'prop', solido:true, limpar:true},
  clinica:           {fonte:'folha:civis', r:[470,180,235,150], pivo:[133,153], base:[133,101], escala:4, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'pharmacy', limpar:true},
  caixa_dagua:       {fonte:'folha:civis', r:[796,222,72,145], pivo:[32,150], base:[32,39], escala:3.2, ref:'altura 15 m', cat:'prop', solido:true, limpar:true},
  loja_esquina:      {fonte:'folha:civis', r:[300,268,210,115], pivo:[116,120], base:[116,93], escala:4, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  posto_rural:       {fonte:'folha:civis', r:[656,280,145,110], pivo:[85,115], base:[85,59], escala:3, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  lojas_rua:         {fonte:'folha:civis', r:[120,342,290,150], pivo:[157,155], base:[157,125], escala:3.6, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  delegacia_azul:    {fonte:'folha:civis', r:[418,335,245,160], pivo:[76,165], base:[76,168], escala:3.4, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  galpao_ferrugem:   {fonte:'folha:civis', r:[684,385,196,125], pivo:[82,130], base:[82,107], escala:3.6, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  viaduto_curto:     {fonte:'folha:civis', r:[0,445,185,125], pivo:[59,130], base:[59,117], escala:3.6, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  ponte_arcos:       {fonte:'folha:civis', r:[0,545,222,135], pivo:[24,140], base:[23,120], escala:3.6, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  barraca_verde:     {fonte:'folha:civis', r:[238,500,108,70], pivo:[59,75], base:[59,48], escala:3, ref:'porta 2,0 m', cat:'camp', solido:true, loot:'camp', limpar:true},
  barraca_verde2:    {fonte:'folha:civis', r:[348,490,92,62], pivo:[39,67], base:[39,52], escala:3, ref:'porta 2,0 m', cat:'camp', solido:true, loot:'camp', limpar:true},
  tenda_medica:      {fonte:'folha:civis', r:[310,545,98,64], pivo:[41,69], base:[41,56], escala:3, ref:'porta 2,0 m', cat:'camp', solido:true, loot:'pharmacy', limpar:true},
  cabana_madeira:    {fonte:'folha:civis', r:[505,492,112,80], pivo:[63,85], base:[63,48], escala:3.2, ref:'porta 2,0 m', cat:'camp', solido:true, loot:'camp', limpar:true},
  forte_palicada:    {fonte:'folha:civis', r:[388,548,498,200], pivo:[229,201], base:[229,259], escala:3.6, ref:'faixa 3,5 m', cat:'struct', solido:true, limpar:true},
  torre_vigia_alta:  {fonte:'folha:civis', r:[808,488,70,110], pivo:[28,115], base:[28,32], escala:2.5, ref:'altura 9 m', cat:'prop', solido:true, limpar:true},
  torre_vigia_2:     {fonte:'folha:civis', r:[115,648,72,100], pivo:[28,105], base:[28,37], escala:2.7, ref:'altura 9 m', cat:'prop', solido:true, limpar:true},
  guarita_2:         {fonte:'folha:civis', r:[0,684,70,64], pivo:[27,69], base:[27,33], escala:1.8, ref:'altura 3,5 m', cat:'prop', solido:true, limpar:true},
  tree:              {fonte:'assets/obj_tree.png', r:[0,0,240,270], pivo:[123,275], base:[54,46], escala:0.885, ref:'altura 8 m', cat:'veg', solido:true, limpar:true},
  deadtree:          {fonte:'assets/obj_deadtree.png', r:[0,0,220,239], pivo:[110,244], base:[54,44], escala:0.873, ref:'altura 7 m', cat:'veg', solido:true, limpar:true},
  stump:             {fonte:'assets/obj_stump.png', r:[0,0,128,105], pivo:[57,109], base:[56,68], escala:0.291, ref:'comprimento 0,8 m', cat:'veg', solido:false, limpar:true},
  boulder:           {fonte:'assets/obj_boulder.png', r:[0,0,192,185], pivo:[95,189], base:[90,89], escala:0.605, ref:'comprimento 2,2 m', cat:'rocha', solido:true, limpar:true},
  rubble:            {fonte:'assets/obj_rubble.png', r:[0,0,160,135], pivo:[80,139], base:[79,76], escala:0.783, ref:'comprimento 2,5 m', cat:'chao', solido:false, limpar:true},
  bush:              {fonte:'assets/obj_bush.png', r:[0,0,144,148], pivo:[69,153], base:[58,61], escala:0.279, ref:'altura 1,4 m', cat:'veg', solido:true, limpar:true},
  pebbles:           {fonte:'assets/obj_pebbles.png', r:[0,46,62,73], pivo:[33,76], base:[17,22], escala:0.34, ref:'comprimento 0,3 m', cat:'chao', solido:false, limpar:true},
  branch:            {fonte:'assets/obj_branch.png', r:[0,30,112,73], pivo:[35,78], base:[35,75], escala:0.396, ref:'comprimento 1,2 m', cat:'chao', solido:false, limpar:true},
  scrap:             {fonte:'assets/obj_scrap.png', r:[0,0,160,136], pivo:[88,140], base:[82,66], escala:0.45, ref:'altura 2,5 m', cat:'prop', solido:true, limpar:true},
  car:               {fonte:'assets/obj_car.png', r:[0,0,260,189], pivo:[173,192], base:[180.1,76.1], escala:0.618, ref:'comprimento 4,5 m', cat:'vehicle', solido:true, limpar:true},
  totem1:            {fonte:'assets/obj_totem1.png', r:[0,0,88,218], pivo:[42,222], base:[41,44], escala:0.329, ref:'altura 2,4 m', cat:'prop', solido:true, limpar:true},
  totem5:            {fonte:'assets/obj_totem5.png', r:[0,0,116,252], pivo:[56,256], base:[56,56], escala:0.331, ref:'altura 2,8 m', cat:'prop', solido:true, limpar:true},
  house:             {fonte:'assets/obj_house.png', r:[0,0,320,342], pivo:[158,344], base:[156,160], escala:0.75, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  pharmacy:          {fonte:'assets/obj_pharmacy.png', r:[0,0,320,290], pivo:[154,295], base:[154,165], escala:0.55, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'pharmacy', limpar:true},
  sewer:             {fonte:'assets/obj_sewer.png', r:[0,0,260,240], pivo:[129,245], base:[127,129], escala:0.6, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  camp:              {fonte:'assets/obj_camp.png', r:[0,0,300,286], pivo:[140,291], base:[138,159], escala:0.42, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  waterfall:         {fonte:'assets/obj_waterfall.png', r:[0,0,260,270], pivo:[137,275], base:[128,120], escala:1.1, ref:'altura 12 m', cat:'prop', solido:true, limpar:true},
  shelter:           {fonte:'assets/obj_shelter.png', r:[0,0,260,251], pivo:[136,255], base:[130,120], escala:0.53, ref:'altura 5 m', cat:'prop', solido:true, limpar:true},
  fence:             {fonte:'assets/obj_fence.png', r:[0,0,200,148], pivo:[96,152], base:[95,102], escala:0.5, ref:'altura 3,5 m', cat:'prop', solido:true, limpar:true},
  lamp:              {fonte:'assets/obj_lamp.png', r:[0,0,80,152], pivo:[36,156], base:[26,22], escala:1, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  tires:             {fonte:'assets/obj_tires.png', r:[0,0,160,99], pivo:[78,104], base:[69,79], escala:0.6, ref:'altura 1,6 m', cat:'prop', solido:true, limpar:true},
  barrier:           {fonte:'assets/obj_barrier.png', r:[0,0,180,121], pivo:[116,126], base:[115,59], escala:0.34, ref:'altura 2,5 m', cat:'prop', solido:true, limpar:true},
  bldA:              {fonte:'assets/obj_bldA.png', r:[0,0,380,374], pivo:[195,379], base:[193,184], escala:2, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  bldB:              {fonte:'assets/obj_bldB.png', r:[26,0,354,402], pivo:[163,407], base:[160,188], escala:2.27, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  bldC:              {fonte:'assets/obj_bldC.png', r:[0,0,400,378], pivo:[191,383], base:[188,206], escala:1.95, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  warehouse:         {fonte:'assets/obj_warehouse.png', r:[0,0,460,380], pivo:[234,385], base:[230,225], escala:1.24, ref:'andar 3,2 m · porta 2,1 m', cat:'row', solido:true, loot:'house', limpar:true},
  hotel:             {fonte:'assets/obj_hotel.png', r:[24,0,316,335], pivo:[150,340], base:[143,162], escala:2.5, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  church:            {fonte:'assets/obj_church.png', r:[0,0,400,400], pivo:[187,405], base:[184,212], escala:1.06, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  bank:              {fonte:'assets/obj_bank.png', r:[18,0,382,321], pivo:[195,326], base:[189,186], escala:1.6, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  ruintower:         {fonte:'assets/obj_ruintower.png', r:[15,0,325,358], pivo:[166,363], base:[162,156], escala:2.4, ref:'andar 3,0–3,5 m', cat:'tower', solido:true, loot:'house', limpar:true},
  guardtower:        {fonte:'assets/obj_guardtower.png', r:[67,38,133,176], pivo:[70,181], base:[67,62], escala:1.2, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  watertower:        {fonte:'assets/obj_watertower.png', r:[48,31,82,148], pivo:[39,153], base:[35,39], escala:2.408, ref:'altura 12 m', cat:'prop', solido:true, limpar:true},
  compound:          {fonte:'assets/obj_compound.png', r:[0,135,460,359], pivo:[222,364], base:[222,235], escala:0.5, ref:'altura 30 m', cat:'prop', solido:true, limpar:true},
  metro:             {fonte:'assets/obj_metro.png', r:[18,87,282,233], pivo:[126,238], base:[123,155], escala:0.75, ref:'altura 8 m', cat:'prop', solido:true, limpar:true},
  manhole:           {fonte:'assets/obj_manhole.png', r:[6,41,106,84], pivo:[49,89], base:[39,48], escala:0.464, ref:'comprimento 0,9 m', cat:'chao', solido:false, flat:true, limpar:true},
  tentblue:          {fonte:'assets/obj_tentblue.png', r:[0,43,360,350], pivo:[212,355], base:[210,147], escala:0.5, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  woodtower:         {fonte:'assets/obj_woodtower.png', r:[37,15,155,209], pivo:[74,214], base:[71,79], escala:1.1, ref:'altura 7 m', cat:'prop', solido:true, limpar:true},
  camp2:             {fonte:'assets/obj_camp2.png', r:[0,63,339,308], pivo:[130,313], base:[129,204], escala:0.5, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  medtent:           {fonte:'assets/obj_medtent.png', r:[2,60,298,260], pivo:[154,265], base:[150,143], escala:0.5, ref:'altura 6 m', cat:'prop', solido:true, limpar:true},
  shed:              {fonte:'assets/obj_shed.png', r:[11,46,269,256], pivo:[112,261], base:[108,153], escala:0.7, ref:'porta 2,0 m', cat:'camp', solido:true, loot:'camp', limpar:true},
  cabin:             {fonte:'assets/obj_cabin.png', r:[0,45,300,284], pivo:[169,289], base:[167,130], escala:0.9, ref:'andar 2,8 m · porta 2,1 m', cat:'house', solido:true, loot:'house', limpar:true},
  palisade:          {fonte:'assets/obj_palisade.png', r:[17,57,463,455], pivo:[246,460], base:[241,216], escala:1.232, ref:'comprimento 12 m', cat:'prop', solido:true, limpar:true},
  cave:              {fonte:'assets/obj_cave.png', r:[11,48,329,321], pivo:[133,326], base:[129,192], escala:1.288, ref:'comprimento 10 m', cat:'prop', solido:true, limpar:true},
  forestpatch:       {fonte:'assets/obj_forestpatch.png', r:[0,31,360,350], pivo:[152,353], base:[143,201], escala:1.477, ref:'comprimento 12 m', cat:'prop', solido:true, limpar:true},
  rockcliff:         {fonte:'assets/obj_rockcliff.png', r:[6,31,294,280], pivo:[144,285], base:[140,149], escala:1.494, ref:'comprimento 9 m', cat:'prop', solido:true, limpar:true},
  archruin:          {fonte:'assets/obj_archruin.png', r:[14,17,286,288], pivo:[122,291], base:[120,154], escala:1.446, ref:'comprimento 9 m', cat:'prop', solido:true, limpar:true},
  farm:              {fonte:'assets/obj_farm.png', r:[0,0,460,436], pivo:[227,441], base:[217,212], escala:1.824, ref:'comprimento 16 m', cat:'prop', solido:false, flat:true, limpar:true},
  fencedtower:       {fonte:'assets/obj_fencedtower.png', r:[0,0,280,283], pivo:[123,287], base:[119,123], escala:0.7, ref:'altura 9 m', cat:'prop', solido:true, limpar:true},
}};
