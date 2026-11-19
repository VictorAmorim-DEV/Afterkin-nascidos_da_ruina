class_name MuralNo
extends Node2D
## Mural de recados da praça de uma comunidade (Rumores, Q47): uma tábua em dois mourões com papéis pregados.
## E perto dele abre a MuralUI: pedidos, avisos, desaparecidos, quem morreu e as novidades da comunidade.

const ALCANCE := 1.8 * IsoMath.METRO
const VPM := 30.3

var comunidade: String = ""


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("mural")
	y_sort_enabled = true
	light_mask = 2
	queue_redraw()


func _draw() -> void:
	var madeira := Color8(104, 78, 54)
	for x in [-30.0, 30.0]:
		draw_rect(Rect2(Vector2(x - 2.5, -1.9 * VPM), Vector2(5, 1.9 * VPM)), madeira.darkened(0.25))
	draw_rect(Rect2(Vector2(-38, -2.0 * VPM), Vector2(76, 0.95 * VPM)), madeira)
	draw_rect(Rect2(Vector2(-38, -2.0 * VPM), Vector2(76, 0.95 * VPM)), madeira.darkened(0.4), false, 1.5)
	var papeis := [[-31, -56, 14, 17, Color8(232, 226, 204)], [-14, -58, 12, 14, Color8(240, 236, 220)],
		[0, -55, 15, 18, Color8(226, 214, 180)], [18, -57, 13, 15, Color8(236, 230, 214)]]
	for pp in papeis:
		draw_rect(Rect2(Vector2(pp[0], pp[1]), Vector2(pp[2], pp[3])), pp[4])
	draw_colored_polygon(PackedVector2Array([Vector2(-34, 2), Vector2(34, 2), Vector2(26, 6), Vector2(-26, 6)]), Color(0, 0, 0, 0.25))


func _dist() -> float:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	return INF if j == null else IsoMath.tela_para_mundo(j.global_position - global_position).length()


func prioridade_interacao() -> int:
	return 5


func texto_interacao() -> String:
	return "E — ler o mural" if _dist() < ALCANCE else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _dist() > ALCANCE:
		return
	if get_tree().get_first_node_in_group("janela_jogo") != null:
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	var ui := MuralUI.new()
	ui.mural = self
	get_tree().current_scene.add_child(ui)
