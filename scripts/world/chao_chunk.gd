class_name ChaoChunk
extends Node2D
## Chão de UM chunk (1024 × 1024 u), desenhado em isométrico 2:1 a partir de MundoGen.
## Camadas, de baixo para cima: bioma (tropical → semiárido → deserto, com mistura suave pelos vértices)
## → manchas de solo rachado → quintais e roças → cidade → água → estradas e trilhas → ruas → ponte.
## Tudo é recortado ao retângulo do chunk, então chunks vizinhos nunca se sobrepõem.
## Os UVs vêm das coordenadas do mundo: a textura continua entre chunks, sem emenda.

const U_POR_PX_GRAMA := 2.0
const TINTA_TROPICAL := Color(0.90, 1.00, 0.88)
const TINTA_SEMIARIDO := Color(1.00, 0.83, 0.52)

var c := Vector2i.ZERO
var grama: Texture2D = null
var _r := Rect2()
var _desenho: Desenho = null      ## detalhes da cidade (lixo, folhas, poças, canteiros)


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_r = Rect2(c.x * MundoGen.CH, c.y * MundoGen.CH, MundoGen.CH, MundoGen.CH)
	_detalhes()
	queue_redraw()


func _tile(tex: Texture2D) -> Vector2:
	if tex == grama and grama != null:
		return grama.get_size() * U_POR_PX_GRAMA
	return Vector2(TerrenoTexturas.MUNDO, TerrenoTexturas.MUNDO)


func _uvs(pts: PackedVector2Array, tex: Texture2D) -> PackedVector2Array:
	var t := _tile(tex)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(p.x / t.x, p.y / t.y))
	return uvs


func _poli(pts: PackedVector2Array, tex: Texture2D, cor: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, cor, _uvs(pts, tex), tex)


func _poli_cores(pts: PackedVector2Array, cores: PackedColorArray, tex: Texture2D) -> void:
	draw_polygon(pts, cores, _uvs(pts, tex), tex)


func _poli_recortado(pts: PackedVector2Array, tex: Texture2D, cor: Color) -> void:
	var rp := PackedVector2Array([_r.position, Vector2(_r.end.x, _r.position.y), _r.end, Vector2(_r.position.x, _r.end.y)])
	for q in Geometry2D.intersect_polygons(pts, rp):
		var qp: PackedVector2Array = q
		# lascas de recorte (< 1 u², ex.: trilha raspando o canto do chunk) não triangulam e são invisíveis
		if not Geometry2D.is_polygon_clockwise(qp) and _area_dupla(qp) >= 2.0:
			_poli(qp, tex, cor)


