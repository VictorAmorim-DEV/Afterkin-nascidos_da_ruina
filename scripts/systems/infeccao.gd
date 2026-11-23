class_name Infeccao
extends RefCounted
## Infecção vampírica do marco 3 (docs/DECISOES_DESIGN.md, "Marco 3 — o dilema da infecção").
## O estado fica no jogador (`doenca`, por jogador: regra do co-op); aqui ficam as regras.
## 48 h de jogo em 4 estágios: Marca (0–12 h), Fome (12–24 h), Sede (24–40 h), Limiar (40–48 h).
## O estágio aparece para o jogador; as horas só com o diagnóstico de Medicina. No Limiar nada cura.
## Às 48 h o jogador vira vampiro (o provisório da V13 até o marco 4).

const TIPO := "Infecção vampírica"
const TOTAL_H := 48.0
const ESTAGIOS := ["Marca", "Fome", "Sede", "Limiar"]
const FIM_ESTAGIO_H := [12.0, 24.0, 40.0, 48.0]      ## horas desde a mordida em que cada estágio acaba
const AVANCO_MORDIDA_H := 6.0                        ## mordida nova em quem já está infectado

## Mordida do vampiro (habilidade): chance de romper fundo e infectar, pelo jeito da mordida.
const CHANCE_FRENTE := 0.25
const CHANCE_COSTAS := 0.5                           ## pelas costas, agachado ou deitado
const CHANCE_CAIDO := 0.8                            ## caído, dormindo ou descansando
const PROTECAO_PESCOCO := 0.15                       ## gola ou cachecol de couro
const DANO_MORDIDA := 10.0

## Sintomas por estágio: [recuperação do fôlego ×, velocidade ×, fome ×, vida perdida por segundo, sede ×]
## (mesmo formato de Player.SINTOMAS). A perda de vida do Limiar só vale sem sangue no corpo (3.2b).
const SINTOMAS := [[0.85, 1.0, 1.0, 0.0, 1.0], [0.85, 1.0, 1.0, 0.0, 1.0], [0.8, 1.0, 1.0, 0.0, 1.0],
	[0.75, 1.0, 1.0, 0.08, 1.0]]
const VISAO_ESCURO := [0.0, 0.25, 0.55, 0.6]         ## quanto a noite clareia para quem está infectado
const COMIDA := [1.0, 0.5, 0.25, 0.25]               ## quanto a comida humana sacia
const SOL := [0.0, 0.0, 0.6, 1.0]                     ## quanto o sol queima (o vampiro é 1)
const SOL_CANSA := 0.75                               ## Fome em diante: o fôlego volta mais devagar ao sol
const AVISOS := ["",
	"Uma fome estranha, que comida não resolve. E, no escuro, você enxerga mais do que deveria.",
	"O sol queima a sua pele e a comida enjoa. Seus olhos mudaram: quem olhar de perto vai notar.",
	"Algo dentro de você parou de lutar. Nenhuma cura funciona mais."]


static func nova() -> Dictionary:
	return {"tipo": TIPO, "horas": TOTAL_H, "total": TOTAL_H, "estagio": 0.0, "origem": "vampire"}


static func ativa(j: Node) -> bool:
	return str((j.doenca as Dictionary).get("tipo", "")) == TIPO


## Estágio (0 Marca … 3 Limiar) pelas horas que restam; -1 sem a infecção.
static func estagio(j: Node) -> int:
	if not ativa(j):
		return -1
	return estagio_por_horas(float(j.doenca["horas"]))


static func estagio_por_horas(restam: float) -> int:
	var passou := TOTAL_H - restam
	for i in FIM_ESTAGIO_H.size():
		if passou < float(FIM_ESTAGIO_H[i]):
			return i
	return 3


static func nome_estagio(e: int) -> String:
	return str(ESTAGIOS[clampi(e, 0, 3)])


## Horas que faltam até o próximo estágio (para o F1 e os testes).
static func horas_ate_proximo(j: Node) -> float:
	var e := estagio(j)
	if e < 0:
		return 0.0
	return float(FIM_ESTAGIO_H[e]) - (TOTAL_H - float(j.doenca["horas"]))


static func no_limiar(j: Node) -> bool:
	return estagio(j) >= 3


## Fator do sintoma 'i' (ver SINTOMAS) para o estágio atual.
static func sintoma(j: Node, i: int) -> float:
	var e := estagio(j)
	var v: float = (SINTOMAS[e] as Array)[i]
	if i == 3 and float(j.sangue_t) > 0.0:
		v = 0.0                                  # Limiar: com sangue no corpo, a vida não cai
	if i == 0 and e >= 1 and j.ao_sol_direto():
		v *= SOL_CANSA
	return v


## 0 a 1: quanto a escuridão da noite clareia para este jogador (DiaNoite).
static func visao_escuro(j: Node) -> float:
	if str(j.raca) == "vampire":
		return 0.6
	var e := estagio(j)
	return 0.0 if e < 0 else float(VISAO_ESCURO[e])


static func fator_comida(j: Node) -> float:
	var e := estagio(j)
	return 1.0 if e < 0 else float(COMIDA[e])


## Quanto o sol queima: 1 para o vampiro, pelo estágio para o infectado, 0 para os outros.
static func sol(j: Node) -> float:
	if str(j.raca) == "vampire":
		return 1.0
	var e := estagio(j)
	return 0.0 if e < 0 else float(SOL[e])


## Os olhos já mudaram (Sede em diante): os NPCs que olharem de perto notam (etapa 3.5).
static func olhos_mudados(j: Node) -> bool:
	return estagio(j) >= 2


## Começa a infecção, ou adianta +6 h se já estiver infectado. Devolve o aviso para o jogador.
static func morder(j: Node) -> String:
	if ativa(j):
		var antes := estagio(j)
		j.doenca["horas"] = maxf(0.01, float(j.doenca["horas"]) - AVANCO_MORDIDA_H)
		j.doenca["estagio"] = float(estagio(j))
		var txt := "A mordida rompeu fundo de novo: a infecção avançou."
		if estagio(j) > antes:
			txt += " " + str(AVISOS[estagio(j)])
		return txt
	j.doenca = nova()
	return "Ele cravou os dentes fundo. Você sente o veneno entrando: você foi infectado."


## Chance de a mordida romper fundo, pelo jeito como ela aconteceu (de onde veio o vampiro e a postura).
static func chance_mordida(j: Node, de_onde_mundo: Vector2) -> float:
	var c := CHANCE_FRENTE
	if j.descansando != null or bool(j.dormindo):
		c = CHANCE_CAIDO
	elif int(j.postura) != 0:                 # agachado ou deitado (Player.Postura.EM_PE é 0)
		c = CHANCE_COSTAS
	else:
		var olhar := Vector2.from_angle(float(j.face))
		var para_vampiro := de_onde_mundo - IsoMath.tela_para_mundo(j.global_position)
		if para_vampiro.length() > 0.01 and olhar.dot(para_vampiro.normalized()) < -0.35:
			c = CHANCE_COSTAS                    # veio por trás
	if protegido(j):
		c -= PROTECAO_PESCOCO
	return clampf(c, 0.0, 1.0)


## Gola ou cachecol de couro na mochila (até existir roupa vestida).
static func protegido(j: Node) -> bool:
	return Itens.DB.has("cachecol_couro") and j.inventario.contar("cachecol_couro") > 0
