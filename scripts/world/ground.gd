extends Node2D
## Chão da cena de teste: grama e estrada HD (texturas vistas de cima) projetadas
## em isométrico 2:1. As texturas vêm de tools/preparar_chao_hd.py e se repetem sem emenda.
## Provisório — será trocado pelo mapa real nas próximas fases.

@export var grama: Texture2D
@export var estrada: Texture2D
@export var raio: float = 1500.0              ## alcance do chão, em unidades de mundo, para cada lado
@export var unidades_por_px: float = 2.0      ## tamanho no mundo de cada px da textura
@export var estrada_x: float = 30.0           ## x de mundo da borda esquerda da faixa da estrada (ela corre no eixo Y)


func _draw() -> void:
	draw_set_transform_matrix(IsoMath.ISO)
	if grama:
		var t := grama.get_size() * unidades_por_px
		var x := -ceilf(raio / t.x) * t.x
		while x < raio:
			var y := -ceilf(raio / t.y) * t.y
			while y < raio:
				draw_texture_rect(grama, Rect2(x, y, t.x, t.y), false)
				y += t.y
			x += t.x
	if estrada:
		var e := estrada.get_size() * unidades_por_px
		var ye := -ceilf(raio / e.y) * e.y
		while ye < raio:
			draw_texture_rect(estrada, Rect2(estrada_x, ye, e.x, e.y), false)
			ye += e.y
