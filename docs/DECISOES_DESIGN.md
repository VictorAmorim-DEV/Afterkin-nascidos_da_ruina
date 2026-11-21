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

**Kits das origens não dão vantagem grande** (17/11/2026): armas e equipamentos bons se conseguem no mundo ou se
fabricam. A pistola do Policial no marco 1 é provisória, só para testar o barulho do tiro; os perks do Mecânico
(fabricar com menos sucata, veículo gasta menos combustível), do Mestre de Obras (abrigo e totem mais baratos e
resistentes) e do Enfermeiro(a) (vê estágio e tempo das doenças) também são provisórios até existirem durabilidade e
comunidade.

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
2. ~~**Peso da mochila**~~ — decidido: 35 kg (era 25; subiu e os itens ficaram ~40% mais leves depois do primeiro playtest); acima disso, até −50% de velocidade, o dobro de fôlego e +80 de ruído andando (marco 1, etapa 4).
3. **Receitas por especialização**: definir no balanceamento de cada marco.
4. **Cura do vampirismo**: conteúdo tardio, fora do MVP.

---

## Ajustes do playtest do marco 1 (17/11/2026)

1. **Onde você estava quando tudo começou** (escolha depois da origem): escolhe-se o **lugar** — Porto Atlântico,
   Baía Dourada, São Jorge, Vila Nova da Serra, Vila das Roças ou o Acampamento Santuário do Sol — e o **prédio é
   sorteado** a cada partida: uma casa ou um prédio de apartamentos qualquer dentro dele (pode ser perto de um ponto
   de interesse, mas nunca dentro de hospital, mercado, delegacia, farmácia, oficina, posto etc.). Motivo: nascer
   dentro do hospital entregaria o melhor loot sem incursão. Padrão: Porto Atlântico; Mestre de Obras, acampamento.
   A tela dessa escolha mostra o **mapa** com os nomes e os ícones dos locais (a casa não tem ícone).
2. **Começo seguro**: dentro do prédio escolhido, às 08:00, sem inimigos lá dentro. O perigo está do lado de fora.
3. **Mapa do mundo** (M, no meio da tela; o minimapa fica com um tamanho só, área pequena ao redor):
   - nomes de cidades e vilarejos visíveis desde o início;
   - **acampamentos começam como "?"** numa cor própria ("Local desconhecido" na legenda); ao chegar perto,
     "Local descoberto: Acampamento ...". O acampamento onde você começou já vem descoberto;
   - terreno e ícones aparecem conforme você passa perto ou entra (e, no marco 2, por rumores);
   - ícones: hospital, farmácia, supermercado, delegacia, posto, oficina, escola, igreja, restaurante (novo tipo de
     loja), acampamento, vilarejo, cidade, você, totem e abrigo; **NPC principal** reservado para o marco 2;
   - marcador próprio: clicar no mapa para marcar um ponto.
4. **Nomes e categorias** dos lugares (cidade grande, cidade, povoado, vilarejo, acampamento, local especial) em
   `MundoGen.AREAS`, `VILAREJOS` e `ACAMPAMENTOS`; categorias provisórias, sujeitas a mudança.
5. **Começo guiado**, sem travar o jogo (compatível com a Q32): prólogo de 2–3 telas escrito para a combinação local
   + origem (pode pular) e uma lista de **primeiros passos** na voz do personagem (água → juntar coisas → fogo →
   ferver → lugar seguro antes de escurecer → sobreviver à primeira noite), com dica de tecla só na primeira vez.
   Opção de pular e chave no menu. A lista vira a primeira página do diário (Q24, marco 3).
6. Ordem: nomes → início → prólogo e primeiros passos → mapa.

---

## Marco 2 — Comunidade e rumores (entrevista a partir de 18/11/2026)

