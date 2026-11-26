class_name NoiteDoAtaque
extends RefCounted
## "A noite do ataque" (marco 3, etapa 3.7c; docs/DECISOES_DESIGN.md, ato 1): evento do mundo no fim do ato 1.
## Na noite do dia em que alguém viu o ninho (MissaoPrincipal passo 5), às 22h, os da noite ARROMBAM o portão da Vila
## dos Pescadores: 3 vampiros (+1 por jogador a mais) entram e caçam quem estiver acordado. Os guardas e os mais fortes
## lutam; os outros se trancam em casa. Moradores saem feridos, não mortos (marco 3). Acaba quando todos os vampiros
## caem ou ao amanhecer (os que sobrarem fogem). O portão fica arrombado (aberto) até alguém consertar.

const COM := MissaoPrincipal.COM
const HORA := 22.0
const N_BASE := 3
const N_POR_JOGADOR := 1
const PERTO_M := 160.0                       ## jogador a esta distância da Vila: o ataque acontece de verdade, com ele
const VIDA_MIN_MORADOR := 8.0                ## no ataque, ninguém da Vila morre: cai ferido
const CONSERTO_MADEIRA := 4
const CONSERTO_SOZINHO_H := 24.0             ## sem ajuda, a Vila conserta o portão sozinha depois disso
const LUTA_M := 14.0                         ## o lutador parte para cima do vampiro a esta distância
const GOLPE := 9.0
const TIRO := 14.0

static var marcado_h := -1.0                 ## hora (absoluta, de jogo) em que o ataque começa; -1 = não marcado
static var ativo := false
static var aconteceu := false
static var arrombado_ate := -1.0             ## hora de jogo em que a Vila termina o conserto sozinha; -1 = inteiro
static var _vampiros: Array = []             ## nós dos invasores (não vão no save)
static var _feridos: Dictionary = {}         ## id do NPC -> true (quem caiu ferido nesta noite)


static func zerar() -> void:
	marcado_h = -1.0
	ativo = false
	aconteceu = false
	arrombado_ate = -1.0
	_vampiros = []
	_feridos = {}


static func arrombado(com: String) -> bool:
	return com == COM and arrombado_ate >= 0.0


## Marca o ataque para as 22h de hoje (ou daqui a meia hora, se já passou das 22h ou é madrugada).
static func agendar() -> void:
	if marcado_h >= 0.0 or aconteceu:
		return
	var agora := Reputacao.agora_h()
	var dia := floorf(agora / 24.0)
	var h := agora - dia * 24.0
	marcado_h = dia * 24.0 + HORA if (h >= 6.0 and h < HORA) else agora + 0.5


## Quantos vampiros entram: 3, mais 1 por jogador além do primeiro.
static func quantos(arv: SceneTree) -> int:
	return N_BASE + N_POR_JOGADOR * maxi(0, arv.get_nodes_in_group("jogador").size() - 1)


static func _jogador_perto(arv: SceneTree) -> bool:
	var j := arv.get_first_node_in_group("jogador") as Node2D
	var g := Comunidades.geo(COM)
	if j == null or g.is_empty():
		return false
	var r: Rect2 = g["area"]
	return r.grow(PERTO_M * IsoMath.METRO).has_point(IsoMath.tela_para_mundo(j.global_position))


## A cada meio segundo (GerenteComunidades).
static func passo(arv: SceneTree) -> void:
	var agora := Reputacao.agora_h()
	if arrombado_ate >= 0.0 and not ativo and agora >= arrombado_ate:
		arrombado_ate = -1.0
		Simulacao.registrar_noticia(COM, "A Vila dos Pescadores consertou o portão que os da noite arrombaram.")
	if not ativo and marcado_h >= 0.0 and not aconteceu and agora >= marcado_h:
		comecar(arv)
		return
	if not ativo:
		return
	_vampiros = _vampiros.filter(func(v): return is_instance_valid(v) and not (v as Inimigo).morto)
	var ciclo := arv.get_first_node_in_group("ciclo_dia_noite")
	var amanheceu: bool = ciclo != null and float(ciclo.minutos) >= 360.0 and float(ciclo.minutos) < 18.0 * 60.0
	if _vampiros.is_empty() or amanheceu:
		terminar(arv)


