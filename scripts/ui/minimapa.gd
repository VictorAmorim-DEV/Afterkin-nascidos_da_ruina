class_name Minimapa
extends Control
## Minimapa (V13: desenharMinimapa, l.1784-1818): círculo no canto superior direito com o mapa na MESMA projeção
## isométrica do jogo (andar para o "N" do minimapa é ir para o norte), anel de bússola, seta do jogador,
## totem, inimigos em alerta e o rumo por extenso. Um tamanho só (60 m em volta); M abre o mapa do mundo (TelaMapa).
##
## O mapa-base sai de MinimapaBase numa Thread; o recorte circular e a projeção são feitos num shader.

const PEQUENO := 190.0
const GRANDE := 320.0
const RAIO_PEQUENO_M := 60.0
const RAIO_GRANDE_M := 180.0
const RUMOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

const SHADER := """
shader_type canvas_item;
uniform sampler2D mapa : filter_nearest;
uniform vec2 centro;          // jogador, em px do mapa
uniform float esc;            // px do mapa por px de tela
uniform vec2 tam_mapa;
uniform float raio;           // px de tela
uniform vec2 tam;             // tamanho do retângulo, px de tela
void fragment() {
	vec2 d = (UV - 0.5) * tam;
	if (length(d) > raio) { discard; }
	// tela -> mundo: inversa da projeção 2:1 do jogo (x = tx + 2·ty, y = 2·ty - tx)
	vec2 w = vec2(d.x + 2.0 * d.y, 2.0 * d.y - d.x) * esc;
	vec2 uv = (centro + w) / tam_mapa;
	vec3 c = texture(mapa, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { c = vec3(0.04, 0.06, 0.05); }
	COLOR = vec4(c, 0.93);
}
"""

var grande := false                ## não muda mais: o mapa grande é a TelaMapa
## Textura do mundo inteiro (1 px = 128 u, norte para cima), pronta quando a thread termina; o mapa do mundo usa.
static var textura_mundo: ImageTexture = null
var _mapa := ColorRect.new()
var _sobre := Control.new()
var _rumo := Label.new()
var _dica := Label.new()
var _mat := ShaderMaterial.new()
var _thread: Thread = null
var _pronto := false
var _t := 0.0
var _jogador: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # termina a imagem mesmo com a tela inicial pausando o jogo
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mapa.material = _mat
	_mapa.color = Color(0.04, 0.06, 0.05)
	_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mapa)
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobre.draw.connect(_desenhar_sobre)
	add_child(_sobre)
	for l: Label in [_rumo, _dica]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	_rumo.add_theme_font_size_override("font_size", 13)
	_dica.add_theme_font_size_override("font_size", 11)
	_dica.modulate = Color(1, 1, 1, 0.6)
	_dica.text = "M · ampliar"
	_layout()
	MinimapaBase.preparar()
	MinimapaBase.preparar_cache()
	_thread = Thread.new()
	_thread.start(MinimapaBase.gerar_ou_cache)    # do cache em disco quando existir


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _layout() -> void:
	var d := GRANDE if grande else PEQUENO
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -d - 16.0
	offset_right = -16.0
	offset_top = 12.0
	offset_bottom = 12.0 + d + 34.0
	_mapa.position = Vector2.ZERO
	_mapa.size = Vector2(d, d)
	_sobre.position = Vector2.ZERO
	_sobre.size = Vector2(d, d)
	_rumo.position = Vector2(0, d - 4.0)
	_rumo.size = Vector2(d, 18)
	_dica.position = Vector2(0, d + 12.0)
	_dica.size = Vector2(d, 16)
	_dica.text = "%s · mapa" % Controles.nome("minimapa")
	_mat.set_shader_parameter("tam", Vector2(d, d))
	_mat.set_shader_parameter("raio", _raio_tela())
	_sobre.queue_redraw()


func _raio_tela() -> float:
	return (GRANDE if grande else PEQUENO) * 0.5 - 20.0


## px do mapa por px de tela: o raio do círculo, na horizontal da tela, cobre o raio em metros.
func _esc() -> float:
	var raio_u := (RAIO_GRANDE_M if grande else RAIO_PEQUENO_M) * IsoMath.METRO
	return raio_u / (MinimapaBase.PX * _raio_tela() * sqrt(2.0))


func _process(delta: float) -> void:
	if not _pronto and _thread != null and not _thread.is_alive():
		var img: Image = _thread.wait_to_finish()
		_thread = null
		textura_mundo = ImageTexture.create_from_image(img)
		_mat.set_shader_parameter("mapa", textura_mundo)
		_mat.set_shader_parameter("tam_mapa", Vector2(img.get_width(), img.get_height()))
		_pronto = true
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D
		if _jogador == null:
			return
	var p := _pos_mundo()
	_mat.set_shader_parameter("centro", p / MinimapaBase.PX)
	_mat.set_shader_parameter("esc", _esc())
	_t -= delta
	if _t <= 0.0:                                     # V13: a cada 50 ms
		_t = 0.05
		_sobre.queue_redraw()


## Posição do jogador (ou do carro que ele dirige) em u de mundo.
func _pos_mundo() -> Vector2:
	var alvo: Node2D = _jogador
	if "dirigindo" in _jogador and _jogador.dirigindo != null:
		alvo = _jogador.dirigindo
	return IsoMath.tela_para_mundo(alvo.global_position)


