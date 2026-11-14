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


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_r = Rect2(c.x * MundoGen.CH, c.y * MundoGen.CH, MundoGen.CH, MundoGen.CH)
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
		if not Geometry2D.is_polygon_clockwise(qp):
			_poli(qp, tex, cor)


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
	if MundoGen.CIDADE.intersects(_r):
		_ret(MundoGen.CIDADE, TerrenoTexturas.obter("concreto"), Color.WHITE)


func _ruas() -> void:
	var faixas := MundoGen.ruas(_r)
	if faixas.is_empty():
		return
	var calcada := TerrenoTexturas.obter("calcada")
	var asfalto := TerrenoTexturas.obter("asfalto")
	for f in faixas:
		_ret((f as Dictionary)["r"], calcada, Color.WHITE)
	for f in faixas:
		_ret(((f as Dictionary)["r"] as Rect2).grow(-MundoGen.CALCADA), asfalto, Color.WHITE)
	var x0: float = MundoGen.CIDADE.position.x
	var y0: float = MundoGen.CIDADE.position.y
	var amarelo := Color(0.85, 0.72, 0.2, 0.9)
	for f in faixas:
		var fd: Dictionary = f
		var fr: Rect2 = fd["r"]
		var vertical: bool = fd["v"]
		var t: float = fr.position.y if vertical else fr.position.x
		var fim: float = fr.end.y if vertical else fr.end.x
		t = floorf(t / 192.0) * 192.0
		while t < fim:
			var cx := Vector2(fr.get_center().x, t + 40.0) if vertical else Vector2(t + 40.0, fr.get_center().y)
			# sem faixa dentro dos cruzamentos
			var em_x: bool = posmod(int(cx.x - x0), int(MundoGen.BLOCO)) < int(MundoGen.RUA)
			var em_y: bool = posmod(int(cx.y - y0), int(MundoGen.BLOCO)) < int(MundoGen.RUA)
			if not (em_x and em_y):
				var dash := Rect2(cx.x - 5.0, cx.y - 40.0, 10.0, 80.0) if vertical else Rect2(cx.x - 40.0, cx.y - 5.0, 80.0, 10.0)
				_ret(dash, null, amarelo)
			t += 192.0


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


func _circulo(p: Vector2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(p + Vector2.from_angle(TAU * i / 12.0) * raio)
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
