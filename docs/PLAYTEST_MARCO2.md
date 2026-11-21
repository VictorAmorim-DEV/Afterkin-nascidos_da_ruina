# Playtest do marco 2 (etapa 2a): comunidade e rumores

## 21/11/2026, Victor, 1 partida

**Amostra:** uma partida de 39 min (Policial, começou em Porto Atlântico), com o F1 ligado (pulou do dia 1 ao 7 com
"Simular 1 dia") e as respostas escritas em `docs/PLAYTEST_MARCO2A.md`. Os cenários de crime (bater, matar, luto,
vingança) foram testados antes, em partidas que não geraram diário; por isso eles aparecem só nas respostas, não nos
números. Uma pessoa só não prova nada: isto aponta direções, não fecha números.

### Resumo em 5 linhas

- **Funcionou:** as consequências foram justas e compreensíveis, e voltar às comunidades vale a pena porque as falas
  mudam, as missões andam e surgem boatos novos.
- **Não funcionou:** os trabalhos são "ficar parado numa área", ninguém comenta depois e os diálogos não emendam o
  que acabou de acontecer.
- **Não funcionou:** a reputação é invisível (não se sabe quanto subiu nem quanto se tem) e os rumores são demais
  (36 em 39 min).
- **Surpresa:** o único NPC que importou foi o Dr. Heitor, e por utilidade ("se ele morresse eu não terminava a
  missão"), não por afeto.
- **Falta um norte:** nada nas primeiras horas mostra o que o jogo é ("o mundo lembra… e quer te transformar no
  monstro"). Isso confirma que o próximo passo é o marco 3.

### Números

| | |
|---|---|
| Tempo real | 39 min (dia 1 → dia 9 no jogo) |
| Mortes do jogador | 0 |
| Tempo na Vila dos Pescadores | 34 min (89%) · Santuário 4 min · Porto Atlântico 1 min |
| Rumores anotados | **36** (quase 1 por minuto) |
| Mudanças de reputação | 23 · Vila 0 → 48 · Santuário 0 → 25 |
| Medicina | as 4 habilidades em **~23 h de jogo** (dia 8 16h → dia 9 15h), ~14 min reais |
| Escambo | 3 trocas · Trabalhos: 1 no diário (vigia, +3) · Recados: 0 · Dormir: 0 |

### Histórias

1. **O aprendiz do Dr. Heitor.** O boato "Há um médico na Vila", depois "Um rapaz ferido no Santuário", foi até o
   Guga e o tratou ("Alguém de fora tratou Guga"). Voltou, aprendeu Diagnóstico, ficou de vigia no portão e em
   meio dia terminou a Cirurgia de campo. É o arco mais completo da partida, mas rápido demais: as quatro lições
   cabem num dia de jogo e nenhuma pediu algo difícil.
2. **O mundo andando sozinho.** A Rosa saiu do Santuário atrás de material, morreu em Cruz das Almas, o Santuário
   fez vigília e o Seu Bento passou a cobrir o portão. É uma boa história, mas o jogador nunca a viu: ela ficou
   soterrada entre dezenas de "Fulano foi atacado pelos da noite e escapou ferido".
3. **Mortos que voltam.** A Jussara "foi morta por zumbis" no dia 2 e, no dia 7, "chegou no Santuário do Sol
   pedindo abrigo e foi aceita". A Patrícia e o Fábio também se repetem. Os errantes novos sorteiam o nome de uma
   lista curta e reaproveitam os nomes dos mortos (`errantes.gd`, `novo()`). Para um jogo em que "o mundo lembra",
   esse bug pesa.

### Sistemas pouco usados

- **Recados (0) e cama de hóspede (0):** o jogador fez vigia e as redes (estas não aparecem no diário como trabalho,
  vale conferir), mas não pegou recado nem dormiu na Vila. Hipótese: os trabalhos dão só reputação, e com o F1 ele
  não precisou de nada.
- **Crimes (0 nesta partida):** foram testados à parte, e a resposta foi que as consequências são justas.

### Onde morre e por quê

Não morreu. Com 89% do tempo dentro da Vila e o F1 ligado, esta partida não diz nada sobre o perigo da incursão.

### Respostas às perguntas do marco

| Pergunta | Resposta | Evidência |
|---|---|---|
| O social gera histórias que você quer contar? | **Incerto, mais para não** | A melhor história (Rosa) aconteceu fora da vista. A do jogador é uma lista de tarefas cumpridas, com um médico importante "por utilidade". |
| Você quer voltar às comunidades? | **Sim** | "É bom voltar porque você conclui missões, os diálogos mudam, surgem novos boatos." |
| As consequências são justas e compreensíveis? | **Sim** | Resposta 3. |
| A reputação se entende? | **Não** | "Não sabia quando eu subia nem quanto eu subia, nem quanto estava de reputação." 22 das 23 mudanças foram silenciosas; só o fim de um trabalho mostrou o número. |
| Os trabalhos valem o tempo? | **Não** | Parados, sem retorno do NPC, sem recompensa além da reputação. |
| As primeiras horas têm rumo? | **Não** | Resposta 7: falta o gancho do pitch. |

### Propostas (passadas pelo filtro da `afterkin-ideia`)

**⬜ Agora (consertos do que já existe):**

1. **Diálogo que emenda.** Quando o NPC reage a algo (elogio, agradecimento, cobrança), a abertura normal não deve
   recomeçar como se nada tivesse sido dito: a reação vira a primeira fala e o resto continua dali.
2. **Retorno dos trabalhos.** Ao voltar ao NPC que deu o trabalho, uma fala própria ("Como foi a vigília? Viu
   alguma coisa?", "A rede ficou boa, obrigado") com uma ou duas respostas.
3. **Guga e a missão do doutor.** A opção "vou falar com o doutor" não deve aparecer se a missão já está ativa ou já
   foi cumprida.
4. **Reputação visível.** Um aviso discreto a cada mudança ("Vila dos Pescadores +3: ajudou na vigia") e o valor
   atual com o nível ("respeitado", "bem-vindo"…) no mapa (M) ou no diário das comunidades.
5. **Menos rumores.** Cortar pela metade a frequência dos rumores do mundo, juntar os repetidos ("três andarilhos
   atacados perto da Vila do Lago") e priorizar os que envolvem gente que o jogador conhece. As conversas entre NPCs
   continuam como estão. Também corrigir o ponto duplo no fim ("ferida..").
6. **Nomes únicos dos errantes.** Um nome não volta enquanto quem o usava estiver vivo ou tiver morrido nesta partida.
   A lista de nomes cresce, ou ganha sobrenome ou apelido.
7. **Diário:** conferir por que o trabalho das redes não foi gravado como trabalho.

**⬜ no marco 3 (infecção):**

8. **Gancho das primeiras horas.** A infecção começa cedo (mordida ou contágio no começo da partida, com o primeiro
   sintoma em horas) e dá o norte: "descubra o que está acontecendo com você antes de virar um deles". É a
   resposta direta à pergunta 7.
9. **Medicina com peso.** Hoje ela é superficial porque não há nada sério para tratar. No marco 3 ela trata e
   retarda a infecção (diagnosticar o estágio, remédio que segura, cirurgia arriscada), e as lições pedem casos
   reais e progresso por uso, não quatro tarefas num dia. É aqui que "pensar juntos" rende mais.
10. **Importar-se com as pessoas.** O médico importou por utilidade. A infecção cria laços reais: quem esconde que
    você está infectado, quem te denuncia, quem cuida de você.

**💭 Em avaliação (sistema novo durante o congelamento):**

11. **Habilidades que melhoram com os trabalhos** (costura com as redes, atenção com a vigia, precisão…). É um
    sistema de progressão novo. Encaixa bem no marco 3 se a progressão humana competir com a da natureza ("ficar
    humano tem seu valor").
12. **Trabalhos com algo para fazer** (vigia que avista e avisa, rede como pequena tarefa). É conteúdo novo de
    trabalho. Volta depois do marco 3, ou junto com o item 11.