static func _area_dupla(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		s += p[i].x * p[j].y - p[j].x * p[i].y
	return absf(s)


func _ret(rc: Rect2, tex: Texture2D, cor: Color) -> void:
	var q := rc.intersection(_r)
	if q.size.x <= 0.5 or q.size.y <= 0.5:
		return
	_poli(PackedVector2Array([q.position, Vector2(q.end.x, q.position.y), q.end, Vector2(q.position.x, q.end.y)]), tex, cor)


func _draw() -> void:
	draw_set_transform_matrix(IsoMath.ISO)
	_bioma()
	_fazendas()
	_cidade_chao()
	_agua()
	_estradas()
	_ruas()
	_viaduto()
	_ponte()


# ───────────────────────────── bioma ─────────────────────────────

func _bioma() -> void:
	_ret(_r, grama, TINTA_TROPICAL)
	var q := 256.0
	var v: Array = []
	for j in 5:
		var linha: Array = []
		for i in 5:
			linha.append(MundoGen.bioma_valor(_r.position.x + i * q, _r.position.y + j * q))
		v.append(linha)
	var rachada := TerrenoTexturas.obter("rachada")
	var areia := TerrenoTexturas.obter("areia")
	for camada in 3:
		for j in 4:
			for i in 4:
				var pts := PackedVector2Array()
				var cores := PackedColorArray()
				var algum := false
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var dv: Vector2i = d
					var vv: float = (v[j + dv.y] as Array)[i + dv.x]
					var p := Vector2(_r.position.x + (i + dv.x) * q, _r.position.y + (j + dv.y) * q)
					pts.append(p)
					var a1: float = clampf(vv, 0.0, 1.0)
					var a: float
					var cor: Color
					if camada == 0:                         # grama seca por cima da tropical
						a = a1
						cor = Color(TINTA_SEMIARIDO.r, TINTA_SEMIARIDO.g, TINTA_SEMIARIDO.b, a)
					elif camada == 1:                       # manchas de solo rachado (semiárido)
						a = clampf(MundoGen.ruido_mancha(p.x, p.y) * 1.8 - 0.55, 0.0, 0.9) * a1 * (1.0 - clampf(vv - 1.0, 0.0, 1.0))
						cor = Color(1, 1, 1, a)
					else:                                   # areia do deserto
						a = clampf(vv - 1.0, 0.0, 1.0)
						cor = Color(1, 1, 1, a)
					if a > 0.01:
						algum = true
					cores.append(cor)
				if algum:
					_poli_cores(pts, cores, grama if camada == 0 else (rachada if camada == 1 else areia))


# ───────────────────────────── roças, quintais, acampamentos ─────────────────────────────

func _fazendas() -> void:
	var terra := TerrenoTexturas.obter("terra")
	var lavrado := TerrenoTexturas.obter("lavrado")
	var plantios: Array = []
	for a in MundoGen.aldeias():
		var ad: Dictionary = a
		for l in ad["lotes"]:
			var lr: Rect2 = l
			_ret(lr, terra, Color(1, 1, 1, 0.38))
		for p in ad["plantios"]:
			plantios.append(p)
	var iso: Dictionary = MundoGen.casa_isolada_em(c)
	if not iso.is_empty():
		var cr: Rect2 = iso["casa"]
		_ret(cr.grow(70.0), terra, Color(1, 1, 1, 0.38))
		plantios.append({"r": iso["plantio"], "k": iso["kind"]})
	for p in plantios:
		var pd: Dictionary = p
		var pr: Rect2 = pd["r"]
		if not pr.intersects(_r):
			continue
		var seco: bool = pd["k"] == "seco"
		_ret(pr, lavrado, Color(1, 1, 1, 1))
		var y := pr.position.y + 36.0
		var n := 0
		while y < pr.end.y - 30.0:
			if not seco or n % 2 == 0:
				var cor := Color(0.24, 0.48, 0.14) if n % 2 == 0 else Color(0.33, 0.55, 0.17)
				if seco:
					cor = Color(0.52, 0.43, 0.20, 0.8)
				_ret(Rect2(pr.position.x + 30.0, y, pr.size.x - 60.0, 18.0 if not seco else 10.0), null, cor)
			y += 56.0
			n += 1
	for cm in MundoGen.acampamentos():
		var cd: Dictionary = cm
		var cc: Vector2 = cd["c"]
		var ret := Rect2(cc.x - float(cd["hw"]) - 100.0, cc.y - float(cd["hh"]) - 100.0,
			float(cd["hw"]) * 2.0 + 200.0, float(cd["hh"]) * 2.0 + 200.0)
		_ret(ret, terra, Color(0.95, 0.9, 0.85, 0.85))


# ───────────────────────────── cidade ─────────────────────────────

func _cidade_chao() -> void:
	if not MundoGen.toca_urbano(_r):
		return
	for a in MundoGen.AREAS.size():
		_ret(MundoGen.area_rect(a), TerrenoTexturas.obter("concreto"), Color.WHITE)
	# chão dos quarteirões: lotes gramados, estacionamentos e vagas, quadra de esportes, cemitério, praça
	for c in Quadras.chao_no(_r):
		var t: String = c["t"]
		var tex: Texture2D = null
		if t == "grama":
			tex = grama
		elif t != "":
			tex = TerrenoTexturas.obter(t)
		_ret(c["r"], tex, c["c"])


func _ruas() -> void:
	var faixas := MundoGen.ruas(_r)
	var rc := Quadras.centro_rotatoria()
	var T := Quadras.TILE
	var tem_rot := _r.grow((Quadras.ROT_RO + Quadras.ROT_CALCADA) * T).has_point(rc)
	if faixas.is_empty() and not tem_rot:
		return
	var calcada := TerrenoTexturas.obter("calcada")
	var asfalto := TerrenoTexturas.obter("asfalto")
	for f in faixas:
		_ret((f as Dictionary)["r"], calcada, Color.WHITE)
	if tem_rot:                                       # calçada em volta do anel (o asfalto das ruas continua por cima)
		_poli_recortado(_circulo(rc, (Quadras.ROT_RO + Quadras.ROT_CALCADA) * T, 64), calcada, Color.WHITE)
	for f in faixas:
		_ret((f as Dictionary)["asf"], asfalto, Color.WHITE)
	if tem_rot:
		_rotatoria(rc, calcada, asfalto)
	var nos: Array = []                               # cruzamentos perto do chunk: sem faixa central neles
	for cz in Quadras.cruzamentos():
		var c0: Vector2 = (cz as Dictionary)["c"]
		if _r.grow(1200.0).has_point(c0):
			nos.append(c0)
	var lim := MundoGen.RUA * 0.5 + 170.0
	var via := MundoGen.viaduto().grow_individual(0.0, 170.0, 0.0, 170.0)
	var amarelo := Color(0.85, 0.72, 0.2, 0.9)
	for f in faixas:
		var fd: Dictionary = f
		if fd["sec"]:
			continue                                  # rua secundária: sem faixa central
		var fr: Rect2 = fd["r"]
		var vertical: bool = fd["v"]
		var t: float = fr.position.y if vertical else fr.position.x
		var fim: float = fr.end.y if vertical else fr.end.x
		t = floorf(t / 192.0) * 192.0
		while t < fim:
			var cx := Vector2(fr.get_center().x, t + 40.0) if vertical else Vector2(t + 40.0, fr.get_center().y)
			# sem faixa dentro dos cruzamentos, nas faixas de pedestre, no viaduto e no anel da rotatória
			var livre: bool = not via.has_point(cx)
			for no in nos:
				var nv: Vector2 = no
				if absf(cx.x - nv.x) < lim and absf(cx.y - nv.y) < lim:
					livre = false
					break
			if livre and cx.distance_to(rc) > (Quadras.ROT_RO + 5.0) * T:
				var dash := Rect2(cx.x - 5.0, cx.y - 40.0, 10.0, 80.0) if vertical else Rect2(cx.x - 40.0, cx.y - 5.0, 80.0, 10.0)
				_ret(dash, null, amarelo)
			t += 192.0
	_faixas_pedestre(rc)


## Anel de asfalto, faixa tracejada, ilha com meio-fio e grama (V13: pintarRotatoria).
func _rotatoria(rc: Vector2, calcada: Texture2D, asfalto: Texture2D) -> void:
	var T := Quadras.TILE
	_poli_recortado(_circulo(rc, Quadras.ROT_RO * T, 64), asfalto, Color.WHITE)
	var rm := (Quadras.ROT_RO + Quadras.ROT_RI) * 0.5 * T     # tracejado branco no meio da pista
	var n := 28
	for k in n:
		var a0 := TAU * k / n
		var a1 := a0 + TAU / n * 0.45
		var ext := PackedVector2Array()
		var inn := PackedVector2Array()
		for s in 4:
			var a := lerpf(a0, a1, s / 3.0)
			ext.append(rc + Vector2.from_angle(a) * (rm + 5.0))
			inn.append(rc + Vector2.from_angle(a) * (rm - 5.0))
		inn.reverse()
		ext.append_array(inn)
		_poli_recortado(ext, null, Color(0.86, 0.85, 0.8, 0.75))
	_poli_recortado(_circulo(rc, Quadras.ROT_RI * T, 40), calcada, Color(0.95, 0.94, 0.9))
	_poli_recortado(_circulo(rc, (Quadras.ROT_RI - 1.0) * T, 40), grama, Color(0.85, 0.98, 0.8))


## Faixas de pedestre (V13: faixas): listras logo fora de cada cruzamento, em todos os braços que existem;
## na rotatória, depois da calçada do anel.
func _faixas_pedestre(rc: Vector2) -> void:
	var meia := MundoGen.RUA * 0.5 - MundoGen.CALCADA      # meia largura do asfalto
	var branco := Color(0.88, 0.87, 0.82, 0.8)
	for cz in Quadras.cruzamentos():
		var cd: Dictionary = cz
		var c: Vector2 = cd["c"]
		if absf(c.x - _r.get_center().x) > 1400.0 or absf(c.y - _r.get_center().y) > 1400.0:
			continue
		var C := MundoGen.area_rect(cd["a"])
		var d0: float = MundoGen.RUA * 0.5 + 10.0
		if cd["rot"]:
			d0 = (Quadras.ROT_RO + Quadras.ROT_CALCADA + 0.4) * Quadras.TILE
		for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var dv: Vector2 = dir
			if not C.has_point(c + dv * (d0 + 200.0)):
				continue
			var w := dv.orthogonal()
			var s := -meia + 14.0
			while s < meia - 30.0:
				var a: Vector2 = c + dv * d0 + w * s
				var b: Vector2 = c + dv * (d0 + 110.0) + w * (s + 26.0)
				_ret(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()), null, branco)
				s += 48.0