### Rodada 1 (Q35–Q38)
- **Q35. Rede de comunidades, não uma só.** Os acampamentos têm comunidades menores e os vilarejos, maiores; as
  **cidades são zona perigosa de exploração**, com sobreviventes soltos que o jogador pode ajudar, roubar ou matar.
  Cada comunidade pode ter um forte (agricultura, caça, pesca...) e sempre tem guardas.
  - **Comunidades:** vilarejos **Vila Nova da Serra**, **Vila dos Pescadores** e **Rancho do Cânion**; acampamentos
    **Lago da Águia**, **Santuário do Sol** e **Mangue Vermelho** (o **covil dos Assassinos**: saqueiam a cidade e
    atacam quem está explorando; ameaça humana de dia, que ocupa o lugar da infâmia adiada).
  - **As comunidades se comunicam:** rumores de uma apontam especialistas, necessidades e conflitos de outra (ex.: no
    acampamento X falam de um mestre de Medicina no vilarejo Y, que por sua vez precisa de um mecânico do acampamento
    Z). Relações entre comunidades (parcerias, acordos, conflitos de interesse) mudam com os eventos e com o que o
    jogador faz, no espírito de roleplay. Os especialistas podem estar numa comunidade ou noutra.
  - **Conteúdo em camadas, sistema completo:** comunidades, NPCs, relações, rumores e diálogos ficam em **arquivos
    de dados**, para que uma comunidade nova seja só escrever dados.
    - **2a** (vai para o playtest): um vilarejo e um acampamento completos, ligados por uma parceria em aberto (o
      mestre de Medicina numa, a necessidade na outra), mais 2–3 tipos de sobrevivente errante na cidade.
    - **2b**: Mangue Vermelho (Assassinos) e as demais comunidades.
- **Q36. 5–10 NPCs com nome por comunidade** (mais figurantes sem diálogo), podendo crescer no futuro.
- **Q37. Árvore de diálogo** para os NPCs principais, com condições (reputação, hora, rumores conhecidos, origem) e
  consequências (reputação, novos rumores, relação entre comunidades); figurantes só com falas curtas.
- **Q38. Especialização do marco 2: Medicina** (prepara a cura do marco 3).

### Rodada 2 (Q39–Q42)
- **Q39. Etapa 2a: Vila dos Pescadores + Acampamento Santuário do Sol.** É só o ponto de partida para testar.
  **O objetivo é um ecossistema vivo**, não roteiro fixo: as comunidades têm necessidades e decidem sozinhas (ex.: alguém
  volta ferido da cidade, o acampamento não tem quem saiba Medicina → vão buscar ajuda na comunidade que tem médico →
  depois tentam aprender Medicina, fazer parceria etc.). A parceria inicial da 2a é só a primeira situação; as
  seguintes nascem da simulação.
- **Q40. Reputação por testemunha e boato.** Cada NPC **lembra o que viu ou ouviu** de você, dentro ou fora da comunidade.
  Ninguém viu = ninguém sabe (matar alguém sem testemunha não afeta a reputação; se uma testemunha escapar, ela conta).
  O NPC espalha o que sabe na comunidade dele, e a **reputação da comunidade** (−100 a +100) sobe ou desce conforme o
  boato corre; a **reputação humana geral** leva esses boatos às comunidades aliadas, com atraso e mais fraco.
- **Q41. Escambo em duas colunas + balança:** mochila de um lado, estoque do NPC do outro, itens arrastados para o meio;
  a balança diz "aceita / quer mais / recusa", sem números de preço (valor por escassez, saturação e demanda, Q22/Q30).
- **Q42. Sobreviventes soltos na cidade:** pedem ajuda, trocam, podem ser ameaçados/roubados/mortos, alguns são hostis
  (saqueadores; na 2b, Assassinos) e **alguns estão em combate**: ajudar rende agradecimento, recompensa, reputação por
  boato e até **convite para uma comunidade ou clã**; o jogador também pode **convidar** sobreviventes para uma
  comunidade ou clã.

### Rodada 3 (Q43–Q46)
- **Q43. Simulação abstrata longe, real perto.** Cada comunidade tem membros, habilidades, estoque, necessidades e
  relações; a cada hora de jogo decide ações (expedição, pedir ajuda, trocar, aprender) e sorteia o resultado com
  risco. Perto do jogador, os NPCs aparecem e agem de verdade (caravana na estrada, grupo saqueando um prédio).
- **Q44. NPCs com nome morrem de vez, e a comunidade se refaz:** sente a perda (habilidade, estoque, relações) e com o
  tempo acolhe errantes. Se o mestre de Medicina morre, a Medicina some dali até alguém aprender.
- **Q45. Convidar = encaminhar o sobrevivente para uma comunidade** (ela cresce, você ganha reputação lá).
  Companheiros que te seguem e um clã próprio ficam para o marco 6, com a base.
- **Q46. Arte dos NPCs: o Victor traz folhas de sprite novas**; eu preparo recorte e animações. Até chegarem, os NPCs
  usam o humano atual como provisório.

