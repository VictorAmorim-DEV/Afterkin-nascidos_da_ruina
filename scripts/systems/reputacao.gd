class_name Reputacao
extends RefCounted
## Reputação por testemunha e boato (marco 2, etapa 6; docs/DECISOES_DESIGN.md Q40 e Q44).
##
## - Quando o jogador faz algo que importa (roubar dentro de uma comunidade, agredir ou matar um morador, defender a
##   comunidade de um monstro), cada NPC acordado que VIU guarda a lembrança. Ninguém viu = ninguém sabe.
## - A testemunha conta na comunidade dela 1–2 h de jogo depois: aí a reputação da comunidade muda e todos passam a
##   "ter ouvido". Se a testemunha morrer antes de contar, o boato morre com ela.
## - Depois o boato viaja: chega às comunidades aliadas em ~12 h (metade do peso) e às neutras em ~24 h (um quarto);
##   rivais não conversam. A reputação humana geral acompanha a metade de cada boato.
## - Morador morto não volta (Q44): o GerenteComunidades não o recria.
## As conversas também mexem na reputação direto (Conversas, efeito "rep"): ali quem ouve é o próprio NPC.

const EVENTOS := {
	"furto": {"peso": -8, "viu": "viu você mexendo no que é dos outros", "boato": "anda pegando o que não é seu"},
	"agressao": {"peso": -15, "viu": "viu você atacar gente daqui", "boato": "atacou gente da comunidade"},
	"assassinato": {"peso": -45, "viu": "viu você matar gente daqui", "boato": "matou gente da comunidade"},
	"defesa": {"peso": 4, "viu": "viu você enfrentar um monstro perto do muro", "boato": "defendeu a comunidade"},
	"ameaca": {"peso": -6, "viu": "viu você ameaçar gente daqui", "boato": "anda ameaçando os moradores"},
}
const ATRASO_H := Vector2(1.0, 2.0)            ## horas de jogo até a testemunha contar
const ALIADA := {"aliada": [12.0, 0.5], "neutra": [24.0, 0.25]}   ## [atraso em h, fração do peso]

static var rep: Dictionary = {}                ## comunidade -> int (-100 a 100)
static var humana: float = 0.0                 ## reputação humana geral
static var memorias: Dictionary = {}           ## "comunidade/npc" -> [{ev, como ("vitima"/"viu"/"ouviu"), dia, alvo, cobrado, resolvido}]
static var pendentes: Array = []               ## [{com, ev, peso, hora, testemunha, origem, alvo}]
static var mortos: Dictionary = {}             ## "comunidade/npc" -> true


static func zerar() -> void:
	rep = {}
	humana = 0.0
	memorias = {}
	pendentes = []
	mortos = {}


static func valor(com: String) -> int:
	return int(rep.get(com, 0))


static func mudar(com: String, n: int) -> void:
	rep[com] = clampi(valor(com) + n, -100, 100)


static func vivo(com: String, npc: String) -> bool:
	return not mortos.has("%s/%s" % [com, npc])


static func memoria(com: String, npc: String) -> Array:
	return memorias.get("%s/%s" % [com, npc], [])


## 'alvo': id do NPC que sofreu (agressão, assassinato, ameaça) na mesma comunidade; "" se não houver.
static func _lembrar(chave: String, ev: String, como: String, alvo: String = "") -> void:
	if not memorias.has(chave):
		memorias[chave] = []
	(memorias[chave] as Array).append({"ev": ev, "como": como, "dia": _dia(), "alvo": alvo, "cobrado": false, "resolvido": ""})


static func _ciclo() -> Node:
	var arv := Engine.get_main_loop() as SceneTree
	return arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null


static func _dia() -> int:
	var c := _ciclo()
	return int(c.dia) if c != null else 1


## Hora absoluta do jogo (h desde o dia 0).
static func agora_h() -> float:
	var c := _ciclo()
	return float(c.dia) * 24.0 + float(c.minutos) / 60.0 if c != null else 0.0


