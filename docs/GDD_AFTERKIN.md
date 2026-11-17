# Afterkin: Nascidos da Ruína
## Game Design Document — GDD Base v1.0

> ⚠️ **Revisado em 16/11/2026 por `docs/DECISOES_DESIGN.md`, que prevalece em caso de conflito.** Principais mudanças:
> profissão virou **Origem** (§4, §51); **nível/XP eliminados** (§43); raridade em cores trocada por condição,
> qualidade e artefatos (§23); combate letal e evitável (§19); missões viraram **rumores** (§40); sede entra no MVP
> (§36); infâmia, PvP e multiplayer saem do MVP (§14–18, §61–63); loop principal = **incursão** (§47);
> MVP dividido em 6 marcos com playtest, numa única cidade e single-player (§49–68).

> **Propósito deste documento:** este GDD é a referência de design para orientar o desenvolvimento de Afterkin: Nascidos da Ruína. Ele deve ser lido em conjunto com `CLAUDE.md` e com a documentação técnica existente. O código atual do projeto continua sendo a fonte de verdade sobre o que já está implementado; este documento define principalmente **para onde o jogo deve evoluir**.
> O documento `docs/GDD_AFTERKIN.md` é a referência principal para a visão futura, game design, progressão de personagem, profissões, especializações, transformações, facções, PvP, loot, crafting, multiplayer e MVP de Afterkin.
> Ao implementar novas funcionalidades, consulte o GDD para entender a intenção de design e preserve suas regras fundamentais.
> O GDD descreve principalmente o estado desejado/futuro do produto.
> O código existente continua sendo a fonte de verdade sobre o que já está implementado.
> Também consulte `docs/RESUMO_V13.md` quando for necessário entender a arquitetura, sistemas históricos ou decisões relacionadas à migração do projeto.

---


## 1. Visão do produto

**Afterkin: Nascidos da Ruína** é um RPG de sobrevivência pós-apocalíptico isométrico, com elementos de MMORPG, exploração, construção, crafting, combate, facções, progressão de personagem, PvE, PvP e transformação de natureza.

O jogador começa sua jornada como **Humano**, escolhe uma profissão e sobrevive em um mundo persistente e hostil.

Ao explorar o mundo, encontra comunidades, criaturas, facções, ruínas, dungeons, chefes, recursos, tecnologias e sociedades sobrenaturais.

Suas experiências determinam o que aprende. Suas escolhas determinam com quem se relaciona. Sua exploração determina quais caminhos descobre. Suas decisões podem determinar **no que seu personagem se transforma**.

A proposta central é:

> **Não escolher apenas uma classe, mas viver uma história capaz de transformar o personagem em algo diferente de quem ele era.**

---

## 2. Pilares de design

1. **Sobrevivência:** fome, stamina, saúde, doenças, infecções, abrigo, recursos e ameaças.
2. **Exploração:** o mundo deve recompensar curiosidade com locais, facções, recursos, histórias e oportunidades.
3. **Progressão emergente:** profissão, especializações, relações, exploração, PvE, PvP e decisões constroem a identidade.
4. **Transformação:** mudar de natureza altera habilidades, necessidades, relações, território e estilo de jogo.
5. **Consequência:** ações do jogador alteram reputação, afinidades, acesso e oportunidades.
6. **História emergente:** sistemas combinados devem gerar histórias únicas dos jogadores.

---

## 3. Modelo de personagem

O personagem é formado por camadas:

```text
PERSONAGEM
├── NATUREZA
│   └── Humano / Vampiro / Bestial / Necrótico / Profano
├── PROFISSÃO
│   └── Atirador / Engenheiro / Médico / etc.
├── ESPECIALIZAÇÃO 1
├── ESPECIALIZAÇÃO 2
├── HABILIDADES
├── EQUIPAMENTOS
├── REPUTAÇÕES
├── INFÂMIA
└── AFINIDADES
```

### Regra fundamental

**Profissão/especialização representam o que o personagem aprendeu.**

**Natureza representa o que o personagem se tornou.**

Exemplo:

