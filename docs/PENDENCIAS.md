# Pendências do Afterkin

Lista viva do que falta fazer, mantida a cada pedido. A migração da V13 está em `docs/RESUMO_V13.md`; aqui ficam os
pedidos novos e as ideias em aberto.

Legenda: ⬜ falta · 🔄 em andamento · ✅ feito (com o commit) · 💭 ideia ainda em avaliação (não começar sem confirmar)

## Em aberto
- ⬜ Guarda/mirar (`guard` da V13): na V13 é só um anel em volta do jogador, sem efeito; fazer quando houver bloqueio ou arma à distância.
- ⬜ Menu de configurações, aba Vídeo: opções para o vento (`Vento.forca`) e as sombras do sol (`SombraSol.ativo`).
- ⬜ Pisos dos cômodos com textura (tábua, ladrilho, xadrez, carpete), no estilo do "Atlas de Texturas Urbanas Desgastadas".


### MVP em marcos (`docs/DECISOES_DESIGN.md` §12) — cada um termina com playtest
- ⬜ Marco 1 — Incursão humana: 6 fases do dia (~40 min), sede e fontes de água, fim do XP/nível, origens (4), tirar a escolha de raça do início, peso da mochila.
- ⬜ Marco 2 — Comunidade e rumores: NPCs, escambo (escassez/saturação/demanda), reputação, uma especialização, log de eventos.
- ⬜ Marco 3 — Dilema da infecção: estágios com tentação, ponto sem volta, cura, morte infectada, diário (decidir linhagem/legado).
- ⬜ Marco 4 — Vida de vampiro: sangue, sol, território vampírico, Furtividade.
- ⬜ Marco 5 — Ninho e Vampiro Ancestral: prédio-ninho, chefe, três desfechos.
- ⬜ Marco 6 — Base e cercos: construção do §60, Engenharia, cercos noturnos.

## Ideias em avaliação
- 💭 (o Victor ainda está pensando em mais coisas para acrescentar)

## Feito recentemente
- ✅ Validação do GDD (entrevista Q1–Q34) → `docs/DECISOES_DESIGN.md`
- ✅ Ilha do mapa-múndi, biomas, vento, sombras de contato, normal maps e partículas (`a4ed901`)
- ✅ Save/load (`47d8a92`) · ninhos de morcegos, antídoto e sintomas por estágio (`023c279`)