# ───────────────────────────── testemunhas ─────────────────────────────

## O jogador fez 'ev' no ponto 'p' (mundo). Devolve quantos viram. 'vitima' (Npc) também vê, se sobreviver, e
## lembra como vítima. 'alvo' é o id de quem sofreu quando a vítima não pode lembrar (morreu).
static func registrar(ev: String, p: Vector2, vitima: Node = null, alvo: String = "") -> int:
	var arv := Engine.get_main_loop() as SceneTree
	var j := arv.get_first_node_in_group("jogador") as Node2D
	if j == null or not EVENTOS.has(ev):
		return 0
	var viram: Array = []
	for n in arv.get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.morto or npc.comunidade == "":
			continue                               # errante não leva o boato a comunidade nenhuma por aqui
		if npc == vitima or _viu(npc, j, p):
			viram.append(npc)
	viram.append_array(_dono_acordado(ev, p, viram))
	if vitima != null and alvo == "":
		alvo = str((vitima as Npc).dados.get("id", ""))
	var por_com: Dictionary = {}
	for npc in viram:
		var chave := "%s/%s" % [npc.comunidade, str(npc.dados.get("id", ""))]
		_lembrar(chave, ev, "vitima" if npc == vitima else "viu", alvo)
		if not por_com.has(npc.comunidade):
			por_com[npc.comunidade] = npc
	for com in por_com:
		var t: Npc = por_com[com]
		pendentes.append({"com": com, "ev": ev, "peso": int(EVENTOS[ev]["peso"]),
			"hora": agora_h() + randf_range(ATRASO_H.x, ATRASO_H.y),
			"testemunha": "%s/%s" % [com, str(t.dados.get("id", ""))], "origem": com, "alvo": alvo})
	Consequencias.testemunhado(ev, alvo, viram)
	if not viram.is_empty():
		var nomes: PackedStringArray = []
		for npc in viram.slice(0, 2):
			nomes.append((npc as Npc).nome())
		var mais := " e mais %d" % (viram.size() - 2) if viram.size() > 2 else ""
		j.aviso("%s%s %s." % [" e ".join(nomes), mais, EVENTOS[ev]["viu"]])
	return viram.size()


## O NPC enxerga o ponto? Acordado, perto o bastante (luz do dia, noite, lanterna, postura) e no mesmo ambiente:
## os dois na rua, ou os dois no mesmo prédio.
static func _viu(npc: Npc, j: Node2D, p: Vector2) -> bool:
	if npc.dormindo:
		return false
	var pn := IsoMath.tela_para_mundo(npc.global_position)
	var alcance: float = j.alcance_ser_visto() if j.has_method("alcance_ser_visto") else 12.0 * IsoMath.METRO
	if pn.distance_to(p) > alcance:
		return false
	return _predio_em(npc.get_tree(), pn) == _predio_em(npc.get_tree(), p)


static func _predio_em(arv: SceneTree, p: Vector2) -> Node:
	for e in arv.get_nodes_in_group("edificio"):
		if e.sala_de(p - IsoMath.tela_para_mundo(e.global_position)) >= 0:
			return e
	return null


## Furto dentro de uma casa de noite: o morador que dorme ali acorda e vê, com 60% de chance.
static func _dono_acordado(ev: String, p: Vector2, ja: Array) -> Array:
	if ev != "furto":
		return []
	var arv := Engine.get_main_loop() as SceneTree
	var predio := _predio_em(arv, p)
	if predio == null:
		return []
	var centro := IsoMath.tela_para_mundo(predio.global_position)
	for n in arv.get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.morto or not npc.dormindo or ja.has(npc):
			continue
		if npc.ponto_da_tarefa("casa").distance_to(centro) < 700.0 and randf() < 0.6:
			npc.acordar_assustado()
			return [npc]
	return []


