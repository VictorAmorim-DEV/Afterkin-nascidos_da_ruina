class_name Fogueira
extends Node2D
## Fogueira do acampamento: pedras, chamas que tremem e uma luz quente (só aparece de noite).

var _t: float = 0.0
var _luz := PointLight2D.new()


func _ready() -> void:
	_t = randf() * 10.0
	light_mask = 2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.80, 0.45, 1.0))
	g.set_color(1, Color(1.0, 0.45, 0.15, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_luz.texture = tex
	_luz.texture_scale = 2.2
	_luz.energy = 1.2
	_luz.shadow_enabled = false
	_luz.range_item_cull_mask = 3
	_luz.position = Vector2(0, -14)
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	_luz.energy = 1.15 + 0.22 * sin(_t * 17.0) + 0.1 * sin(_t * 41.0)
	queue_redraw()


func _draw() -> void:
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector2.from_angle(a) * Vector2(20.0, 10.0)
		draw_circle(p, 4.5, Color(0.36, 0.35, 0.33))
	draw_line(Vector2(-14, -2), Vector2(12, 4), Color(0.25, 0.16, 0.09), 4.0)
	draw_line(Vector2(-12, 4), Vector2(14, -3), Color(0.30, 0.19, 0.10), 4.0)
	var f := 1.0 + 0.25 * sin(_t * 13.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(0, -34 * f), Vector2(11, 0)]), Color(0.95, 0.40, 0.08, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(2, -26 * f), Vector2(8, 0)]), Color(1.0, 0.72, 0.15, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(0, -16 * f), Vector2(4, 0)]), Color(1.0, 0.95, 0.6, 0.95))
