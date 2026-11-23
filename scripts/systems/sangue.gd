class_name Sangue
extends RefCounted
## Beber sangue (marco 3, docs/DECISOES_DESIGN.md): o jeito de ceder à infecção. Tecla B ("morder").
## Na Marca não dá; da Fome em diante dá força (e, da Sede em diante, velocidade) por algumas horas de jogo, e no
## Limiar o sangue segura a perda de vida. Cada gole também adianta a infecção.
## Fontes: bicho (rato morto: meio efeito, +1 h), corpo de gente morta há até 1 h (efeito inteiro, +3 h) e pessoa
## viva caída (efeito dobrado, +6 h, crime grave se alguém vir). O estado do efeito fica no jogador.

const ALCANCE := 1.3 * IsoMath.METRO
const FRESCO_H := 1.0                              ## horas de jogo em que o corpo ainda tem sangue bom
const FAREJA := 30.0 * IsoMath.METRO               ## da Sede em diante: sente o cheiro de sangue até aqui
const FONTES := {
	"bicho": {"mult": 0.5, "avanco_h": 1.0},
	"corpo": {"mult": 1.0, "avanco_h": 3.0},
	"pessoa": {"mult": 2.0, "avanco_h": 6.0},
}
## Por estágio (0 Marca … 3 Limiar): [força extra no corpo a corpo, velocidade extra, horas de jogo de efeito].
const EFEITO := [[0.0, 0.0, 0.0], [0.3, 0.0, 4.0], [0.5, 0.2, 6.0], [0.5, 0.2, 9.0]]
const FORCA_MAX := 0.8
const VEL_MAX := 0.35


## Estágio que vale para o sangue: o da infecção, 3 para o vampiro, -1 para quem não tem por que beber.
static func estagio(j: Node) -> int:
	if str(j.raca) == "vampire":
		return 3
	return Infeccao.estagio(j)


## O alvo mais perto ao alcance: {"no", "fonte"} para beber, {"recusa": texto} se não serve, {} se não há nada.
static func alvo(j: Node) -> Dictionary:
	var pj := IsoMath.tela_para_mundo(j.global_position)
	var melhor: Dictionary = {}
	var dist := ALCANCE
	var arv := j.get_tree()
	for n in arv.get_nodes_in_group("corpo") + arv.get_nodes_in_group("errante"):
		var no := n as Node2D
		if no == null or not is_instance_valid(no):
			continue
		var d := IsoMath.tela_para_mundo(no.global_position).distance_to(pj)
		if d >= dist:
			continue
		var r := _avaliar(no)
		if r.is_empty():
			continue
		melhor = r
		dist = d
	return melhor


static func _avaliar(no: Node2D) -> Dictionary:
	if no.has_meta("sem_sangue"):
		return {"recusa": "Não sobrou sangue aí."}
	if no is Inimigo:
		var i := no as Inimigo
		if not i.morto:
			return {}
		match i.raca:
			"rat":
				return {"no": no, "fonte": "bicho", "nome": "do rato"}
			"zombie":
				return {"recusa": "O sangue dele é preto e podre. Nem a fome aceita isso."}
		return {"recusa": "Não tem sangue nele. Só pó."}
	if no is Npc:
		var p := no as Npc
		if p.morto:
			if Reputacao.agora_h() - float(no.get_meta("morte_h", -99.0)) > FRESCO_H:
				return {"recusa": "O sangue já coagulou."}
			return {"no": no, "fonte": "corpo", "nome": "de %s" % p.nome()}
		if no is Errante and (no as Errante).caido():
			return {"no": no, "fonte": "pessoa", "nome": "de %s" % p.nome()}
	return {}


## Dica do HUD perto de um alvo (só para quem já pode beber).
static func dica(j: Node) -> String:
	if estagio(j) < 1:
		return ""
	var a := alvo(j)
	if a.is_empty() and int(j.postura) == 1:
		var v := _vitima_de_pe(j)
		if v != null:
			return "%s — nocautear %s (por trás)" % [Controles.nome("morder"), v.nome()]
	if not a.has("no"):
		return ""
	return "%s — beber o sangue %s" % [Controles.nome("morder"), str(a["nome"])]