# ───────────────────────────── boatos ─────────────────────────────

## Chamado pelo GerenteComunidades: espalha os boatos cuja hora chegou.
static func passo() -> void:
	if pendentes.is_empty():
		return
	var h := agora_h()
	var restam: Array = []
	var novos: Array = []
	for b in pendentes:
		var bd: Dictionary = b
		if float(bd["hora"]) > h:
			restam.append(bd)
			continue
		var t: String = str(bd["testemunha"])
		if t != "" and mortos.has(t):
			continue                           # a testemunha morreu antes de contar
		var com: String = bd["com"]
		mudar(com, int(bd["peso"]))
		for npc in Comunidades.dados(com).get("npcs", []):
			var chave := "%s/%s" % [com, str((npc as Dictionary)["id"])]
			if chave != t and not mortos.has(chave):
				_lembrar(chave, str(bd["ev"]), "ouviu", str(bd.get("alvo", "")) if str(bd["origem"]) == com else "")
		Consequencias.boato_correu(com, bd)
		if str(bd["origem"]) == com:           # primeira vez que o boato corre: segue para as outras comunidades
			humana = clampf(humana + float(bd["peso"]) * 0.5, -100.0, 100.0)
			if int(bd["peso"]) < 0:
				mudar("saqueadores", int(-int(bd["peso"]) / 3.0))    # o que espanta as comunidades agrada os bandos
			var rel: Dictionary = Comunidades.dados(com).get("relacoes", {})
			for outra in rel:
				var tipo := str(rel[outra])
				if ALIADA.has(tipo):
					var par: Array = ALIADA[tipo]
					var peso := roundi(float(bd["peso"]) * float(par[1]))
					if peso != 0:
						novos.append({"com": str(outra), "ev": bd["ev"], "peso": peso, "hora": h + float(par[0]),
							"testemunha": "", "origem": com, "alvo": bd.get("alvo", "")})
	pendentes = restam + novos


## Um errante ajudado ou roubado escapa e conta na comunidade mais perto, 8–16 h depois (Q40: "se uma
## testemunha escapar, ela conta"). A reputação humana geral acompanha metade.
static func boato_errante(peso: int, ev: String) -> void:
	var arv := Engine.get_main_loop() as SceneTree
	var j := arv.get_first_node_in_group("jogador") as Node2D
	if j == null:
		return
	var pj := IsoMath.tela_para_mundo(j.global_position)
	var melhor := ""
	var dist := INF
	for id in Comunidades.ids():
		var g := Comunidades.geo(str(id))
		if not g.is_empty() and (g["centro"] as Vector2).distance_to(pj) < dist:
			dist = (g["centro"] as Vector2).distance_to(pj)
			melhor = str(id)
	if melhor == "":
		return
	pendentes.append({"com": melhor, "ev": ev, "peso": peso, "hora": agora_h() + randf_range(8.0, 16.0),
		"testemunha": "", "origem": melhor})


## Morador morto: não volta, e o que ele viu sem contar morre junto (passo() descarta).
static func npc_morreu(com: String, npc: String) -> void:
	mortos["%s/%s" % [com, npc]] = true


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"rep": rep.duplicate(), "humana": humana, "memorias": memorias.duplicate(true),
		"pendentes": pendentes.duplicate(true), "mortos": mortos.keys()}


static func restaurar(d: Dictionary) -> void:
	zerar()
	var rd: Dictionary = d.get("rep", {})
	for k in rd:
		rep[str(k)] = int(rd[k])
	humana = float(d.get("humana", 0.0))
	memorias = (d.get("memorias", {}) as Dictionary).duplicate(true)
	for b in d.get("pendentes", []):
		var bd: Dictionary = (b as Dictionary).duplicate()
		bd["peso"] = int(bd["peso"])
		bd["hora"] = float(bd["hora"])
		pendentes.append(bd)
	for m in d.get("mortos", []):
		mortos[str(m)] = true
