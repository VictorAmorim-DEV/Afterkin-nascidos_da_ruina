class_name Plantacao
extends Node2D
## Pés de milho (roça verde) ou de capim seco (roça do semiárido) em pé sobre as fileiras que o ChaoChunk pinta,
## balançando com o Vento. Cada fileira é dividida em pedaços de SEGMENTO u, um nó cada, para o Y-Sort acertar quem
## passa no meio da roça. Cada pedaço é UM array de triângulos; o alfa do vértice leva a altura (0 no pé, 1 no topo)
## para o shader do vento, que o devolve a 1.

const SEGMENTO := 160.0
const PASSO := 34.0

var r := Rect2()          ## retângulo da roça no mundo
var seco := false
var semente := 0


func _ready() -> void:
	y_sort_enabled = true
	position = IsoMath.mundo_para_tela(r.position)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var y := r.position.y + 36.0
	var n := 0
	while y < r.end.y - 30.0:
		if not seco or n % 2 == 0:
			var x := r.position.x + 30.0
			while x < r.end.x - 30.0:
				var f := Fileira.new()
				f.inicio = Vector2(x, y + 9.0)
				f.comp = minf(SEGMENTO, r.end.x - 30.0 - x)
				f.seco = seco
				f.semente = rng.randi()
				f.position = IsoMath.mundo_para_tela(f.inicio) - position
				add_child(f)
				x += SEGMENTO
		y += 56.0
		n += 1


class Fileira extends Node2D:
	var inicio := Vector2.ZERO
	var comp := 160.0
	var seco := false
	var semente := 0

	func _ready() -> void:
		light_mask = 2
		material = Vento.material(3.0 if seco else 4.5, true)
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		var pts := PackedVector2Array()
		var cores := PackedColorArray()
		var idx := PackedInt32Array()
		var x := rng.randf_range(0.0, 10.0)
		while x < comp:
			var base := IsoMath.mundo_para_tela(Vector2(x, rng.randf_range(-6.0, 6.0)))
			var alto := rng.randf_range(18.0, 25.0) if seco else rng.randf_range(32.0, 44.0)
			var cor := Color(0.66, 0.56, 0.3) if seco else Color(0.28, 0.5, 0.16)
			cor = cor.lightened(rng.randf_range(0.0, 0.12))
			_tri(pts, cores, idx, [base + Vector2(-1.5, 0), base + Vector2(1.5, 0), base + Vector2(0.8, -alto),
				base + Vector2(-0.8, -alto)], [0.0, 0.0, 1.0, 1.0], cor.darkened(0.15))          # caule
			for k in 3:                                                                       # folhas
				var h := alto * (0.3 + 0.22 * k)
				var lado := -1.0 if (k + int(x)) % 2 == 0 else 1.0
				var ponta := base + Vector2(lado * rng.randf_range(7.0, 11.0), -h - rng.randf_range(-2.0, 5.0))
				_tri(pts, cores, idx, [base + Vector2(0, -h), ponta, base + Vector2(0, -h - 4.0)],
					[h / alto, minf(1.0, h / alto + 0.15), (h + 4.0) / alto], cor)
			if not seco and rng.randf() < 0.5:                                                # espiga
				var e := base + Vector2(1.5, -alto * 0.6)
				_tri(pts, cores, idx, [e, e + Vector2(3, -2), e + Vector2(3, -9), e + Vector2(0, -8)],
					[0.6, 0.62, 0.8, 0.8], Color(0.78, 0.66, 0.3))
			x += PASSO * rng.randf_range(0.7, 1.2)
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cores)

	## Polígono convexo (leque) com a altura relativa de cada ponto no alfa.
	func _tri(pts: PackedVector2Array, cores: PackedColorArray, idx: PackedInt32Array, p: Array, alt: Array, cor: Color) -> void:
		var b := pts.size()
		for i in p.size():
			pts.append(p[i])
			cores.append(Color(cor.r, cor.g, cor.b, clampf(alt[i], 0.0, 1.0)))
		for i in range(1, p.size() - 1):
			idx.append_array([b, b + i, b + i + 1])
