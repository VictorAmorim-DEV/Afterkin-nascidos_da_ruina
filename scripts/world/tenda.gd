class_name Tenda
extends StaticBody2D
## Barraca de acampamento (prisma triangular em isométrico) desenhada por código. Colide na base.

@export var cor: int = 0
const W := 150.0        ## comprimento (eixo x do mundo)
const D := 120.0        ## largura (eixo y do mundo)
const H := 62.0         ## altura da cumeeira, em px de tela


func _ready() -> void:
	light_mask = 2
	var forma := CollisionShape2D.new()
	var s := ConvexPolygonShape2D.new()
	s.points = PackedVector2Array([_p(-W / 2, -D / 2, 0), _p(W / 2, -D / 2, 0), _p(W / 2, D / 2, 0), _p(-W / 2, D / 2, 0)])
	forma.shape = s
	add_child(forma)


static func _p(x: float, y: float, alt: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) + Vector2(0, -alt)


func _draw() -> void:
	var tecido: Array = [Color(0.31, 0.43, 0.24), Color(0.58, 0.38, 0.22), Color(0.42, 0.47, 0.52)]
	var c: Color = tecido[cor % 3]
	var sombra := PackedVector2Array([_p(-W / 2 - 10, -D / 2 - 10, 0), _p(W / 2 + 10, -D / 2 - 10, 0),
		_p(W / 2 + 10, D / 2 + 10, 0), _p(-W / 2 - 10, D / 2 + 10, 0)])
	draw_colored_polygon(sombra, Color(0, 0, 0, 0.2))
	# água do telhado voltada para +y (a que a câmera vê) e empena do lado +x
	draw_colored_polygon(PackedVector2Array([_p(-W / 2, D / 2, 0), _p(W / 2, D / 2, 0), _p(W / 2, 0, H), _p(-W / 2, 0, H)]), c)
	draw_colored_polygon(PackedVector2Array([_p(W / 2, -D / 2, 0), _p(W / 2, D / 2, 0), _p(W / 2, 0, H)]), c.darkened(0.3))
	# porta escura na empena e costura da cumeeira
	draw_colored_polygon(PackedVector2Array([_p(W / 2, -D / 6, 0), _p(W / 2, D / 6, 0), _p(W / 2, 0, H * 0.55)]), Color(0.08, 0.07, 0.06))
	draw_line(_p(-W / 2, 0, H), _p(W / 2, 0, H), c.lightened(0.25), 2.0)
	for k in 3:
		var x: float = -W / 2 + W * (k + 1) / 4.0
		draw_line(_p(x, D / 2, 0), _p(x, 0, H), c.darkened(0.18), 1.5)
