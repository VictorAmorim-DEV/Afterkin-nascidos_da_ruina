# Pendências do Afterkin

Lista viva do que falta fazer, mantida a cada pedido. A migração da V13 está em `docs/RESUMO_V13.md`; aqui ficam os
pedidos novos e as ideias em aberto.

Legenda: ⬜ falta · 🔄 em andamento · ✅ feito (com o commit) · 💭 ideia ainda em avaliação (não começar sem confirmar)

## Em aberto
- ⬜ Guarda/mirar (`guard` da V13): na V13 é só um anel em volta do jogador, sem efeito; fazer quando houver bloqueio ou arma à distância.
- ⬜ Menu de configurações, aba Vídeo: opções para o vento (`Vento.forca`) e as sombras do sol (`SombraSol.ativo`).
- ⬜ Pisos dos cômodos com textura (tábua, ladrilho, xadrez, carpete), no estilo do "Atlas de Texturas Urbanas Desgastadas".


### MVP em marcos (`docs/DECISOES_DESIGN.md` §12) — cada um termina com playtest
- ✅ Marco 1 — Incursão humana (aprovado no playtest de 18/11/2026; resultado em `docs/PLAYTEST_MARCO1.md`). Etapas:
  - ✅ 1. Fim do XP/nível; todos começam humanos (`dd97f4c`).
  - ✅ 2. Relógio de 6 fases (40 min/dia), temperatura, multiplicadores de visão/ruído (`3ad0ec4`, `8f6c6ee`).
  - ✅ 3. Sede e água (fome e sede por hora de jogo, água suja/limpa, ferver, disenteria) (`3218b4f`).
  - ✅ 4. Peso da mochila (25 kg) (`d07679b`).
  - ✅ 5. Tela de origem (Policial com pistola mínima provisória, Mecânico, Enfermeiro(a), Mestre de Obras) (`a3e14a4`).
  - ✅ 6. Bilhete inicial apontando a água e roteiro de playtest (`docs/PLAYTEST_MARCO1.md`).
  - ✅ 7. Playtest do Victor e ajustes a partir das respostas. Primeiros ajustes pedidos:
    - ✅ 7a. Início com sentido: nascer num lugar da cidade ligado à história ("eu estava no acampamento / no
      supermercado / na delegacia quando tudo começou"), não no meio da rodovia. (`84bea31`, `09cd6a1`)
    - ✅ 7b (`975088b`). Minimapa de um tamanho só (área pequena ao redor); M abre o mapa do mundo inteiro no meio da tela, com
      ícones e legenda (supermercado, hospital, restaurante, NPCs principais...) e nomes dos lugares por categoria
      (acampamentos, vilarejos, cidades grandes).
    - ✅ 7c (`5ed4fba`). Começo guiado: diálogo/mini tutorial que apresente a história, a lógica e as mecânicas.
    Retorno do primeiro playtest (17/11): sem objetivo claro a incursão não se sustenta (confirma o marco 2);
    não deu para testar noite, sede, doença e fogueira por falta de tempo. Pedidos:
    - ✅ 7d–7j (`166a323`). Modo desenvolvedor: dar itens, teleportar, fôlego infinito, voar pelo mapa, pular o tempo etc.
    - ✅ 7e. Tiro vai para onde o mouse aponta (mira), não para onde o boneco está virado.
    - ✅ 7f. Faróis do carro não acendiam (a luz nascia dentro da carroceria e o oclusor do próprio carro a apagava); o HUD dentro do carro mostra os faróis, não a lanterna.
    - ✅ 7g. A luz da lanterna sai do pé; deve sair da lanterna na mão.
    - ✅ 7h. Peso: 35 kg e itens ~40% mais leves.
    - ✅ 7i. Água suja: só "Você bebeu"; a disenteria aparece 2–5 h de jogo depois, e o aviso é o sintoma.
    - ✅ 7j. Roteiro de playtest mais simples (o que é incursão, onde anotar), usando o modo desenvolvedor.
    Segundo retorno (18/11): marco aprovado. Pedidos:
    - ✅ 7k. Voo do modo desenvolvedor com 4×, 8×, 10× e 16×.
    - ✅ 7l. Disenteria: fase aguda curta e efeito prolongado (36 h) até passar ou até um antibiótico.
    - ✅ 7m. Mapa da tela inicial demorava ~5,6 s para gerar: agora vem de um cache em disco (user://).
- 🔄 Marco 2 — Comunidade e rumores: NPCs, escambo (escassez/saturação/demanda), reputação, uma especialização, log de eventos.
  - ✅ 1. Rodada de perguntas de design (Q35–Q56) → `docs/DECISOES_DESIGN.md`, seção "Marco 2".
  **Etapa 2a** (Vila dos Pescadores + Acampamento Santuário do Sol; termina com playtest):
  - ✅ 2. Locais de início sem comunidade, cama fabricável e tela de respawn com o mapa (camas + lugares de início).
    - ✅ 2a. Início em Porto Atlântico, Baía Dourada, São Jorge, Cruz das Almas, Cruzeiro e Areal (`e03c8ea`).
    - ✅ 2b. Cama fabricável e tela de respawn (`2894619`).
  - ✅ 2c (`2d7b5c6`). Cansaço e cama: E na cama abre "Deitar e descansar" (o tempo corre, descansa aos poucos) e "Deitar e
    dormir" (6–7 h de jogo passam, descanso 100%). O cansaço sobe com o tempo acordado e limita até onde o fôlego
    recarrega (100% → 80% → 60% → 40% → 15% quando esgotado).
  - ✅ 3 (`a5b62db`). Dados de comunidades e NPCs (arquivos de dados), NPCs no mundo com sprite provisório, rotina pelas fases e portões.
  - ✅ 4 (`91308aa`). Personagens das duas comunidades aprovados pelo Victor (documento "Afterkin — Personagens
    das comunidades", https://claude.ai/artifact/12rxpJCaHWvp9ChuAFt9JX) e passados para `data/comunidades/*.json`
    (nome, idade, quem é, como fala, o que quer, segredo, como recebe o jogador, parentes).
  - ✅ 4b (`50b342f`). Gênero do personagem (masculino/feminino) na criação, para as falas se ajustarem ("meu filho"/"minha
    filha" da Dona Iracema) e, quando houver, o sprite.
  - ✅ 5 (`50b342f`). Diálogo em árvore (condições: reputação, hora, rumores, origem; consequências).
  - ✅ 6 (`d7873fc`). Memória dos NPCs (testemunhas e boatos) → reputação por comunidade e humana geral, com atraso entre aliadas.
  - ✅ 7 (`77b0683`). Escambo em duas colunas + balança (escassez, saturação, demanda).
  - ✅ 8 (`6b1aa4f`). Simulação abstrata das comunidades (necessidades, decisões, expedições), real perto do jogador.
  - ✅ 9 (`689ffde`). Rumores por conversa, conversas ouvidas, mural/bilhetes e rádio, marcando regiões no mapa.
  - ✅ 9b (`d7ab01d`). Rumor no mapa como "?" âmbar com "Rumor: <rótulo>"; ao chegar ao lugar de verdade,
    "Local descoberto: <nome>" e o "?" vira o ícone do que foi achado (morcego no ninho, perigo, suprimentos...).
  - ✅ 10 (`8c28cb6`). Sobreviventes errantes na cidade (pedem ajuda, trocam, roubar/matar, hostis, em combate, encaminhar).
  - ✅ 10b (`fe2ee5d`). Ecossistema vivo de errantes (pedido de 20/11/2026): população persistente que vive sem o jogador
    (anda pelo mapa, vasculha, caça, luta, foge, pede ajuda, embosca), abstrata longe e real perto; combate de verdade
    entre NPCs e monstros (tabela de monstros: zumbi, vampiro, rato e, no futuro, bárbaros, feiticeiras...); índole que
    muda com a vida; reputação com bandos de saqueadores/Assassinos para ser aceito; expedições das comunidades como
    grupos que andam. Substitui o "aparece perto do jogador" da etapa 10. Fases A–E (confirmado).
  - ✅ 11 (`704a5d5`). Medicina: mestre, cadeia gerada pela necessidade, habilidades (pedido de 21/11/2026: as quatro habilidades,
    Diagnóstico, Tratar ferimentos, Preparar remédios e Cirurgia de campo, uma por passo; o Enfermeiro(a) pula o primeiro;
    depois de aprender, as comunidades sem médico pedem ajuda ao jogador).
  - ✅ 11b (`9640519`). Retorno do teste de 21/11/2026 (fases A–E, confirmado):
    - ✅ Cobrança: vítima ≠ testemunha, falam do alvo pelo nome/parentesco, a vítima não conversa até você se redimir;
      desculpas (com ou sem reparação), mentir e ameaçar.
    - ✅ Dona Iracema viva de novo: não se reproduziu; morador que consta como morto agora some na hora, e as falas que
      citavam um morto como vivo somem ou mudam.
    - ✅ Consequências da morte: luto, quem assume o papel (aprendiz de médico com nível que evolui), parentes que
      investigam e se vingam (atacar, emboscar, contratar saqueadores, cobrar justiça) e comunidade que expulsa o assassino.
  - ✅ 12 (`b6e3b8b`). Vida na comunidade: dormir, usar a estrutura, trabalhar por reputação; portão fechado com reputação baixa
    (respostas de 21/11/2026: dormir só com reputação alta; trabalhos de vigia, pesca/caça/roça, recados e consertos;
    tudo em tempo real; abaixo de −20 só se fala pelo portão).
  - ⬜ 12b. Cama de hóspede dentro de uma barraca/casa acessível (hoje fica ao lado da fogueira, sem lógica). Fazer
    depois da troca de sprites e assets que o Victor vai trazer.
  - ✅ 13 (`d929603`). Log de eventos, exportar o diário e ferramenta de resumo visual (21/11/2026: sem botão; exporta sozinho
    ao morrer e ao fechar o jogo, na pasta do jogo; o resumo é uma página HTML).
  - ✅ 14. Playtest da 2a (roteiro em `docs/PLAYTEST_MARCO2A.md`; relatório em `docs/PLAYTEST_MARCO2.md`).
  - ✅ 14b (`f6aec85`). Ajustes do playtest (21/11/2026): diálogo que emenda, retorno dos trabalhos, falas do Guga e do
    Caio, reputação visível (HUD e mapa), menos rumores (novidade não é pista; intervalo de 3 h), nomes únicos dos
    errantes. O diário grava o trabalho do forte (testado); as redes do playtest provavelmente não chegaram ao fim.
  **Rumo (21/11/2026):** depois do playtest, congelar sistemas sociais novos e ir para o marco 3 (ver "Rumo depois do
  marco 2" em `docs/DECISOES_DESIGN.md`; ideias novas passam pela skill `afterkin-ideia`).
  **Etapa 2b:** Mangue Vermelho (Assassinos), Vila Nova da Serra, Rancho do Cânion e Lago da Águia.
  - ⬜ Sprites novos dos NPCs (o Victor traz as folhas; eu recorto e animo).
  - ⬜ Skill `afterkin-npc` (rascunhar um NPC novo no formato dos JSON de comunidade e diálogo), na etapa 2b.
- ⬜ Marco 3 — Dilema da infecção (entrevista de 22–23/11/2026: "Marco 3 e o formato do jogo" em
  `docs/DECISOES_DESIGN.md`). Código novo escrito "por jogador" (co-op). Etapas:
  - ✅ 3.1 (`978bebd`) Herança da V13 e vocabulário: todos começam humanos (sai a raça da criação; F1 continua), febre da carniça
    no lugar da mordida de zumbi, zumbis e ratos apresentados como Necróticos e Bestiais.
  - ✅ 3.2 (`811c045`, `d8043be`, `6852f26`) Infecção vampírica: 48 h em 4 estágios (Marca, Fome, Sede, Limiar), poderes e custos, mordida como
    habilidade do vampiro (aviso, recarga, chance pelo jeito da mordida), sangue (bicho, corpo, pessoa) e rapto.
  - ✅ 3.2d (`4fcddab`) Ajustes pedidos depois da 3.2: corpos ficam até o jogador ir a mais de 70 m (aí 5 min
    reais, pausando quando ele volta), arrastar corpos, corpo com marcas de dentes achado põe a comunidade em alerta;
    moradores dormem visíveis na cama (Vila) ou na entrada da barraca, acordam com barulho; pegar quem dorme.
  - ✅ 3.3 (`3387a16`) Cura e Medicina com peso: antídoto em camadas, soro de contenção, diagnóstico com as horas, sequela;
    Mãe da Colônia no ninho de morcegos (sangue antigo, um por jogador perto, renasce 1 h real com a sala aberta).
  - ✅ 3.4 (`dff79c1`) Morte: transforma só nos estágios 3–4; mapa de renascimento com locais descobertos, camas e base.
  - ✅ 3.5 (`62c2c38`, `a77f89c`, `b002772`) Reação social (laços pela infecção): quarentena, vistoria, esconder/mentir/contar, quem acoberta e quem
    denuncia, transformado é monstro (guarda ataca de dia e de noite). A regra da comunidade vale para qualquer
    infectado ou transformado, jogador ou NPC (23/11/2026): quarentena (enfermaria ou casa trancada até existir a
    cela), expulsão, ou morte se ninguém tiver afinidade com ele; atacando, os outros reagem.
  - ✅ 3.6 (`0056082`) Diário do jogador (J): objetivo atual, sobrevivência, "O que está acontecendo comigo?", lista com [✓],
    página "Raças e espécies".
  - ⬜ 3.7 Começo e ato 1 (gancho das primeiras horas): cutscene provisória (pular aos 5 s, ESC por 2 s), enfermaria
    da Vila e o Toné, missão principal até "A noite do ataque".
  - ⬜ 3.8 Playtest do marco 3.
- ⬜ Depois do marco 3: níveis de habilidade (por hobbies e trabalhos; a missão do mestre dá o nível máximo; sem
  nível de personagem). Junta as antigas ideias de habilidades e trabalhos do playtest 2a.
- ⬜ Depois do 3D: teste de rede — sala no PC do host (até 10), Epic Online Services (amigos, lobby, retransmissão),
  convite da Steam e código da sala, rede separada da loja; converter os pontos que supõem um jogador só;
  configurações da sala (dificuldade Novato/Intermediário/Expert, morte permanente); caído e kit de reanimação.
- ⬜ Cutscene completa de abertura (queda do mundo, espécies, militares, resgate de carro), quando houver arte.
- ⬜ Depois do marco 3: teste curto de 3D (2–3 dias, num ramo separado) para decidir entre 3D completo, 3D gravado em
  sprite ou 2D. Montar um personagem completo (corpo base MPFB2 ou pacote modular, uma troca de roupa, uma armadura,
  uma arma na mão, uma capa com SpringBone, um ataque com animação Mixamo/Quaternius) e uma criatura gerada no Tripo
  ou Meshy. Referências: folhas de personagem que o Victor vai gerar (frente/lado/costas, pose em T ou A, fundo liso,
  1024 px+, peças de roupa e armas separadas; eu ajudo no prompt). Pede conta no Tripo ou no Meshy.
- ⬜ Marco 4 — Vida de vampiro: sangue, sol, território vampírico, Furtividade, ecos das especializações, bônus ao
  voltar a ser humano, trégua de 2 dias com o amigo que virou (salvar, juntar-se ou romper), cativo.
  - ⬜ NPC mordido pelo jogador vampiro (23/11/2026): pega a infecção e, sem cura em 24 h de jogo, vira vampiro;
    morrer antes impede, em qualquer estágio. Transformado, pode explicar quem é ou atacar se não resistir; a
    comunidade reage pela regra da 3.5. O humano infectado não passa a infecção: só o transformado.
- ⬜ Marco 5 — Guerra das raças: bases e bosses por espécie, base-mestra com totem, Ancestral e fortaleza humana,
  ritual de transformação, os quatro finais (cura global com cutscene, extermínios, conversão forçada), raça extinta.
  NPC do ato 2 que explica as raças e as espécies.
- ⬜ Marco 6 — Base e cercos: construção do §60, Engenharia, cercos noturnos.
  - ⬜ Cela de quarentena (nas comunidades e na base), para prender infectados e transformados (23/11/2026).

## Ideias em avaliação
- 💭 (o Victor ainda está pensando em mais coisas para acrescentar)
- 💭 Loot: rever o que cada recipiente/local dá (a discutir).
- 💭 Construções e funções de cada local; casas e prédios em lugares estranhos; distribuição de árvores e ruas.
- 💭 Dificuldade dos monstros e o nome deles (em estudo: "Transformados").
- 💭 Trabalhos com algo para fazer (vigia que avista e avisa, rede como pequena tarefa) (playtest 2a); pode entrar
  junto com os níveis de habilidade.
- 💭 Servidor dedicado ou público (24 h, sem host); por enquanto, só a sala no PC do host.
- 💭 Bestiais e Necróticos jogáveis; nomes (Bárbaro no lugar do Homem-tigre? Ratman).
- 💭 Tamanho do mapa e distâncias entre os lugares (o Victor ainda está avaliando; não mexer por enquanto).

## Feito recentemente
- ✅ Validação do GDD (entrevista Q1–Q34) → `docs/DECISOES_DESIGN.md` (`6262f42`)
- ✅ Ilha do mapa-múndi, biomas, vento, sombras de contato, normal maps e partículas (`a4ed901`)
- ✅ Save/load (`47d8a92`) · ninhos de morcegos, antídoto e sintomas por estágio (`023c279`)
