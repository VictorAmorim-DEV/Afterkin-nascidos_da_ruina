class_name Desenho
extends Node2D
## Nó que acumula polígonos e linhas e desenha tudo num único _draw().
## Substitui um Polygon2D por face nos edifícios: criar milhares de nós custava ~17 µs cada
## (um hospital de 4 andares tinha 3200 nós e levava 54 ms para entrar na árvore).
## A ordem de desenho é a ordem em que as peças foram adicionadas; modulate/visible valem para o conjunto.

var _polis: Array = []        ## [PackedVector2Array, Color]
var _linhas: Array = []       ## [PackedVector2Array, Color, largura]
var _pendente := false


func _init() -> void:
	light_mask = 2


func poli(pts: PackedVector2Array, cor: Color) -> void:
	if pts.size() < 3 or cor.a <= 0.0:
		return
	_polis.append([pts, cor])
	if not _pendente:
		_pendente = true
		queue_redraw()


func linha(pts: PackedVector2Array, cor: Color, largura: float = 1.0) -> void:
	_linhas.append([pts, cor, largura])
	if not _pendente:
		_pendente = true
		queue_redraw()


func _draw() -> void:
	_pendente = false
	for p in _polis:
		draw_colored_polygon(p[0], p[1])
	for l in _linhas:
		draw_polyline(l[0], l[1], l[2])
