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
	for n in arv.get_nodes_in_group("corpo") + arv.get_nodes_in_group("npc"):
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
		if p.desacordado() or (no is Errante and (no as Errante).caido()):
			return {"no": no, "fonte": "pessoa", "nome": "de %s" % p.nome()}
	return {}


## Dica do HUD perto de um alvo (só para quem já pode beber).
static func dica(j: Node) -> String:
	if estagio(j) < 1:
		return ""
	var a := alvo(j)
	if a.is_empty():
		var dormindo := _dormindo_perto(j)
		if dormindo != null:
			return "%s — pegar %s dormindo" % [Controles.nome("morder"), dormindo.nome()]
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
		var dormindo := _dormindo_perto(j)
		if dormindo != null:
			if dormindo.tentar_captura(j):
				j.golpe_t = 0.3
				j.aviso("%s nem acordou. Está desacordado: %s arrasta, %s bebe." % [dormindo.nome(),
					Controles.nome("interact"), Controles.nome("morder")])
				DiarioPartida.evento("rapto", "Pegou %s dormindo." % dormindo.nome())
			return
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
		_ferir_pessoa(j, no as Npc)
	if Infeccao.ativa(j):
		j.doenca["horas"] = maxf(0.01, float(j.doenca["horas"]) - float(f["avanco_h"]))
	DiarioPartida.evento("sangue", "Bebeu o sangue %s (%s)." % [str(a["nome"]), fonte])


## Pessoa viva: fica mais fraca, lembra de você e, se alguém de uma comunidade viu, é crime grave.
static func _ferir_pessoa(j: Node, e: Npc) -> void:
	e.vida = maxf(2.0, e.vida - 9.0)
	if e is Errante:
		var er := e as Errante
		er.agente["vida"] = maxf(5.0, float(er.agente["vida"]) - 20.0)
		er.agente["opiniao"] = int(er.agente.get("opiniao", 0)) - 80
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


## Morador dormindo ao alcance (na cama ou na entrada da barraca).
static func _dormindo_perto(j: Node) -> Npc:
	var pj := IsoMath.tela_para_mundo(j.global_position)
	var melhor: Npc = null
	var dist := ALCANCE
	for n in j.get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.morto or not npc.dormindo or npc.fora:
			continue
		var d := IsoMath.tela_para_mundo(npc.global_position).distance_to(pj)
		if d < dist:
			dist = d
			melhor = npc
	return melhor


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


## E no desacordado ou num corpo: começa ou para de arrastar.
static func arrastar(j: Node, no: Node2D) -> void:
	var nome_no: String = no.call("nome") if no.has_method("nome") else "o corpo"
	if j.carregando == no:
		_largar(j)
		j.aviso("Você solta %s." % nome_no)
		return
	_largar(j)
	j.carregando = no
	if no is Npc:
		(no as Npc).arrastado_por = j
	j.set_meta("rapto_visto", false)
	j.aviso("Você arrasta %s. Devagar, e sem correr." % ("o corpo de " + nome_no if no.is_in_group("corpo") else nome_no))


static func _largar(j: Node) -> void:
	var c: Node2D = j.carregando
	if c != null and is_instance_valid(c) and c is Npc:
		(c as Npc).arrastado_por = null
	j.carregando = null


## O que está sendo arrastado ainda pode ser arrastado (corpo, ou alguém ainda desacordado)?
static func arrastavel(no: Node2D) -> bool:
	if no == null or not is_instance_valid(no) or no.is_queued_for_deletion():
		return false
	if no is Npc:
		return (no as Npc).morto or (no as Npc).desacordado()
	return no.is_in_group("corpo")


## Enquanto arrasta: se alguém de uma comunidade vir, é crime (uma vez por arrasto).
static func vigiar_arrasto(j: Node) -> void:
	var e: Node2D = j.carregando
	if not arrastavel(e):
		_largar(j)
		return
	if bool(j.get_meta("rapto_visto", false)):
		return
	var p := IsoMath.tela_para_mundo(e.global_position)
	for n in j.get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc != null and npc != e and not npc.morto and npc.comunidade != "" and not npc.dormindo \
				and not npc.desacordado() and Reputacao._viu(npc, j, p):
			j.set_meta("rapto_visto", true)
			Reputacao.registrar("corpo" if e.is_in_group("corpo") else "rapto", p)
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
	for n in arv.get_nodes_in_group("corpo") + arv.get_nodes_in_group("npc"):
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
