class_name Desenho
extends Node2D
## Nó que acumula polígonos e linhas e desenha tudo de uma vez.
## Substitui um Polygon2D por face nos edifícios: criar milhares de nós custava ~17 µs cada
## (um hospital de 4 andares tinha 3200 nós e levava 54 ms para entrar na árvore).
## Os polígonos são triangulados ao entrar e viram UM array de triângulos com cor por vértice: um comando
## de desenho por nó. Com um draw_colored_polygon por face, a cidade passava de 4000 draw calls por quadro.
## A ordem de desenho é a ordem em que as peças foram adicionadas; modulate/visible valem para o conjunto.

var _pts := PackedVector2Array()
var _cores := PackedColorArray()
var _idx := PackedInt32Array()
var _linhas: Array = []       ## [PackedVector2Array, Color, largura]
var _pendente := false


func _init() -> void:
	light_mask = 2


func poli(pts: PackedVector2Array, cor: Color) -> void:
	if pts.size() < 3 or cor.a <= 0.0:
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return                                        # degenerado (área zero): não aparece mesmo
	var base := _pts.size()
	_pts.append_array(pts)
	for k in pts.size():
		_cores.append(cor)
	for i in tri:
		_idx.append(base + i)
	_marcar()


func linha(pts: PackedVector2Array, cor: Color, largura: float = 1.0) -> void:
	_linhas.append([pts, cor, largura])
	_marcar()


## Retângulo na tela (no espaço do pai) que os polígonos deste nó ocupam.
func caixa() -> Rect2:
	if _pts.is_empty():
		return Rect2(position, Vector2.ZERO)
	var r := Rect2(_pts[0], Vector2.ZERO)
	for p in _pts:
		r = r.expand(p)
	return Rect2(position + r.position, r.size)


func _marcar() -> void:
	if not _pendente:
		_pendente = true
		queue_redraw()


func _draw() -> void:
	_pendente = false
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cores)
	for l in _linhas:
		draw_polyline(l[0], l[1], l[2])