## Lixo, folhas, poças, mato e rachaduras pintados no chão (V13: decais das esquinas e das árvores de calçada).
## Cada detalhe é desenhado inteiro, sem recorte, pelo chunk onde está o centro, num Desenho filho um z acima do
## chão: o chão do chunk vizinho não o corta e nada é pintado duas vezes.
func _detalhes() -> void:
	if not MundoGen.toca_urbano(_r.grow(200.0)):
		return
	var lista := Quadras.detalhes_no(_r)
	if lista.is_empty():
		return
	_desenho = Desenho.new()
	_desenho.name = "Detalhes"
	_desenho.z_index = 1
	_desenho.light_mask = light_mask
	add_child(_desenho)
	var rng := RandomNumberGenerator.new()
	for d in lista:
		var dd: Dictionary = d
		var p: Vector2 = dd["p"]
		var s: float = dd["s"]
		var a: float = dd["a"]
		rng.seed = int(dd["v"])
		match String(dd["t"]):
			"folhas":
				for k in rng.randi_range(5, 8):
					var cor: Color = [Color(0.55, 0.33, 0.12), Color(0.7, 0.5, 0.15), Color(0.45, 0.38, 0.14), Color(0.62, 0.26, 0.1)][rng.randi() % 4]
					cor.a = 0.85
					var q := p + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0, 18.0 * s)
					_dp(_elipse(q, 7.0 * s, 4.0 * s, rng.randf_range(0, PI)), cor)
			"jornal":
				_dp(_caixa(p, Vector2(36, 26) * s, a), Color(0.8, 0.78, 0.72, 0.95))
				for k in 3:
					_dp(_caixa(p + Vector2(0, -7.0 + k * 7.0).rotated(a) * s, Vector2(26, 2.5) * s, a), Color(0.45, 0.45, 0.45, 0.6))
			"papelao":
				_dp(_caixa(p, Vector2(44, 32) * s, a), Color(0.55, 0.42, 0.27, 0.95))
				_dp(_caixa(p, Vector2(44, 3) * s, a), Color(0.4, 0.3, 0.18, 0.8))
			"saco":
				_dp(_mancha(p, 12.0 * s, rng), Color(0.1, 0.11, 0.1, 0.95))
				_dp(_elipse(p + Vector2(-3, -3) * s, 4.0 * s, 2.5 * s, a), Color(0.35, 0.37, 0.35, 0.7))
			"grama":
				_dp(_mancha(p, 16.0 * s, rng), Color(0.33, 0.47, 0.2, 0.8))
				_dp(_mancha(p + Vector2(4, 2), 8.0 * s, rng), Color(0.42, 0.56, 0.24, 0.85))
			"musgo":
				_dp(_mancha(p, 20.0 * s, rng), Color(0.28, 0.4, 0.2, 0.5))
			"entulho":
				for k in rng.randi_range(4, 7):
					var q2 := p + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0, 16.0 * s)
					var g := rng.randf_range(0.38, 0.6)
					_dp(_mancha(q2, rng.randf_range(3.0, 7.0) * s, rng, 5), Color(g, g * 0.97, g * 0.92))
			"poca":
				_dp(_mancha(p, 34.0 * s, rng, 12), Color(0.2, 0.25, 0.3, 0.55))
				_dp(_elipse(p + Vector2(-6, -4) * s, 14.0 * s, 6.0 * s, a), Color(0.55, 0.64, 0.72, 0.25))
			"canteiro":
				_dp(_caixa(p, Vector2(54, 54), 0.0), Color(0.5, 0.48, 0.44, 0.9))
				_dp(_caixa(p, Vector2(44, 44), 0.0), Color(0.3, 0.22, 0.14, 0.95))
			"mato":
				_rachadura(p, a, s, rng, Color(0.12, 0.12, 0.12, 0.6))
				for k in 3:
					_dp(_mancha(p + Vector2.from_angle(a) * rng.randf_range(-16, 16) * s, 6.0 * s, rng, 6), Color(0.35, 0.5, 0.2, 0.85))
			"rachadura":
				_rachadura(p, a, s, rng, Color(0.1, 0.1, 0.1, 0.55))
			"oleo":
				_dp(_mancha(p, 22.0 * s, rng, 10), Color(0.05, 0.05, 0.06, 0.55))
				_dp(_elipse(p + Vector2(-4, -3) * s, 8.0 * s, 3.0 * s, a), Color(0.35, 0.3, 0.45, 0.25))
			"mancha":
				_dp(_mancha(p, 18.0 * s, rng, 9), Color(0.3, 0.24, 0.16, 0.35))
			"lixo":
				for k in rng.randi_range(4, 6):
					var q3 := p + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0, 14.0 * s)
					var cl: Color = [Color(0.75, 0.2, 0.15), Color(0.85, 0.85, 0.8), Color(0.2, 0.35, 0.6), Color(0.2, 0.5, 0.25), Color(0.9, 0.75, 0.2)][rng.randi() % 5]
					_dp(_caixa(q3, Vector2(rng.randf_range(4, 9), rng.randf_range(3, 6)) * s, rng.randf_range(0, PI)), cl)
			"cone":                                   # cone de trânsito tombado
				var ponta := p + Vector2.from_angle(a) * 22.0
				var n2 := Vector2.from_angle(a).orthogonal()
				_dp(PackedVector2Array([p - n2 * 11.0, ponta, p + n2 * 11.0]), Color(0.9, 0.42, 0.1))
				_dp(PackedVector2Array([p + Vector2.from_angle(a) * 9.0 - n2 * 6.5, p + Vector2.from_angle(a) * 13.0 - n2 * 4.5,
					p + Vector2.from_angle(a) * 13.0 + n2 * 4.5, p + Vector2.from_angle(a) * 9.0 + n2 * 6.5]), Color(0.95, 0.95, 0.9))
				_dp(_caixa(p - Vector2.from_angle(a) * 2.0, Vector2(6, 26), a), Color(0.2, 0.2, 0.2))
			"pneu":                                   # pneu deitado
				_dp(_elipse(p, 21.0, 21.0, 0.0), Color(0.07, 0.07, 0.08))
				_dp(_elipse(p, 11.0, 11.0, 0.0), Color(0.2, 0.2, 0.21))


