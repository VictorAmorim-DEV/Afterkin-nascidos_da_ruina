class_name CercaNo
extends StaticBody2D
## Trecho de cerca (até ~256 u) entre dois pontos do mundo. Desenhada por código:
## "madeira" (mourões e duas travas), "arame" (mourões finos e fios) e "palicada" (toras pontudas).
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
