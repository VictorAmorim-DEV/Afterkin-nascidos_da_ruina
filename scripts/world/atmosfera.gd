class_name Atmosfera
extends Node2D
## Partículas do ambiente em volta da câmera: poeira suspensa no ar (forte no semiárido, no deserto e nas cidades,
## fraca na mata) e folhas caindo na mata fechada. Emitem no espaço do mundo (as que já saíram ficam onde estão)
## e a intensidade (opacidade do emissor) segue o lugar da câmera, revista a cada meio segundo.
## CPUParticles2D: as GPUParticles2D não aparecem no renderizador GL Compatibility deste projeto.

var _poeira := CPUParticles2D.new()
var _folhas := CPUParticles2D.new()
var _t := 0.0
var _alvo_poeira := 0.0
var _alvo_folhas := 0.0
static var _ponto: Texture2D = null


func _ready() -> void:
	z_index = 4                                   # acima dos objetos em pé
	_montar(_poeira, 160, 6.0, _textura_ponto(), Color(1.0, 0.97, 0.9, 0.55), Vector2(16.0, 3.0), 8.0, 22.0, 0.4, 0.9)
	_montar(_folhas, 60, 7.0, _textura_folha(), Color(1, 1, 1, 1), Vector2(10.0, 18.0), 4.0, 14.0, 2.6, 3.8)
	_folhas.angular_velocity_min = -120.0
	_folhas.angular_velocity_max = 120.0
	_folhas.angle_min = -180.0
	_folhas.angle_max = 180.0
	var g := Gradient.new()                      # verdes e marrons de folha
	g.set_color(0, Color(0.85, 0.72, 0.22))
	g.set_color(1, Color(0.8, 0.38, 0.14))
	g.add_point(0.5, Color(0.95, 0.6, 0.18))
	_folhas.color_initial_ramp = g
	_poeira.modulate.a = 0.0
	_folhas.modulate.a = 0.0


static func emissor(p: CPUParticles2D, n: int, vida: float, tex: Texture2D) -> void:
	p.amount = n
	p.lifetime = vida
	p.texture = tex
	p.local_coords = false
	p.light_mask = 0
	var fade := Gradient.new()                   # entra e sai suave
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	p.color_ramp = fade


func _montar(p: CPUParticles2D, n: int, vida: float, tex: Texture2D, cor: Color, gravidade: Vector2, v0: float,
		v1: float, e0: float, e1: float) -> void:
	emissor(p, n, vida, tex)
	p.preprocess = vida
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(720.0, 440.0)               # a área que a câmera mostra, com sobra
	p.direction = Vector2(1.0, 0.25)
	p.spread = 35.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = gravidade
	p.scale_amount_min = e0
	p.scale_amount_max = e1
	p.color = cor
	add_child(p)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	global_position = cam.get_screen_center_position()
	# a intensidade muda devagar (sem piscar ao cruzar a borda de um bioma)
	_poeira.modulate.a = move_toward(_poeira.modulate.a, _alvo_poeira, delta * 0.5)
	_folhas.modulate.a = move_toward(_folhas.modulate.a, _alvo_folhas, delta * 0.5)
	_poeira.emitting = _poeira.modulate.a > 0.02
	_folhas.emitting = _folhas.modulate.a > 0.02
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var w := IsoMath.tela_para_mundo(global_position)
	var v := MundoGen.bioma_valor(w.x, w.y)
	var urb := MundoGen.urbano_em(w, 0.0)
	var mar := MapaMundi.sd(w.x, w.y) > 3.0
	_alvo_poeira = clampf(0.12 + 0.45 * v + (0.3 if urb else 0.0), 0.0, 1.0) * (0.25 if mar else 1.0)
	_alvo_folhas = 0.0 if urb or mar else clampf(MapaMundi.mata(w.x, w.y) * 1.3 - 0.25, 0.0, 1.0) * (1.0 - clampf(v, 0.0, 1.0))


static func _textura_ponto() -> Texture2D:
	if _ponto != null:
		return _ponto
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_ponto = t
	return t


static func _textura_folha() -> Texture2D:
	var img := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 8:
			var d := Vector2((x - 3.5) / 4.0, (y - 1.5) / 2.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.2 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
