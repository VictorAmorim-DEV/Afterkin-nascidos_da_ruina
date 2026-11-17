# Afterkin — Decisões de design (validação do GDD, 16/11/2026)

Resultado da entrevista de validação do `docs/GDD_AFTERKIN.md` (perguntas Q1–Q34).
**Quando este documento e o GDD discordarem, vale este documento.** O GDD continua como visão de longo prazo.

---

## 1. Experiência central
**"Humano à beira de virar monstro."** Você começa humano; o mundo tenta te transformar (mordida, tentação, pacto);
você decide resistir ou aceitar, e o que fazer com o que se tornou. Sobrevivência é a base; a transformação é o
drama que a atravessa. (Q1)

## 2. Core loop — a incursão (30–60 min)
> Preparar no abrigo → sair com um objetivo (rumor, recurso, cura) → explorar/vasculhar com o risco subindo
> (barulho, peso, hora, sede, ferimentos, infecção) → **decidir quando voltar** → processar (fabricar, aprender,
> trocar, consertar) → o mundo responde (reputação, cerco, nova oportunidade).

A decisão repetida é **"forço mais um prédio ou volto?"**. Como vampiro, o loop se inverte: sai à noite, volta
antes do sol, caça sangue. Todo sistema novo precisa dizer como alimenta ou tensiona essa decisão. (Q16)

## 3. Loops secundários
- **Dia e noite em 6 fases** (Q17, Q27), dia de ~40 min reais (valores em `@export`):

  | Fase | Horas | Efeito |
  |---|---|---|
  | Madrugada | 0–5 | escuro máximo, frio, vampiros e ratos no auge, som vai mais longe |
  | Amanhecer | 5–7 | vampiros voltam para casa, neblina reduz a visão, janela segura do humano |
  | Manhã | 7–12 | mais seguro, NPCs ativos, comércio aberto |
  | Tarde | 12–16 | calor: sede mais rápida, correr cansa mais, o sol queima mais o vampiro |
  | Tardezinha | 16–19 | luz baixa, sombras longas, a comunidade fecha os portões, vampiros acordam |
  | Noite | 19–24 | humano com visão curta e lanterna que denuncia; expediente do vampiro |

  "Física real" = ângulo do sol/sombras, luz ambiente, temperatura (sede e stamina), alcance de visão e de ruído,
  rotina dos NPCs. Sem estações nem latitude no MVP.
- **Escambo** (Q22, Q30): sem moeda. Valor base inverso à escassez
  (sucata < madeira < comida < minério < água limpa < antibiótico < munição); **saturação** por NPC (estoque que se
  recupera com os dias); **demanda** variável por NPC/comunidade, anunciada por rumores. Vampiros trocam sangue,
  artefatos e informação.
- **Comunidade e rumores** (Q15, Q23): reputação abre acesso; rumores marcam uma *região*, não um ponto;
  cadeias de especialização com 3–4 passos, cada um pedindo escolha ou habilidade; rumores vampíricos só com afinidade.
- **Especialização** (Q19): no máximo 2, sem desaprender no MVP.
- **Dilema da infecção** (Q9, Q10): ~2 dias de jogo (~80 min reais) com estágios; os estágios do meio dão poderes
  e custos (tentação); ponto sem volta no último; cura cara (antídoto do ninho ou mestre de Medicina com reputação);
  pacto como caminho deliberado, com termos melhores. A transformação é permanente no MVP.
- **Base e cercos** (Q14): cercos noturnos atraídos por barulho, luz e tempo no território; abrigo do sol obrigatório
  para o vampiro; ponto de respawn.

## 4. Por que o jogador continua
A pergunta "quem eu vou me tornar?" e a tentação concreta da infecção; o **diário** que torna o progresso visível sem
nível (Q24); os três desfechos com o Ancestral (Q31); rejogar com outra origem/especialização/natureza.

## 5. Identidade do personagem
Três eixos sem sobreposição: **Origem** (o que você era) · **Especializações** (o que aprendeu) ·
**Natureza** (o que se tornou). Ex.: *"Enfermeira, Medicina + Furtividade, Vampira que serviu o Ancestral"*.

