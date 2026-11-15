# Índice rápido da V13 (`docs/prototipo_html_v13/index.html`, 1888 linhas)

Só nomes e linhas aproximadas. Consulte com `sed -n 'A,Bp'` em vez de reler o arquivo.
Legenda: ✅ já na Godot · ⬜ falta migrar.

## Inventário, loot e itens (etapa atual)
- ✅ `ITEMS` (l.70), `RECIPES` (l.81), `NODE`, `LABEL` (l.86-87)
- ✅ `addToSlots`, `canAdd`, `addItems`, `countItem`, `removeItem`, `moveSlot`, `resetInventory` (l.88-104)
- ✅ `useSlot`, `eat`, `useMed` (l.123, 1450, 1452) · `renderInventory` (l.124) → `InventarioUI`
- ✅ `SAQUE`, `CONTEM`, `movelPerto`, `EDIF_interagir` (l.1054, 1169-1182) → `Edificio`
- ✅ `loot` para objetos soltos: só `scrap` (l.1398)
- ✅ `craft`, `recipeCost`, `placeTotem`, `removeTotem`, `build` (l.106-122, 995, 1451) → `Inventario.fabricar` + `Territorio` (totem, abrigo, receita do totem na UI)
- ✅ `harvestHit`, `NODE` (árvore/pedra com machado/picareta, l.1427) → `Coletavel`
- ✅ `branch`/`pebble` (l.1398-1404) → `ColetaSolta` (1–3 madeira/pedra, 2 XP; espalhados por `MundoGen._coletas` + anel no início; o que foi pego não volta: `Mundo._coletados`)
- ✅ `xpGain` (l.154) · ✅ `updateUI` (l.1460): `hudStealth` (postura + furtividade), `hudArea`, cartões `statusItems` na mochila, anel de barulho no chão (l.1650)

## Combate e inimigos
- ✅ `attack` (l.1415), `nearestEnemy` (l.1397) → `Player.atacar`; ✅ morte do jogador (`step`, l.1848)
- ✅ `infectPlayer` (l.1436), `useMed` (l.1452) → `Player.infectar` / `usar_antibiotico`
- ✅ `atualizarInimigos` (l.1358), `rota`, `proxPorta` (l.1346-1357) → `Inimigo` + `Edificio.rota_*`; zumbi arromba porta, rato abre
- ✅ vampiro inimigo (dorme de dia, sai à noite ×1,35, volta para casa); ⬜ `cortes` (l.1342, só desenho de parede)
- ✅ `povoarEdificios` (l.1160): zumbi 58% / vampiro 22% / rato 20% (`Edificio.moradores`); ✅ prédios altos (moradores por tamanho em `Quadras._predio`)
- ✅ inimigos pelo mundo aberto: densidade por zona (`MundoGen._inimigos`); o que o jogador matou não volta ao recarregar o chunk
- ✅ sprites HD das 4 raças (`SpriteFrames`: humano, homem_rato, rato_gigante, vampiro, zumbi)

## Raças e formas
- ✅ `race()`, `formRat()`, `transform` (l.1446), `maxLife` (l.153), `speed` (l.152) → `Player.definir_raca` etc.
- ✅ tela de seleção (`start`, `descriptions`, l.23-24, 1384-1389) → `SelecaoRaca` (F9 troca nos testes)
- ✅ ataque por raça (l.1419-1420), `recipeCost` humano (l.107-108)
- ✅ vampiro jogável: `player.sun`, vinheta e dano do sol (l.1745, 1845); ✅ proteção pelo totem; ⬜ antídoto de ninho de morcegos
- ✅ `player.disease` (Leptospirose, Mutação vampírica, Infecção zumbi, l.1846), mutação de raça ao fim; ⬜ efeitos do estágio (a V13 não tem)
- ✅ fome: `player.food` decai 0,13/s (l.1844) → feito junto do inventário