> Humano → Atirador → Engenheiro → Vampiro

Resultado:

> **Vampiro Atirador-Engenheiro**

A transformação não apaga automaticamente a profissão ou as especializações anteriores.

---

## 4. Criação de personagem

### Natureza inicial

Todos os personagens começam como:

> **Humano**

Isso cria uma experiência inicial comum e faz a transformação ser uma consequência da jornada.

### Profissão inicial

Na criação, o jogador escolhe uma profissão.

Exemplos:

- Atirador
- Guerreiro
- Engenheiro
- Médico
- Mecânico
- Ladrão
- Policial
- Soldado
- Explorador
- Caçador

A profissão define habilidades, equipamentos, estilo de jogo e possibilidades iniciais, mas não determina todo o futuro.

---

## 5. Especializações

Especializações **não devem ser obtidas simplesmente acumulando XP de qualquer atividade**.

O jogador aprende especializações através do mundo:

- mestres;
- NPCs;
- comunidades;
- escolas;
- oficinas;
- facções;
- sobreviventes especializados;
- cadeias de missões.

Exemplo:

> Um mecânico de uma comunidade pode ensinar Engenharia Mecânica.

Para ganhar sua confiança, o jogador pode precisar recuperar ferramentas, encontrar peças, reparar uma máquina e proteger a oficina.

Ao completar a cadeia:

> **Especialização: Engenharia Mecânica desbloqueada.**

### Objetivo de design

Evitar que um jogador faça pequenas quantidades de todas as atividades e acabe com todas as especializações.

---

## 6. Segunda especialização

Em determinado estágio de progressão, o jogador poderá adquirir **uma segunda especialização**.

Ela deve representar uma decisão importante.

Exemplo:

> Humano → Atirador → Engenharia

Mais tarde, o jogador encontra oportunidades para escolher entre:

- Medicina;
- Mecânica;
- Furtividade;
- Sobrevivência;
- Exploração;
- outras.

O jogador não deve poder acumular especializações indefinidamente.

---

## 7. Transformação de natureza

A Natureza representa:

> **"O que eu me tornei."**

Ela não é simplesmente uma segunda classe.

O jogador não precisa completar uma árvore fixa para se transformar.

A transformação pode acontecer em diferentes momentos da experiência do jogador, desde que ele descubra uma oportunidade e cumpra seus requisitos.

### Princípio

> **A transformação é descoberta no mundo, não selecionada simplesmente em uma tela de criação.**

---

## 8. Como uma transformação é descoberta

O jogador encontra uma região, comunidade ou cadeia de eventos relacionada a determinada natureza.

Exemplo:

> território vampírico.

O jogador pode:

- lutar;
- explorar;
- investigar;
- negociar;
- ajudar;
- fazer pactos;
- realizar rituais;
- sofrer infecção;
- aceitar consequências;
- enfrentar chefes;
- encontrar artefatos.

As ações realizadas podem abrir diferentes caminhos.

---

## 9. Requisitos + Afinidade + Oportunidade

Cada transformação deve considerar três componentes.

### Requisitos

Condições necessárias.

Exemplos:

- encontrar um artefato;
- conhecer determinado NPC;
- completar uma missão;
- sobreviver a uma infecção;
- realizar um ritual;
- possuir determinado recurso.

### Afinidade

Representa a conexão do personagem com aquela natureza.

Pode aumentar através de:

- explorar territórios;
- lutar contra uma raça;
- ajudar seus membros;
- realizar pactos;
- estudar conhecimentos;
- utilizar recursos;
- completar missões;
- sofrer determinadas experiências.

### Oportunidade

É o momento em que o mundo efetivamente oferece a transformação.

Exemplo:

> uma vampira ancestral oferece um pacto.

O jogador pode ter afinidade suficiente, mas ainda precisa encontrar a oportunidade.

---

## 10. Naturezas previstas

### Profanos

- Vampiro
- Feiticeira/Bruxo
- Necromante
- Banshee

Possíveis características:

- magia;
- pactos;
- maldições;
- poderes sobrenaturais;
- rituais;
- efeitos negativos.

