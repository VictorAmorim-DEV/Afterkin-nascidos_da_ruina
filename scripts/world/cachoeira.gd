class_name Cachoeira
extends StaticBody2D
## Cachoeira (na saída do lago norte do mapa-múndi): paredão de rocha atravessando o rio e uma cortina d'água animada.
## O paredão bloqueia a passagem (colisão); a água cai no rio fundo logo abaixo (chão + colisão do chunk).
## Origem = base do paredão no mundo (MundoGen.cachoeira_pos: meio do rio); a largura vem do rio naquele ponto.

const ALTURA := 230.0                 ## px de tela
var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 20.0
	var rc := MundoGen.cachoeira_rect()
	var c := MundoGen.cachoeira_pos()
	var col := CollisionPolygon2D.new()
	var pts := PackedVector2Array()
	for p in [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]:
		pts.append(IsoMath.mundo_para_tela((p as Vector2) - c))
	col.polygon = pts
	add_child(col)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var meia: float = MundoGen.cachoeira()["meia"]
	var w := meia + 500.0
	var bl := IsoMath.mundo_para_tela(Vector2(-w, 0.0))
	var br := IsoMath.mundo_para_tela(Vector2(w, 0.0))
	var up := Vector2(0, -ALTURA)
	# face do paredão, em faixas de rocha
	var faixas := 8
	for i in faixas:
		var t0 := float(i) / faixas
		var t1 := float(i + 1) / faixas
		var tom: float = 0.30 + 0.26 * t1 + 0.04 * sin(i * 2.3)
		draw_colored_polygon(PackedVector2Array([bl + up * t0, br + up * t0, br + up * t1, bl + up * t1]),
			Color(tom, tom * 0.95, tom * 0.86))
	# topo (a mata que fica em cima do paredão)
	var fundo := IsoMath.mundo_para_tela(Vector2(0.0, -200.0))
	draw_colored_polygon(PackedVector2Array([bl + up, br + up, br + up + fundo, bl + up + fundo]), Color(0.16, 0.30, 0.14))
	# cortina d'água
	var wa := IsoMath.mundo_para_tela(Vector2(-meia * 0.85, 0.0))
	var wb := IsoMath.mundo_para_tela(Vector2(meia * 0.85, 0.0))
	draw_colored_polygon(PackedVector2Array([wa + up, wb + up, wb, wa]), Color(0.62, 0.80, 0.88, 0.92))
	for k in 16:
		var x: float = lerpf(0.04, 0.96, float(k) / 15.0)
		var base := wa.lerp(wb, x)
		var off: float = fposmod(_t * (0.9 + 0.35 * (k % 3)) + k * 0.37, 1.0)
		var y0: float = -ALTURA * off
		draw_line(base + Vector2(0, y0), base + Vector2(0, minf(0.0, y0 + 46.0)), Color(1, 1, 1, 0.8), 3.0 + (k % 3))
	# névoa na base
	for k in 7:
		var p := wa.lerp(wb, (k + 0.5) / 7.0) + Vector2(0, 6)
		var r: float = 24.0 + 6.0 * sin(_t * 2.0 + k)
		draw_circle(p, r, Color(1, 1, 1, 0.22))