## 6. Diferencial
- vs. DayZ/Zomboid: a sobrevivência tem arco; a infecção é escolha com tentação; virar monstro abre um segundo jogo.
- vs. Perfect World/MMOs: sem nível, sem raridade em cores, sem hotbar; poder = o que você sabe, carrega, é e conhece.
- vs. "escolha sua raça": a natureza é conquistada ou sofrida no mundo, nunca escolhida num menu.

## 7. O que fica do GDD
Começar humano; especializações aprendidas no mundo (máx. 2); transformação por requisito + afinidade + oportunidade;
dois caminhos para o vampiro (mordida e pacto); ficar humano é válido e nenhuma natureza é "a melhor"; reputação por
facção; crafting central; Ninho Vampírico e Vampiro Ancestral; mundo existente evoluído; território por risco em vez
de nível; dados em tabelas.

## 8. O que muda
| GDD | Decisão |
|---|---|
| Profissão escolhida (§4, §51) | **Origem** (Q5, Q18, Q28): Policial (pistola + poucas balas; comunidade confia mais), Mecânico (ferramentas; conserta com menos peças), Enfermeiro(a) (bandagens + antibiótico; vê o estágio das doenças), Mestre de Obras (martelo, pregos, tábuas; estruturas mais baratas e resistentes, conserta a base mais rápido) |
| Nível e XP (§43) | **Eliminados** (Q4): progresso = conhecimento, equipamento, natureza e relações |
| Loop de 13 etapas (§47) | Loop de incursão (Q16) |
| Raridade Comum→Lendário (§23) | Condição/durabilidade + qualidade de fabricação + poucos artefatos com nome e história; anel/colar só para artefatos (Q13) |
| Combate com habilidades (§19) | Letal e evitável: poucos golpes matam, stamina limita, barulho atrai, armas de fogo raras e barulhentas, esquiva e bloqueio simples; 2–3 habilidades por especialização, 1–2 por natureza (Q12) |
| Missões (§40) | Rumores + cadeias curtas de especialização (Q23) |
| Morte | Humano sem infecção: respawn na base, mochila fica no corpo. **Morreu infectado: acorda transformado** pelo caminho ruim. Permadeath como modo opcional (Q7) |
| Sobrevivência (§36) | Humano: fome, **sede**, stamina, vida, doença. Vampiro: **sangue** no lugar de fome e sede, mais exposição ao sol (Q20, Q29) |
| Sede | Água parada perto e contaminada; rio/cachoeira limpo mas longe e exposto; ferver exige fogo (luz e barulho); garrafa/cantil limitam a carga; sede cai mais rápido que a fome e acelera no calor e na corrida (Q29) |
| Infâmia (§14) | Adiada para quando houver PvP; no MVP crimes contra NPCs baixam a reputação humana e sobem a vampírica (Q15) |
| Bônus de construção da raça humana | Passa para a origem Mestre de Obras (Q28) |
| Raças na tela inicial (código) | Removidas; F9 fica só como debug (Q3) |

**Origem × Engenharia** (Q28): a origem constrói a estrutura (parede, porta, chão, teto); a Engenharia faz funcionar
(armadilhas, gerador, luz UV, alarme, torre).

**Especializações do MVP** (Q19): Medicina (médica da comunidade; caminho da cura), Engenharia (mecânico da
comunidade; defesas para os cercos), Furtividade (território vampírico; exige reputação vampírica para humanos).

**Vampiro** (Q11): o balanço é por **troca de acesso**, não por números iguais. O território vampírico vira refúgio
(comerciantes, mestre exclusivo, áreas novas), o dia se inverte, a comunidade humana fecha as portas.

**Ancestral** (Q31): **matar** (humano ou vampiro rebelde; luz UV, fogo, estaca, entrar de dia), **servir** (vampiro
ou humano com pacto; vira vassalo, a comunidade humana passa a sofrer cercos), **substituir** (vampiro com reputação
alta; os vampiros da região obedecem e os humanos te veem como inimigo). Sem tela de fim: a região muda e fica no diário.

**Ninho** (Q25): prédio grande feito à mão dentro do mundo (igreja ou hospital com subsolo); cheio de vampiros
dormindo de dia, perigoso à noite.

