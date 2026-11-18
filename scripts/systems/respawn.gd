class_name Respawn
extends RefCounted
## Camas, mochila deixada no corpo e renascimento (docs/DECISOES_DESIGN.md, Q51, Q55 e Q56).
##
## - A cama é fabricada e montada num lugar coberto (dentro de um prédio ou do abrigo); pode haver até MAX_CAMAS.
## - Ao morrer (humano), a mochila inteira fica no chão onde o corpo caiu e abre a TelaRespawn: renasce numa das
##   suas camas ou num dos lugares de início (Inicio, casa sorteada). Comunidade não é ponto de respawn.
## - A morte infectada (acordar transformado) fica para o marco 3.
## Estado estático, como o Descobertas: zera no começo de partida e vai para o SaveJogo.

const MAX_CAMAS := 5
const ALCANCE_ABRIGO := 2.6 * IsoMath.METRO     ## montar a cama "dentro" do abrigo do totem

## [{"p": Vector2 (mundo), "nome": String, "no": CamaNo}]
static var camas: Array = []


## Começo de partida: sem camas nem mochilas (os nós da partida anterior foram junto com a cena).
static func zerar() -> void:
	camas = []


# ───────────────────────────── camas ─────────────────────────────

## Monta a cama do slot 'slot' onde o jogador está, se for um lugar coberto.
static func colocar_cama(j: Node, slot: int) -> void:
	if j.dirigindo != null:
		return
	if not _coberto(j):
		j.aviso("A cama precisa ficar num lugar coberto: dentro de uma casa ou do seu abrigo.")
		return
	_limpar_camas()
	if camas.size() >= MAX_CAMAS:
		j.aviso("Você já tem %d camas. Recolha uma (E perto dela) antes de montar outra." % MAX_CAMAS)
		return
	var p := IsoMath.tela_para_mundo(j.global_position)
	for c in camas:
		if (c["p"] as Vector2).distance_to(p) < 1.5 * IsoMath.METRO:
			j.aviso("Já existe uma cama aqui.")
			return
	j.inventario.retirar(slot, 1)
	_criar(j.get_parent(), p)
	j.aviso("Cama montada %s. Se morrer, você pode renascer aqui." % nome_do_lugar(p))


static func _coberto(j: Node) -> bool:
	if j._dentro_de_casa():
		return true
	var t: Territorio = j.territorio
	if t._no_abrigo != null and is_instance_valid(t._no_abrigo):
		return IsoMath.tela_para_mundo(t._no_abrigo.global_position - j.global_position).length() < ALCANCE_ABRIGO
	return false


static func _criar(pai: Node, p: Vector2) -> void:
	var no := CamaNo.new()
	pai.add_child(no)
	no.global_position = IsoMath.mundo_para_tela(p)
	camas.append({"p": p, "nome": nome_do_lugar(p), "no": no})


## Recolhe a cama do nó 'no' de volta para a mochila do jogador.
static func recolher(j: Node, no: Node) -> void:
	if j.inventario.adicionar_parcial("cama", 1) > 0:
		j.aviso("Mochila cheia! Libere um espaço para recolher a cama.")
		return
	for i in range(camas.size() - 1, -1, -1):
		if camas[i]["no"] == no:
			camas.remove_at(i)
	no.queue_free()
	j.aviso("Cama recolhida para a mochila.")


static func _limpar_camas() -> void:
	camas = camas.filter(func(c): return is_instance_valid(c["no"]))


## "em Porto Atlântico" / "perto de Areal": o lugar com nome mais próximo do ponto (mundo).
static func nome_do_lugar(p: Vector2) -> String:
	var melhor := ""
	var dist := INF
	var lugares: Array = []
	for a in MundoGen.AREAS.size():
		lugares.append([str(MundoGen.AREAS[a]["nome"]), MundoGen.area_rect(a)])
	for v in MundoGen.aldeias():
		lugares.append([str((v as Dictionary)["nome"]), (v as Dictionary)["area"]])
	for c in MundoGen.acampamentos():
		var cc: Vector2 = (c as Dictionary)["c"]
		lugares.append([str((c as Dictionary)["nome"]), Rect2(cc - Vector2(900, 900), Vector2(1800, 1800))])
	for l in lugares:
		var r: Rect2 = l[1]
		if r.has_point(p):
			return "em %s" % l[0]
		var d := r.get_center().distance_to(p)
		if d < dist:
			dist = d
			melhor = l[0]
	return "perto de %s" % melhor if melhor != "" else "no meio do nada"


# ───────────────────────────── morte e renascimento ─────────────────────────────

## Deixa a mochila inteira no chão, onde o corpo caiu. Devolve quantos itens ficaram.
static func largar_mochila(j: Node) -> int:
	var slots: Array = j.inventario.slots.map(func(x): return null if x == null else (x as Dictionary).duplicate())
	var n := slots.filter(func(x): return x != null).size()
	if n > 0:
		MochilaNoChao.largar(j.get_parent(), IsoMath.tela_para_mundo(j.global_position), slots)
	j.inventario.slots.fill(null)
	j.inventario.equipado = -1
	j.inventario.mudou.emit()
	return n


## Renasce na cama de índice 'i' (de 'camas'). Devolve a frase para o aviso.
static func renascer_na_cama(arvore: SceneTree, i: int) -> String:
	_limpar_camas()
	if i < 0 or i >= camas.size():
		return ""
	var p: Vector2 = camas[i]["p"] + Vector2(0.0, 0.9 * IsoMath.METRO)
	Inicio.zona_segura = Rect2()
	_levar(arvore, p)
	return "Você acorda na sua cama, %s." % str(camas[i]["nome"])


## Renasce numa casa sorteada do lugar de início 'id' (Inicio). Devolve a frase para o aviso.
static func renascer_no_lugar(arvore: SceneTree, id: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := Inicio.achar(id, rng)
	if a.is_empty():
		return ""
	Inicio.zona_segura = a["zona"]
	_levar(arvore, a["p"])
	return "Você acorda %s." % str(a["onde"])


static func _levar(arvore: SceneTree, p: Vector2) -> void:
	var j := arvore.get_first_node_in_group("jogador")
	if j != null:
		j.renascer()
	var mundo := arvore.get_first_node_in_group("mundo")
	if mundo != null and mundo.has_method("teleportar"):
		mundo.teleportar(p)


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar(arvore: SceneTree) -> Dictionary:
	_limpar_camas()
	var lc: Array = []
	for c in camas:
		var p: Vector2 = c["p"]
		lc.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var lm: Array = []
	for m in arvore.get_nodes_in_group("mochila_chao"):
		var p := IsoMath.tela_para_mundo((m as Node2D).global_position)
		lm.append({"p": [snappedf(p.x, 0.1), snappedf(p.y, 0.1)], "slots": (m as MochilaNoChao).slots.duplicate(true)})
	return {"camas": lc, "mochilas": lm}


static func restaurar(arvore: SceneTree, d: Dictionary) -> void:
	zerar()
	var j := arvore.get_first_node_in_group("jogador")
	if j == null:
		return
	for c in d.get("camas", []):
		var l: Array = c
		_criar(j.get_parent(), Vector2(float(l[0]), float(l[1])))
	for m in d.get("mochilas", []):
		var md: Dictionary = m
		var pl: Array = md["p"]
		MochilaNoChao.largar(j.get_parent(), Vector2(float(pl[0]), float(pl[1])), SaveJogo.slots_de(md.get("slots", [])))
