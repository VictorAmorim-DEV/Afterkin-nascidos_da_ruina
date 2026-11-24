class_name Revoada
extends Node2D
## Revoada de morcegos chamada pela Mãe da Colônia: cerca o jogador por alguns segundos, bicando (pouca vida, muito
## fôlego). Desenhada em código, presa ao jogador.

const DURA := 5.0
const DANO_S := 1.5
const FOLEGO_S := 9.0
const N := 9

var _t := 0.0


static func soltar(j: Node2D) -> void:
	if j.get_node_or_null("Revoada") != null:
		return
	var r := Revoada.new()
	r.name = "Revoada"
	r.z_index = 20
	j.add_child(r)
	j.aviso("Uma revoada de morcegos te cerca!")


func _process(delta: float) -> void:
	_t += delta
	var j := get_parent()
	if _t >= DURA or j == null or bool(j.morto):
		queue_free()
		return
	j.receber_dano(DANO_S * delta, "vampire")
	j.stamina = maxf(0.0, float(j.stamina) - FOLEGO_S * delta)
	queue_redraw()


func _draw() -> void:
	var some := clampf((DURA - _t) / 0.8, 0.0, 1.0)
	for k in N:
		var fase := _t * (3.0 + 0.4 * k) + TAU * k / N
		var r := 26.0 + 10.0 * sin(_t * 2.0 + k)
		var c := Vector2(cos(fase) * r * 1.6, sin(fase) * r * 0.7 - 50.0 + 8.0 * sin(fase * 3.0))
		var asa := 7.0 + 3.0 * absf(sin(_t * 18.0 + k))
		var cor := Color(0.08, 0.06, 0.07, 0.9 * some)
		draw_line(c, c + Vector2(-asa, -asa * 0.5), cor, 2.0)
		draw_line(c, c + Vector2(asa, -asa * 0.5), cor, 2.0)
		draw_circle(c, 2.2, cor)
