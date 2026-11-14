class_name AbrigoNo
extends Node2D
## Abrigo básico do totem: cabana simples (3 × 2,4 m) desenhada com polígonos, sem colisão (como na V13).

const M := IsoMath.METRO
const VPM := 30.3


func _ready() -> void:
	y_sort_enabled = true
	light_mask = 2
	queue_redraw()


func _p(x: float, y: float, z: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) - Vector2(0.0, z)


func _draw() -> void:
	var x0 := -1.5 * M
	var x1 := 1.5 * M
	var y0 := -1.2 * M
	var y1 := 1.2 * M
	var h := 1.7 * VPM
	var cume := h + 0.7 * VPM
	var madeira := Color8(112, 86, 62)
	draw_colored_polygon(PackedVector2Array([_p(x0, y1, 0), _p(x1, y1, 0), _p(x1, y1, h), _p(x0, y1, h)]), madeira.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([_p(x1, y1, 0), _p(x1, y0, 0), _p(x1, y0, h), _p(x1, y1, h)]), madeira.darkened(0.38))
	# empena (triângulo) na face leste e duas águas de lona
	draw_colored_polygon(PackedVector2Array([_p(x1, y0, h), _p(x1, y1, h), _p(x1, 0.0, cume)]), madeira.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([_p(x0, y1, h), _p(x1, y1, h), _p(x1, 0.0, cume), _p(x0, 0.0, cume)]), Color8(92, 100, 84))
	draw_colored_polygon(PackedVector2Array([_p(x0, 0.0, cume), _p(x1, 0.0, cume), _p(x1, y0, h), _p(x0, y0, h)]), Color8(74, 82, 68))
	# porta escura na face sul
	draw_colored_polygon(PackedVector2Array([_p(-0.35 * M, y1, 0), _p(0.35 * M, y1, 0), _p(0.35 * M, y1, 1.5 * VPM), _p(-0.35 * M, y1, 1.5 * VPM)]), Color8(30, 26, 22))
