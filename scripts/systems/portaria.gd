class_name Portaria
extends RefCounted
## Portão de comunidade como posto de controle (marco 3.5, docs/DECISOES_DESIGN.md Q60–Q71). O portão fica sempre
## fechado; entra e sai quem fala com o guarda do turno, que faz o controle pela reputação e abre por alguns segundos.
## - Primeira vez, reputação de 0 a 50, alerta ou castigo: revista (recolhe as armas, devolve na saída).
## - De 50 a 70: pergunta (mordida, ferido, armado); quem diz que está armado deixa as armas; quem mente e é visto
##   com a arma lá dentro é abordado (recolhe, −10, revista por 3 dias).
## - De 70 em diante: só pergunta se está ferido ou mordido.
## A vistoria da infecção (o pescoço e os olhos) entra pelo exame (etapa 3.5c). O estado é por jogador (co-op).

const ABRE_S := 8.0
const REP_PERGUNTA := 50
const REP_CONFIA := 70
const CASTIGO_H := 72.0
const MULTA_ARMA := 10
## O que o guarda recolhe na revista: armas de fogo (e a munição), arco e flecha, lança. Ferramentas ficam.
const RECOLHE := ["pistola", "municao", "espingarda", "rifle", "arco", "flecha", "lanca", "besta"]

static var guardados: Dictionary = {}       ## com -> [[id, qtd], ...] que o guarda guardou
static var abre_ate: Dictionary = {}        ## com -> segundos reais até quando o portão fica aberto
static var conhece: Dictionary = {}         ## com -> true: já passou pelo controle uma vez
static var castigo_h: Dictionary = {}       ## com -> hora do jogo até quando volta a ser revistado
static var mentiu_arma: Dictionary = {}     ## com -> true: entrou dizendo que não estava armado, e estava
static var recusou: Dictionary = {}         ## com -> dia em que se recusou a mostrar o pescoço (em alerta)
static var _t_vigia := 0.0


static func zerar() -> void:
	guardados = {}
	abre_ate = {}
	conhece = {}
	castigo_h = {}
	mentiu_arma = {}
	recusou = {}


static func _dia() -> int:
	return int(Reputacao.agora_h() / 24.0)


static func _agora_s() -> float:
	return Time.get_ticks_msec() / 1000.0


## O guarda abriu o portão e ele ainda está aberto?
static func aberto(com: String) -> bool:
	return float(abre_ate.get(com, -1.0)) > _agora_s()


static func abrir(com: String) -> void:
	abre_ate[com] = _agora_s() + ABRE_S


## "revista", "pergunta" ou "confia", pela reputação, pela primeira vez, pelo castigo e pelo alerta.
static func faixa(com: String) -> String:
	var rep := Reputacao.valor(com)
	if not conhece.has(com) or rep < REP_PERGUNTA or Simulacao.alerta(com) or float(castigo_h.get(com, -1.0)) > Reputacao.agora_h():
		return "revista"
	return "pergunta" if rep < REP_CONFIA else "confia"


static func armas(j: Node) -> Array:
	var out: Array = []
	for id in RECOLHE:
		var n: int = j.inventario.contar(id)
		if n > 0:
			out.append([id, n])
	return out


static func dentro(com: String, j: Node2D) -> bool:
	return Comunidades.em(IsoMath.tela_para_mundo(j.global_position)) == com


## O guarda de turno no portão: o NPC com a tarefa "portao" mais perto de 'perto' (até PERTO_GUARDA), ou, sem
## 'perto', qualquer um da comunidade. null se não há ninguém.
const PERTO_GUARDA := 12.0 * IsoMath.METRO


static func guarda_do_portao(arv: SceneTree, com: String, perto := Vector2.INF) -> Npc:
	var melhor: Npc = null
	var dist := PERTO_GUARDA if perto != Vector2.INF else INF
	for n in arv.get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.comunidade != com or npc.tarefa != "portao" or npc.morto or npc.dormindo or npc.fora \
				or npc.desacordado():
			continue
		var d := 0.0 if perto == Vector2.INF else IsoMath.tela_para_mundo(npc.global_position).distance_to(perto)
		if d < dist:
			dist = d
			melhor = npc
	return melhor


# ───────────────────────────── conversa ─────────────────────────────