### Necróticos

- Zumbi
- Carniçal
- Esqueleto
- Múmia

Possíveis características:

- força;
- resistência;
- infecção;
- resistência elemental;
- habilidades de horda;
- resistência a condições humanas.

### Bestiais

- Lobisomem
- Homem-Tigre
- Homem-Rato
- futuras formas híbridas

Possíveis características:

- força;
- velocidade;
- sentidos;
- transformação;
- instinto;
- mobilidade.

### Humanos

Continuar humano é uma escolha válida.

Humanos podem obter vantagens por:

- tecnologia;
- medicina;
- armas;
- engenharia;
- veículos;
- comércio;
- comunidades;
- organização;
- equipamentos;
- alianças.

Nenhuma natureza deve ser simplesmente "a melhor".

---

## 11. Exemplo de progressão

Personagem:

> Humano → Atirador

Encontra uma comunidade:

> aprende Engenharia

Resultado:

> Humano → Atirador + Engenheiro

Explora território vampírico:

- investiga;
- ajuda uma vampira;
- descobre um ritual;
- é mordido;
- tenta a cura;
- decide aceitar a transformação.

Resultado:

> **Vampiro Atirador-Engenheiro**

Outro jogador pode chegar a:

> **Humano Guerreiro + Médico → Lobisomem**

ou:

> **Humano Ladrão + Engenharia → Homem-Rato**

A trajetória é parte da identidade.

---

## 12. Facções

Facções devem possuir:

- território;
- NPCs;
- líderes;
- recursos;
- missões;
- objetivos;
- inimigos;
- aliados;
- reputação;
- recompensas;
- especializações;
- possíveis caminhos de transformação.

Grupos previstos:

- Comunidades Humanas;
- Vampiros;
- Bestiais;
- Necróticos;
- Profanos;
- Assassinos e outras facções clandestinas.

---

## 13. Reputação

Reputação deve existir por comunidade/facção.

Exemplo:

```text
Comunidade Humana A: +80
Comunidade Humana B: +25
Vampiros: +45
Bestiais: -10
Assassinos: +20
```

Reputação influencia:

- treinamento;
- comércio;
- missões;
- acesso;
- abrigo;
- informações;
- oportunidades.

Reputação negativa pode:

- aumentar preços;
- exigir tarefas adicionais;
- dificultar treinamento;
- reduzir recompensas;
- impedir determinados acessos temporariamente.

---

## 14. Infâmia

Infâmia representa a reputação negativa associada a comportamentos hostis/criminosos.

Pode aumentar por:

- assassinato não provocado;
- ataques repetidos;
- traição;
- roubo;
- sabotagem;
- crimes contra comunidades.

A Infâmia não deve ser apenas uma punição.

Ela pode abrir caminhos para:

- assassinos;
- mercenários;
- criminosos;
- facções clandestinas.

Princípio:

> **Comportamento → consequência social → nova oportunidade.**

---

## 15. PvP

PvP deve ser contextualizado por região.

### Cidades seguras

PvP proibido.

### Comunidades protegidas

PvP proibido ou altamente limitado.

### Áreas de exploração

PvP permitido.

### Territórios contestados

PvP incentivado.

### Dungeons/eventos especiais

Regras específicas por conteúdo.

---

## 16. Estado de PvP

### Não envolvido

O jogador não participou recentemente de PvP.

Atacá-lo caracteriza ataque não provocado.

### Envolvido

Participou de combate recentemente.

Os participantes do conflito podem lutar entre si com menor penalidade.

### Hostil

Jogador identificado como agressor/hostil.

Outros jogadores podem enfrentá-lo com menor risco de penalização.

O sistema deve registrar:

- quem iniciou;
- quem participou;
- quem respondeu;
- quem estava fora do conflito.

---

## 17. Consequência de atacar jogador inocente

Se um jogador atacar e matar outro jogador que não estava envolvido em PvP:

- Infâmia aumenta;
- reputação humana diminui;
- acesso a comunidades pode piorar;
- especializações humanas podem exigir mais trabalho;
- preços podem aumentar;
- NPCs podem desconfiar;
- afinidade com caminhos assassinos pode aumentar.