### Rodada 4 (Q47–Q50)
- **Q47. Rumores chegam por todos os canais:** conversa com NPCs (o que ele conta depende da reputação e do que ele viu
  ou ouviu), conversas ouvidas entre NPCs, bilhetes no loot e mural de recados em cada comunidade, e rádio
  (transmissões de outras comunidades em certas horas).
- **Q48. A cadeia para aprender Medicina nasce da necessidade:** o mestre pede coisas ligadas ao que a comunidade dele
  precisa naquele momento (remédios do hospital, salvar um ferido, trazer um livro), escolhidas pela simulação;
  exige reputação mínima para começar.
- **Q49. Na comunidade onde é bem-vindo, o jogador pode:** dormir em segurança com os portões fechados, usar a
  estrutura (fogueira, água limpa, bancada, enfermaria; pagando ou por reputação) e trabalhar por reputação (vigiar o
  portão, ajudar na pesca/roça). Baú próprio na comunidade: não.
- **Q50. Escrita:** Claude rascunha os NPCs (nome, história, personalidade, falas) num arquivo de dados legível e o
  Victor revisa, corta e aprova.

### Rodada 5 (Q51–Q54)
- **Q51. Comunidade não é ponto de respawn.** Ao morrer, abre uma **tela de respawn com o mapa ao lado** (como a tela
  de início, sem escolher a origem de novo) para escolher entre as **camas que o jogador construiu** e os **pontos de
  respawn padrão do mapa**. A mochila continua ficando no corpo.
- **Q52. Reputação muito baixa:** portão fechado (só se fala pelo portão), trocas piores e mestres que não ensinam;
  **redenção possível** (tarefas, presentes, ajudar aliados; o boato bom também corre). Sem caçada/hostilidade ativa
  das comunidades no marco 2.
- **Q53. A origem muda só falas e opções** do diálogo (o Enfermeiro oferece ajuda médica, o Policial usa a autoridade)
  e a primeira impressão; sem bônus fixo de reputação.
- **Q54. Para os testadores:** arquivo de eventos automático em `user://` (mortes, trocas, reputação, tempo em cada
  lugar), botão para exportar o diário da partida em texto e uma ferramenta de resumo visual (mapa de mortes, rotas,
  tempos) que lê esses arquivos.

### Rodada 6 (Q55–Q56)
- **Q55. Pontos de respawn padrão = os lugares de início** (casa sorteada dentro do lugar). **Onde há comunidade não é
  ponto de início nem de respawn**: o jogador precisa ir até ela e descobri-la. **Lugares de início (18/11/2026):**
  Porto Atlântico, Baía Dourada, São Jorge, Cruz das Almas, Cruzeiro e Areal (saíram Vila Nova da Serra, Vila das
  Roças e o Acampamento Santuário do Sol). Lugar sugerido por origem (só pré-seleção): Policial → Porto Atlântico, Mecânico → Areal, Enfermeiro(a) → Baía Dourada, Mestre de Obras → Cruz das Almas. O Areal ganhou
  um quarteirão de casas ao lado da oficina para ter onde nascer.
- **Q56. Cama: fabricar e colocar** (tábuas + pano/colchão do loot), dentro de um lugar coberto; pode haver várias; o
  Mestre de Obras faz mais barato; no marco 6 pode ser destruída num cerco.
  - Implementação (valores provisórios): receita 6 madeira + 3 panos (pano no guarda-roupa e na cômoda); monta-se
    dentro de um prédio ou do abrigo; até 5 camas; E perto dela recolhe. Ao morrer, a mochila inteira fica no chão
    (aparece no mapa como "M") e abre a tela de respawn; renasce com vida cheia, fome e sede em 70, sem doença e de
    mochila vazia.
- **Cansaço e cama** (pedido de 18/11/2026): E na cama abre um menu (sem pausar o jogo; fecha ao se afastar) com **Deitar e descansar** (o tempo corre normal,
  o descanso volta aos poucos; mexer-se levanta), **Deitar e dormir** (passam 6–7 h de jogo, descanso 100%; fome e
  sede caem no ritmo do sono, 60%) e **Recolher**. Com inimigo acordado a menos de 14 m não dá para deitar; com
  descanso acima de 90 você "não está com sono". O **descanso** (100 = descansado) cai ~5 por hora acordado (+60%
  correndo) e limita até onde o fôlego recarrega: ≥70 → 100%, ≥50 → 80%, ≥30 → 60%, ≥15 → 40%, abaixo → 15%
  ("esgotado"). Na cama, volta ~14 por hora. Valores provisórios, para o playtest.