## Abertura do guarda no portão para quem está do lado de fora (DialogoUI). {} se não for o caso.
static func abertura(com: String, npc: Npc, ctx: Dictionary) -> Dictionary:
	var j: Node2D = ctx["jogador"]
	if npc.tarefa != "portao" or dentro(com, j) or VidaComunidade.barrado(com) or Consequencias.expulso(com):
		return {}
	if aberto(com):
		return {"no": "_p_aberto", "nos": {"_p_aberto": {"fala": "Já tá aberto. Entra logo."}}}
	var ciclo := j.get_tree().get_first_node_in_group("ciclo_dia_noite")
	var noite: bool = ciclo != null and not Comunidades.portao_aberto(com, float(ciclo.minutos))
	if noite and Reputacao.valor(com) < VidaComunidade.REP_NOITE:
		return {"no": "_p_noite", "nos": {"_p_noite": {"fala": "De noite não abre pra quem eu não conheço. Volta de manhã."}}}
	if int(recusou.get(com, -1)) == _dia():
		return {"no": "_p_recusou", "nos": {"_p_recusou": {"fala": "Já falei: sem mostrar o pescoço, hoje não entra."}}}
	var nos := {"_p_entra": {"fala": "...", "_dinamico": true}, "_p_nao": {"fala": "Então daí você não passa."},
		"_p_recusa": {"fala": "Então hoje você não entra. Com a vila em alerta, não tem conversa.", "efeitos": [{"portaria": "recusou"}]}}
	var arm := armas(j)
	var mordido := Infeccao.ativa(j)
	var alerta := Simulacao.alerta(com)
	match faixa(com):
		"revista":
			var abre := "Alto lá. Primeira vez aqui? " if not conhece.has(com) else "Alto lá. "
			if Simulacao.alerta(com):
				abre = "Alto lá. A vila tá em alerta: todo mundo passa pelo procedimento. "
			var pede := " E mostra o pescoço." if alerta else ""
			var ops: Array = [{"texto": "Pode olhar.", "vai": "_p_entra", "efeitos": [{"portaria": "revista"}]}]
			if mordido:
				ops.append({"texto": "Fui mordido. Pode olhar.", "vai": "_p_entra", "efeitos": [{"portaria": "revista", "contar": true}]})
			ops.append({"texto": "Ninguém mexe nas minhas coisas.", "vai": "_p_nao"})
			if alerta:
				ops.append({"texto": "Não vou mostrar o pescoço.", "vai": "_p_recusa"})
			nos["_p_revista"] = {"fala": abre + "Vou te olhar e dar uma geral na mochila. Arma fica comigo; você pega na saída." + pede,
				"opcoes": ops}
			return {"no": "_p_revista", "nos": nos}
		"pergunta":
			var ops2: Array = [{"texto": "Tô armado. Deixo com você.", "vai": "_p_entra", "efeitos": [{"portaria": "deixa"}]},
				{"texto": "Nada disso.", "vai": "_p_entra", "efeitos": [{"portaria": "nada", "armado": not arm.is_empty()}]}]
			if mordido:
				ops2.append({"texto": "Fui mordido.", "vai": "_p_entra", "efeitos": [{"portaria": "deixa", "contar": true}]})
			nos["_p_pergunta"] = {"fala": "Procedimento: mordida, ferido, armado?", "opcoes": ops2}
			return {"no": "_p_pergunta", "nos": nos}
	var ops3: Array = [{"texto": "Tudo certo.", "vai": "_p_entra", "efeitos": [{"portaria": "confia"}]}]
	if mordido:
		ops3.append({"texto": "Fui mordido.", "vai": "_p_entra", "efeitos": [{"portaria": "confia", "contar": true}]})
	nos["_p_confia"] = {"fala": "Ô, de volta. Tudo bem? Nada de ferida, nada de mordida?", "opcoes": ops3}
	return {"no": "_p_confia", "nos": nos}


## Opção de sair, para quem fala com o guarda do portão do lado de dentro.
static func opcoes(arvore: Dictionary, ctx: Dictionary, npc: Npc, abertura_conv: bool) -> Array:
	var j: Node2D = ctx["jogador"]
	var com := str(ctx["com"])
	if not abertura_conv or npc.tarefa != "portao" or not dentro(com, j):
		return []
	var g: Array = guardados.get(com, [])
	var fala := "Toma o que é seu. (Devolve %s.) Vai com Deus." % Itens.texto_lista(g) if not g.is_empty() else "Vai com Deus. Volta antes de escurecer."
	arvore["nos"]["_p_sai"] = {"fala": fala, "efeitos": [{"portaria": "sair"}]}
	return [{"texto": "Abre pra mim? Vou sair.", "vai": "_p_sai"}]