## Polígono em u de mundo no Desenho de detalhes (que fica em coordenadas de tela).
func _dp(pts: PackedVector2Array, cor: Color) -> void:
	var tela := PackedVector2Array()
	for p in pts:
		tela.append(IsoMath.mundo_para_tela(p))
	_desenho.poli(tela, cor)


func _caixa(c: Vector2, tam: Vector2, a: float) -> PackedVector2Array:
	var h := tam * 0.5
	return PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(a), c + Vector2(h.x, -h.y).rotated(a),
		c + Vector2(h.x, h.y).rotated(a), c + Vector2(-h.x, h.y).rotated(a)])


func _elipse(c: Vector2, rx: float, ry: float, a: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var t := TAU * i / 10.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(a))
	return pts


## Polígono irregular em volta de c (raio varia ±35%).
func _mancha(c: Vector2, r: float, rng: RandomNumberGenerator, n: int = 9) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(TAU * i / n) * r * rng.randf_range(0.65, 1.35))
	return pts


## Rachadura em zigue-zague, desenhada como tiras finas.
func _rachadura(p: Vector2, a: float, s: float, rng: RandomNumberGenerator, cor: Color) -> void:
	var q := p - Vector2.from_angle(a) * 30.0 * s
	for k in 5:
		var q2 := q + Vector2.from_angle(a + rng.randf_range(-0.7, 0.7)) * 13.0 * s
		var n := (q2 - q).normalized().orthogonal() * 1.6
		_dp(PackedVector2Array([q - n, q2 - n, q2 + n, q + n]), cor)
		q = q2


