# Índice rápido da V13 (`docs/prototipo_html_v13/index.html`, 1888 linhas)

Só nomes e linhas aproximadas. Consulte com `sed -n 'A,Bp'` em vez de reler o arquivo.
Legenda: ✅ já na Godot · ⬜ falta migrar.

## Inventário, loot e itens (etapa atual)
- ✅ `ITEMS` (l.70), `RECIPES` (l.81), `NODE`, `LABEL` (l.86-87)
- ✅ `addToSlots`, `canAdd`, `addItems`, `countItem`, `removeItem`, `moveSlot`, `resetInventory` (l.88-104)
- ✅ `useSlot`, `eat`, `useMed` (l.123, 1450, 1452) · `renderInventory` (l.124) → `InventarioUI`
- ✅ `SAQUE`, `CONTEM`, `movelPerto`, `EDIF_interagir` (l.1054, 1169-1182) → `Edificio`
- ✅ `loot` para objetos soltos: só `scrap` (l.1398)
- ⬜ `craft`, `recipeCost`, `placeTotem`, `removeTotem`, `build` (l.106-122, 995, 1451): fabricação, totem, abrigo
- ✅ `harvestHit`, `NODE` (árvore/pedra com machado/picareta, l.1427) → `Coletavel`
- ⬜ `branch`/`pebble` (galho e pedra pequena pegos com E, l.1398-1403)
- ✅ `xpGain` (l.154) · ⬜ `updateUI` completo (l.1460): falta raça/nível/exposição solar/doença/totem

## Combate e inimigos
- ✅ `attack` (l.1415), `nearestEnemy` (l.1397) → `Player.atacar`; ✅ morte do jogador (`step`, l.1848)
- ⬜ `infectPlayer` (l.1436), `useMed` (doenças)
- ✅ `atualizarInimigos` (l.1358), `rota`, `proxPorta` (l.1346-1357) → `Inimigo` + `Edificio.rota_*`; zumbi arromba porta, rato abre
- ⬜ vampiro (dorme de dia, sai à noite), `cortes` (l.1342, só desenho de parede)
- ✅ `povoarEdificios` (l.1160) só zumbi/rato (`Edificio.moradores`); ⬜ prédios altos e vampiros
- ⬜ inimigos pelo mundo aberto (hoje só os da cena de teste)
- ✅ sprites HD de zumbi e rato gigante (`SpriteFrames`); ⬜ vampiro/homem-rato jogáveis

## Raças e formas
- ⬜ `race()`, `formRat()`, `transform` (l.1446), `maxLife` (l.153), `speed`
- ⬜ vampiro: `player.sun` e exposição (l.1845), antídoto; zumbi; rato (forma rato/humano)
- ⬜ `player.disease` (Leptospirose, Mutação vampírica, Infecção zumbi, l.1846)
- ⬜ fome: `player.food` decai 0,13/s (l.1844) → feito junto do inventário

## Veículos / cenário (objetos `COD`, l.691-727)
- ⬜ `COD`, `codObj`, `codBox`, `estacionamento` (l.728), `SPR_CAR` (l.984)
- ⬜ cercas e portões: `fseg`, `fenceRect`, `gate`, `toggleGate`, `nearGate` (l.272-291, 991)
- ⬜ `LAMP`, `mobiliarioUrbano` (l.294, 324)
- Na V13 carros NÃO são lootáveis (só `scrap`, `house`, `pharmacy`, `sewer`, `camp`)

## Mundo aberto (gerador procedural, l.166-980)
- ⬜ `genWorld` (l.943), `cidadesTWD` (l.914), `cidade`, `vilarejo`, `acampamento` (l.393-459)
- ⬜ quadras: `quadraCasas`, `quadraComercial`, `quadraHospital`, `quadraMercado`, `quadraEscola`, `quadraIgreja`, `quadraPosto`, `quadraIndustrial`, `quadraPraca`, `quadraParque` (l.364-380, 771-872)
- ⬜ ruas: `rua`, `pintarVias`, `faixas`, `esquina`, `rotatoria`, `arvoresCalcada` (l.299-323, 880-898)
- ⬜ rio e pontes: `riverCells`, `paintRiver`, `ponte`, `cachoeira`, `viaduto` (l.460-508)
- ⬜ prédios altos: `predio` (l.528), `fachadaPredio`, `telhadoPlano`, `torreIgreja`, `PAREDES_PREDIO`, `LOJAS`, `PLACAS`, `PICHA`
- ⬜ terreno: `tileAt`, `autotileRoads`, `buildBlendLayer` (`js/terrain.js`), `decal`, `cluster`
- ⬜ minimapa: `construirMinimapa`, `desenharMinimapa` (l.1763-1818)

## Construções (já na Godot: `scripts/world/edificio.gd`)
- ✅ `novoEdificio`, `bsp`, `porta`, `mobiliar`, `edifColisoes`, `EDIF_atualizar`
- ⬜ texturas procedurais (`tex`, `GTEX`), sujeira, hera, pichação, `ímã de porta`, prédios com vários andares

## Sistemas gerais
- ✅ câmera, Y-Sort, movimento, fôlego, lanterna, ciclo dia/noite (`js/lighting.js`, `js/depth.js`)
- ⬜ menu/ajustes e remapeamento de teclas (`bindings`, l.1852-1880), `showModal`, `toast`
- ⬜ save/load (não existe na V13)