**Infecções do MVP** (Q21): só a mordida vampírica transforma. Zumbi e rato causam doenças curáveis que matam se
ignoradas (morte comum). A arquitetura infecção → natureza fica genérica.

**Veículos** (Q26): ficam como estão, com combustível escasso, sem sistemas novos no MVP.

## 9. Descartado / adiado
- Descartado: nível e XP; escolha de raça no início; raridade em cores com atributos sorteados.
- Adiado (pós-MVP): multiplayer, PvP, estados de envolvimento, infâmia separada, guildas, economia entre jogadores,
  Bestiais, Necróticos, Profanos, estações, novos sistemas de veículos, as outras 15 cidades como conteúdo.
- Aspiração da Fase 3 (Q2): co-op com host e depois PvP. Regra: não pagar nada de rede agora, mas manter o estado do
  jogo serializável e centralizado.

## 10. O que falta no código
NPCs humanos com diálogo e rotina (a maior lacuna); rumores; escambo; reputação; sede e fontes de água; fases do dia
com temperatura; origens; especializações e mestres; infecção com tentação e ponto sem volta; loop do vampiro
(sangue, abrigo diurno, território); diário; prédio-ninho e Ancestral; cercos; armas de fogo, esquiva e bloqueio;
log de eventos para playtest.

## 11. Primeira hora (Q32)
Acorda num abrigo improvisado com o kit da origem → fome, sede e um bilhete com rumor levam à comunidade (10–15 min) →
a comunidade fecha os portões na tardezinha; quem não se preparou passa a primeira noite fora → na primeira ou segunda
sessão o jogador vê o território vampírico e ouve o rumor da cura antes de ser mordido. Sem pop-ups: só dicas
contextuais curtas na primeira vez que algo acontece.

## 12. MVP: 6 marcos com playtest (Q6, Q33, Q34)
Uma única cidade da ilha e o entorno, single-player.

1. **Incursão humana**: o loop sair → arriscar → voltar é divertido sozinho? (fases do dia, sede e fome, fim do XP, origens)
2. **Comunidade e rumores**: o jogador quer voltar e se relacionar? (NPCs, escambo, reputação, uma especialização).
   A partir daqui, 5–10 testadores externos, log local de eventos e exportação do diário.
3. **Dilema da infecção**: o jogador hesita, sente tentação, a decisão pesa? (estágios, cura, morte infectada, diário)
4. **Vida de vampiro**: o loop invertido é um segundo jogo? (sangue, sol, território vampírico, Furtividade)
5. **Ninho e Ancestral**: o clímax fecha a trajetória? (prédio-ninho, chefe, três desfechos)
6. **Base e cercos**: a base cria tensão? (construção, Engenharia, cercos, Mestre de Obras)

Se o marco 1 não for divertido, nada depois salva o jogo.

---

## Riscos
1. NPCs e diálogo são caros (arte, escrita, rotina); uma comunidade vazia esvazia reputação e especializações.
2. Arte: faltam sprites de NPCs, marcas da infecção e o Ancestral.
3. Vampiro inferior ao humano: se a troca de acesso não compensar, a mordida vira só castigo.
4. Incursão repetitiva: a cidade gerada precisa de locais feitos à mão com densidade de decisões.
5. Escambo virando grind: calibrar a saturação no playtest.
6. Sede e fome como tarefas domésticas: precisam gerar escolhas, não manutenção.
7. A ambição do MMO voltar antes da hora.

## Hipóteses a validar
- ~80 min de infecção dão tempo para hesitar sem irritar.
- Provar os poderes nos estágios do meio cria tentação real.
- Os diários contam histórias diferentes (métrica do GDD §67).
- O jogo de pressionar a sorte, sozinho, já prende no marco 1.
- Dia de ~40 min com 6 fases tem o ritmo certo para incursões de 30–60 min.

## Em aberto
1. **Linhagem/legado**: um novo personagem herda mundo, base e rumores do anterior? Decidir no marco 3.
2. **Peso da mochila** como freio da incursão: recomendação de peso simples já no marco 1.
3. **Receitas por especialização**: definir no balanceamento de cada marco.
4. **Cura do vampirismo**: conteúdo tardio, fora do MVP.
