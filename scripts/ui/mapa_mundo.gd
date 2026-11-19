class_name MapaMundo
extends Control
## Mapa do mundo inteiro, norte para cima (docs/DECISOES_DESIGN.md, ajustes do playtest, item 3).
## Usa a textura do mapa-base que o Minimapa gera (Minimapa.textura_mundo). Mostra:
## - o terreno, com névoa onde o jogador ainda não esteve (Descobertas);
## - os nomes de cidades, povoados, locais especiais e vilarejos (conhecidos desde o começo);
## - acampamentos: "?" até serem descobertos;
## - ícones dos pontos de interesse (hospital, mercado...) já revelados;
## - você, o totem, o abrigo, as camas, a mochila deixada no corpo e o marcador.
## Roda do mouse aproxima, arrastar move, botão direito põe/tira o marcador.
## No modo da tela inicial ('modo_inicio'), não há névoa e só o lugar escolhido ('destaque', um id de Inicio) mostra
## os ícones (é a cidade onde o personagem morava).

const SHADER := """
shader_type canvas_item;
uniform sampler2D nevoa : filter_linear;
uniform vec2 esc_nevoa;
uniform bool sem_nevoa;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float v = sem_nevoa ? 1.0 : texture(nevoa, UV * esc_nevoa).r;
	vec3 desconhecido = vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11))) * 0.16 + vec3(0.04, 0.045, 0.055);
	COLOR = vec4(mix(desconhecido, c.rgb, v), 1.0);
}
"""

## Ícones: [letra, cor do fundo, cor da letra, rótulo da legenda].
const ICONES := {
	"hospital": ["H", Color("#eeeeea"), Color("#c0201e"), "Hospital"],
	"farmacia": ["+", Color("#1e8a4e"), Color("#ffffff"), "Farmácia"],
	"mercado": ["S", Color("#d6902e"), Color("#1e1408"), "Supermercado"],
	"delegacia": ["D", Color("#2a4a9a"), Color("#ffffff"), "Delegacia"],
	"posto": ["C", Color("#d8402e"), Color("#ffffff"), "Posto de combustível"],
	"oficina": ["O", Color("#555555"), Color("#f0c030"), "Oficina"],
	"escola": ["E", Color("#9a5a32"), Color("#f4e4c4"), "Escola"],
	"igreja": ["†", Color("#e8dcc0"), Color("#3a2a1a"), "Igreja"],
	"restaurante": ["R", Color("#7a2a1a"), Color("#f4d9a0"), "Restaurante"],
	"acampamento": ["▲", Color("#d99a3a"), Color("#2a1a08"), "Acampamento"],
	"desconhecido": ["?", Color("#7a4ab0"), Color("#ffffff"), "Local desconhecido"],
	"npc": ["!", Color("#e8c832"), Color("#2a2208"), "NPC principal (em breve)"],
	"marcador": ["✚", Color("#e83a6a"), Color("#ffffff"), "Seu marcador"],
	"totem": ["T", Color("#4ab0a0"), Color("#0a1a18"), "Seu totem"],
	"abrigo": ["A", Color("#4ab0a0"), Color("#0a1a18"), "Seu abrigo"],
	"cama": ["Z", Color("#6a8ad8"), Color("#ffffff"), "Sua cama"],
	"mochila": ["M", Color("#9a3a2a"), Color("#ffffff"), "Sua mochila (onde morreu)"],
	"rumor": ["R", Color("#9a6ad0"), Color("#ffffff"), "Rumor (região aproximada)"],
}
const ORDEM_LEGENDA := ["hospital", "farmacia", "mercado", "delegacia", "posto", "oficina", "escola", "igreja",
	"restaurante", "acampamento", "desconhecido", "npc", "totem", "abrigo", "cama", "mochila", "rumor", "marcador"]

@export var modo_inicio := false
var destaque := ""                     ## id de Inicio realçado (tela inicial e tela de respawn)
var destaque_ponto := Vector2.INF      ## ponto (mundo) realçado com um anel (cama escolhida na tela de respawn)

var _terreno := Control.new()
var _sobre := Control.new()
var _mat := ShaderMaterial.new()
var _nevoa_tex: ImageTexture = null
var _versao := -1
var _zoom := 1.0
var _centro := Vector2(MinimapaBase.W, MinimapaBase.H) * 0.5     ## px do mapa-base no meio da vista
var _arrastando := false
var _t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("sem_nevoa", modo_inicio)
	_terreno.material = _mat
	for c: Control in [_terreno, _sobre]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	_terreno.draw.connect(_desenhar_terreno)
	_sobre.draw.connect(_desenhar_sobre)
	resized.connect(_redesenhar)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not modo_inicio and Descobertas.versao != _versao and Descobertas.mascara != null:
		_versao = Descobertas.versao
		if _nevoa_tex == null or _nevoa_tex.get_size() != Vector2(Descobertas.mascara.get_size()):
			_nevoa_tex = ImageTexture.create_from_image(Descobertas.mascara)
		else:
			_nevoa_tex.update(Descobertas.mascara)
		_mat.set_shader_parameter("nevoa", _nevoa_tex)
		var m := Descobertas.mascara.get_size()
		_mat.set_shader_parameter("esc_nevoa", Vector2(float(MinimapaBase.W) / (m.x * Descobertas.CELULA),
			float(MinimapaBase.H) / (m.y * Descobertas.CELULA)))
		_terreno.queue_redraw()
	_t -= delta
	if _t <= 0.0:
		_t = 0.25                                       # a seta do jogador anda
		_redesenhar()


