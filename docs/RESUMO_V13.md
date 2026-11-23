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
- ✅ vampiro inimigo (dorme de dia, sai à noite ×1,35, volta para casa); ✅ `cortes` (l.1342: só divide a parede em volta das portas para desenhar) — coberto por `Edificio._trecho`, que desenha cada tile com batentes e folha da porta
- ✅ `povoarEdificios` (l.1160): zumbi 58% / vampiro 22% / rato 20% (`Edificio.moradores`); ✅ prédios altos (moradores por tamanho em `Quadras._predio`)
- ✅ inimigos pelo mundo aberto: densidade por zona (`MundoGen._inimigos`); o que o jogador matou não volta ao recarregar o chunk
- ✅ sprites HD das 4 raças (`SpriteFrames`: humano, homem_rato, rato_gigante, vampiro, zumbi)

## Raças e formas
- ✅ `race()`, `formRat()`, `transform` (l.1446), `maxLife` (l.153), `speed` (l.152) → `Player.definir_raca` etc.
- ✅ tela de seleção (`start`, `descriptions`, l.23-24, 1384-1389) → `SelecaoRaca` (F9 troca nos testes)
- ✅ ataque por raça (l.1419-1420), `recipeCost` humano (l.107-108)
- ✅ vampiro jogável: `player.sun`, vinheta e dano do sol (l.1745, 1845); ✅ proteção pelo totem; ✅ antídoto de ninho de morcegos (novo: a V13 só cita) → `NinhoMorcegos` + `MundoGen.ninhos` (7 tocas na mata fechada, vampiros dormindo perto na 1ª visita, vasculhar dá 1–2 antídotos uma única vez: `Mundo._saqueados`); antídoto cura a mutação vampírica, antibiótico só a retarda (+6h)
- ✅ `player.disease` (Leptospirose, Mutação vampírica, Infecção zumbi, l.1846), mutação de raça ao fim (marco 3: a mordida de zumbi virou a febre da carniça, sem transformar); ✅ efeitos do estágio (novo) → `Player.SINTOMAS`: estágio 0–3 pelos quartos do prazo, fôlego/velocidade/fome/vida por doença, avisos ao piorar; mutação vampírica do estágio 2 em diante já sente o sol (pela metade); HUD lista os sintomas
- ✅ fome: `player.food` decai 0,13/s (l.1844) → feito junto do inventário

