class_name Cacto
extends StaticBody2D
## Cacto desenhado por código (não há arte de cacto no projeto). Três variantes; colide como um pilar.

@export var variante: int = 0


func _ready() -> void:
	light_mask = 2
	var forma := CollisionShape2D.new()
	var s := ConvexPolygonShape2D.new()
	s.points = PackedVector2Array([Vector2(0, 0), Vector2(-13, -6.5), Vector2(0, -13), Vector2(13, -6.5)])
	forma.shape = s
	add_child(forma)


func _poli(pts: Array, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), cor)


func _draw() -> void:
	var h: float = [74.0, 54.0, 90.0][variante % 3]
	var verde := Color(0.27, 0.47, 0.23)
	var escuro := Color(0.17, 0.33, 0.16)
	var claro := Color(0.40, 0.60, 0.30)
	# sombra no chão
	var sombra := PackedVector2Array()
	for i in 12:
		sombra.append(Vector2.from_angle(TAU * i / 12.0) * Vector2(24.0, 11.0))
	draw_colored_polygon(sombra, Color(0, 0, 0, 0.22))
	# braços (atrás do tronco)
	if variante != 1:
		_braco(-1.0, h * 0.50, verde, escuro)
	if variante == 2:
		_braco(1.0, h * 0.62, verde, escuro)
	# tronco: caixa com topo arredondado e lado de sombra
	draw_rect(Rect2(-9, -h, 18, h), verde)
	draw_circle(Vector2(0, -h), 9.0, verde)
	draw_rect(Rect2(2, -h, 7, h), escuro)
	draw_rect(Rect2(-5, -h, 3, h), claro)
	for k in 5:
		var y := -h * (0.15 + 0.17 * k)
		draw_line(Vector2(-12, y), Vector2(-9, y - 3), Color(0.9, 0.9, 0.7, 0.8), 1.0)
		draw_line(Vector2(12, y - 6), Vector2(9, y - 9), Color(0.9, 0.9, 0.7, 0.8), 1.0)
	if variante == 0:
		draw_circle(Vector2(0, -h - 7), 3.0, Color(0.9, 0.35, 0.5))


func _braco(lado: float, alt: float, verde: Color, escuro: Color) -> void:
	var x0: float = lado * 9.0
	var x1: float = lado * 25.0
	draw_rect(Rect2(minf(x0, x1), -alt - 8.0, absf(x1 - x0), 9.0), verde)
	draw_rect(Rect2(x1 - 4.5, -alt - 36.0, 9.0, 37.0), verde)
	draw_circle(Vector2(x1, -alt - 36.0), 4.5, verde)
	draw_rect(Rect2(x1 + (0.0 if lado > 0.0 else -4.5) , -alt - 36.0, 4.5, 37.0), escuro)