static func comecar(arv: SceneTree) -> void:
	ativo = true
	aconteceu = true
	arrombado_ate = Reputacao.agora_h() + CONSERTO_SOZINHO_H + 12.0
	_feridos = {}
	MissaoPrincipal.inicio_do_ataque()
	var j := arv.get_first_node_in_group("jogador")
	if not _jogador_perto(arv):
		# longe da Vila: o ataque acontece sem ele, e ele fica sabendo depois
		Simulacao.registrar_noticia(COM, "Os da noite arrombaram o portão da Vila dos Pescadores. Dois moradores saíram feridos.", 2)
		terminar(arv)
		return
	var g := Comunidades.geo(COM)
	var portoes: Array = g["portoes"]
	var cena: PackedScene = load("res://scenes/enemies/inimigo.tscn")
	var pai: Node = j.get_parent() if j != null else arv.current_scene
	var centro: Vector2 = g["centro"]
	for i in quantos(arv):
		var pt: Dictionary = portoes[i % portoes.size()]
		var v := cena.instantiate() as Inimigo
		v.raca = "vampire"
		v.dorme = false
		v.invasao = centro
		pai.add_child(v)
		var fora: Vector2 = pt["fora"]
		v.global_position = IsoMath.mundo_para_tela(fora + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		_vampiros.append(v)
	for n in arv.get_nodes_in_group("npc"):
		var np := n as Npc
		if np != null and np.comunidade == COM and lutador(np) and np.dormindo and not np.morto:
			np._dormir(false)                     # o estrondo acorda quem pega em arma
	Simulacao.alertar(COM, "Os da noite arrombaram o portão!")
	if j != null:
		j.aviso("Um estrondo no portão! Os da noite arrombaram o portão da Vila!")


static func terminar(arv: SceneTree) -> void:
	ativo = false
	var fugiram := 0
	for v in _vampiros:
		if is_instance_valid(v) and not (v as Inimigo).morto:
			(v as Inimigo).fugir_da_vila()
			fugiram += 1
	_vampiros = []
	var nomes: PackedStringArray = []
	for id in _feridos:
		nomes.append(Simulacao._nome_npc(COM, str(id)))
	if not nomes.is_empty():
		Simulacao.registrar_noticia(COM, "Na noite do ataque, %s %s feridos." % [", ".join(nomes), "saiu" if nomes.size() == 1 else "saíram"], 2)
	if fugiram > 0:
		Simulacao.registrar_noticia(COM, "Ao amanhecer, os da noite que sobraram fugiram da Vila pelo portão arrombado.")
	var j := arv.get_first_node_in_group("jogador")
	MissaoPrincipal.fim_do_ataque(j)


## O ataque está acontecendo nesta comunidade?
static func na_vila(com: String) -> bool:
	return ativo and com == COM


## Este morador pega em arma no ataque? (os guardas e os mais fortes, como na Vigilancia)
static func lutador(np: Npc) -> bool:
	var papel := str(np.dados.get("papel", ""))
	return papel.begins_with("guarda") or papel in Vigilancia.FORTES


## Dano de monstro num morador da Vila durante o ataque: ele cai ferido, não morre.
static func segurar_dano(np: Npc, n: float) -> float:
	if not na_vila(np.comunidade):
		return n
	if np.vida - n < VIDA_MIN_MORADOR:
		var id := str(np.dados.get("id", ""))
		if not _feridos.has(id):
			_feridos[id] = true
			var c := Simulacao.estado(COM)
			if not c.is_empty() and Simulacao.ferido(COM, id).is_empty():
				(c["feridos"] as Array).append({"quem": id, "nome": np.nome(), "grav": 0.5, "tratado": false, "hosp": ""})
			np.falar("Ai! Me ajuda!", 2.5)
		return maxf(0.0, np.vida - VIDA_MIN_MORADOR)
	return n


## O vampiro invasor mais perto do morador (até LUTA_M), ou null.
static func alvo_do_lutador(np: Npc) -> Inimigo:
	var melhor: Inimigo = null
	var dist := LUTA_M * IsoMath.METRO
	var p := IsoMath.tela_para_mundo(np.global_position)
	for v in _vampiros:
		if not is_instance_valid(v) or (v as Inimigo).morto:
			continue
		var d := IsoMath.tela_para_mundo((v as Node2D).global_position).distance_to(p)
		if d < dist:
			dist = d
			melhor = v
	return melhor


# ───────────────────────────── consertar o portão ─────────────────────────────

## Opção na conversa com o guarda ou a líder: ajudar a consertar o portão arrombado (madeira).
static func opcoes(arvore: Dictionary, ctx: Dictionary, abertura: bool) -> Array:
	var out: Array = []
	if not abertura or ativo or not arrombado(str(ctx["com"])):
		return out
	var papel := ""
	for n in Comunidades.dados(COM).get("npcs", []):
		if str((n as Dictionary).get("id", "")) == str(ctx["npc"]):
			papel = str((n as Dictionary).get("papel", ""))
	if not (papel.begins_with("guarda") or papel == "lider"):
		return out
	var j: Node = ctx["jogador"]
	var nos: Dictionary = arvore["nos"]
	if j != null and j.inventario.contar("madeira") >= CONSERTO_MADEIRA:
		nos["_portao_conserto"] = {"fala": "Com essa madeira dá pra fechar aquilo de novo. Segura aqui que eu prego. (Vocês trabalham até o portão voltar a fechar.)",
			"efeitos": [{"pedir": "madeira", "qtd": CONSERTO_MADEIRA}, {"portao_conserto": true}]}
		out.append({"texto": "Trouxe madeira pra consertar o portão (%d)." % CONSERTO_MADEIRA, "vai": "_portao_conserto"})
	else:
		nos["_portao_falta"] = {"fala": "Precisa de madeira, umas %d tábuas. Sem isso, aquele portão não fecha nem com reza." % CONSERTO_MADEIRA}
		out.append({"texto": "Dá pra consertar o portão?", "vai": "_portao_falta"})
	return out


static func consertar(com: String) -> String:
	if not arrombado(com):
		return ""
	arrombado_ate = -1.0
	Reputacao.mudar(com, 5, "ajudou a consertar o portão")
	Simulacao.registrar_noticia(com, "Alguém de fora ajudou a consertar o portão que os da noite arrombaram.")
	return "O portão da Vila voltou a fechar."


static func dados_para_salvar() -> Dictionary:
	return {"marcado_h": marcado_h, "aconteceu": aconteceu, "arrombado_ate": arrombado_ate}


## No save não vão os invasores: carregar no meio do ataque encerra a noite (o portão continua arrombado).
static func restaurar(d: Dictionary) -> void:
	zerar()
	marcado_h = float(d.get("marcado_h", -1.0))
	aconteceu = bool(d.get("aconteceu", false))
	arrombado_ate = float(d.get("arrombado_ate", -1.0))
