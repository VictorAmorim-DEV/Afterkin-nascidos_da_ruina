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
  - ⬜ 10b. Ecossistema vivo de errantes (pedido de 20/11/2026): população persistente que vive sem o jogador
    (anda pelo mapa, vasculha, caça, luta, foge, pede ajuda, embosca), abstrata longe e real perto; combate de verdade
    entre NPCs e monstros (tabela de monstros: zumbi, vampiro, rato e, no futuro, bárbaros, feiticeiras...); índole que
    muda com a vida; reputação com bandos de saqueadores/Assassinos para ser aceito; expedições das comunidades como
    grupos que andam. Substitui o "aparece perto do jogador" da etapa 10. Fases A–E, aguardando confirmação.
  - ⬜ 11. Medicina: mestre, cadeia gerada pela necessidade, habilidades.
  - ⬜ 12. Vida na comunidade: dormir, usar a estrutura, trabalhar por reputação; portão fechado com reputação baixa.
  - ⬜ 13. Log de eventos em user://, exportar o diário e ferramenta de resumo visual.
  - ⬜ 14. Playtest da 2a.
  **Etapa 2b:** Mangue Vermelho (Assassinos), Vila Nova da Serra, Rancho do Cânion e Lago da Águia.
  - ⬜ Sprites novos dos NPCs (o Victor traz as folhas; eu recorto e animo).
- ⬜ Marco 3 — Dilema da infecção: estágios com tentação, ponto sem volta, cura, morte infectada, diário (decidir linhagem/legado).
- ⬜ Marco 4 — Vida de vampiro: sangue, sol, território vampírico, Furtividade.
- ⬜ Marco 5 — Ninho e Vampiro Ancestral: prédio-ninho, chefe, três desfechos.
- ⬜ Marco 6 — Base e cercos: construção do §60, Engenharia, cercos noturnos.

## Ideias em avaliação
- 💭 (o Victor ainda está pensando em mais coisas para acrescentar)
- 💭 Loot: rever o que cada recipiente/local dá (a discutir).
- 💭 Construções e funções de cada local; casas e prédios em lugares estranhos; distribuição de árvores e ruas.
- 💭 Dificuldade dos monstros e o nome deles (em estudo: "Transformados").
- 💭 Tamanho do mapa e distâncias entre os lugares (o Victor ainda está avaliando; não mexer por enquanto).

## Feito recentemente
- ✅ Validação do GDD (entrevista Q1–Q34) → `docs/DECISOES_DESIGN.md` (`6262f42`)
- ✅ Ilha do mapa-múndi, biomas, vento, sombras de contato, normal maps e partículas (`a4ed901`)
- ✅ Save/load (`47d8a92`) · ninhos de morcegos, antídoto e sintomas por estágio (`023c279`)
