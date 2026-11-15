class_name ObjetoUrbano
extends StaticBody2D
## Objetos urbanos desenhados em código (V13: codObj/COD, LAMP, caçamba e caixa de correio — l.294, 690-727):
## pilar, cobertura e bomba do posto, totem com placa, contêiner, lápide, estátua, cesta de basquete, banco de praça,
## chaminé, caixa d'água, barricada, caçamba, caixa de correio e poste de luz.
##
## 'fp' é a base no chão em u de mundo; 'h' a altura em px de tela. A origem do nó fica no canto da frente da base
## (fp.end), o ponto mais "à frente" na tela, para o Y-Sort acertar com quem passa em volta.

const VPM := 30.3
const METRO := 49.48

var tipo: String = "banco"
var fp := Rect2()
var h: float = 30.0
var solido: bool = true
var extra: Dictionary = {}      ## txt, bg, fg, precos, cor, cova, semente

var _luz: PointLight2D = null
var _t := 0.0
var _ligado := false
static var _tex_luz: GradientTexture2D = null


func _ready() -> void:
	light_mask = 2
	position = IsoMath.mundo_para_tela(fp.end)
	if solido and fp.size.x > 0.0 and fp.size.y > 0.0:
		var col := CollisionPolygon2D.new()
		col.polygon = PackedVector2Array([S(fp.position.x, fp.position.y, 0.0), S(fp.end.x, fp.position.y, 0.0),
			S(fp.end.x, fp.end.y, 0.0), S(fp.position.x, fp.end.y, 0.0)])
		add_child(col)
	if tipo == "poste":
		_montar_luz()
	else:
		set_process(false)
	queue_redraw()


## Ponto 3D (u, u, px) -> tela local.
func S(x: float, y: float, z: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) - position - Vector2(0.0, z)


static func zm(m: float) -> float:
	return m * VPM


func _semente() -> float:
	return float(extra.get("semente", fp.position.x * 0.37 + fp.position.y * 0.61))


func caixa(x0: float, y0: float, x1: float, y1: float, z0: float, z1: float, topo: Color, sul: Color = Color(0, 0, 0, 0), leste: Color = Color(0, 0, 0, 0)) -> void:
	if sul.a == 0.0:
		sul = topo.darkened(0.15)
	if leste.a == 0.0:
		leste = topo.darkened(0.32)
	draw_colored_polygon(PackedVector2Array([S(x0, y1, z0), S(x1, y1, z0), S(x1, y1, z1), S(x0, y1, z1)]), sul)
	draw_colored_polygon(PackedVector2Array([S(x1, y1, z0), S(x1, y0, z0), S(x1, y0, z1), S(x1, y1, z1)]), leste)
	draw_colored_polygon(PackedVector2Array([S(x0, y0, z1), S(x1, y0, z1), S(x1, y1, z1), S(x0, y1, z1)]), topo)