A intenção é que o PvP tenha consequências narrativas e sistêmicas.

---

## 18. PvP por motivo

Áreas PvP devem possuir razões para existir:

- recursos raros;
- territórios;
- chefes;
- artefatos;
- caravanas;
- missões;
- eventos;
- materiais de crafting;
- posições estratégicas.

O objetivo é evitar que uma zona PvP seja simplesmente uma arena de morte aleatória.

---

## 19. Combate

O combate deve considerar:

- ataques básicos;
- ataques especiais;
- habilidades;
- esquiva;
- bloqueio;
- posicionamento;
- stamina;
- armas corpo a corpo;
- armas de fogo;
- ataques sobrenaturais;
- furtividade;
- condições;
- efeitos de status.

Profissões e naturezas devem alterar o estilo de combate.

---

## 20. Armas

### Corpo a corpo

- faca;
- facão;
- machado;
- bastão;
- lança;
- espada;
- martelo;
- armas improvisadas.

### Armas de fogo

- pistolas;
- revólveres;
- espingardas;
- submetralhadoras;
- rifles;
- rifles de precisão;
- armas automáticas.

### Especiais

- armas modificadas;
- tecnológicas;
- sobrenaturais;
- específicas de facções.

---

## 21. Armaduras e equipamentos

Slots previstos:

### Cabeça

- capacete;
- máscara;
- chapéu;
- proteções especiais.

### Peitoral

- colete;
- armadura;
- jaqueta;
- proteção improvisada.

### Pernas

- calças;
- proteção de pernas;
- armaduras especializadas.

### Mãos

- luvas;
- manoplas;
- equipamentos especiais.

### Pés

- botas;
- calçados especiais.

### Acessórios

- anel 1;
- anel 2;
- colar;
- possíveis slots adicionais.

---

## 22. Atributos dos equipamentos

Itens podem possuir:

- defesa;
- resistência;
- dano;
- precisão;
- velocidade;
- stamina;
- regeneração;
- resistência a doenças;
- resistência elemental;
- furtividade;
- capacidade de carga;
- bônus de profissão;
- bônus de natureza;
- bônus situacionais.

---

## 23. Loot

Fontes:

- inimigos;
- cadáveres;
- baús;
- casas;
- veículos;
- dungeons;
- chefes;
- eventos;
- comunidades;
- facções;
- depósitos;
- estruturas.

Categorias:

- Comum;
- Incomum;
- Raro;
- Épico;
- Lendário;
- Único.

O loot deve respeitar contexto e localização.

---

## 24. Drop relacionado a transformação

Evitar:

> "Mate o chefe e receba diretamente o item 'Transformação em Vampiro'."

Chefes podem fornecer:

- sangue;
- essência;
- artefatos;
- fragmentos;
- componentes;
- livros;
- itens rituais.

Esses itens podem contribuir para o caminho da transformação.

A transformação final depende de:

- requisitos;
- afinidade;
- oportunidade;
- decisões.

---

## 25. Crafting

Crafting deve ser central.

### Sobrevivência

- comida;
- água;
- bandagens;
- medicamentos;
- ferramentas.

### Construção

- madeira;
- pedra;
- metal;
- sucata;
- estruturas.

### Equipamentos

- armas;
- munição;
- armaduras;
- ferramentas.

### Medicina/Alquimia

- poções;
- medicamentos;
- antídotos;
- estimulantes;
- venenos.

### Sobrenatural

- rituais;
- componentes;
- artefatos;
- itens de sangue;
- objetos mágicos.

---

## 26. Poções e consumíveis

Exemplos:

- cura;
- stamina;
- resistência;
- antídoto;
- resistência elemental;
- visão noturna;
- fortalecimento;
- regeneração;
- efeitos temporários.

Consumíveis sobrenaturais podem possuir custos e efeitos colaterais.

---

## 27. Recursos

Recursos previstos:

- madeira;
- pedra;
- minério;
- ferro;
- cobre;
- sucata;
- tecido;
- couro;
- plantas;
- medicamentos;
- componentes eletrônicos;
- combustível;
- sangue;
- essências;
- recursos sobrenaturais.

Alguns recursos devem ser regionais ou específicos de determinadas naturezas.

---

## 28. Construção

Todos os personagens podem construir.

Construções:

- abrigo;
- casa;
- muro;
- portão;
- torre;
- depósito;
- oficina;
- bancada;
- gerador;
- armadilhas;
- defesas;
- estruturas de guilda.

Profissões podem melhorar aspectos específicos.

---

## 29. Bases

Bases funcionam como:

- abrigo;
- armazenamento;
- crafting;
- defesa;
- ponto de respawn;
- centro de operações.

Tipos:

- individuais;
- de grupo;
- de guilda.

---

## 30. Guildas / Clãs

Guildas devem oferecer:

- armazenamento;
- território;
- missões;
- construção coletiva;
- comércio;
- defesa;
- guerras;
- especializações coletivas;
- eventos;
- objetivos.

Não devem ser apenas grupos com chat.

---

## 31. Cooperação

Funções possíveis:

- dano;
- suporte;
- médico;
- engenheiro;
- explorador;
- assassino;
- especialista sobrenatural.

Jogadores solo devem continuar viáveis.

Grupo deve ampliar possibilidades, não bloquear o jogo solo.

---

## 32. Dungeons

Dungeons são áreas de risco concentrado.

Exemplo:

### Ninho Vampírico

- pouca iluminação;
- criaturas vampíricas;
- sangue;
- armadilhas;
- furtividade;
- áreas secretas;
- NPCs;
- recursos raros;
- mini-chefes;
- chefe final.

Recompensas:

- equipamentos;
- sangue;
- artefatos;
- componentes;
- receitas;
- itens vampíricos;
- informações sobre transformação.

---

## 33. Bosses

Bosses devem possuir:

- mecânicas próprias;
- padrões de ataque;
- fraquezas;
- fases;
- recompensas;
- história;
- território.

Exemplos:

- Vampiro Ancestral;
- Rei Ghoul;
- Alfa Lobisomem;
- Necromante;
- Múmia Ancestral.

---

## 34. Mundo

O mundo deve continuar grande, persistente e explorável.

A estrutura existente do projeto já possui a base para isso, incluindo:

- cidades;
- vilas;
- acampamentos;
- estradas;
- rios;
- lagos;
- cachoeiras;
- deltas;
- praias;
- montanhas;
- desertos;
- regiões semiáridas;
- biomas.

O novo design deve **evoluir essa base**, não substituí-la.

---

## 35. Territórios de risco

Evitar progressão puramente:

> nível 1 → nível 10 → nível 20 → nível 50.

Usar principalmente:

- segurança;
- risco;
- recursos;
- presença de facções;
- contaminação;
- criaturas;
- eventos;
- PvP.

---

## 36. Sobrevivência

Sistemas:

- fome;
- stamina;
- saúde;
- doença;
- infecção;
- condições ambientais;
- sangramento;
- ferimentos;
- intoxicação;
- transformação.

Cada natureza pode modificar essas necessidades.

---

## 37. Sobrevivência por natureza

### Humanos

- comida;
- água;
- medicina;
- abrigo.

### Vampiros

- sangue;
- exposição solar;
- controle de transformação.

### Necróticos

- matéria orgânica/energia necrótica;
- resistência a decomposição.

### Bestiais

- alimentação;
- instinto;
- controle de transformação.

### Profanos

- componentes mágicos;
- recursos de rituais;
- energia sobrenatural.

Os números e regras finais devem ser definidos no balanceamento/prototipagem.

---

## 38. Dia e noite

Dia/noite deve alterar:

- atividade de criaturas;
- vulnerabilidade de vampiros;
- recursos;
- eventos;
- segurança;
- comportamento de NPCs.

---

## 39. Veículos

Os veículos existentes devem ser integrados ao novo loop.

Possíveis sistemas:

- combustível;
- manutenção;
- peças;
- dano;
- armazenamento;
- veículos de facção;
- veículos especiais.

Mecânicos/Engenheiros podem possuir vantagens.

---

## 40. Missões

Missões devem servir a:

### Progressão

Desbloquear:

- especializações;
- habilidades;
- equipamentos.

### História

Revelar:

- facções;
- personagens;
- locais;
- acontecimentos.

### Mundo

Alterar:

- reputação;
- território;
- relações;
- recursos;
- eventos.

Evitar excesso de missões genéricas do tipo:

> vá até X → mate Y → volte.

---

## 41. Missões de especialização

Exemplo:

### Engenharia

1. Encontrar mestre.
2. Recuperar ferramentas.
3. Reparar equipamento.
4. Recuperar componentes.
5. Defender oficina.
6. Construir algo funcional.
7. Receber treinamento.

Resultado:

> Especialização Engenharia.

---

## 42. Missões/caminhos de transformação

Transformações devem ser abertas.

Exemplo:

### Investigação Bestial

O jogador encontra território Bestial.

Pode:

- atacar;
- observar;
- conversar;
- ajudar;
- negociar;
- fazer pacto;
- encontrar artefatos;
- enfrentar chefes.

Dependendo da trajetória, podem surgir oportunidades para:

- Lobisomem;
- Homem-Tigre;
- Homem-Rato.

---

## 43. Equipamentos e progressão

A progressão deve ser composta por:

- nível;
- profissão;
- especializações;
- natureza;
- habilidades;
- equipamentos;
- reputações;
- afinidades;
- experiência do jogador.

Nenhuma camada deve dominar absolutamente todas as outras.

---

## 44. Solo e multiplayer

O mesmo universo de regras deve suportar:

### Solo

- exploração;
- combate;
- construção;
- crafting;
- progressão;
- transformação.

### Multiplayer

- grupos;
- comércio;
- guildas;
- PvP;
- cooperação;
- economia;
- guerras;
- eventos.

---

## 45. Multiplayer: requisitos técnicos de design

O multiplayer deve considerar desde cedo:

- autoridade do servidor;
- persistência;
- replicação;
- inventário server-side;
- loot server-side;
- combate;
- IA;
- movimentação;
- veículos;
- construção;
- economia;
- anti-cheat;
- reconexão;
- sincronização.

O desenvolvimento inicial deve evitar sistemas que exijam reescrita completa para multiplayer.

---

## 46. Economia

Possíveis elementos:

- moedas;
- comércio entre jogadores;
- NPCs;
- recursos;
- itens raros;
- receitas;
- serviços;
- guildas.

A economia deve ser projetada para evitar inflação e duplicação.

---

## 47. Loop principal

```text
EXPLORAR
   ↓
ENCONTRAR
   ↓
SOBREVIVER
   ↓
LUTAR / NEGOCIAR / EVITAR
   ↓
OBTER RECURSOS
   ↓
CRAFTAR / EQUIPAR / CONSTRUIR
   ↓
DESCOBRIR NOVOS CAMINHOS
   ↓
ESPECIALIZAR-SE
   ↓
CRIAR RELAÇÕES
   ↓
ASSUMIR RISCOS
   ↓
SOFRER CONSEQUÊNCIAS
   ↓
TRANSFORMAR-SE / EVOLUIR
   ↓
VOLTAR AO MUNDO COM NOVAS POSSIBILIDADES
```

---

## 48. Diferencial

O principal diferencial de Afterkin deve ser:

> **A identidade emergente do personagem.**

O jogador não escolhe apenas uma build. Ele vive uma trajetória.

---

# 49. MVP — OBJETIVO

O MVP não deve tentar construir o MMORPG completo.

Pergunta que o MVP precisa responder:

> **"A experiência de sobreviver, explorar, especializar-se e transformar-se em outra natureza é divertida o suficiente para sustentar Afterkin?"**

---

# 50. MVP — mundo

Uma pequena região vertical contendo:

- 1 pequena cidade;
- 1 comunidade humana;
- 1 área Bestial;
- 1 área Vampírica;
- 1 dungeon;
- 1 área de exploração PvP;
- 1 área segura;
- estradas;
- recursos;
- construções.

---

# 51. MVP — personagem

### Natureza

- Humano.

### Profissões

- Atirador;
- Engenheiro;
- Médico.

---

# 52. MVP — especializações

Implementar:

- Engenharia;
- Medicina;
- Furtividade.

O jogador deve conseguir aprender pelo menos uma através de NPC/missão.

---

# 53. MVP — transformação

Implementar inicialmente uma natureza:

> **Vampiro**

O sistema deve ser arquitetado para futuras naturezas.

---

# 54. MVP — caminhos vampíricos

Implementar pelo menos duas formas de chegar à transformação:

1. Infecção/mordida.
2. Pacto/ritual.

Ambos resultam em Vampiro, mas através de experiências diferentes.

---

# 55. MVP — Vampiro

### Vantagens

- visão noturna;
- habilidade sobrenatural;
- regeneração limitada;
- habilidade de transformação.

### Desvantagens

- vulnerabilidade à luz;
- necessidade de sangue;
- alteração de reputação humana.

---

# 56. MVP — Dungeon

Criar:

> **Ninho Vampírico**

Com:

- entrada;
- inimigos;
- loot;
- recursos;
- mini-chefe;
- chefe;
- evento de transformação;
- recompensa especial.

---

# 57. MVP — Boss

Implementar:

> **Vampiro Ancestral**

Com:

- fases;
- ataques;
- fraquezas;
- recompensas;
- relação com transformação.

---

# 58. MVP — loot

Implementar:

### Armas

- pistola;
- rifle;
- faca;
- machado;
- arma improvisada.

### Armaduras

- capacete;
- peitoral;
- calças;
- luvas;
- botas.

### Acessórios

- anel;
- colar.

### Consumíveis

- bandagens;
- poções;
- comida;
- antídoto.

### Recursos

- madeira;
- pedra;
- metal;
- sucata;
- tecido;
- componentes.

---

# 59. MVP — crafting

Implementar:

- armas simples;
- munição;
- bandagens;
- poções;
- ferramentas;
- estruturas básicas;
- reparos.

Loop:

> explorar → coletar → craftar → melhorar sobrevivência.

---

# 60. MVP — construção

Implementar:

- parede;
- porta;
- chão;
- teto;
- baú;
- bancada;
- pequena defesa.

Não tentar implementar todo o sistema de construção no MVP.

---

# 61. MVP — PvP

Implementar uma área claramente delimitada onde:

> PvP é permitido.

Implementar:

- Não Envolvido;
- Envolvido;
- Hostil;
- registro de agressor;
- Infâmia;
- reputação humana.

---

# 62. MVP — consequência PvP

Teste:

Jogador A ataca Jogador B sem B estar envolvido.

Resultado:

- Infâmia aumenta;
- reputação humana diminui;
- NPCs podem dificultar acesso;
- oportunidades relacionadas a Assassino podem aparecer.

Validar:

> **comportamento → consequência social → nova oportunidade.**

---

# 63. MVP — multiplayer

Meta inicial:

> **2–8 jogadores.**

Validar:

- sincronização;
- combate;
- loot;
- inventário;
- construção;
- PvP;
- morte;
- reputação;
- persistência.

---

# 64. MVP — persistência

Salvar:

- personagem;
- inventário;
- equipamentos;
- construções;
- recursos;
- reputação;
- Infâmia;
- afinidades;
- profissão;
- especializações;
- natureza;
- estado de transformação.

---

# 65. Fora do MVP

Não tentar inicialmente:

- 10+ raças;
- dezenas de classes;
- guerra de guildas;
- economia complexa;
- centenas de jogadores;
- mundo inteiro;
- todos os biomas;
- dezenas de dungeons;
- centenas de bosses;
- PvP global;
- todas as transformações.

Esses conteúdos entram após validação.

---

# 66. Critérios de sucesso do MVP

O MVP será promissor se jogadores:

1. explorarem sem serem obrigados;
2. procurarem equipamentos melhores;
3. quiserem descobrir o território vampírico;
4. quiserem entender como virar vampiro;
5. sentirem diferença real após transformação;
6. quiserem continuar jogando depois da transformação;
7. criarem histórias sobre suas escolhas;
8. perceberem consequências do PvP;
9. utilizarem crafting;
10. procurarem especializações;
11. desejarem repetir a experiência com outro personagem.

---

# 67. Métricas

Medir:

- retenção;
- tempo de sessão;
- exploração;
- taxa de descoberta da transformação;
- taxa de tentativa de transformação;
- uso de crafting;
- aquisição de especializações;
- participação PvP;
- cooperação;
- diversidade de trajetórias.

Pergunta qualitativa principal:

> **"O que seu personagem se tornou e como isso aconteceu?"**

Respostas variadas são um indicador importante de sucesso.

---

# 68. Roadmap conceitual

### Fase 1 — Vertical Slice / MVP

- Humano;
- 3 profissões;
- 3 especializações;
- Vampiro;
- 1 dungeon;
- 1 boss;
- crafting;
- loot;
- construção;
- PvP;
- reputação;
- transformação;
- multiplayer 2–8.

### Fase 2 — Expansão

Adicionar:

- Bestiais;
- Necróticos;
- Profanos adicionais;
- mais cidades;
- mais dungeons;
- mais profissões;
- mais especializações;
- guildas;
- comércio.

### Fase 3 — MMORPG

Adicionar:

- servidores persistentes;
- guildas;
- economia;
- território;
- eventos;
- world bosses;
- guerras;
- conteúdo cooperativo;
- PvP avançado.

### Fase 4 — Endgame

- território;
- guildas;
- chefes;
- dungeons;
- guerras;
- reputação;
- transformação avançada;
- equipamentos raros;
- comércio;
- eventos mundiais;
- exploração;
- histórias emergentes.

---

# 69. Regras de design fundamentais para Claude

Ao propor ou implementar novas funcionalidades, Claude deve preservar estes princípios:

1. **Não transformar Afterkin em um MMORPG genérico.**
2. **Sobrevivência e exploração continuam centrais.**
3. **Transformação é mudança de natureza, não apenas aumento de poder.**
4. **Profissão e especialização representam conhecimento; natureza representa transformação.**
5. **Especializações devem ser conquistadas através do mundo, NPCs, facções e missões, e não por simples farming indiscriminado de XP.**
6. **Transformações devem depender de requisitos, afinidades e oportunidades descobertas no mundo.**
7. **O jogador pode permanecer humano.**
8. **PvP deve possuir contexto e consequências.**
9. **Atacar jogadores não envolvidos pode aumentar Infâmia e reduzir reputação humana, mas também pode abrir caminhos relacionados a Assassinos.**
10. **Nenhuma classe/natureza deve ser simplesmente superior; o objetivo é trocar possibilidades, vantagens e custos.**
11. **Solo deve continuar viável.**
12. **Sistemas devem se interconectar.**
13. **O mundo existente do projeto deve ser aproveitado e expandido, não descartado sem justificativa.**
14. **Performance continua sendo requisito estrutural do projeto.**
15. **Não implementar o MMORPG inteiro antes de validar o MVP.**
16. **Quando houver conflito entre esta visão de design e uma limitação técnica atual, preservar a intenção do design e propor uma implementação incremental.**
17. **Não reescrever sistemas existentes sem necessidade.**
18. **Toda nova feature deve considerar persistência e futura compatibilidade multiplayer quando tecnicamente relevante.**
19. **Preferir sistemas orientados a dados e extensíveis para profissões, especializações, naturezas, itens, loot, facções e transformações.**
20. **O MVP deve ser usado como instrumento de validação, não como versão definitiva do jogo.**

---

# 70. Princípio final

> **Você começa humano. O mundo decide o que você pode se tornar.**

Afterkin não deve perguntar apenas:

> "Qual classe você quer ser?"

A experiência deve levar o jogador a perguntar:

> **"Quem eu vou me tornar?"**