## Veículos / cenário (objetos `COD`, l.691-727) → `ObjetoUrbano`
- ✅ carros dirigíveis: **a V13 não tem** (só cenário); `Veiculo` é recurso novo (5 veículos HD, sem combustível)
- ✅ carros abandonados nas ruas/estradas (`MundoGen._carro`: 82% dirigíveis, 18% estáticos); ✅ `COD` (pilar, cobertura, bomba, totem, contêiner, lápide, estátua, cesta, banco, chaminé, caixa d'água, barricada + caçamba e correio) → `ObjetoUrbano`; ✅ `estacionamento` → `Quadras._estacionamento` (vagas pintadas, carros, óleo)
- ✅ cercas (`CercaNo`: madeira, arame, paliçada; `_cerca_ret`); ✅ portões (`gate`, `toggleGate`, `nearGate`, `drawGate`) → `PortaoNo` em todo vão de `_cerca_ret` (ferro no acampamento, fechado como na V13; madeira nos quintais/roças); estado lembrado em `Mundo._portoes`
- ✅ `LAMP`, `mobiliarioUrbano` (l.294, 324) → postes nas calçadas a cada 16 tiles (`Quadras.postes_no`); só ~20% acendem à noite (sem rede elétrica), piscando · ⬜ bueiros e lixo ao longo das vias
- ✅ `muro` e cerca `chain` → `CercaNo` estilos "muro" e "alambrado"
- Na V13 carros NÃO são lootáveis (só `scrap`, `house`, `pharmacy`, `sewer`, `camp`)

## Mundo aberto (gerador procedural, l.166-980) → `MundoGen` + `Mundo` (chunks de 1024 u, mundo 60 × 28 chunks)
- ✅ `genWorld` (l.943) → `Mundo` (streaming: chão e água raio 3, objetos raio 2, descarrega acima de 4) + `MundoGen.planejar`
- ✅ `cidadesTWD` (l.914), `cidade` (l.393) → cidade 3 × 4 quarteirões com papéis fixos (`Quadras.PAPEIS`), gerados uma vez por quarteirão e distribuídos por chunk (`Quadras.specs_no`, `chao_no`)
- ✅ `vilarejo` (l.413) → `MundoGen._aldeia`: casas dos dois lados da estrada de terra, quintais cercados e roças; vilarejo seco no semiárido; casas isoladas na roça (`casa_isolada_em`)
- ✅ `acampamento` (l.438) → `_planejar_acampamento`: paliçada/arame, tendas, fogueira com luz, caixotes lootáveis, sacos de areia no portão; 2 acampamentos ligados por trilhas
- ✅ ruas: `rua`, `pintarVias`, `faixas` → `ChaoChunk._ruas` (calçada, asfalto, faixa central, faixas de pedestre em todos os braços dos cruzamentos)
- ✅ `esquina`, `rotatoria`/`pintarRotatoria`, `arvoresCalcada` (l.319, 881-897) → `Quadras._vias` (gerado uma vez): lixo, folhas, mato e poças nos cantos das esquinas, pintados num `Desenho` acima do chão (`ChaoChunk._detalhes`); rotatória no cruzamento (1, 2) com anel tracejado, ilha com estátua e pracinhas nos 4 cantos (`_reservar_rotatoria` tira prédios e lotes dali); ~65 árvores de calçada com canteiro, longe de postes, cruzamentos e entradas de posto/indústria/hospital; copa conforme a folga até o prédio da frente (`_folga_predio`: nenhuma, só jovem ou qualquer) · ⬜ `matoNasRuas`
- ✅ rio e pontes: `riverCells`, `paintRiver`, `ponte`, `cachoeira` (l.460-508) → rio N→S com água funda bloqueando (colisão), água rasa (−38% de velocidade), 2 vaus, ponte de madeira, cachoeira animada na nascente; ⬜ `viaduto`
- ✅ biomas (novo, a V13 não tinha): tropical → semiárido → deserto, mistura suave do chão por vértice; 5 `Area2D` + Tween de `DiaNoite.tinta_bioma`
- ✅ quadras especiais → `Quadras`: `quadraComercial` (fileiras, beco com caçambas, estacionamentos), `quadraHospital`, `quadraMercado`, `quadraEscola` (quadra de esportes), `quadraIgreja` (cemitério com muro), `quadraPosto`, `quadraIndustrial` (galpões, contêineres, chaminé), `quadraPraca`, `quadraCasas`/`loteCasa` (garagem, jardim, quintal, correio, cercas); `fileira`/`fabrica` · ⬜ `quadraParque` e `quadraResidencialDividida` (rua secundária); área industrial e cidade pequena separadas (a Godot tem uma cidade só: a indústria virou um quarteirão)
- ✅ prédios altos: `predio` (l.528) → `Edificio` com tipo "predio" (andares, uso, cobertura plana/galpão/igreja); `fachadaPredio`, `janelaAndar`, `vitrines`, `placaFace`, `placaTelhado`, `pichar`, `deteriorar`, `escadaIncendio`, `telhadoPlano`, `torreIgreja` → `Fachada`; `PAREDES_PREDIO`, `MAT_USO`, `LOJAS`, `PLACAS`, `PICHA`, `USO_SALAS`, móveis de loja, escritório, enfermaria, sala de aula, igreja e depósito
- ✅ terreno: `tileAt`, `autotileRoads`, `buildBlendLayer` → texturas procedurais (`TerrenoTexturas`) + polígonos recortados por chunk (`ChaoChunk`)
- ✅ minimapa: `construirMinimapa` → `MinimapaBase` (1 px por tile, gerado numa Thread a partir do MundoGen/Quadras, edifícios pelo uso), `desenharMinimapa` → `Minimapa` (projeção isométrica no shader, recorte circular, bússola, seta, totem, inimigos em alerta, rumo; M amplia 60 m ↔ 180 m)

## Construções (já na Godot: `scripts/world/edificio.gd`)
- ✅ `novoEdificio`, `bsp`, `porta`, `mobiliar`, `edifColisoes`, `EDIF_atualizar`
- ✅ sujeira, hera, pichação, prédios com vários andares (`Fachada`) · ⬜ texturas procedurais das paredes (`tex`, `GTEX`: hoje cor lisa + detalhes desenhados), `ímã de porta`

## Sistemas gerais
- ✅ câmera, Y-Sort, movimento, fôlego, lanterna, ciclo dia/noite (`js/lighting.js`, `js/depth.js`)
- ✅ menu/ajustes e remapeamento de teclas (`bindings`, `setBinding`, `resetBindings`, `showModal`, l.1852-1880) → `MenuConfig` (ESC; abas Controles/Vídeo/Áudio) + `Controles` (InputMap, conflito tira a tecla da outra ação, `user://configuracoes.cfg`); a linha de ajuda do HUD segue as teclas; `toast` = `HUD.aviso` · ⬜ `guard` (mirar/guarda) não existe na Godot ainda
- ⬜ save/load (não existe na V13)