## Texto numa face vertical: face sul (eixo x, em y = c) ou face leste (eixo y, em x = c).
func texto_face(eixo_x: bool, a0: float, a1: float, c: float, v_topo: float, alt: float, txt: String, fg: Color, bg: Color = Color(0, 0, 0, 0)) -> void:
	var o: Vector2 = S(a0, c, v_topo) if eixo_x else S(c, a1, v_topo)
	var d: Vector2 = (S(a0 + 1.0, c, 0.0) - S(a0, c, 0.0)) if eixo_x else -(S(c, a0 + 1.0, 0.0) - S(c, a0, 0.0))
	draw_set_transform_matrix(Transform2D(d, Vector2(0, 1), o))
	var w := a1 - a0
	if bg.a > 0.0:
		draw_rect(Rect2(0, 0, w, alt), bg)
		draw_rect(Rect2(0, 0, w, alt), Color(0, 0, 0, 0.5), false, 1.5)
	var f := ThemeDB.fallback_font
	var fs: int = maxi(6, int(alt * 0.62))
	var tam := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var sx := minf(1.75, w * 0.9 / maxf(1.0, tam.x))
	draw_set_transform_matrix(Transform2D(d, Vector2(0, 1), o) * Transform2D(0.0, Vector2(sx, 1.0), 0.0, Vector2(w * 0.5, alt * 0.5)))
	draw_string(f, Vector2(-tam.x * 0.5, (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _elipse(c: Vector2, rx: float, ry: float, cor: Color, a0: float = 0.0, a1: float = TAU) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if a1 - a0 < TAU - 0.01:
		pts.append(c)
	draw_colored_polygon(pts, cor)


func _draw() -> void:
	var x0 := fp.position.x
	var y0 := fp.position.y
	var x1 := fp.end.x
	var y1 := fp.end.y
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var sd := _semente()
	match tipo:
		"pilar":
			caixa(x0, y0, x1, y1, 0.0, h, Color8(200, 196, 186), Color8(176, 172, 162), Color8(148, 144, 138))
		"cobertura":                                  # cobertura do posto, apoiada nos pilares
			var t := zm(0.8)
			caixa(x0, y0, x1, y1, h, h + t, Color8(236, 235, 230), Color8(207, 205, 198), Color8(168, 166, 158))
			draw_colored_polygon(PackedVector2Array([S(x0, y1, h + t * 0.3), S(x1, y1, h + t * 0.3), S(x1, y1, h + t * 0.62), S(x0, y1, h + t * 0.62)]), Color8(184, 42, 34))
			draw_colored_polygon(PackedVector2Array([S(x1, y0, h + t * 0.3), S(x1, y1, h + t * 0.3), S(x1, y1, h + t * 0.62), S(x1, y0, h + t * 0.62)]), Color8(150, 36, 32))
			texto_face(true, cx - 2.2 * METRO, cx + 2.2 * METRO, y1 + 1.0, h + t * 0.92, t * 0.84, str(extra.get("txt", "POSTO")), Color8(184, 42, 34))
			if fmod(sd, 1.0) < 0.4:                   # chapa solta pendurada
				draw_colored_polygon(PackedVector2Array([S(x0 + 2.0 * METRO, y1, h + t), S(x0 + 4.0 * METRO, y1, h + t), S(x0 + 3.4 * METRO, y1, h - zm(0.6)), S(x0 + 2.4 * METRO, y1, h - zm(0.3))]), Color8(214, 212, 206))
		"bomba":
			caixa(x0, y0, x1, y1, 0.0, h, Color8(232, 230, 224), Color8(216, 214, 208), Color8(200, 198, 192))
			caixa(x0, y0, x1, y1, h * 0.78, h, Color8(200, 48, 42), Color8(184, 42, 34), Color8(160, 36, 32))
			var c := S(cx, y1, h * 0.55)
			draw_rect(Rect2(c.x - 6.0, c.y - 6.0, 12.0, 8.0), Color8(10, 12, 14) if fmod(sd, 1.0) < 0.5 else Color8(29, 42, 48))
			var m := S(x1, cy, h * 0.5)
			draw_polyline(PackedVector2Array([m, m + Vector2(8, 10), m + Vector2(3, zm(0.5))]), Color8(17, 17, 17), 2.0)
		"totem":                                      # totem de placa (posto, farmácia)
			var base := S(cx, cy, 0.0)
			var topo := S(cx, cy, h)
			draw_rect(Rect2(base.x - 4.0, topo.y, 8.0, base.y - topo.y), Color8(58, 58, 60))
			var w := zm(2.6)
			var hh := zm(1.3)
			var bg: Color = Color(extra.get("bg", "#c8281e"))
			var fg: Color = Color(extra.get("fg", "#ffffff"))
			draw_rect(Rect2(topo.x - w * 0.5 + 5.0, topo.y - hh + 4.0, w, hh), Color(0, 0, 0, 0.4))
			draw_rect(Rect2(topo.x - w * 0.5, topo.y - hh, w, hh), bg)
			draw_rect(Rect2(topo.x - w * 0.5, topo.y - hh, w, hh), Color8(26, 26, 26), false, 2.0)
			var f := ThemeDB.fallback_font
			var txt := str(extra.get("txt", "POSTO"))
			var fs: int = int(hh * 0.42)
			var tam := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var esc := minf(1.0, w * 0.9 / maxf(1.0, tam.x))          # encolhe para caber, sem cortar letras
			draw_set_transform(Vector2(topo.x, topo.y - hh * 0.5), 0.0, Vector2(esc, 1.0))
			draw_string(f, Vector2(-tam.x * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
			draw_set_transform(Vector2.ZERO)
			if extra.get("precos", false):
				draw_rect(Rect2(topo.x - w * 0.4, topo.y - hh * 0.42, w * 0.8, hh * 0.34), Color8(17, 17, 17))
				draw_string(f, Vector2(topo.x - w * 0.32, topo.y - hh * 0.15), "-.-- -.--", HORIZONTAL_ALIGNMENT_LEFT, -1, int(hh * 0.24), Color8(232, 160, 48))
		"container":
			var cor: Color = Color(extra.get("cor", "#3a5a7a"))
			caixa(x0, y0, x1, y1, 0.0, h, cor.lightened(0.05), cor.darkened(0.1), cor.darkened(0.28))
			var ao_x := x1 - x0 > y1 - y0
			var comp := (x1 - x0) if ao_x else (y1 - y0)
			var k := 14.0
			while k < comp:
				var a := S(x0 + k, y1, 0.0) if ao_x else S(x1, y0 + k, 0.0)
				var b := S(x0 + k, y1, h) if ao_x else S(x1, y0 + k, h)
				draw_line(a, b, Color(0, 0, 0, 0.28), 1.0)
				k += 14.0
			_elipse(S(x0 + (x1 - x0) * 0.6, y1, h * 0.3), 14.0, 7.0, Color(0.47, 0.24, 0.1, 0.35))
		"lapide":
			if extra.get("cova", false):              # cova aberta na frente
				draw_colored_polygon(PackedVector2Array([S(x0 - 6.0, y1 + 6.0, 0.0), S(x1 + 6.0, y1 + 6.0, 0.0),
					S(x1 + 6.0, y1 + 6.0 + 1.9 * METRO, 0.0), S(x0 - 6.0, y1 + 6.0 + 1.9 * METRO, 0.0)]), Color8(42, 30, 20))
			caixa(x0, y0, x1, y1, 0.0, h, Color8(154, 152, 143), Color8(138, 136, 127), Color8(110, 108, 100))
			_elipse(S(cx, y1, h) + Vector2(3, 0), 9.0, 5.0, Color8(138, 136, 127), PI, TAU)
		"estatua":
			var hp := zm(1.4)
			caixa(x0, y0, x1, y1, 0.0, hp, Color8(168, 164, 152), Color8(152, 148, 136), Color8(124, 120, 110))
			var tp := S(cx, cy, hp)
			var s := zm(1.0)
			var bronze := Color8(62, 90, 74)
			_elipse(tp + Vector2(0, -s * 0.9), s * 0.28, s * 0.75, bronze)
			_elipse(tp + Vector2(0, -s * 1.85), s * 0.2, s * 0.2, bronze)
			draw_line(tp + Vector2(4, -s * 1.3), tp + Vector2(s * 0.5, -s * 2.1), bronze, 5.0)
			draw_rect(Rect2(tp.x - 6.0, tp.y - s * 2.05, 5.0, 3.0), Color(0.86, 0.86, 0.82, 0.5))   # cocô de pombo
		"cesta":
			var b2 := S(cx, cy, 0.0)
			var t2 := S(cx, cy, zm(3.05))
			draw_rect(Rect2(b2.x - 2.5, t2.y, 5.0, b2.y - t2.y), Color8(74, 74, 74))
			draw_rect(Rect2(t2.x - zm(0.9), t2.y - zm(1.05), zm(1.8), zm(1.05)), Color8(232, 230, 224))
			draw_rect(Rect2(t2.x - zm(0.3), t2.y - zm(0.5), zm(0.6), zm(0.45)), Color8(200, 64, 30), false, 2.0)
			draw_arc(t2 + Vector2(0, 2), zm(0.25), 0.0, TAU, 16, Color8(200, 64, 30), 2.0)
		"correio":
			caixa(cx - 3.0, cy - 3.0, cx + 3.0, cy + 3.0, 0.0, zm(1.0), Color8(74, 58, 42), Color8(74, 58, 42), Color8(58, 42, 30))
			var cm: Color = Color(extra.get("cor", "#5a6a7a"))
			caixa(cx - 0.25 * METRO, cy - 0.12 * METRO, cx + 0.25 * METRO, cy + 0.12 * METRO, zm(1.0), zm(1.25), cm, cm.darkened(0.1), cm.darkened(0.3))
		"banco":
			var mad := Color8(122, 90, 58)
			caixa(x0, y0, x1, y1, zm(0.4), zm(0.48), mad, Color8(106, 74, 48), Color8(90, 62, 40))
			if x1 - x0 > y1 - y0:
				caixa(x0, y0, x1, y0 + 4.0, zm(0.48), zm(0.9), mad, Color8(106, 74, 48), Color8(90, 62, 40))
			else:
				caixa(x0, y0, x0 + 4.0, y1, zm(0.48), zm(0.9), mad, Color8(106, 74, 48), Color8(90, 62, 40))
			for p in [Vector2(x0 + 4, y1 - 2), Vector2(x1 - 4, y1 - 2)]:
				var pb := S(p.x, p.y, 0.0)
				draw_rect(Rect2(pb.x - 1.5, pb.y - zm(0.4), 3.0, zm(0.4)), Color8(40, 40, 40))
		"chamine":
			var b3 := S(cx, cy, 0.0)
			var t3 := S(cx, cy, h)
			var r := (x1 - x0) * 0.36
			draw_rect(Rect2(b3.x - r, t3.y, r * 0.7, b3.y - t3.y), Color8(122, 70, 54))
			draw_rect(Rect2(b3.x - r * 0.3, t3.y, r * 0.8, b3.y - t3.y), Color8(90, 50, 38))
			draw_rect(Rect2(b3.x + r * 0.5, t3.y, r * 0.5, b3.y - t3.y), Color8(58, 32, 24))
			var y := t3.y + zm(3.0)
			while y < b3.y:
				draw_rect(Rect2(b3.x - r, y, 2.0 * r, 5.0), Color(0, 0, 0, 0.25))
				y += zm(5.0)
			_elipse(t3, r, r * 0.5, Color8(26, 18, 16))
			_elipse(t3 + Vector2(0, 3), r * 0.8, r * 0.35, Color(0, 0, 0, 0.6))
		"caixa_agua":
			for p in [Vector2(x0, y0), Vector2(x1 - 6.0, y0), Vector2(x0, y1 - 6.0), Vector2(x1 - 6.0, y1 - 6.0)]:
				caixa(p.x, p.y, p.x + 6.0, p.y + 6.0, 0.0, h * 0.6, Color8(58, 58, 58), Color8(58, 58, 58), Color8(42, 42, 42))
			caixa(x0, y0, x1, y1, h * 0.6, h, Color8(106, 90, 72), Color8(122, 102, 80), Color8(94, 78, 60))
		"barricada":
			caixa(x0, y0, x1, y1, 0.0, h, Color8(122, 106, 74), Color8(138, 118, 80), Color8(106, 90, 62))
			var ax := x1 - x0 > y1 - y0
			for k2 in range(1, 4):
				var z := h * k2 / 4.0
				var a2 := S(x0, y1, z) if ax else S(x1, y0, z)
				draw_line(a2, S(x1, y1, z), Color(0.16, 0.12, 0.07, 0.55), 1.0)
		"cacamba":                                    # caçamba de lixo do beco
			var verde := Color8(52, 84, 58).lerp(Color8(84, 70, 46), fmod(sd, 1.0))
			caixa(x0, y0, x1, y1, 0.0, h, verde.darkened(0.2), verde, verde.darkened(0.3))
			caixa(x0 - 3.0, y0 - 3.0, x1 + 3.0, y0 + (y1 - y0) * 0.5, h, h + 4.0, verde.darkened(0.05))
			_elipse(S(x0 + (x1 - x0) * 0.3, y1, h * 0.4), 10.0, 5.0, Color(0.47, 0.24, 0.1, 0.35))
		"poste":
			var b4 := S(cx, cy, 0.0)
			var t4 := S(cx, cy, h)
			draw_rect(Rect2(b4.x - 2.5, t4.y, 5.0, b4.y - t4.y), Color8(64, 66, 68))
			draw_rect(Rect2(b4.x - 2.5, t4.y, 2.0, b4.y - t4.y), Color8(96, 98, 100))
			var braco := t4 + Vector2(18, 6)
			draw_line(t4, braco, Color8(64, 66, 68), 3.0)
			_elipse(braco + Vector2(2, 2), 8.0, 4.0, Color8(40, 40, 42))
			_elipse(braco + Vector2(2, 4), 6.0, 2.5, Color(1.0, 0.86, 0.55, 0.95) if _ligado else Color8(70, 74, 72))


# ───────────────────────────── poste: luz que pisca à noite ─────────────────────────────

func _montar_luz() -> void:
	# sem rede elétrica: só alguns postes ainda acendem (gerador, bateria solar)
	if fmod(_semente() * 7.31, 1.0) > 0.2:
		set_process(false)
		return
	if _tex_luz == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.88, 0.62, 1.0))
		g.set_color(1, Color(1.0, 0.7, 0.35, 0.0))
		_tex_luz = GradientTexture2D.new()
		_tex_luz.gradient = g
		_tex_luz.fill = GradientTexture2D.FILL_RADIAL
		_tex_luz.fill_from = Vector2(0.5, 0.5)
		_tex_luz.fill_to = Vector2(1.0, 0.5)
		_tex_luz.width = 256
		_tex_luz.height = 256
	_luz = PointLight2D.new()
	_luz.texture = _tex_luz
	_luz.texture_scale = 2.4
	_luz.energy = 0.0
	_luz.shadow_enabled = false
	_luz.range_item_cull_mask = 3
	_luz.position = S(fp.get_center().x, fp.get_center().y, 0.0) + Vector2(20, 6)      # no chão, embaixo da lâmpada
	_luz.enabled = false
	add_child(_luz)
	_t = fmod(_semente(), 10.0)


func _process(delta: float) -> void:
	_t += delta
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	var noite: bool = ciclo != null and ciclo.has_method("eh_noite") and ciclo.eh_noite()
	# pisca de vez em quando, como lâmpada velha
	var falha := sin(_t * 2.3) + sin(_t * 7.9 + 1.3) > 1.75
	var ligar := noite and not falha
	if ligar != _ligado:
		_ligado = ligar
		_luz.enabled = ligar
		queue_redraw()
	if ligar:
		_luz.energy = 0.85 + 0.08 * sin(_t * 31.0)