func _redesenhar() -> void:
	_terreno.queue_redraw()
	_sobre.queue_redraw()


## Centraliza a vista num ponto do mundo, com o zoom dado.
func focar(p_mundo: Vector2, zoom: float) -> void:
	_centro = p_mundo / MinimapaBase.PX
	_zoom = clampf(zoom, 1.0, 12.0)
	_redesenhar()


# ───────────────────────────── conversões ─────────────────────────────

func _esc() -> float:
	return minf(size.x / MinimapaBase.W, size.y / MinimapaBase.H) * _zoom


## Mundo (u) -> ponto local deste controle.
func para_tela(p_mundo: Vector2) -> Vector2:
	return size * 0.5 + (p_mundo / MinimapaBase.PX - _centro) * _esc()


func para_mundo(p_local: Vector2) -> Vector2:
	return ((p_local - size * 0.5) / _esc() + _centro) * MinimapaBase.PX


# ───────────────────────────── entrada ─────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var antes := para_mundo(mb.position)
			_zoom = clampf(_zoom * (1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 12.0)
			_centro += (antes - para_mundo(mb.position)) / MinimapaBase.PX     # o ponto sob o mouse fica parado
			_redesenhar()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not modo_inicio:
			_alternar_marcador(para_mundo(mb.position))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_arrastando = true
			accept_event()
	elif event is InputEventMouseButton and not event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_arrastando = false
	elif event is InputEventMouseMotion and _arrastando:
		_centro -= (event as InputEventMouseMotion).relative / _esc()
		_redesenhar()
		accept_event()


func _alternar_marcador(p: Vector2) -> void:
	if Descobertas.marcador != Vector2.INF and para_tela(Descobertas.marcador).distance_to(para_tela(p)) < 14.0:
		Descobertas.marcador = Vector2.INF
	else:
		Descobertas.marcador = p
	_redesenhar()


# ───────────────────────────── desenho ─────────────────────────────

func _desenhar_terreno() -> void:
	var tex := Minimapa.textura_mundo
	if tex == null:
		return
	var o := para_tela(Vector2.ZERO)
	_terreno.draw_texture_rect(tex, Rect2(o, Vector2(MinimapaBase.W, MinimapaBase.H) * _esc()), false)


func _desenhar_sobre() -> void:
	var fonte := get_theme_default_font()
	if Minimapa.textura_mundo == null:
		_sobre.draw_string(fonte, size * 0.5 + Vector2(-90, 0), "Desenhando o mapa...", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color(1, 1, 1, 0.7))
		return
	var area_destaque := _area_destaque()
	# pontos de interesse
	var r_icone := clampf(4.0 + _zoom * 1.2, 6.0, 11.0)
	if _zoom >= 2.0 or modo_inicio:
		for poi in Descobertas.pois():
			var pd: Dictionary = poi
			var p: Vector2 = pd["p"]
			var ver := area_destaque.has_point(p) if modo_inicio else Descobertas.revelado(p)
			if ver:
				icone(_sobre, para_tela(p), str(pd["uso"]), r_icone, fonte)
	# nomes das áreas urbanas
	for a in MundoGen.AREAS.size():
		var ad: Dictionary = MundoGen.AREAS[a]
		var cat: String = ad.get("cat", "cidade")
		var tam := {"cidade_grande": 17, "cidade": 14, "especial": 13, "povoado": 12}.get(cat, 12) as int
		var cor := Color(1, 1, 1) if cat != "especial" else Color(1.0, 0.85, 0.6)
		_rotulo(fonte, para_tela(MundoGen.area_rect(a).get_center()), str(ad["nome"]), tam, cor)
	for v in MundoGen.aldeias():
		var vd: Dictionary = v
		_rotulo(fonte, para_tela((vd["area"] as Rect2).get_center()), str(vd["nome"]), 11, Color(0.9, 0.95, 0.75))
	# acampamentos: "?" até descobrir
	for c in MundoGen.acampamentos():
		var cd: Dictionary = c
		var conhecido: bool = Descobertas.acampamentos.has(cd["nome"]) or (modo_inicio and _e_destaque_acampamento(cd))
		var pc := para_tela(cd["c"])
		icone(_sobre, pc, "acampamento" if conhecido else "desconhecido", 9.0, fonte)
		if conhecido:
			_rotulo(fonte, pc + Vector2(0, 20), str(cd["nome"]), 11, Color(1.0, 0.85, 0.55))
	if area_destaque.has_area():
		var r := Rect2(para_tela(area_destaque.position), area_destaque.size / MinimapaBase.PX * _esc()).grow(6.0)
		_sobre.draw_rect(r, Color(1.0, 0.85, 0.3), false, 2.0)
	if modo_inicio:
		return
	# você, totem, abrigo e marcador
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j != null:
		var t: Territorio = j.territorio
		if t.tem_totem():
			icone(_sobre, para_tela(IsoMath.tela_para_mundo(t.totem.no.global_position)), "totem", 8.0, fonte)
		if t._no_abrigo != null and is_instance_valid(t._no_abrigo):
			icone(_sobre, para_tela(IsoMath.tela_para_mundo(t._no_abrigo.global_position)), "abrigo", 8.0, fonte)
	for rid in Rumores.no_mapa():
		var rg: Dictionary = Rumores.regiao(rid)
		var pc := para_tela(rg["centro"])
		var rr := maxf(6.0, float(rg["raio"]) / MinimapaBase.PX * _esc())
		_sobre.draw_circle(pc, rr, Color(0.6, 0.42, 0.82, 0.10))
		for k in 24:
			if k % 2 == 0:
				_sobre.draw_arc(pc, rr, TAU * k / 24.0, TAU * (k + 1) / 24.0, 4, Color(0.7, 0.52, 0.92, 0.9), 1.5)
		icone(_sobre, pc, "rumor", 7.0, fonte)
		if _zoom >= 3.0:
			_rotulo(fonte, pc + Vector2(0, rr + 12.0), Rumores.titulo(rid), 11, Color(0.85, 0.75, 1.0))
	for c in Respawn.camas:
		if is_instance_valid(c["no"]):
			icone(_sobre, para_tela(c["p"]), "cama", 8.0, fonte)
	for m in get_tree().get_nodes_in_group("mochila_chao"):
		icone(_sobre, para_tela(IsoMath.tela_para_mundo((m as Node2D).global_position)), "mochila", 8.0, fonte)
	if destaque_ponto != Vector2.INF:
		_sobre.draw_arc(para_tela(destaque_ponto), 15.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3), 2.5)
	if Descobertas.marcador != Vector2.INF:
		icone(_sobre, para_tela(Descobertas.marcador), "marcador", 9.0, fonte)
	if j != null and not j.morto:
		var alvo: Node2D = j.dirigindo if j.dirigindo != null else j
		var pj := para_tela(IsoMath.tela_para_mundo(alvo.global_position))
		var f := Vector2.from_angle(j.face)                # direção no mundo = direção no mapa (norte para cima)
		var pts := PackedVector2Array([pj + f * 11.0, pj + f.rotated(2.5) * 7.0, pj + f.rotated(-2.5) * 7.0])
		_sobre.draw_colored_polygon(pts, Color(1, 1, 1))
		_sobre.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0), 1.5)


