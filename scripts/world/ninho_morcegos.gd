class_name NinhoMorcegos
extends StaticBody2D
## Ninho de morcegos (RECURSO NOVO: a V13 só cita "encontre um antídoto em ninhos de morcegos"): toca de pedra na
## mata fechada, com guano escorrendo e morcegos voando em volta. Vasculhar dá o antídoto da mutação vampírica
## (Lootavel "ninho"); vazio, os morcegos vão embora. Desenhado em código; origem = centro da base no chão.

const M := IsoMath.METRO
const VPM := 30.3
const RAIO := 1.6 * M                       ## raio da base da toca (u de mundo)

var semente: float = 0.0
var _t := 0.0
var _loot: Lootavel = null


func _ready() -> void:
	y_sort_enabled = true
	light_mask = 2
	var col := CollisionPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(IsoMath.mundo_para_tela(Vector2(cos(a), sin(a)) * RAIO * 0.8))
	col.polygon = pts
	add_child(col)
	for c in get_children():
		if c is Lootavel:
			_loot = c


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _p(x: float, y: float, z: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) - Vector2(0.0, z)


func _h(k: float) -> float:
	return fposmod(sin(semente * 12.9898 + k * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	# monte de pedras com a boca da toca virada para a câmera (sul)
	var pedra := Color8(96, 92, 84)
	var base := PackedVector2Array()
	var topo := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var r := RAIO * (0.85 + 0.25 * _h(i))
		base.append(_p(cos(a) * r, sin(a) * r, 0.0))
		topo.append(_p(cos(a) * r * 0.55, sin(a) * r * 0.55, 1.5 * VPM + 8.0 * _h(i + 20)))
	draw_colored_polygon(base, Color(0.1, 0.09, 0.08, 0.45))
	for i in 16:                                      # encosta: faixas entre a base e o topo
		var j := (i + 1) % 16
		var lado := 0.5 + 0.5 * sin(TAU * i / 16.0 + 0.8)
		var faixa := PackedVector2Array([base[i], base[j], topo[j], topo[i]])
		if not Geometry2D.triangulate_polygon(faixa).is_empty():   # faixa vista de lado (sem área) não desenha
			draw_colored_polygon(faixa, pedra.darkened(0.35 - 0.3 * lado))
	draw_colored_polygon(topo, pedra.lightened(0.08))
	# musgo no topo
	for k in 3:
		var c := _p((_h(k + 40) - 0.5) * RAIO, (_h(k + 50) - 0.5) * RAIO * 0.6, 1.5 * VPM + 4.0)
		draw_circle(c, 6.0 + 6.0 * _h(k + 60), Color(0.26, 0.36, 0.18, 0.8))
	# boca da toca e guano escorrendo
	var boca := _p(0.0, RAIO * 0.75, 0.55 * VPM)
	var vazio := _loot != null and _loot.usado
	_elipse(boca, 15.0, 11.0, Color8(14, 11, 10))
	for k in 4:
		var x := (_h(k + 70) - 0.5) * 40.0
		var alto := 8.0 + 18.0 * _h(k + 80)
		draw_line(boca + Vector2(x, -10.0 - alto), boca + Vector2(x, -6.0), Color(0.86, 0.84, 0.76, 0.75), 2.0)
	if vazio:
		return
	# morcegos voando em volta (mais agitados à noite seria o ideal; aqui sempre, para o ninho ser achado de dia)
	for k in 5:
		var fase := _t * (1.2 + 0.4 * _h(k + 90)) + TAU * k / 5.0
		var r2 := RAIO * (0.9 + 0.6 * _h(k + 100))
		var c2 := _p(cos(fase) * r2, sin(fase) * r2 * 0.8, 2.2 * VPM + 18.0 * sin(fase * 2.3 + k))
		var asa := 4.0 + 3.0 * absf(sin(_t * 14.0 + k * 1.7))
		draw_colored_polygon(PackedVector2Array([c2 + Vector2(-7, -asa), c2 + Vector2(-2, 0), c2 + Vector2(0, -2),
			c2 + Vector2(2, 0), c2 + Vector2(7, -asa), c2 + Vector2(3, 2), c2 + Vector2(0, 3), c2 + Vector2(-3, 2)]), Color8(20, 16, 18))


func _elipse(c: Vector2, rx: float, ry: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, cor)