## Viaduto (V13: viaduto): acostamento de concreto, asfalto, faixa dupla amarela no meio, faixas tracejadas entre
## as pistas e linha de bordo. Desenhado depois das ruas: as ligações que o cruzam passam por baixo da pintura.
func _viaduto() -> void:
	var v := MundoGen.viaduto()
	if not v.intersects(_r):
		return
	var y := MundoGen.VIA_Y
	_ret(v, TerrenoTexturas.obter("calcada"), Color(0.9, 0.9, 0.88))
	var asf := v.grow_individual(0.0, -MundoGen.VIA_ACOST, 0.0, -MundoGen.VIA_ACOST)
	_ret(asf, TerrenoTexturas.obter("asfalto"), Color(0.93, 0.93, 0.96))
	var amarelo := Color(0.85, 0.72, 0.2, 0.9)
	var branco := Color(0.88, 0.87, 0.82, 0.75)
	_ret(Rect2(_r.position.x, y - 14.0, _r.size.x, 7.0), null, amarelo)
	_ret(Rect2(_r.position.x, y + 7.0, _r.size.x, 7.0), null, amarelo)
	_ret(Rect2(_r.position.x, asf.position.y + 14.0, _r.size.x, 6.0), null, branco)
	_ret(Rect2(_r.position.x, asf.end.y - 20.0, _r.size.x, 6.0), null, branco)
	for off in [-176.0, 176.0]:
		var x := floorf(_r.position.x / 256.0) * 256.0
		while x < _r.end.x:
			_ret(Rect2(x + 40.0, y + off - 4.0, 120.0, 8.0), null, branco)
			x += 256.0


