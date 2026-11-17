# Playtest do marco 1 — Incursão humana

**Pergunta do marco** (`docs/DECISOES_DESIGN.md` §12): o loop *sair → arriscar → voltar* é divertido sozinho,
sem NPCs e sem transformação?

Se a resposta for "não", o problema tem de ser resolvido aqui, antes do marco 2. NPCs e transformação não salvam
um loop de incursão que não funciona.

---

## Como jogar a sessão

- **3 ou 4 incursões**, de preferência com **origens diferentes** (pelo menos Policial e uma outra).
- Uma **incursão** = sair de um ponto seguro com um objetivo, e voltar (ou morrer).
  Sem base de verdade ainda, o "ponto seguro" é onde você decidir: o totem, uma casa limpa, o início.
- Escolha um objetivo antes de sair, e anote: *"achar água limpa"*, *"juntar material para a fogueira"*,
  *"vasculhar aquela quadra"*, *"passar a noite vivo"*.
- Jogue pelo menos **uma noite inteira** (do fim da tardezinha ao amanhecer) e **uma tarde** (calor).
- Não use F9 (troca de raça) durante o playtest.

## Ficha por incursão

Copie e preencha uma linha por incursão (tempo real, do relógio do computador):

| # | Origem | Objetivo | Fase do dia na saída | Duração (min) | Voltou ou morreu? | Por que voltou (ou como morreu) | Peso na volta (kg) |
|---|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |

## Perguntas depois da sessão

Responda em uma ou duas frases cada. As respostas viram ajustes (tabela no fim).

**O loop**
1. Em algum momento você pensou *"forço mais um prédio ou volto?"* Quando, e o que decidiu?
2. O que mais te fez voltar: sede, fome, peso, noite, ferimento, medo de inimigo, ou tédio?
3. Qual foi a morte mais boba (injusta, sem aviso, sem chance de reagir)?
4. Teve algum momento de tédio de verdade? Fazendo o quê?

**Sede e água**
5. O bilhete ajudou a achar água? A água estava perto demais, longe demais ou no ponto?
6. Você bebeu água suja sem ferver alguma vez? Pegou disenteria? Valeu o risco?
7. Fabricou uma fogueira para ferver? O barulho e a luz pesaram na decisão?
8. A sede apertou rápido demais, devagar demais ou no ponto? E a fome?

**Peso**
9. Você chegou a ficar em SOBRECARGA? Largou coisa no chão para conseguir voltar?
10. Os 25 kg pareceram pouco, muito ou no ponto?

**Dia e noite**
11. A noite foi perigosa de verdade? Você mudou o jeito de jogar à noite (agachar, apagar a lanterna, esperar)?
12. A neblina do amanhecer foi notada? Usou para passar escondido?
13. O calor da tarde mudou alguma decisão (não correr, beber antes de sair)?
14. 40 minutos por dia: o dia pareceu longo, curto ou no ponto?

**Combate e barulho**
15. (Policial) Você atirou? O que aconteceu depois do estampido? Valeu a bala?
16. Os inimigos te viram/ouviram de forma justa? Algum te pegou "do nada"?

**Origens**
17. A origem mudou alguma coisa no seu jeito de jogar, ou só no kit inicial?
18. Alguma origem pareceu muito melhor ou muito pior que as outras?

**Geral**
19. Em uma frase: o que aconteceu de mais interessante na sessão?
20. Você teria vontade de jogar mais uma incursão agora? Por quê?

---

## Critério do marco 1

O marco passa se:
- as perguntas 1 e 20 tiverem resposta positiva na maioria das incursões;
- a pergunta 2 mostrar **motivos variados** para voltar (não só "tédio" e não sempre o mesmo);
- a pergunta 19 render uma história que você contaria a alguém.

O marco **não passa** se o motivo principal de voltar for tédio, ou se a sede/peso parecerem só manutenção
(encher a barra) em vez de decisão.

---

## Botões de ajuste

Tudo que provavelmente vai precisar de ajuste está num lugar só:

| O que | Onde | Valor atual |
|---|---|---|
| Duração do dia | `scripts/systems/dia_noite.gd` · `minutos_por_segundo` | 0,6 (40 min/dia) |
| Temperatura (média e amplitude) | `dia_noite.gd` · `temp_media`, `temp_amplitude` | 23 °C ± 10 |
| Visão dos inimigos (dia / noite) | `dia_noite.gd` · `visao_dia_m`, `visao_noite_m` | 12 m / 3,5 m |
| Som à noite / neblina | `dia_noite.gd` · `som_noite`, `neblina_max` | ×1,25 / 0,6 |
| Fome e sede por hora de jogo | `scripts/player/player.gd` · `fome_por_hora`, `sede_por_hora` | 2,78 / 5,56 |
| Sede no calor / correndo | `player.gd` · `sede_no_calor`, `sede_correndo` | +50% / +30% |
| Fôlego no calor | `player.gd` · `folego_no_calor` | +30% |
| Chance de disenteria (poça / rio / garrafa suja) | `scripts/systems/agua.gd` · `CHANCE_*` | 50% / 15% / 35% |
| Gole direto da fonte | `agua.gd` · `GOLE` | 50 |
| Fervura (s por garrafa) / fogueira acesa | `scripts/world/fogueira.gd` · `TEMPO_FERVER`, `DURACAO_ACESA` | 6 s / 300 s |
| Capacidade da mochila | `scripts/systems/inventario.gd` · `CAPACIDADE_KG` | 25 kg |
| Peso de cada item | `scripts/systems/itens.gd` · `"peso"` em `DB` | — |
| Pistola (alcance, dano, ruído) | `player.gd` · `ALCANCE_TIRO_M`, `DANO_TIRO`, `RUIDO_TIRO` | 12 m, 30, 900 |
| Kits e perks das origens | `scripts/systems/origens.gd` | — |
| Loot (água, garrafa, bandagem, munição) | `itens.gd` · `saque()` | — |

## Limitações conhecidas (não são bugs do marco 1)

- A visão dos inimigos e o tiro não testam paredes dentro do mesmo ambiente.
- A fogueira acesa pelo jogador não entra no save (é temporária).
- O vampiro (F9) não tem sede; o sangue vem no marco 4.
- Não há NPCs, rumores de verdade, reputação nem log de eventos: tudo isso é o marco 2.
- Os perks das origens são provisórios (`docs/DECISOES_DESIGN.md`).