### Etapa 3 — como ficou (provisório até o playtest)
- Cada comunidade é um arquivo em `data/comunidades/<id>.json`: nome, local (vilarejo/acampamento do mapa), forte,
  horário do portão e os NPCs (nome, papel, habilidades, casa e rotina por fase: casa, portão, fogueira, praça ou
  trabalho), mais figurantes. Nomes ainda provisórios: a etapa 4 escreve os personagens.
- **Vila dos Pescadores** ganhou muro de paliçada com um portão de ferro em cada ponta da rua e uma fogueira na
  praça; as roças ficam do lado de fora. O **Santuário do Sol** usa a cerca e o portão que já tinha.
- **Portões das comunidades: abrem às 6h e fecham às 18h**, sozinhos (o jogador não mexe neles; fora do horário a
  dica diz "fechado até de manhã"). Pedir para entrar fica para a etapa 12 (reputação e portão).
- Dentro das comunidades não nascem inimigos nem moradores-monstro nas casas.
- Os NPCs aparecem quando o jogador chega a ~100 m da comunidade e somem a ~145 m. Quem está "em casa" na
  madrugada e à noite entra e dorme (some até a rotina mudar). E num NPC: por enquanto, uma fala curta pelo papel.

### Etapa 4 — personagens (aprovados em 18/11/2026)
- **Vila dos Pescadores:** Dona Iracema (líder), Toné (guarda do dia), Neide (guarda da noite), Seu Valdir
  (comerciante), Dr. Heitor (médico, mestre de Medicina), Jajá (pescador) e Dona Marlene (pescadora, mãe do Jajá).
- **Santuário do Sol:** Caio (líder), Rosa (guarda), Seu Bento (caçador), Tati (catadora) e Guga (ferido, irmão da Rosa).
- Fichas completas em `data/comunidades/*.json`; o tom: gente comum, desconfiada, fala curta, sem palavrão pesado.
- Respostas do Victor: os humanos dizem **"os da noite"**, não "vampiro"; **Neide** mantém o lenço no pescoço (gancho
  do marco 3); **Seu Valdir** troca com os Assassinos (gancho da 2b); o **portão da primeira noite** (Dona Iracema
  deixou o irmão do Caio do lado de fora) é o conflito central; o **Guga pode morrer** se ninguém ajudar;
  7 + 5 personagens bastam para o playtest. O tremor do Dr. Heitor fica como o motivo de ele precisar de aprendiz.
- A Dona Iracema chama o jogador de "meu filho" ou "minha filha" conforme o personagem: o jogo precisa saber o
  gênero do personagem (pendência 4b).

### Etapa 5 — diálogo em árvore (provisório até o playtest)
- **Criação do personagem** pergunta "Você é: Homem / Mulher"; as falas usam a forma certa (`{filho/filha}` no texto).
- **Conversas** em `data/dialogos/<comunidade>.json` (uma árvore por NPC) e **rumores** em `data/rumores.json`.
  Condições: reputação na comunidade, fase do dia, origem, gênero, flags, rumores conhecidos, já ter conversado,
  ter um item. Efeitos: reputação, flags, rumor anotado, dar/pedir item, abrir as trocas (etapa 7).
- A janela de conversa fica embaixo, **sem pausar o jogo**: o NPC para e olha para você; respostas por clique ou
  teclas 1–9; afastar-se, ESC ou "Até mais" encerra. Figurantes continuam só com uma fala curta.
- Primeiras conversas dos 12 personagens escritas (90 falas, 11 rumores). Faixas de reputação usadas: 15 (já te
  conhecem) e 35 (confiam em você). A parceria do médico já anda pelas conversas: Guga pede → Dr. Heitor explica as
  três saídas → Dona Iracema aceita ajudar se o Caio pedir → o Caio aceita por orgulho ferido ou pelo recado.
- A reputação, por enquanto, é um número por comunidade mexido pelas conversas; a etapa 6 a liga a testemunhas e
  boatos.

### Etapa 6 — reputação por testemunha e boato (valores provisórios)
- **Atos que contam:** furto (vasculhar qualquer coisa dentro de uma comunidade: −8), agressão a um morador (−15),
  assassinato (−45) e defesa (matar um monstro a até 15 m do muro: +4). As conversas continuam mexendo na hora.
