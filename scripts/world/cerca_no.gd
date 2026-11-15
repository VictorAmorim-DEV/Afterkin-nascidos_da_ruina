class_name CercaNo
extends StaticBody2D
## Trecho de cerca (até ~256 u) entre dois pontos do mundo. Desenhada por código:
## "madeira" (mourões e duas travas), "arame" (mourões finos e fios), "palicada" (toras pontudas),
## "alambrado" (tela de aço da V13: chain), "muro" (muro baixo de tijolo/reboco do cemitério e dos lotes) e
## "mureta" (barreira de concreto, V13: rail).
## Origem do nó = meio do trecho; a colisão é uma tira fina ao longo dele.

var a := Vector2.ZERO        ## extremos em coordenadas de MUNDO
var b := Vector2.ZERO
var estilo: String = "madeira"
var _la := Vector2.ZERO      ## extremos em tela, relativos ao nó
var _lb := Vector2.ZERO


func _ready() -> void:
	light_mask = 2
	var meio := (a + b) * 0.5
	position = IsoMath.mundo_para_tela(meio)
	_la = IsoMath.mundo_para_tela(a) - position
	_lb = IsoMath.mundo_para_tela(b) - position
	var dir := (b - a).normalized()
	var n := dir.orthogonal() * 7.0
	var col := CollisionPolygon2D.new()
	col.polygon = PackedVector2Array([
		IsoMath.mundo_para_tela(a - n - meio), IsoMath.mundo_para_tela(b - n - meio),
		IsoMath.mundo_para_tela(b + n - meio), IsoMath.mundo_para_tela(a + n - meio)])
	add_child(col)


func _draw() -> void:
	if estilo == "muro":
		_muro()
		return
	if estilo == "alambrado":
		_alambrado()
		return
	if estilo == "mureta":
		_mureta()
		return
	var altura: float = 64.0 if estilo == "palicada" else (30.0 if estilo == "arame" else 34.0)
	var cor_madeira := Color(0.42, 0.30, 0.18)
	var escuro := cor_madeira.darkened(0.35)
	if estilo == "palicada":
		var n: int = maxi(2, int(a.distance_to(b) / 26.0))
		for i in range(n + 1):
			var p := _la.lerp(_lb, float(i) / n)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0), p + Vector2(5, -altura + 8), p + Vector2(0, -altura), p + Vector2(-5, -altura + 8)]),
				cor_madeira if i % 2 == 0 else escuro)
		return
	for h in ([0.45, 0.85] if estilo == "madeira" else [0.35, 0.65, 0.95]):
		var cor_fio: Color = cor_madeira if estilo == "madeira" else Color(0.62, 0.62, 0.6)
		draw_line(_la + Vector2(0, -altura * h), _lb + Vector2(0, -altura * h), cor_fio, 3.0 if estilo == "madeira" else 1.2)
	for p in [_la, (_la + _lb) * 0.5, _lb]:
		var pp: Vector2 = p
		draw_line(pp, pp + Vector2(0, -altura), escuro if estilo == "madeira" else Color(0.4, 0.33, 0.27), 5.0 if estilo == "madeira" else 3.0)


func _muro() -> void:
	var alt := 36.0                                   # ~1,2 m
	var tijolo := fmod(absf(a.x * 0.13 + a.y * 0.07), 1.0) < 0.5
	var cor := Color8(150, 82, 62) if tijolo else Color8(170, 166, 154)
	var d := (_lb - _la).normalized()
	var esp := Vector2(-d.y, d.x).normalized() * 3.0  # meia espessura na tela
	draw_colored_polygon(PackedVector2Array([_la, _lb, _lb + Vector2(0, -alt), _la + Vector2(0, -alt)]), cor.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([_la + Vector2(0, -alt) - esp, _lb + Vector2(0, -alt) - esp, _lb + Vector2(0, -alt) + esp, _la + Vector2(0, -alt) + esp]), cor.lightened(0.12))
	if tijolo:
		for k in range(1, 5):
			var y := -alt * k / 5.0
			draw_line(_la + Vector2(0, y), _lb + Vector2(0, y), Color(0, 0, 0, 0.15), 1.0)
	draw_line(_la, _lb, Color(0.15, 0.12, 0.09, 0.35), 3.0)           # sujeira no pé


func _alambrado() -> void:
	var alt := 58.0                                   # ~1,9 m
	var n: int = maxi(1, int(a.distance_to(b) / 96.0))
	draw_colored_polygon(PackedVector2Array([_la, _lb, _lb + Vector2(0, -alt), _la + Vector2(0, -alt)]), Color(0.62, 0.64, 0.64, 0.16))
	var passo := 9.0
	var comp := _la.distance_to(_lb)
	var x := 0.0
	while x < comp:                                   # trama em losango
		var p0 := _la.lerp(_lb, x / comp)
		var p1 := _la.lerp(_lb, minf(1.0, (x + alt * 0.5) / comp))
		draw_line(p0, p1 + Vector2(0, -alt), Color(0.7, 0.72, 0.72, 0.28), 1.0)
		draw_line(p0 + Vector2(0, -alt), p1, Color(0.7, 0.72, 0.72, 0.28), 1.0)
		x += passo * 2.0
	draw_line(_la + Vector2(0, -alt), _lb + Vector2(0, -alt), Color8(110, 112, 112), 2.0)
	for i in range(n + 1):
		var p := _la.lerp(_lb, float(i) / n)
		draw_line(p, p + Vector2(0, -alt - 2.0), Color8(96, 98, 100), 3.0)


## Barreira de concreto (~0,8 m), base mais larga, manchas de sujeira e marcas de batida.
func _mureta() -> void:
	var alt := 24.0
	var d := (_lb - _la).normalized()
	var esp := Vector2(-d.y, d.x).normalized() * 4.0
	var cor := Color8(156, 154, 146)
	draw_colored_polygon(PackedVector2Array([_la + esp, _lb + esp, _lb + Vector2(0, -alt * 0.35) + esp * 0.6,
		_la + Vector2(0, -alt * 0.35) + esp * 0.6]), cor.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([_la + Vector2(0, -alt * 0.35) + esp * 0.6, _lb + Vector2(0, -alt * 0.35) + esp * 0.6,
		_lb + Vector2(0, -alt), _la + Vector2(0, -alt)]), cor.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([_la + Vector2(0, -alt) - esp * 0.5, _lb + Vector2(0, -alt) - esp * 0.5,
		_lb + Vector2(0, -alt) + esp * 0.5, _la + Vector2(0, -alt) + esp * 0.5]), cor.lightened(0.12))
	var sd := fmod(absf(a.x * 0.013 + a.y * 0.007), 1.0)
	for k in 3:                                       # escorridos e marcas pretas de pneu
		var t := fmod(sd * 7.3 + k * 0.37, 1.0)
		var p := _la.lerp(_lb, t)
		draw_line(p + Vector2(0, -alt + 2.0), p + Vector2(0, -alt * (0.3 + 0.2 * k)), Color(0.1, 0.09, 0.08, 0.18), 3.0)
	draw_line(_la, _lb, Color(0.12, 0.1, 0.08, 0.35), 3.0)