## Direção na tela (normalizada) de um rumo em graus (0 = norte, 90 = leste).
static func _tela(graus: float) -> Vector2:
	var r := deg_to_rad(graus)
	return IsoMath.mundo_para_tela(Vector2(sin(r), -cos(r))).normalized()


## Deslocamento no mundo (u) -> px do minimapa a partir do centro.
func _no_mapa(delta_u: Vector2) -> Vector2:
	return IsoMath.mundo_para_tela(delta_u) / (_esc() * MinimapaBase.PX)


func _desenhar_sobre() -> void:
	var d := GRANDE if grande else PEQUENO
	var c := Vector2(d, d) * 0.5
	var rm := _raio_tela()
	if not _pronto:
		_sobre.draw_circle(c, rm, Color(0.04, 0.06, 0.05, 0.93))
		_sobre.draw_string(ThemeDB.fallback_font, c + Vector2(-40, 4), "mapeando…", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 1, 1, 0.6))
	if _jogador != null and is_instance_valid(_jogador):
		var p := _pos_mundo()
		var raio_u := (RAIO_GRANDE_M if grande else RAIO_PEQUENO_M) * IsoMath.METRO
		# totem e raio do território
		var terr = _jogador.get("territorio")
		if terr != null and terr.tem_totem() and is_instance_valid(terr.totem.no):
			var tp := IsoMath.tela_para_mundo((terr.totem.no as Node2D).global_position)
			var pts := PackedVector2Array()
			for k in 33:
				var a := TAU * k / 32.0
				var q := c + _no_mapa(tp - p + Vector2.from_angle(a) * float(terr.totem.alcance))
				pts.append(q)
			_sobre.draw_polyline(pts, Color("#82b5ff"), 1.5)
			var tc := c + _no_mapa(tp - p)
			if tc.distance_to(c) < rm:
				_sobre.draw_rect(Rect2(tc - Vector2(3, 3), Vector2(6, 6)), Color("#82b5ff"))
		# inimigos que perceberam você
		for e in get_tree().get_nodes_in_group("inimigo"):
			if not ("alerta" in e) or float(e.alerta) <= 0.0:
				continue
			var ep := IsoMath.tela_para_mundo((e as Node2D).global_position)
			if ep.distance_to(p) > raio_u * 1.6:
				continue
			var q2 := c + _no_mapa(ep - p)
			if q2.distance_to(c) < rm - 2.0:
				_sobre.draw_circle(q2, 2.6, Color("#ff4d4d"))
	# anel da bússola
	_sobre.draw_arc(c, rm + 7.0, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 14.0)
	_sobre.draw_arc(c, rm, 0.0, TAU, 64, Color(0, 0, 0, 0.55), 2.0)
	for b in range(0, 360, 15):
		var l := 0.0 if b % 90 == 0 else (5.0 if b % 45 == 0 else 3.0)
		if l > 0.0:
			var v := _tela(b)
			_sobre.draw_line(c + v * (rm + 2.0), c + v * (rm + 2.0 + l), Color(1, 1, 1, 0.55), 1.0)
	var f := ThemeDB.fallback_font
	for par in [["N", 0.0], ["L", 90.0], ["S", 180.0], ["O", 270.0]]:
		var v2 := _tela(par[1])
		var q3 := c + v2 * (rm + 7.0)
		_sobre.draw_circle(q3, 8.0, Color(0.04, 0.055, 0.08, 0.85))
		var cor_l := Color("#ff6a5f") if par[0] == "N" else Color("#eef3fb")
		_sobre.draw_string(f, q3 + Vector2(-4.5, 4.5), par[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor_l)
	var vn := _tela(0.0)                              # agulha do norte
	var ortn := Vector2(-vn.y, vn.x)
	_sobre.draw_colored_polygon(PackedVector2Array([c + vn * (rm - 2.0), c + vn * (rm - 12.0) + ortn * 5.0, c + vn * (rm - 12.0) - ortn * 5.0]), Color("#ff5a4f"))
	# jogador: seta no centro apontando para o rumo atual
	if _jogador == null or not is_instance_valid(_jogador):
		return
	var andando := false
	var dir := Vector2.from_angle(float(_jogador.get("face")))
	var vel: Vector2 = IsoMath.tela_para_mundo(_jogador.velocity) if _jogador is CharacterBody2D else Vector2.ZERO
	if vel.length() > 12.0:
		dir = vel
		andando = true
	var rumo := fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0)
	var a3 := _tela(rumo)
	var ort := Vector2(-a3.y, a3.x)
	var seta := PackedVector2Array([c + a3 * 9.0, c - a3 * 7.0 + ort * 6.5, c - a3 * 3.5, c - a3 * 7.0 - ort * 6.5])
	_sobre.draw_colored_polygon(seta, Color("#ffd23f"))
	seta.append(seta[0])
	_sobre.draw_polyline(seta, Color("#1a1405"), 1.5)
	var nome: String = RUMOS[int(roundf(rumo / 45.0)) % 8]
	_rumo.text = "%s %s · %03d°" % ["Indo para" if andando else "Olhando para", nome, int(roundf(rumo)) % 360]
