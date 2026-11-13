extends Node2D
## Chão de teste: desenha os tiles (quadrados, 128 px) projetados em isométrico 2:1,
## como o protótipo fazia. Provisório — será trocado pelo mapa real nas próximas fases.

@export var tiles: Texture2D
@export var raio: int = 14                 ## tamanho do chão, em tiles, para cada lado

const ORIGEM := 128.0                      ## tamanho de cada tile na imagem
const GRAMA := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const ASFALTO := [Vector2i(6, 1), Vector2i(6, 1), Vector2i(7, 1)]
const CALCADA := [Vector2i(5, 1), Vector2i(4, 1)]


func _draw() -> void:
	if tiles == null:
		return
	draw_set_transform_matrix(IsoMath.ISO)
	var t := IsoMath.TILE
	for y in range(-raio, raio):
		for x in range(-raio, raio):
			var lista := GRAMA
			if y >= 3 and y <= 5:
				lista = ASFALTO
			elif y == 2 or y == 6:
				lista = CALCADA
			var c: Vector2i = lista[absi(x * 73 + y * 151 + x * y * 7) % lista.size()]
			var origem := Rect2(c.x * ORIGEM + 0.5, c.y * ORIGEM + 0.5, ORIGEM - 1.0, ORIGEM - 1.0)
			draw_texture_rect_region(tiles, Rect2(x * t, y * t, t + 0.5, t + 0.5), origem)
