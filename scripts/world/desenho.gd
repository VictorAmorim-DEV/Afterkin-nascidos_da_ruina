class_name Desenho
extends Node2D
## Nó que acumula polígonos e linhas e desenha tudo de uma vez.
## Substitui um Polygon2D por face nos edifícios: criar milhares de nós custava ~17 µs cada
## (um hospital de 4 andares tinha 3200 nós e levava 54 ms para entrar na árvore).
## Os polígonos são triangulados ao entrar e viram UM array de triângulos com cor por vértice: um comando
## de desenho por nó. Com um draw_colored_polygon por face, a cidade passava de 4000 draw calls por quadro.
## A ordem de desenho é a ordem em que as peças foram adicionadas; modulate/visible valem para o conjunto.
## Tudo sai com o atlas de materiais (TexturasParede, com normal map: relevo na luz da lanterna): peças com material
## usam poli_uv; as outras, o texel branco.

var _pts := PackedVector2Array()
var _cores := PackedColorArray()
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()
var _linhas: Array = []       ## [PackedVector2Array, Color, largura]
var _pendente := false


func _init() -> void:
	light_mask = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR     # o atlas é reduzido na tela: sem filtro, cintila


func poli(pts: PackedVector2Array, cor: Color) -> void:
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	uvs.fill(TexturasParede.uv_branco())
	poli_uv(pts, uvs, cor)


## Polígono com coordenadas de textura no atlas de materiais (uma por ponto).
func poli_uv(pts: PackedVector2Array, uvs: PackedVector2Array, cor: Color) -> void:
	if pts.size() < 3 or cor.a <= 0.0:
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return                                        # degenerado (área zero): não aparece mesmo
	var base := _pts.size()
	_pts.append_array(pts)
	_uvs.append_array(uvs)
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
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cores, _uvs,
			PackedInt32Array(), PackedFloat32Array(), TexturasParede.atlas_relevo().get_rid())
	for l in _linhas:
		draw_polyline(l[0], l[1], l[2])
