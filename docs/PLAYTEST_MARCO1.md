# Playtest do marco 1 — Incursão humana (versão curta)

**Pergunta do marco:** sair → arriscar → voltar é divertido, mesmo sem NPCs e sem transformação?

**Incursão** = sair de um lugar seguro com um objetivo, fazer o que der, e voltar vivo para esse lugar (ou morrer).
Como o jogo ainda não dá objetivos (isso vem com os rumores do marco 2), os objetivos estão prontos aqui embaixo.

**Onde anotar:** onde for mais fácil — um bloco de notas, o celular, ou só me contar depois. Não precisa de tabela.

**Modo desenvolvedor (F1):** dar itens, teleportar, fôlego infinito, invencível, sem fome/sede, invisível, voar,
pular a hora, acelerar o relógio (×10, ×60), revelar o mapa, curar, pegar doença, matar inimigos perto.
Use à vontade para chegar rápido no que quer testar; nas incursões "de verdade" (parte 2), deixe tudo desligado.

---

## Parte 1 — Cenários rápidos com o F1 (~15 min)

Cada um leva 2–3 minutos. Depois de cada, anote uma frase: *funcionou? foi interessante? algo estranho?*

1. **Começo.** Partida nova, leia (ou pule) o prólogo e siga os dois primeiros passos da lista (água e vasculhar).
2. **Água suja.** Beba de uma poça. No F1, ponha o relógio em ×60 e espere: a disenteria pode aparecer horas
   depois (ou não — é chance). Depois, F1 → dê 5 madeira e 3 pedra, fabrique a fogueira e ferva água suja.
3. **Noite.** F1 → 19h. Ande pela cidade com a lanterna ligada, depois desligada (F) e agachado (Ctrl).
   Os inimigos reagem diferente? A noite dá medo?
4. **Peso.** F1 → dê 40 madeira. Ande e corra. A sobrecarga incomoda na medida certa?
5. **Tiro.** Comece como Policial, equipe a pistola, mire com o mouse num zumbi e atire. Quem mais aparece?
6. **Carro.** Entre num carro de noite (F1 → 22h) e ligue/desligue os faróis com F.
7. **Mapa.** M: procure um "?" de acampamento, F1 → "Ir para o marcador" depois de marcar perto dele (botão direito
   no mapa), e veja a descoberta.

## Parte 2 — Duas incursões "de verdade" (~20 min, F1 desligado)

Escolha **um** objetivo por incursão e volte para o ponto de partida:

- **A. Água limpa:** sair de manhã, conseguir 2 garrafas de água limpa (achando ou fervendo) e voltar antes das 19h.
- **B. Abastecer:** juntar comida para 2 dias (4 comidas) e voltar sem ficar em sobrecarga.
- **C. Primeira noite:** pôr o totem num lugar fechado e sobreviver até as 06h do dia seguinte.
- **D. Arriscado:** chegar ao hospital (ícone H no mapa), vasculhar e voltar vivo.

Para cada uma, anote em uma linha: **objetivo · deu certo? · por que voltou (ou como morreu) · a parte mais tensa.**

## Perguntas finais (responda o que der)

1. Teve algum momento de "vou mais um pouco ou volto?"
2. Qual foi a coisa mais chata ou mais confusa?
3. Qual foi a coisa mais legal?
4. Sede, fome e peso: incomodaram na medida, de menos ou demais?
5. A noite foi diferente do dia de verdade?
6. O mapa e os primeiros passos ajudaram a saber o que fazer?
7. Você jogaria mais uma incursão agora? Por quê?

---

## Valores de ajuste (para eu calibrar depois)

| O que | Onde | Valor atual |
|---|---|---|
| Duração do dia | `scripts/systems/dia_noite.gd` · `minutos_por_segundo` | 0,6 (40 min/dia) |
| Visão dos inimigos (dia / noite) | `dia_noite.gd` · `visao_dia_m`, `visao_noite_m` | 12 m / 3,5 m |
| Fome e sede por hora de jogo | `scripts/player/player.gd` · `fome_por_hora`, `sede_por_hora` | 2,78 / 5,56 |
| Chance de disenteria (poça / rio / garrafa suja) | `scripts/systems/agua.gd` · `CHANCE_*` | 50% / 15% / 35% |
| Incubação da disenteria | `player.gd` · `INCUBACAO_MIN_H`, `INCUBACAO_MAX_H` | 2 a 5 h de jogo |
| Capacidade da mochila | `scripts/systems/inventario.gd` · `CAPACIDADE_KG` | 35 kg |
| Peso de cada item | `scripts/systems/itens.gd` · `"peso"` em `DB` | — |
| Pistola (alcance, dano, ruído) | `player.gd` · `ALCANCE_TIRO_M`, `DANO_TIRO`, `RUIDO_TIRO` | 12 m, 30, 900 |
| Fervura / fogueira acesa | `scripts/world/fogueira.gd` · `TEMPO_FERVER`, `DURACAO_ACESA` | 6 s / 300 s |

## Limitações conhecidas (não são bugs deste marco)

- A visão dos inimigos e o tiro não testam paredes dentro do mesmo ambiente (dá para acertar através da parede).
- A fogueira acesa pelo jogador não entra no save; a zona sem inimigos do começo também não.
- O vampiro (F9) não tem sede; o sangue vem no marco 4.
- Não há som no jogo ainda.

---

## Resultado do playtest (18/11/2026) — marco 1 aprovado

- **Passou no critério:** dá vontade de explorar mais um lugar, com medo de perder os itens e a vida (o "vou mais um
  pouco ou volto?"), e o Victor jogaria outra incursão mesmo sem NPCs e sem objetivos dados pelo jogo.
- **O mais legal:** explorar o mapa (lugares variados), lutar, sobreviver e voltar a um lugar seguro, e a promessa da
  transformação. Pontos de interesse (hospital, delegacia) cheios de inimigos dificultam o loot, e isso é bom.
- **Funcionou:** tutorial inicial, água suja com efeito atrasado, disenteria, peso, tiro com mira, faróis, mapa,
  modo desenvolvedor.
- **Ajustado depois do teste:** voo do F1 com 4×/8×/10×/16×; disenteria com fase aguda curta e efeito longo (36 h)
  até passar ou até um antibiótico; mapa da tela inicial carregando do cache (antes gerava ~5,6 s a cada abertura).
- **Para depois (anotado em PENDENCIAS como ideias):** loot, construções e funções de cada local, distribuição de
  árvores/ruas/casas, dificuldade dos monstros (nome em estudo: "Transformados") e o tamanho/distâncias do mapa.
- **Lição:** sem objetivo dado pelo jogo a exploração já segura, mas cada incursão vai valer mais com os rumores e
  NPCs do marco 2.
