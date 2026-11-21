---
name: afterkin-ideia
description: Filtra uma ideia, pedido ou retorno de playtest do Afterkin pelos pilares do jogo antes de virar trabalho, e anota em docs/PENDENCIAS.md como ajuste, ideia em avaliação (💭) ou item de um marco futuro. Use sempre que o Victor trouxer uma ideia nova, um "e se...", uma lista de coisas que notou jogando, ou pedir um sistema novo — antes de começar a programar.
---

# Filtro de ideias do Afterkin

O Victor decidiu (21/11/2026) seguir este rumo: fazer o playtest da 2a, **congelar sistemas sociais novos**
e ir para o **marco 3 (infecção)**, que é o que torna o jogo único. Esta skill existe para que cada ideia nova
respeite isso sem frear a criatividade dele: nada se perde, mas nem tudo vira trabalho agora.

## Antes de tudo

1. Leia `docs/PENDENCIAS.md` (o que está em andamento e qual é o marco atual).
2. Leia em `docs/DECISOES_DESIGN.md` as seções 1 (experiência central), 2 (core loop), 4 (por que o jogador
   continua), 12 (marcos) e a seção "Rumo depois do marco 2".

## O filtro (para cada ideia)

Responda, para você mesmo, estas perguntas:

1. **Alimenta um dos dois pilares?**
   - a decisão da incursão: *"forço mais um prédio ou volto?"* (risco, recurso, tempo, barulho, ferimento);
   - a pergunta *"quem eu vou me tornar?"* (infecção, tentação, natureza, o mundo reagindo ao que você virou).
2. **É conserto ou sistema novo?** Conserto = algo que já existe se comporta errado ou sem lógica (bug, fala
   estranha, valor ruim, posição ilógica). Sistema novo = mecânica, tela ou simulação que ainda não existe.
3. **Em que marco ela mora?** (2 comunidade, 3 infecção, 4 vampiro, 5 ninho/Ancestral, 6 base/cercos)
4. **Depende de algo que ainda não existe?** (sprites novos, assets, outro marco)

## Classificação

- **⬜ Agora**: conserto de algo existente, ou sistema que alimenta um pilar *e* pertence ao marco atual.
- **⬜ no marco N**: alimenta um pilar, mas mora num marco futuro → anote embaixo daquele marco.
- **⬜ depois de X**: depende de algo que ainda não existe (ex.: "depois da troca de sprites").
- **💭 Em avaliação**: sistema social novo durante o congelamento, ou ideia que não alimenta nenhum pilar.
  Não é "não": fica guardada em "Ideias em avaliação" e só começa quando o Victor confirmar.

## Como responder ao Victor

1. Para cada ideia, uma linha: a classificação e o porquê em poucas palavras, ligado ao pilar
   (ex.: "💭 — é social e estamos no congelamento; volta depois do marco 3").
2. Se alguma ideia forte não alimenta pilar nenhum, diga com franqueza e sugira como ela poderia alimentar
   (ex.: "o luto ganha força se a comunidade também reagir a você infectado — isso é marco 3").
3. Pergunte se ele concorda com a classificação **antes** de escrever (uma pergunta só, com as opções).
4. Depois de confirmado, anote em `docs/PENDENCIAS.md` no lugar certo, com a data, e faça um commit
   `docs: ...` (sem push).
5. Não comece a programar nada nesta skill. Programar é o passo seguinte, se o item for "⬜ Agora".

## Regras do projeto que valem aqui

- Português do Brasil; legenda das pendências: ⬜ falta · 🔄 em andamento · ✅ feito (com o commit) · 💭 em avaliação.
- O que o Victor decidir vira registro em `docs/DECISOES_DESIGN.md` (vale sobre o GDD).
