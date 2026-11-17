# Pendências do Afterkin

Lista viva do que falta fazer, mantida a cada pedido. A migração da V13 está em `docs/RESUMO_V13.md`; aqui ficam os
pedidos novos e as ideias em aberto.

Legenda: ⬜ falta · 🔄 em andamento · ✅ feito (com o commit) · 💭 ideia ainda em avaliação (não começar sem confirmar)

## Em aberto
- ⬜ Guarda/mirar (`guard` da V13): na V13 é só um anel em volta do jogador, sem efeito; fazer quando houver bloqueio ou arma à distância.
- ⬜ Menu de configurações, aba Vídeo: opções para o vento (`Vento.forca`) e as sombras do sol (`SombraSol.ativo`).
- ⬜ Pisos dos cômodos com textura (tábua, ladrilho, xadrez, carpete), no estilo do "Atlas de Texturas Urbanas Desgastadas".


### MVP em marcos (`docs/DECISOES_DESIGN.md` §12) — cada um termina com playtest
- 🔄 Marco 1 — Incursão humana. Etapas:
  - ✅ 1. Fim do XP/nível; todos começam humanos (`dd97f4c`).
  - ✅ 2. Relógio de 6 fases (40 min/dia), temperatura, multiplicadores de visão/ruído (`3ad0ec4`, `8f6c6ee`).
  - ✅ 3. Sede e água (fome e sede por hora de jogo, água suja/limpa, ferver, disenteria) (`3218b4f`).
  - ✅ 4. Peso da mochila (25 kg) (`d07679b`).
  - ✅ 5. Tela de origem (Policial com pistola mínima provisória, Mecânico, Enfermeiro(a), Mestre de Obras) (`a3e14a4`).
  - ✅ 6. Bilhete inicial apontando a água e roteiro de playtest (`docs/PLAYTEST_MARCO1.md`).
  - 🔄 7. Playtest do Victor (3–4 incursões) e ajustes a partir das respostas. Primeiros ajustes pedidos:
    - ✅ 7a. Início com sentido: nascer num lugar da cidade ligado à história ("eu estava no acampamento / no
      supermercado / na delegacia quando tudo começou"), não no meio da rodovia. (O mapa na tela de escolha vem com o 7b.)
    - ⬜ 7b. Minimapa de um tamanho só (área pequena ao redor); M abre o mapa do mundo inteiro no meio da tela, com
      ícones e legenda (supermercado, hospital, restaurante, NPCs principais...) e nomes dos lugares por categoria
      (acampamentos, vilarejos, cidades grandes).
    - ⬜ 7c. Começo guiado: diálogo/mini tutorial que apresente a história, a lógica e as mecânicas.
- ⬜ Marco 2 — Comunidade e rumores: NPCs, escambo (escassez/saturação/demanda), reputação, uma especialização, log de eventos.
- ⬜ Marco 3 — Dilema da infecção: estágios com tentação, ponto sem volta, cura, morte infectada, diário (decidir linhagem/legado).
- ⬜ Marco 4 — Vida de vampiro: sangue, sol, território vampírico, Furtividade.
- ⬜ Marco 5 — Ninho e Vampiro Ancestral: prédio-ninho, chefe, três desfechos.
- ⬜ Marco 6 — Base e cercos: construção do §60, Engenharia, cercos noturnos.

## Ideias em avaliação
- 💭 (o Victor ainda está pensando em mais coisas para acrescentar)

## Feito recentemente
- ✅ Validação do GDD (entrevista Q1–Q34) → `docs/DECISOES_DESIGN.md` (`6262f42`)
- ✅ Ilha do mapa-múndi, biomas, vento, sombras de contato, normal maps e partículas (`a4ed901`)
- ✅ Save/load (`47d8a92`) · ninhos de morcegos, antídoto e sintomas por estágio (`023c279`)