# ───────────────────────────── água, estradas, ponte ─────────────────────────────

func _agua() -> void:
	var ya := maxf(_r.position.y, MundoGen.RIO_Y0)
	var yb := _r.end.y
	if ya >= yb:
		return
	var cx := MundoGen.rio_x((ya + yb) * 0.5)
	if absf(cx - _r.get_center().x) > MundoGen.CH * 0.5 + MundoGen.RIO_W * 3.0 + 1800.0:
		return
	var agua := TerrenoTexturas.obter("agua")
	var terra := TerrenoTexturas.obter("terra")
	var rasa := MundoGen.poligono_rio(ya, yb, false)
	for m in Geometry2D.offset_polygon(rasa, 70.0, Geometry2D.JOIN_ROUND):
		_poli_recortado(m, terra, Color(0.8, 0.75, 0.65, 0.6))
	_poli_recortado(rasa, agua, Color(0.85, 1.0, 1.0, 0.95))
	for iv in MundoGen.intervalos_fundos():
		var ivv: Vector2 = iv
		var y0 := maxf(ivv.x, _r.position.y)
		var y1 := minf(ivv.y, _r.end.y)
		if y0 < y1:
			_poli_recortado(MundoGen.poligono_rio(y0, y1, true), agua, Color(0.50, 0.65, 0.85, 1.0))


func _circulo(p: Vector2, raio: float, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(p + Vector2.from_angle(TAU * i / float(n)) * raio)
	return pts


func _estradas() -> void:
	var terra := TerrenoTexturas.obter("terra")
	var segs := MundoGen.segmentos(_r)
	if segs.is_empty():
		return
	for passo in 2:
		for s in segs:
			var sd: Dictionary = s
			var a: Vector2 = sd["a"]
			var b: Vector2 = sd["b"]
			var w: float = float(sd["w"]) + (70.0 if passo == 0 else 0.0)
			var n := (b - a).normalized().orthogonal() * w * 0.5
			var cor: Color
			if passo == 0:
				cor = Color(0.8, 0.7, 0.55, 0.45)
			elif sd["t"] == "trilha":
				cor = Color(0.95, 0.88, 0.78, 1.0)
			else:
				cor = Color.WHITE
			_poli_recortado(PackedVector2Array([a - n, b - n, b + n, a + n]), terra, cor)
			_poli_recortado(_circulo(a, w * 0.5), terra, cor)
			_poli_recortado(_circulo(b, w * 0.5), terra, cor)


func _ponte() -> void:
	var pt := MundoGen.ponte()
	if not pt.intersects(_r):
		return
	_ret(pt, TerrenoTexturas.obter("madeira"), Color.WHITE)
	var x := pt.position.x + 24.0
	while x < pt.end.x:
		_ret(Rect2(x, pt.position.y, 5.0, pt.size.y), null, Color(0.18, 0.12, 0.07, 0.55))
		x += 48.0
	_ret(Rect2(pt.position.x, pt.position.y, pt.size.x, 16.0), null, Color(0.22, 0.15, 0.09))
	_ret(Rect2(pt.position.x, pt.end.y - 16.0, pt.size.x, 16.0), null, Color(0.22, 0.15, 0.09))