## Efeitos {"portaria": ...} da conversa.
static func efeito(ed: Dictionary, ctx: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var j: Node2D = ctx["jogador"]
	var com := str(ctx["com"])
	var nos: Dictionary = ctx.get("_nos", {})
	var acao := str(ed["portaria"])
	if acao == "recusou":
		recusou[com] = _dia()
		return msgs
	match acao:
		"sair":
			var g: Array = guardados.get(com, [])
			if not g.is_empty() and j.inventario.adicionar_itens(g):
				msgs.append("Recebeu de volta: %s." % Itens.texto_lista(g))
			elif not g.is_empty():
				for it in g:
					ItemNoChao.largar(j.get_parent(), j.global_position, str(it[0]), int(it[1]))
				msgs.append("O guarda deixa suas coisas no chão (mochila cheia).")
			guardados.erase(com)
			mentiu_arma.erase(com)
			abrir(com)
			return msgs
		"revista", "deixa":
			var arm := armas(j)
			if not arm.is_empty():
				_guardar(j, com, arm)
				msgs.append("O guarda guardou: %s (devolve na saída)." % Itens.texto_lista(arm))
		"nada":
			if bool(ed.get("armado", false)):
				mentiu_arma[com] = true
	var r := exame(j, com, "contar" if bool(ed.get("contar", false)) else acao)
	nos["_p_entra"] = {"fala": str(r["fala"])}
	if bool(r["entra"]):
		conhece[com] = true
		abrir(com)
	if r.has("aviso"):
		msgs.append(str(r["aviso"]))
	return msgs


static func _guardar(j: Node, com: String, arm: Array) -> void:
	var g: Array = guardados.get(com, [])
	for it in arm:
		j.inventario.remover(str(it[0]), int(it[1]))
		var achou := false
		for x in g:
			if str(x[0]) == str(it[0]):
				x[1] = int(x[1]) + int(it[1])
				achou = true
		if not achou:
			g.append([str(it[0]), int(it[1])])
	guardados[com] = g


## O exame visual (e, na 3.5c, a vistoria da infecção). {"entra", "fala", "aviso"?}
static func exame(j: Node, com: String, modo: String) -> Dictionary:
	var v := Vigilancia.vistoria(j, com, modo)
	if not v.is_empty():
		return v
	var ferido: bool = float(j.vida) < float(j.vida_max) * 0.5
	var fala := "(Ele te olha de cima a baixo.) Pode passar."
	if ferido:
		fala = "(Ele te olha de cima a baixo.) Tá machucado. Passa, e vai direto no médico."
	return {"entra": true, "fala": fala}


# ───────────────────────────── vigia lá dentro ─────────────────────────────

## A cada meio segundo (GerenteComunidades): quem mentiu sobre a arma e aparece com ela à vista é abordado.
static func passo(arv: SceneTree) -> void:
	var j := arv.get_first_node_in_group("jogador") as Node2D
	if j == null or bool(j.morto) or mentiu_arma.is_empty():
		return
	var com := Comunidades.em(IsoMath.tela_para_mundo(j.global_position))
	if com == "" or not mentiu_arma.has(com):
		return
	var na_mao := str(j.inventario.id_equipado())
	if not na_mao in RECOLHE:
		return
	var p := IsoMath.tela_para_mundo(j.global_position)
	for n in arv.get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc != null and npc.comunidade == com and not npc.morto and not npc.dormindo and Reputacao._viu(npc, j, p):
			abordar(j, com, npc)
			return


## Viram a arma que você disse não ter: recolhe, multa e revista por 3 dias.
static func abordar(j: Node, com: String, quem: Npc) -> void:
	mentiu_arma.erase(com)
	var arm := armas(j)
	if not arm.is_empty():
		_guardar(j, com, arm)
	castigo_h[com] = Reputacao.agora_h() + CASTIGO_H
	Reputacao.mudar(com, -MULTA_ARMA, "mentiu sobre a arma no portão")
	quem.falar("Ei! Você disse que não tava armado!", 3.0)
	j.aviso("%s viu a arma. O guarda recolhe %s e, por 3 dias, você volta a ser revistado." % [quem.nome(),
		Itens.texto_lista(arm) if not arm.is_empty() else "o que achou"])


static func dados_para_salvar() -> Dictionary:
	return {"guardados": guardados.duplicate(true), "conhece": conhece.duplicate(), "castigo_h": castigo_h.duplicate(),
		"mentiu_arma": mentiu_arma.duplicate(), "recusou": recusou.duplicate()}


static func restaurar(d: Dictionary) -> void:
	zerar()
	guardados = (d.get("guardados", {}) as Dictionary).duplicate(true)
	conhece = (d.get("conhece", {}) as Dictionary).duplicate()
	castigo_h = (d.get("castigo_h", {}) as Dictionary).duplicate()
	mentiu_arma = (d.get("mentiu_arma", {}) as Dictionary).duplicate()
	recusou = (d.get("recusou", {}) as Dictionary).duplicate()