## Veículos / cenário (objetos `COD`, l.691-727) → `ObjetoUrbano`
- ✅ carros dirigíveis: **a V13 não tem** (só cenário); `Veiculo` é recurso novo (5 veículos HD, sem combustível)
- ✅ carros abandonados nas ruas/estradas (`MundoGen._carro`: 82% dirigíveis, 18% estáticos); ✅ `COD` (pilar, cobertura, bomba, totem, contêiner, lápide, estátua, cesta, banco, chaminé, caixa d'água, barricada + caçamba e correio) → `ObjetoUrbano`; ✅ `estacionamento` → `Quadras._estacionamento` (vagas pintadas, carros, óleo)
- ✅ cercas (`CercaNo`: madeira, arame, paliçada; `_cerca_ret`); ✅ portões (`gate`, `toggleGate`, `nearGate`, `drawGate`) → `PortaoNo` em todo vão de `_cerca_ret` (ferro no acampamento, fechado como na V13; madeira nos quintais/roças); estado lembrado em `Mundo._portoes`
- ✅ `LAMP`, `mobiliarioUrbano` (l.294, 324) → postes nas calçadas a cada 16 tiles (`Quadras.postes_no`); só ~20% acendem à noite (sem rede elétrica), piscando · ✅ bueiros e lixo ao longo das vias → `Quadras._bueiros_vias` (bueiro chato no eixo da rua, vasculhável: "esgoto" = 2 sucatas; 40% com rato na 1ª visita ao chunk) e `_lixo_vias` (folhas, lixo, poça/óleo, cone, pneu e mato junto ao meio-fio; sujeira na calçada)
- ✅ `muro` e cerca `chain` → `CercaNo` estilos "muro" e "alambrado"
- Na V13 carros NÃO são lootáveis (só `scrap`, `house`, `pharmacy`, `sewer`, `camp`)

## Mundo aberto (gerador procedural, l.166-980) → `MundoGen` + `MapaMundi` + `Mundo` (ilha do mapa-múndi, chunks de 1024 u, 246 × 225 chunks)
- ✅ **ilha do mapa-múndi** (novo: guia geográfico `assets/new_assets/mapa_mundi_hd.png`) → `tools/gerar_mapa_dados.gd` classifica o mapa em `data/mapa_dados.res` (classe do terreno, mata, bioma, distância à água) e `MapaMundi` responde por ponto (bilinear); 1 px do mapa = 192 u ⇒ ilha de ~5 × 4,7 km com mar, praias, ilhotas, montanha nevada, lago com represa e cachoeira, rio até o porto com as pontes das rodovias, delta pantanoso, deserto com cânion e transição larga pelo semiárido, rodovias e estradas de terra do próprio mapa
- ✅ `genWorld` (l.943) → `Mundo` (streaming contínuo, sem tela de carga: chão e água raio 3, objetos raio 2, descarrega acima de 4, orçamento por quadro; a pé ou de carro) + `MundoGen.planejar` (determinístico por chunk; mar aberto não planeja nada)
- ✅ `cidadesTWD` (l.914), `cidade` (l.393) → 16 áreas urbanas onde o mapa tem cidade (`MundoGen.AREAS`, papéis em `Quadras.PAPEIS_AREAS`): Porto Velho (7 × 5, programa da cidade da V13 em volta da rotatória + cais), Cidade Norte (5 × 3), Vila do Lago, Base Militar (muro, alojamentos, jipes), Aeroporto (pista e hangares), Encruzilhada, São Jorge, Baía do Sul, Cruzeiro, Poeira, Forte do Leste e vilas menores; quarteirões novos `_cais`, `_militar`, `_aeroporto`
- ✅ `vilarejo` (l.413) → `MundoGen._aldeia` (6 vilarejos nas roças do mapa, lotes conferidos contra água e cidade): casas dos dois lados da estrada de terra, quintais cercados e roças com pés de milho/capim que balançam (`Plantacao`); casas isoladas nos campos (`casa_isolada_em`)
- ✅ `acampamento` (l.438) → `_planejar_acampamento` (3 acampamentos: represa, rio e delta; o ponto é achado na margem) com trilha fechada na mata até a estrada mais próxima; paliçada/arame, tendas, fogueira, caixotes, sacos de areia
- ✅ ruas: `rua`, `pintarVias`, `faixas` → `ChaoChunk._ruas` (rua de 512 u: calçada 128 + asfalto 256 + calçada 128; faixa central, faixas de pedestre em todos os braços dos cruzamentos); miolo do quarteirão 40 tiles
- ✅ `esquina`, `rotatoria`/`pintarRotatoria`, `arvoresCalcada` (l.319, 881-897) → `Quadras._vias` (gerado uma vez): lixo, folhas, mato e poças nos cantos das esquinas, pintados num `Desenho` acima do chão (`ChaoChunk._detalhes`); rotatória no cruzamento (1, 2) com anel tracejado, ilha com estátua e pracinhas nos 4 cantos (`_reservar_rotatoria` tira prédios e lotes dali); ~75 árvores de calçada com canteiro perto do meio-fio, longe de postes, cruzamentos e entradas de posto/indústria/hospital; espécie escolhida pelo raio da copa (`ARV_COPA`) contra a folga até o prédio que fica à frente dela na tela (`_folga_predio`) · ✅ `matoNasRuas` → `Quadras._mato_ruas`
- ✅ rio e pontes: `riverCells`, `paintRiver`, `ponte`, `cachoeira` (l.460-508) → água do mapa por marching squares (`MapaMundi.poligonos`): margem rasa (−38%), funda bloqueando (colisão por chunk), riachos estreitos rasos, pontes onde a rodovia do mapa cruza o rio; cachoeira na saída do lago (`MundoGen.cachoeira`, largura medida no rio) · o `viaduto` da V13 deu lugar às rodovias do mapa
- ✅ biomas (novo, a V13 não tinha): tropical → semiárido → deserto vindos do mapa, com transição orgânica; chão em camadas por vértice (`ChaoChunk._camada`: grama seca, mata, solo rachado, areia, lama, terra, rocha, cânion, neve, asfalto); a cada 0,5 s o `Mundo` lê o bioma sob a câmera e faz Tween no `CanvasModulate` (`DiaNoite.tinta_bioma`), com aviso ao entrar
- ✅ quadras especiais → `Quadras`: `quadraComercial` (fileiras, beco com caçambas, estacionamentos), `quadraHospital`, `quadraMercado`, `quadraEscola` (quadra de esportes), `quadraIgreja` (cemitério com muro), `quadraPosto`, `quadraIndustrial` (galpões, contêineres, chaminé), `quadraPraca`, `quadraCasas`/`loteCasa` (garagem, jardim, quintal, correio, cercas); `fileira`/`fabrica` · ✅ `quadraResidencialDividida` (l.910) → papel "casas_dividida" no quarteirão (2, 3): rua secundária N–S de 7 tiles (calçadas de 2, asfalto de 3, sem faixa central) em `Quadras.ruas_secundarias`, entroncamentos em T, postes, árvores, bueiros e lixo, casas dos dois lados; ✅ áreas urbanas separadas (l.931-938) → `MundoGen.AREAS`: cidade pequena ao norte (comércio com oficina/farmácia/loja/mercado + praça e casas) e área industrial a nordeste, depois do rio (2 quarteirões de galpões, um com chaminé), ligadas por estrada de terra ao norte da cachoeira; `MundoGen.ligacoes` desce de cada uma até o viaduto (a da cidade pequena segue até a cidade); o antigo quarteirão industrial da cidade (2, 0) virou casas com rua secundária, como na V13 · `quarteiraoParque`/`quarteiraoPredios`/`quarteiraoCasas`/`quarteiraoRio` (l.353-410) são código morto: `cidade()` nunca é chamada
- ✅ prédios altos: `predio` (l.528) → `Edificio` com tipo "predio" (andares, uso, cobertura plana/galpão/igreja); `fachadaPredio`, `janelaAndar`, `vitrines`, `placaFace`, `placaTelhado`, `pichar`, `deteriorar`, `escadaIncendio`, `telhadoPlano`, `torreIgreja` → `Fachada`; `PAREDES_PREDIO`, `MAT_USO`, `LOJAS`, `PLACAS`, `PICHA`, `USO_SALAS`, móveis de loja, escritório, enfermaria, sala de aula, igreja e depósito
- ✅ terreno: `tileAt`, `autotileRoads`, `buildBlendLayer` → texturas procedurais (`TerrenoTexturas`) + polígonos recortados por chunk (`ChaoChunk`)
- ✅ minimapa: `construirMinimapa` → `MinimapaBase` (1 px a cada 2 tiles; terreno do mapa ampliado + cidades, vilarejos, roças, acampamentos e edifícios pelo uso, numa Thread), `desenharMinimapa` → `Minimapa` (projeção isométrica no shader, recorte circular, bússola, seta, totem, inimigos em alerta, rumo; M amplia)

## Construções (já na Godot: `scripts/world/edificio.gd`)
- ✅ `novoEdificio`, `bsp`, `porta`, `mobiliar`, `edifColisoes`, `EDIF_atualizar`
- ✅ sujeira, hera, pichação, prédios com vários andares (`Fachada`) · ✅ `ímã de porta` (l.1184) → `Edificio._ima_de_porta` · ✅ texturas procedurais (`tex`, `GTEX`, l.1029) → `TexturasParede`: atlas único (tijolo, reboco descascando, concreto, tábuas, zinco, papel listrado/estampado, telha, ardósia, zinco de telhado, laje, reboco liso) no estilo de `concept_art/novo teste`; `Desenho` sempre desenha com o atlas (1 draw call por nó), `Edificio._face`/`_face_poli`/`_plano` mapeiam paredes, oitões, telhados e lajes; variação por trecho (espelho, fase, buracos por fatia)

## Sistemas gerais
- ✅ câmera, Y-Sort, movimento, fôlego, lanterna, ciclo dia/noite (`js/lighting.js`, `js/depth.js`)
- ✅ sombras do sol: `sol`, `sombraSol`, `sombraChar`, `silhueta` (l.1520-1530) → `SombraSol` (um ShaderMaterial compartilhado, inclinação no vertex shader em volta do ponto de apoio; o DiaNoite atualiza o sol) em `IsoProp`, `Veiculo`, jogador e inimigos; `SombraSol.ativo` vira opção do menu depois
- ✅ acabamento visual (novo): vento nas árvores, arbustos, mato e plantações (`Vento`, shader de vértice com fase pela posição); sombras de contato no pé de objetos, veículos e personagens, mais fortes de dia (`SombraSol.contato`); relevo com normal maps nos prédios (atlas), pedras, veículos, caixotes, barris e barricadas, reagindo à lanterna e aos faróis (`Relevo`, `tools/gerar_normais.gd`); partículas de poeira no ar e folhas caindo na mata (`Atmosfera`) e rastro de poeira atrás das rodas na terra e na areia (`Veiculo`)
- ✖ qualidade automática `gfxAuto` (l.69): NÃO portar — decisão do projeto: o gráfico não muda sozinho, só pelo menu de configurações
- ✅ carros queimados: 22% dos carros de rua com `queimado` (l.334), sprite escurecido por `queimar` (l.1499) → `Veiculo.queimado` (shader com a mesma mistura da V13; carcaça não liga nem anda), nas ruas e estradas
- ✅ menu/ajustes e remapeamento de teclas (`bindings`, `setBinding`, `resetBindings`, `showModal`, l.1852-1880) → `MenuConfig` (ESC; abas Controles/Vídeo/Áudio) + `Controles` (InputMap, conflito tira a tecla da outra ação, `user://configuracoes.cfg`); a linha de ajuda do HUD segue as teclas; `toast` = `HUD.aviso` · ⬜ `guard` (mirar/guarda) não existe na Godot ainda
- ✅ save/load (novo: a V13 não tem) → `SaveJogo` (`user://partida.json`): jogador (posição, raça/forma, vitais, XP, doença, mochila), totem e abrigo, relógio e a memória do mundo (coletados, portões, inimigos por chunk, ninhos vasculhados); aba Partida no menu, F5/F8 remapeáveis, "Continuar partida salva" na tela inicial e na de morte; carregar recarrega a cena