- **Quem viu:** NPC acordado, no alcance em que um inimigo te veria (luz, noite, lanterna, postura) e no mesmo
  ambiente (os dois na rua ou no mesmo prédio). Furto de noite numa casa: o morador que dorme ali acorda e vê
  (60%). O jogador é avisado ("Seu Valdir e Dona Iracema viram você mexendo no que é dos outros"); se ninguém viu,
  nada acontece.
- **Boato:** a testemunha conta 1–2 h de jogo depois; aí a reputação da comunidade muda e todos passam a lembrar
  ("ouviu"). Se a testemunha morrer antes, o boato morre junto. Depois viaja: aliadas em ~12 h com metade do peso,
  neutras em ~24 h com um quarto, rivais não. A **reputação humana geral** acompanha metade de cada boato.
  Vila dos Pescadores e Santuário do Sol são **neutras** entre si (`"relacoes"` no arquivo da comunidade).
- **Morador:** tem 40 de vida; atacado, foge. **Atacar um morador pede confirmação** (o primeiro clique só avisa).
  Morto, não volta (Q44).
- **Na conversa:** o NPC cobra uma vez o que lembra ("Eu vi você mexendo no que não é seu", "Soube que você enfrentou
  um monstro perto do muro. A gente agradece") e depois segue normal. Com reputação −40 ou menos, ninguém conversa
  ("Some daqui"). Condição nova nos diálogos: `"lembra": "furto"`.
- **Modo dev (F1):** mostra a reputação de cada comunidade, a humana geral e os boatos a caminho; botões ±20 e
  "Espalhar boatos já".

### Etapa 7 — escambo (valores provisórios)
- **Comerciantes:** Seu Valdir (Vila: peixe seco, água, sucata, pano; quer munição, antibiótico e madeira), Tati
  (Santuário: sucata, pano, madeira, garrafa, bandagem e munição; quer comida, água limpa e antibiótico) e o
  **Dr. Heitor** (bandagem e antibiótico; antibiótico só a partir da reputação 15). Abre pela conversa.
- **Valor base** pela escassez (`Escambo.VALORES`): sucata 1 · madeira e pedra 1,5 · garrafa, pano, água suja 2 ·
  comida 4 · munição 6 · fogueira e água limpa 8 · bandagem 10 · machado e picareta 15 · cama 20 · antibiótico 25 ·
  pistola e antídoto 60. O totem não se troca. O comerciante cobra 25% acima do que paga.
- **Demanda** por comerciante (multiplica o que ele paga; sucata vale pouco para quem já tem). **Saturação:** cada
  unidade do mesmo item recebida baixa 12% o que ele paga pela próxima; some 1/3 por dia. O estoque se repõe por
  dia até o inicial. **Reputação:** de +60 (cobra 20% menos e paga mais) a −60 (cobra 40% mais).
- **Tela:** mochila à esquerda, estoque à direita; no meio, "Você oferece", a balança e "Você leva". Clique passa 1,
  Shift + clique passa 5. A balança diz só "Nem pensar", "Quer bem mais", "Quer um pouco mais", "Aceita" ou "Aceita
  na hora (você está dando mais do que precisa)". Não pausa o jogo.
- Tudo isso fica nos arquivos da comunidade (`"loja"` dentro do NPC): estoque, reposição, demanda e reputação mínima
  por item.

### Etapa 8 — ecossistema das comunidades (valores provisórios)
- Cada comunidade tem **reservas** (comida em dias, remédio, munição), população, feridos, habilidades e a **relação**
  com as outras (`"simulacao"` no arquivo da comunidade: Vila 40 pessoas, 6 dias de comida, 3 remédios, pesca rende um
  pouco mais do que come; Santuário 15 pessoas, 3 dias de comida, sem remédio, caça rende um pouco menos, e o Guga
  ferido em 35%).
- A cada **6 h de jogo** (também durante o sono) ela produz, consome, cuida dos feridos e decide **uma ação** pela
  necessidade: levar o ferido a quem sabe Medicina, expedição à cidade (remédio, comida, material), trocar munição por
  comida com a vizinha, aprender Medicina com a vizinha amiga (relação 30+, 3 dias) ou ficar quieta. Expedição: 18 h
  fora, 3% de morte, 15% de ferido, 42% de achar o que foi buscar; metade das vezes vai um grupo de moradores e não um
  personagem com nome.
- **Ferido** sem tratamento piora 8% por dia e morre em 100%; com médico e remédio (ou tratado pelo jogador) melhora 25%
  por dia. **O orgulho do Caio:** o Santuário só leva o Guga à Vila depois do recado (flag `caio_aceita_ajuda`) ou,
  no desespero (acima de 75%), com 8% de chance por turno. Em 8 rodadas de teste sem o jogador o Guga sobreviveu em 3.
- **O jogador interfere:** as trocas com os comerciantes entram e saem das reservas da comunidade; o que falta faz o
  comerciante pagar mais (comida, remédio, munição); o Guga pode ser tratado com antibiótico, com as instruções do
  Dr. Heitor (flag `heitor_sabe_guga`) ou pela origem Enfermeiro(a).
- **Perto do jogador:** quem saiu em expedição ou foi levado para tratamento some da comunidade; quem está ferido fica
  em casa; quem morreu não volta.
- Tudo vai para o **diário** ("Seu Bento voltou da cidade de mãos vazias", "O Santuário do Sol levou Guga até a Vila dos
  Pescadores para ser tratado"), que a etapa 9 transforma em rumores. O modo dev (F1) mostra reservas, feridos, a ação
  de cada comunidade e as últimas linhas do diário, com um botão "Simular 1 dia".

### Etapa 9 — rumores
- **Fixos** em `data/rumores.json` (18 hoje): título, texto e a **região** aproximada (Q23): o centro do círculo é
  deslocado de forma fixa do lugar real, e o raio vai de ~110 m a ~420 m. Tipos de região: comunidade, acampamento,
  área urbana, ponto de interesse (ex.: o hospital de Porto Atlântico) e o ninho mais perto de uma comunidade.
  Rumor que aponta um acampamento o descobre no mapa.
- **Novidades** saem do diário da simulação: um NPC conta as da comunidade dele (até 3 dias) e as das outras depois de
  meio dia (o tempo de a notícia viajar).
- **Quatro canais (Q47):**
  1. **Conversa:** os efeitos das falas e, em todo NPC com novidade, a opção "Alguma novidade por aqui?".
  2. **Conversas ouvidas:** dois moradores parados a até 5 m um do outro e o jogador a até 8 m conversam em balões a
     cada 30–50 s; contam uma novidade ou uma das conversas fixas da comunidade (`"conversas_ouvidas"`), cada uma
     uma vez; algumas dão rumor.
  3. **Mural** na praça de cada comunidade (E — ler): portão, pedidos que saem da simulação (comida, remédio, quem
     saiba tratar ferida), recados fixos (`"mural"`), quem morreu e as novidades. **Bilhete:** 7% de chance ao
     vasculhar, de um grupo de rumores do canal "bilhete".
  4. **Rádio de pilha** (item novo, raro na cômoda e na estante, vale 30 no escambo): usado das 0h às 5h, pega uma
     transmissão por noite (canal "radio"); de dia, só chiado.
- **Mapa (pedido do Victor, 19/11/2026):** cada rumor com região é um **"?" âmbar** (para não confundir com o "?"
  roxo dos acampamentos não visitados) no meio de um círculo tracejado, com o rótulo curto sempre visível
  ("Rumor: ninho de morcegos"). Ao chegar perto do **lugar de verdade** (30% do raio, entre 40 e 90 m; o centro do
  círculo é deslocado, então é preciso procurar), aparece **"Local descoberto: Ninho de morcegos"** e o "?" vira o
  ícone do que foi achado, no ponto exato: morcego (ninho), "!" (perigo), suprimentos, transmissão de rádio, pessoa
  procurada, coisa estranha, comunidade ou acampamento. Cada rumor do JSON tem `"rotulo"` e
  `"descoberta": {"nome", "icone"}`. A legenda lista os ícones e os últimos 10 rumores ("?" a conferir, "✓" achado).

### Etapa 10b — ecossistema vivo de errantes (pedido de 20/11/2026; substitui o "aparece perto" da etapa 10)
- **População persistente** (`Errantes`): ~30 errantes no começo (sozinhos, em duplas/famílias e **3 bandos de
  saqueadores** de 3–4 com uma **toca** numa cidade); chegam novos pelas estradas quando a população cai abaixo de 24;
  morrem de vez. Cada um: nome, gênero, papel (andarilho, catador, caçador, saqueador, expedição), **índole**
  (pacífico, desconfiado, oportunista, hostil), fome, sede, vida, munição, o que carrega, objetivo, posição e a
  **opinião sobre o jogador**.
- **Longe do jogador (a cada hora de jogo):** necessidades (fome −1,8/h, sede −3,5/h; água em rio/poça, comida achada na
  cidade ou caçando; no desespero sempre acha um pouco — quem sobreviveu três semanas sabe se virar), objetivo (vasculhar a cidade mais perto, água, caçar, abrigo numa comunidade quando ferido, trocar,
  vagar; os bandos emboscam perto da toca ou saem para saquear com fome; quem anda em grupo segue o líder), anda
  **~200 m por hora de jogo** (a mesma velocidade de um corpo), e os encontros são sorteados: **monstros** pelo perigo
  da zona (cidade 3,5%/h, mato 2%/h, ×1,8 de noite; vence, se fere, foge ou morre conforme a força do grupo, a vida, a
  munição e a índole), **outros errantes** (o hostil ou o oportunista faminto assalta, às vezes mata; dois em paz se
  ajudam e às vezes viram grupo) e **comunidades** (pede abrigo: fica, se houver comida; quem o jogador encaminhou é
  aceito e dá +4 de reputação). A fome empurra a índole para o saque; ser ajudado acalma.
- **Perto do jogador:** a menos de 160 m o agente anda em tempo real; a 60 m ganha **corpo** onde estiver (quem já
  estava na cidade aparece; quem chega, aparece chegando) e continua o que fazia; a 80 m volta ao abstrato com o estado.
  O corpo vasculha agachado, embosca agachado, cai ferido e pede ajuda, **luta com monstros** (atira se tem munição,
  bate se tem coragem) ou foge.
- **Monstros caçam humanos:** o Inimigo escolhe a presa entre o jogador e os humanos por perto (errantes e moradores)
  que ele perceba; humano atacado perde vida de verdade. Recompensa e "defesa" só quando quem mata é o jogador.
- **Bandos e reputação "saqueadores":** sobe com os crimes do jogador que viram boato (um terço do peso), cai 10 quando
  ele mata um membro na frente do bando. Abaixo de **30**, o bando embosca ("Passa a mochila!"); acima, deixa passar,
  conversa e **convida** ("Tá dentro. Aparece na toca.") — o rumor da toca vira "?" no mapa e "Toca dos saqueadores"
  quando achada. A opinião de cada errante (ajudado +30, roubado −60, atacado −40) muda a conversa.
- **Expedições das comunidades são agentes:** saem, andam até a cidade mais perto, vasculham ~4 h e voltam com o que
  acharam; correm os mesmos riscos (ferido, morte). A comunidade espera (até 60 h) e recebe o que veio.
- Diário: "Marta, uma andarilha, foi morta pelos da noite perto do Mirante do Vale", "Rafael chegou no Santuário do Sol
  pedindo abrigo e foi aceito", "Rosa voltou da cidade com 2 sucata".
- **Mortalidade (ajuste do Victor, 20/11/2026):** a meta é **10–15% dos errantes em 5 dias de jogo** (~2–3% por dia), com
  a morte vindo do perigo (monstros, sobretudo à noite, e emboscadas) e a fome como causa rara — senão ninguém dura o
  bastante para virar relação e cada morte deixa de pesar. Medido com 4 sementes: **13%**, só monstros e emboscadas.
  Valores: vitória contra monstros = força/(força+monstros) + 15%; perdeu: 60% se fere, senão 75% foge; emboscada mata
  15% das vezes.

### Etapa 10 — sobreviventes errantes (valores provisórios; a forma de aparecer foi substituída pela 10b)
- Aparecem nas **ruas das cidades** (zona urbana, longe das comunidades), a 25–40 m do jogador, com 20% de chance a cada
  3 s, no máximo 2 por vez; somem a ~95 m. De dia: assustado 25, ferido 20, andarilho 15, saqueador 18, em combate 22
  (pesos); **à noite metade são saqueadores**. Nomes e gênero sorteados.
- **Assustado:** conversa, pode ser **encaminhado** (Vila ou Santuário: a comunidade cresce, +4 de reputação lá e
  registro no diário, Q45) ou **roubado** (só com machado, picareta ou pistola na mão).
- **Ferido:** caído, pede bandagem, água ou comida; ajudado, dá um item e, 60% das vezes, um rumor (bilhete) — e
  pode ser encaminhado. **Andarilho:** troca o que carrega (escambo, sem comunidade) ou pode ser roubado.
- **Saqueador:** vem para cima a até 11 m ("Passa a mochila!"), bate 7 a cada 1,2 s, foge ferido; atacar não pede
  confirmação e matá-lo não pesa na reputação (larga um item).
- **Em combate:** 1–2 zumbis acordados em volta; perde vida enquanto houver zumbi colado nele. Salvo, fica **grato**:
  recompensa, boato bom e o **convite** para o Santuário (rumor do Guga).
- **Boato do errante (Q40, "a testemunha escapa"):** ajudar (+5) ou roubar (−8) chega à comunidade mais perto 8–16 h
  depois; matar sem testemunha, ninguém sabe. Nas conversas, o NPC cobra: "Passou um andarilho aqui falando bem de
  você" / "...dizendo que você assalta gente na estrada".

### Etapa 11 — Medicina (pedido de 21/11/2026; valores provisórios até o playtest)
- **Respostas do Victor:** as quatro habilidades, **uma por passo da cadeia**; o **Enfermeiro(a) pula o primeiro**
  (já diagnostica); depois de aprender, **as comunidades sem médico pedem ajuda** ao jogador.
- **Mestre:** o NPC com papel `mestre_medicina` (Dr. Heitor). Morto, a cadeia para (Q44). Sistema em `Medicina`.
- **Ordem das habilidades:** **Diagnóstico** (estágio e prazo das doenças; gravidade dos feridos) → **Tratar
  ferimentos** (bandagem +35 de vida em vez de +15; trata feridos com bandagem ou antibiótico; o curativo num errante
  vale o dobro) → **Preparar remédios** (receitas: bandagem = 2 panos + água limpa; soro caseiro = água limpa +
  comida, mata a sede e corta pela metade o que falta da disenteria; kit cirúrgico = 2 sucatas + 2 panos + bandagem;
  a água limpa devolve a garrafa) → **Cirurgia de campo** (com o kit: num ferido grave, a gravidade cai 50%; em si
  mesmo, abaixo de 50% de vida, 1 h de cirurgia devolve a vida a 80%).
- **Cadeia (Q48):** cada passo pede uma tarefa escolhida pela necessidade do momento, sem repetir o tipo: tratar o
  ferido mais grave sem tratamento de outra comunidade (o mestre dá as instruções: basta antibiótico) > remédios da
  vila (2 antibióticos se a reserva está abaixo de 3, senão 1) > comida (6, se a vila tem menos de 2,5 dias) >
  manual de pronto-socorro (item novo: armário de remédios 8%, arquivo e gaveta de escritório 3%) > 3 águas limpas >
  4 panos. O que se entrega vai para as reservas da vila. Cada lição leva **2 h de jogo** (tela escura) e dá +5 de
  reputação.
- **Reputação para começar cada lição (Q52):** 15, 20, 30 e 40 na comunidade do mestre (o Enfermeiro(a): 15, 20,
  30); com reputação negativa ele recebe o que você trouxe, mas não ensina.
- **Conversa:** as opções da Medicina entram sozinhas na conversa do mestre ("O senhor ensinaria Medicina?", "Trouxe
  o que o senhor pediu", "O que era mesmo...?") e na de qualquer ferido ("Deixa eu cuidar desse ferimento", com
  gravidade se tiver Diagnóstico; "Deixa eu operar isso" com o kit). Tratar: +6 de reputação. Se o ferido morre,
  sara ou é levado ao médico antes, o mestre troca a tarefa.
- **HUD:** "MEDICINA 2/4: traga 3 água limpa ao mestre" embaixo da saúde.
- **Depois da cadeia:** a cada turno da simulação, uma comunidade sem médico com ferido sem tratamento (e reputação
  ≥ 0) **manda procurar quem sabe Medicina** (uma vez por ferido): vai para o diário e daí para as novidades, o mural
  e as conversas. Atender o pedido: +10 de reputação além do tratamento. Ensinar NPCs fica para depois.
- **Modo dev (F1):** linha da Medicina no painel e botões "Cumprir a tarefa", "Próxima habilidade", "Esquecer" e
  "Ferir alguém".
