class_name CamaNo
extends Node2D
## Cama montada pelo jogador (Respawn): estrado de madeira com colchão de pano, 1 × 2 m, desenhada com polígonos e
## sem colisão (como o abrigo). Ponto de renascimento; E perto dela recolhe de volta para a mochila.

const M := IsoMath.METRO
const VPM := 30.3                     ## px de tela por metro de altura (o mesmo do AbrigoNo)
const ALCANCE := 1.6 * IsoMath.METRO


func _ready() -> void:
	y_sort_enabled = true
	light_mask = 2
	add_to_group("interativo")
	add_to_group("cama")
	queue_redraw()


func _p(x: float, y: float, z: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) - Vector2(0.0, z)


## Caixa (x0..x1, y0..y1, z0..z1, em m e px de altura) com topo e as duas faces visíveis (sul e leste).
func _caixa(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_p(x0, y1, z0), _p(x1, y1, z0), _p(x1, y1, z1), _p(x0, y1, z1)]), cor.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([_p(x1, y1, z0), _p(x1, y0, z0), _p(x1, y0, z1), _p(x1, y1, z1)]), cor.darkened(0.42))
	draw_colored_polygon(PackedVector2Array([_p(x0, y0, z1), _p(x1, y0, z1), _p(x1, y1, z1), _p(x0, y1, z1)]), cor)


func _draw() -> void:
	var x0 := -0.5 * M
	var x1 := 0.5 * M
	var y0 := -1.0 * M
	var y1 := 1.0 * M
	# sombra de contato
	draw_colored_polygon(PackedVector2Array([_p(x0 - 6, y0 - 6, 0), _p(x1 + 6, y0 - 6, 0), _p(x1 + 6, y1 + 6, 0),
		_p(x0 - 6, y1 + 6, 0)]), Color(0, 0, 0, 0.3))
	var madeira := Color8(118, 88, 60)
	_caixa(x0, x1, y0, y1, 0.0, 0.22 * VPM, madeira)                                   # estrado
	_caixa(x0 - 2.0, x1 + 2.0, y0 - 6.0, y0 + 4.0, 0.0, 0.75 * VPM, madeira.darkened(0.1))   # cabeceira (norte)
	_caixa(x0 + 3.0, x1 - 3.0, y0 + 6.0, y1 - 3.0, 0.22 * VPM, 0.4 * VPM, Color8(150, 138, 112))   # colchão de pano
	_caixa(x0 + 7.0, x1 - 7.0, y0 + 9.0, y0 + 0.45 * M, 0.4 * VPM, 0.52 * VPM, Color8(196, 190, 172))   # travesseiro
	_caixa(x0 + 3.0, x1 - 3.0, y0 + 0.9 * M, y1 - 3.0, 0.4 * VPM, 0.46 * VPM, Color8(86, 96, 118))       # cobertor


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func _dist() -> float:
	var j := _jogador()
	if j == null:
		return INF
	return IsoMath.tela_para_mundo(global_position - j.global_position).length()


func _e_o_alvo() -> bool:
	var d := _dist()
	if d > ALCANCE:
		return false
	for o in get_tree().get_nodes_in_group("cama"):
		if o != self and o._dist() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 4


func texto_interacao() -> String:
	return "E — recolher a cama" if _e_o_alvo() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	if get_tree().get_nodes_in_group("item_chao").any(func(i): return i.texto_interacao() != ""):
		return                                   # item no chão tem prioridade
	var j := _jogador()
	if j == null or not "inventario" in j or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	Respawn.recolher(j, self)
