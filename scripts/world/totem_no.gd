class_name TotemNo
extends Node2D
## Totem no chão: o ícone do totem em pé e o anel do território (círculo do mundo projetado em isométrico).

var alcance: float = 170.0:
	set(v):
		alcance = v
		queue_redraw()

var _anel := Node2D.new()


func _ready() -> void:
	y_sort_enabled = true
	_anel.z_index = -1                         # acima do chão, abaixo dos objetos em pé
	_anel.draw.connect(_desenhar_anel)
	add_child(_anel)
	var s := Sprite2D.new()
	s.texture = Itens.icone("totem")
	s.scale = Vector2.ONE * 0.8
	s.position = Vector2(0, -34)
	s.light_mask = 2
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	_anel.queue_redraw()


func _desenhar_anel() -> void:
	var pts := PackedVector2Array()
	for k in 48:
		var a := TAU * k / 48.0
		pts.append(IsoMath.mundo_para_tela(Vector2.from_angle(a) * alcance))
	_anel.draw_colored_polygon(pts, Color(0.41, 0.65, 1.0, 0.09))
	pts.append(pts[0])
	_anel.draw_polyline(pts, Color(0.51, 0.71, 1.0, 0.7), 2.0)