## Tecla B: bebe do alvo mais perto, se der; sem alvo, tenta nocautear um errante de pé (rapto).
static func beber(j: Node) -> void:
	var e := estagio(j)
	if e < 0:
		return
	var a := alvo(j)
	if a.is_empty() and e >= 1:
		var v := _vitima_de_pe(j)
		if v != null:
			nocautear(j, v)
			return
	if a.is_empty():
		if e >= 1:
			j.aviso("Não há sangue ao alcance.")
		return
	if a.has("recusa"):
		j.aviso(str(a["recusa"]))
		return
	if e == 0:
		j.aviso("Só de pensar, o estômago revira. Ainda não.")
		return
	var fonte := str(a["fonte"])
	var f: Dictionary = FONTES[fonte]
	var mult: float = f["mult"]
	var ef: Array = EFEITO[e]
	j.sangue_forca = maxf(float(j.sangue_forca), minf(FORCA_MAX, float(ef[0]) * mult))
	j.sangue_vel = maxf(float(j.sangue_vel), minf(VEL_MAX, float(ef[1]) * mult))
	j.sangue_t = maxf(float(j.sangue_t), float(ef[2]) * mult)
	j.vida = minf(float(j.vida_max), float(j.vida) + 10.0 * mult)
	j.fome = minf(100.0, float(j.fome) + 10.0 * mult)
	j.golpe_t = 0.3
	var no: Node2D = a["no"]
	if fonte != "pessoa":
		no.set_meta("sem_sangue", true)
	var txt: String = {"bicho": "Você bebe o sangue %s. Pouco, mas a fraqueza passa." % a["nome"],
		"corpo": "Você bebe o sangue %s. Ainda está morno. A força volta inteira." % a["nome"],
		"pessoa": "Você crava os dentes e bebe o sangue %s. Nunca se sentiu tão forte." % a["nome"]}[fonte]
	j.aviso(txt)
	if fonte == "pessoa":
		_ferir_pessoa(j, no as Errante)
	if Infeccao.ativa(j):
		j.doenca["horas"] = maxf(0.01, float(j.doenca["horas"]) - float(f["avanco_h"]))
	DiarioPartida.evento("sangue", "Bebeu o sangue %s (%s)." % [str(a["nome"]), fonte])


## Pessoa viva: fica mais fraca, lembra de você e, se alguém de uma comunidade viu, é crime grave.
static func _ferir_pessoa(j: Node, e: Errante) -> void:
	e.agente["vida"] = maxf(5.0, float(e.agente["vida"]) - 20.0)
	e.vida = maxf(2.0, e.vida - 9.0)
	e.agente["opiniao"] = int(e.agente.get("opiniao", 0)) - 80
	e.bebido = true
	e.set_meta("sem_sangue", true)            # um gole por vez: a vítima precisa de tempo
	if not e.desacordado():                   # acordado e caído: ele vê quem foi
		e.falar("Socorro! Ele bebeu o meu sangue!" if str(j.genero) == "m" else "Socorro! Ela bebeu o meu sangue!")
		if not rosto_coberto(j):
			Reputacao.boato_errante(-25, "sangue")
	Reputacao.registrar("sangue", IsoMath.tela_para_mundo(e.global_position))


# ───────────────────────────── rapto (3.2c) ─────────────────────────────

## Capuz na mochila (até existir roupa vestida): quem acorda não reconhece o rosto.
static func rosto_coberto(j: Node) -> bool:
	return Itens.DB.has("capuz") and j.inventario.contar("capuz") > 0