func _rotulo(fonte: Font, p: Vector2, texto: String, tam: int, cor: Color) -> void:
	var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var o := p + Vector2(-w * 0.5, tam * 0.35)
	_sobre.draw_string_outline(fonte, o, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color(0, 0, 0, 0.85))
	_sobre.draw_string(fonte, o, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


## Retângulo (mundo) do lugar realçado na tela inicial.
func _area_destaque() -> Rect2:
	var d: Dictionary = Inicio.DADOS.get(destaque, {})
	if d.has("area"):
		for a in MundoGen.AREAS.size():
			if MundoGen.AREAS[a]["nome"] == d["area"]:
				return MundoGen.area_rect(a)
	if d.has("vilarejo"):
		for v in MundoGen.aldeias():
			if (v as Dictionary)["nome"] == d["vilarejo"]:
				return (v as Dictionary)["area"]
	if d.has("acampamento"):
		for c in MundoGen.acampamentos():
			if (c as Dictionary)["nome"] == d["acampamento"]:
				var cc: Vector2 = (c as Dictionary)["c"]
				return Rect2(cc - Vector2(900, 900), Vector2(1800, 1800))
	return Rect2()


func _e_destaque_acampamento(cd: Dictionary) -> bool:
	return (Inicio.DADOS.get(destaque, {}) as Dictionary).get("acampamento", "") == cd["nome"]


## Desenha o ícone 'tipo' (chave de ICONES) centrado em 'p'. Também usado pela legenda.
static func icone(ci: CanvasItem, p: Vector2, tipo: String, r: float, fonte: Font) -> void:
	var d: Array = ICONES.get(tipo, ["•", Color.WHITE, Color.BLACK, ""])
	ci.draw_circle(p, r + 1.5, Color(0, 0, 0, 0.75))
	ci.draw_circle(p, r, d[1])
	var tam := int(r * 1.5)
	var w := fonte.get_string_size(str(d[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	ci.draw_string(fonte, p + Vector2(-w * 0.5, tam * 0.36), str(d[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam, d[2])
