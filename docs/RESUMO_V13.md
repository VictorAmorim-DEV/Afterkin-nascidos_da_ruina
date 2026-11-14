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
- ⬜ `branch`/`pebble` (galho e pedra pequena pegos com E, l.1398-1403)
- ✅ `xpGain` (l.154) · ⬜ `updateUI` completo (l.1460): falta raça/nível/exposição solar/doença/totem

## Combate e inimigos
- ✅ `attack` (l.1415), `nearestEnemy` (l.1397) → `Player.atacar`; ✅ morte do jogador (`step`, l.1848)
- ✅ `infectPlayer` (l.1436), `useMed` (l.1452) → `Player.infectar` / `usar_antibiotico`
- ✅ `atualizarInimigos` (l.1358), `rota`, `proxPorta` (l.1346-1357) → `Inimigo` + `Edificio.rota_*`; zumbi arromba porta, rato abre
- ✅ vampiro inimigo (dorme de dia, sai à noite ×1,35, volta para casa); ⬜ `cortes` (l.1342, só desenho de parede)
- ✅ `povoarEdificios` (l.1160): zumbi 58% / vampiro 22% / rato 20% (`Edificio.moradores`); ⬜ prédios altos
- ✅ inimigos pelo mundo aberto: densidade por zona (`MundoGen._inimigos`); o que o jogador matou não volta ao recarregar o chunk
- ✅ sprites HD das 4 raças (`SpriteFrames`: humano, homem_rato, rato_gigante, vampiro, zumbi)

## Raças e formas
- ✅ `race()`, `formRat()`, `transform` (l.1446), `maxLife` (l.153), `speed` (l.152) → `Player.definir_raca` etc.
- ✅ tela de seleção (`start`, `descriptions`, l.23-24, 1384-1389) → `SelecaoRaca` (F9 troca nos testes)
- ✅ ataque por raça (l.1419-1420), `recipeCost` humano (l.107-108)
- ✅ vampiro jogável: `player.sun`, vinheta e dano do sol (l.1745, 1845); ✅ proteção pelo totem; ⬜ antídoto de ninho de morcegos
- ✅ `player.disease` (Leptospirose, Mutação vampírica, Infecção zumbi, l.1846), mutação de raça ao fim; ⬜ efeitos do estágio (a V13 não tem)
- ✅ fome: `player.food` decai 0,13/s (l.1844) → feito junto do inventário

## Veículos / cenário (objetos `COD`, l.691-727)
- ✅ carros dirigíveis: **a V13 não tem** (só cenário); `Veiculo` é recurso novo (5 veículos HD, sem combustível)
- ✅ carros abandonados nas ruas/estradas (`MundoGen._carro`: 82% dirigíveis, 18% estáticos); ⬜ `COD` completo, `estacionamento`
- ✅ cercas (`CercaNo`: madeira, arame, paliçada; `_cerca_ret`); ⬜ portões que abrem (`gate`, `toggleGate`, `nearGate`: hoje o portão é só um vão)
- ⬜ `LAMP`, `mobiliarioUrbano` (l.294, 324)
- Na V13 carros NÃO são lootáveis (só `scrap`, `house`, `pharmacy`, `sewer`, `camp`)

## Mundo aberto (gerador procedural, l.166-980) → `MundoGen` + `Mundo` (chunks de 1024 u, mundo 60 × 28 chunks)
- ✅ `genWorld` (l.943) → `Mundo` (streaming: chão e água raio 3, objetos raio 2, descarrega acima de 4) + `MundoGen.planejar`
- ✅ `cidadesTWD` (l.914), `cidade` (l.393) → cidade 3 × 4 quarteirões, lotes de 512 u com casa/prédio modular (`Edificio`), entulho, mato (`_planejar_cidade`)
- ✅ `vilarejo` (l.413) → `MundoGen._aldeia`: casas dos dois lados da estrada de terra, quintais cercados e roças; vilarejo seco no semiárido; casas isoladas na roça (`casa_isolada_em`)
- ✅ `acampamento` (l.438) → `_planejar_acampamento`: paliçada/arame, tendas, fogueira com luz, caixotes lootáveis, sacos de areia no portão; 2 acampamentos ligados por trilhas
- ✅ ruas: `rua`, `pintarVias`, `faixas` → `ChaoChunk._ruas` (calçada, asfalto, faixa central); ⬜ `esquina`, `rotatoria`, `arvoresCalcada`
- ✅ rio e pontes: `riverCells`, `paintRiver`, `ponte`, `cachoeira` (l.460-508) → rio N→S com água funda bloqueando (colisão), água rasa (−38% de velocidade), 2 vaus, ponte de madeira, cachoeira animada na nascente; ⬜ `viaduto`
- ✅ biomas (novo, a V13 não tinha): tropical → semiárido → deserto, mistura suave do chão por vértice; 5 `Area2D` + Tween de `DiaNoite.tinta_bioma`
- ⬜ quadras especiais: `quadraComercial`, `quadraHospital`, `quadraMercado`, `quadraEscola`, `quadraIgreja`, `quadraPosto`, `quadraIndustrial`, `quadraPraca`, `quadraParque` (os lotes da cidade são genéricos)
- ⬜ prédios altos: `predio` (l.528), `fachadaPredio`, `telhadoPlano`, `torreIgreja`, `PAREDES_PREDIO`, `LOJAS`, `PLACAS`, `PICHA`
- ✅ terreno: `tileAt`, `autotileRoads`, `buildBlendLayer` → texturas procedurais (`TerrenoTexturas`) + polígonos recortados por chunk (`ChaoChunk`)
- ⬜ minimapa: `construirMinimapa`, `desenharMinimapa` (l.1763-1818)

## Construções (já na Godot: `scripts/world/edificio.gd`)
- ✅ `novoEdificio`, `bsp`, `porta`, `mobiliar`, `edifColisoes`, `EDIF_atualizar`
- ⬜ texturas procedurais (`tex`, `GTEX`), sujeira, hera, pichação, `ímã de porta`, prédios com vários andares

## Sistemas gerais
- ✅ câmera, Y-Sort, movimento, fôlego, lanterna, ciclo dia/noite (`js/lighting.js`, `js/depth.js`)
- ⬜ menu/ajustes e remapeamento de teclas (`bindings`, l.1852-1880), `showModal`, `toast`
- ⬜ save/load (não existe na V13)
