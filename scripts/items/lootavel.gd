class_name Lootavel
extends Node2D
## Recipiente solto no cenário (caixote, entulho/sucata). Vasculha uma vez com E.
## Tabelas da V13: "caixa" (madeira e sucata) e "scrap" (sucata). Veículos não são
## lootáveis na V13, então ficam de fora.

@export_enum("caixa", "scrap") var tipo: String = "caixa"
@export var alcance_m: float = 1.6
var usado: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("lootavel")
	_rng.randomize()


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func _dist() -> float:
	var j := _jogador()
	if j == null:
		return INF
	return IsoMath.tela_para_mundo(global_position - j.global_position).length()


func _e_o_alvo() -> bool:
	if usado or _dist() > alcance_m * IsoMath.METRO:
		return false
	var d := _dist()
	for o in get_tree().get_nodes_in_group("lootavel"):
		if o != self and not o.usado and o._dist() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 5


func texto_interacao() -> String:
	return "E — vasculhar %s" % Itens.CONTEM[tipo] if _e_o_alvo() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	if get_tree().get_nodes_in_group("item_chao").any(func(i): return i.texto_interacao() != ""):
		return                                   # item no chão tem prioridade
	var j := _jogador()
	if j == null or not "inventario" in j:
		return
	get_viewport().set_input_as_handled()
	Loot.vasculhar(j, tipo, _rng, func(): usado = true)