## Errante de pé ao alcance que dá para nocautear (não hostil, sem estar caído).
static func _vitima_de_pe(j: Node) -> Errante:
	var pj := IsoMath.tela_para_mundo(j.global_position)
	var melhor: Errante = null
	var dist := ALCANCE
	for n in j.get_tree().get_nodes_in_group("errante"):
		var e := n as Errante
		if e == null or e.morto or e.caido() or e.hostil():
			continue
		var d := IsoMath.tela_para_mundo(e.global_position).distance_to(pj)
		if d < dist:
			dist = d
			melhor = e
	return melhor


## Golpe na nuca: só agachado e por trás (de frente ele te vê e se defende).
static func nocautear(j: Node, e: Errante) -> void:
	var para_jogador := IsoMath.tela_para_mundo(j.global_position - e.global_position).normalized()
	var olhar: Vector2 = e._olhar.normalized() if e._olhar.length() > 0.01 else Vector2.DOWN
	if int(j.postura) != 1 or olhar.dot(para_jogador) > -0.2:
		j.aviso("%s vai te ver. Chegue por trás, agachado." % e.nome())
		return
	e.nocautear()
	j.golpe_t = 0.3
	j.aviso("Um golpe na nuca, e %s cai desacordado. %s arrasta, %s bebe." % [e.nome(), Controles.nome("interact"),
		Controles.nome("morder")])
	Reputacao.registrar("agressao", IsoMath.tela_para_mundo(e.global_position))
	DiarioPartida.evento("rapto", "Nocauteou %s." % e.nome())


## E no desacordado: começa ou para de arrastar.
static func arrastar(j: Node, e: Errante) -> void:
	if e.arrastado_por != null:
		e.arrastado_por = null
		j.carregando = null
		j.aviso("Você solta %s." % e.nome())
		return
	if j.carregando != null and is_instance_valid(j.carregando):
		j.carregando.arrastado_por = null
	e.arrastado_por = j
	j.carregando = e
	j.set_meta("rapto_visto", false)
	j.aviso("Você arrasta %s. Devagar, e sem correr." % e.nome())


## Enquanto arrasta: se alguém de uma comunidade vir, é crime (uma vez por arrasto).
static func vigiar_arrasto(j: Node) -> void:
	var e: Errante = j.carregando
	if e == null or not is_instance_valid(e) or not e.desacordado():
		j.carregando = null
		return
	if bool(j.get_meta("rapto_visto", false)):
		return
	var p := IsoMath.tela_para_mundo(e.global_position)
	for n in j.get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc != null and not npc.morto and npc.comunidade != "" and not npc.dormindo and Reputacao._viu(npc, j, p):
			j.set_meta("rapto_visto", true)
			Reputacao.registrar("rapto", p)
			return


## Da Sede em diante: o cheiro de sangue fresco mais perto (corpo ou gente caída), para o aviso do jogador.
## Devolve {"no", "dist", "rumo"} ou {}.
static func farejar(j: Node) -> Dictionary:
	if estagio(j) < 2:
		return {}
	var pj := IsoMath.tela_para_mundo(j.global_position)
	var melhor: Dictionary = {}
	var dist := FAREJA
	var arv := j.get_tree()
	for n in arv.get_nodes_in_group("corpo") + arv.get_nodes_in_group("errante"):
		var no := n as Node2D
		if no == null or not is_instance_valid(no):
			continue
		var r := _avaliar(no)
		if not r.has("no") or str(r["fonte"]) == "bicho":
			continue
		var d := IsoMath.tela_para_mundo(no.global_position).distance_to(pj)
		if d < dist and d > ALCANCE * 2.0:
			dist = d
			melhor = {"no": no, "dist": d, "rumo": _rumo(no.global_position - j.global_position)}
	return melhor


## "ao norte", "a sudeste"... pela direção na tela (norte = para cima).
static func _rumo(v: Vector2) -> String:
	var nomes := ["a leste", "a sudeste", "ao sul", "a sudoeste", "a oeste", "a noroeste", "ao norte", "a nordeste"]
	var i := wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)
	return nomes[i]
