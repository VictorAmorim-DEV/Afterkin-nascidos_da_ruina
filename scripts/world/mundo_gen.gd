class_name MundoGen
extends RefCounted
## Geração do mundo aberto. Tudo aqui é DETERMINÍSTICO e analítico (funções do ponto, sem estado):
## qualquer chunk pode ser gerado, descartado e gerado de novo igual, sem tabela do mapa inteiro.
##
## Mapa (u de mundo; 1 chunk = 1024 u ≈ 20 m; mundo 60 × 28 chunks ≈ 1,2 km × 0,58 km):
##   oeste ─────────────────────────────────────────────────────────► leste
##   TROPICAL (mata, rio, cidade)  │ SEMIÁRIDO (cactos, solo rachado) │ DESERTO (areia, ruínas)
## Faixas de transição de 6144 u de largura entre os biomas, com a fronteira ondulada pelo ruído.
##
## Tropical: cidade (grade de 3 × 4 quarteirões), rio N→S com cachoeira na nascente, ponte, dois vaus,
## estrada de terra para leste, vilarejo com roças, trilhas fechadas na mata ligando 2 acampamentos.
## Semiárido: vilarejo seco e casas isoladas. Deserto: ruínas ao longo da estrada.

const CH := 1024.0
const NX := 60
const NY := 28
const LARG := 61440.0
const ALT := 28672.0
const SEMENTE := 1337

const FRENTE1 := 22528.0          ## centro da transição tropical → semiárido
const FRENTE2 := 43008.0          ## centro da transição semiárido → deserto
const FAIXA := 3072.0             ## meia largura de cada transição

# cidade: 3 × 4 quarteirões de 3072 u, separados por ruas de 512 u (calçada 128 + asfalto 256 + calçada 128)
const CIDADE := Rect2(1536.0, 7168.0, 9600.0, 12672.0)
const BLOCO := 3072.0
const RUA := 512.0
const CALCADA := 128.0

const ESTRADA_Y := 13504.0        ## a estrada principal sai pela rua do meio da cidade
const INICIO := Vector2(900.0, 13504.0)

# rio: nasce na cachoeira (RIO_Y0), desce para o sul; dois vaus e uma ponte sem água funda
const RIO_X0 := 13600.0
const RIO_Y0 := 2800.0
const RIO_W := 360.0
const PONTE_MEIA := 160.0
const VAU1 := Vector2(9000.0, 9900.0)
const VAU2 := Vector2(21000.0, 21900.0)

const RUINAS := Rect2(44200.0, 11300.0, 5600.0, 4400.0)

static var _rb: FastNoiseLite = null
static var _rf: FastNoiseLite = null
static var _rp: FastNoiseLite = null
static var _estradas: Array = []
static var _aldeias: Array = []
static var _camps: Array = []
static var _bloq: Array = []


# ───────────────────────────── ruído e biomas ─────────────────────────────

static func _ruidos() -> void:
	if _rb != null:
		return
	_rb = FastNoiseLite.new()
	_rb.seed = SEMENTE
	_rb.frequency = 0.00012
	_rf = FastNoiseLite.new()
	_rf.seed = SEMENTE + 1
	_rf.frequency = 0.0007
	_rp = FastNoiseLite.new()
	_rp.seed = SEMENTE + 2
	_rp.frequency = 0.0016


static func ondulacao(y: float, k: float) -> float:
	_ruidos()
	return _rb.get_noise_2d(7.0, y) * 1400.0 * k


## 0 = tropical, 1 = semiárido, 2 = deserto; valores intermediários nas faixas de transição.
static func bioma_valor(x: float, y: float) -> float:
	var o := ondulacao(y, 1.0)
	var a: float = smoothstep(FRENTE1 - FAIXA, FRENTE1 + FAIXA, x + o)
	var b: float = smoothstep(FRENTE2 - FAIXA, FRENTE2 + FAIXA, x + o * 0.8)
	return a + b


static func bioma_id(v: float) -> int:
	if v < 0.5:
		return 0
	return 1 if v < 1.5 else 2


## x das bordas das faixas de transição na altura y (nas faixas o bioma é misto).
static func borda_x(frente: int, y: float, lado: int) -> float:
	var f: float = FRENTE1 if frente == 0 else FRENTE2
	var k: float = 1.0 if frente == 0 else 0.8
	return f + FAIXA * lado - ondulacao(y, k)


static func floresta(p: Vector2) -> float:
	_ruidos()
	return (_rf.get_noise_2d(p.x, p.y) + 1.0) * 0.5


static func ruido_mancha(x: float, y: float) -> float:
	_ruidos()
	return (_rp.get_noise_2d(x, y) + 1.0) * 0.5


# ───────────────────────────── rio ─────────────────────────────

static func rio_x(y: float) -> float:
	return RIO_X0 + 1300.0 * sin(y * 0.00022) + 500.0 * sin(y * 0.0007 + 2.0)


## Meia largura da água rasa (mais larga na lagoa da cachoeira).
static func rio_meia(y: float) -> float:
	var bojo: float = maxf(0.0, 1.0 - (y - RIO_Y0) / 700.0)
	return RIO_W + 300.0 * bojo


static func _sem_fundo() -> Array:
	return [VAU1, Vector2(ESTRADA_Y - PONTE_MEIA, ESTRADA_Y + PONTE_MEIA), VAU2]


static func rio_funda(y: float) -> float:
	for b in _sem_fundo():
		var bb: Vector2 = b
		if y >= bb.x and y <= bb.y:
			return 0.0
	return rio_meia(y) * 0.62


## Trechos (y0, y1) onde o rio tem água funda: o resto são vaus e a ponte.
static func intervalos_fundos() -> Array:
	var res: Array = []
	var ini := RIO_Y0
	for b in _sem_fundo():
		var bb: Vector2 = b
		if bb.x > ini:
			res.append(Vector2(ini, bb.x))
		ini = bb.y
	res.append(Vector2(ini, ALT))
	return res


static func poligono_rio(y0: float, y1: float, fundo: bool) -> PackedVector2Array:
	var esq := PackedVector2Array()
	var dir := PackedVector2Array()
	var y := y0
	while true:
		var yy: float = minf(y, y1)
		var m: float = rio_meia(yy) * (0.62 if fundo else 1.0)
		var cx := rio_x(yy)
		esq.append(Vector2(cx - m, yy))
		dir.append(Vector2(cx + m, yy))
		if yy >= y1:
			break
		y += 96.0
	dir.reverse()
	esq.append_array(dir)
	return esq


static func ponte() -> Rect2:
	var meia := RIO_W + 360.0
	return Rect2(rio_x(ESTRADA_Y) - meia, ESTRADA_Y - PONTE_MEIA, meia * 2.0, PONTE_MEIA * 2.0)


static func cachoeira_pos() -> Vector2:
	return Vector2(rio_x(RIO_Y0), RIO_Y0)


## Paredão da cachoeira (bloqueia a passagem): faixa larga e funda atrás da nascente.
static func cachoeira_rect() -> Rect2:
	var c := cachoeira_pos()
	var w := RIO_W + 700.0
	return Rect2(c.x - w, c.y - 200.0, w * 2.0, 264.0)


## 0 = seco, 1 = raso (anda devagar), 2 = fundo (bloqueado por colisão).
static func agua_em(x: float, y: float) -> int:
	if y < RIO_Y0 or y > ALT:
		return 0
	var dx: float = absf(x - rio_x(y))
	if dx > rio_meia(y):
		return 0
	if ponte().has_point(Vector2(x, y)):
		return 0
	return 2 if dx < rio_funda(y) else 1


## Fator de velocidade a pé no ponto de mundo p (água rasa atrapalha).
static func fator_terreno(p: Vector2) -> float:
	var a := agua_em(p.x, p.y)
	if a == 1:
		return 0.62
	if a == 2:
		return 0.4
	return 1.0


# ───────────────────────────── estradas, aldeias, acampamentos ─────────────────────────────

static func _dados() -> void:
	if not _estradas.is_empty():
		return
	_ruidos()
	var ca := Vector2(rio_x(RIO_Y0 + 800.0) + 1700.0, RIO_Y0 + 800.0)
	var cb := Vector2(rio_x(21450.0) - 1900.0, 21450.0)
	_camps = [
		{"c": ca, "hw": 640.0, "hh": 512.0, "est": 0, "gate": "s", "nome": "Acampamento da Cachoeira"},
		{"c": cb, "hw": 640.0, "hh": 512.0, "est": 1, "gate": "n", "nome": "Acampamento do Vau"},
	]
	# estrada principal de terra: sai da cidade, cruza a ponte e segue até o fim do deserto
	_estradas.append({"pts": PackedVector2Array([
		Vector2(11136.0, ESTRADA_Y), Vector2(30500.0, ESTRADA_Y), Vector2(33000.0, 13000.0),
		Vector2(37000.0, 13900.0), Vector2(41500.0, 13300.0), Vector2(46000.0, ESTRADA_Y),
		Vector2(49500.0, ESTRADA_Y), Vector2(53000.0, 14100.0), Vector2(58000.0, 13700.0),
		Vector2(LARG, 13700.0)]), "w": 256.0, "t": "terra"})
	# trilha 1: portão do acampamento da cachoeira → mata na margem leste → estrada (vilarejo)
	var t1 := PackedVector2Array([Vector2(ca.x, ca.y + 520.0)])
	for y in [5200.0, 6500.0, 7800.0, 9450.0, 11000.0, 12400.0]:
		var yy: float = y
		t1.append(Vector2(rio_x(yy) + 1500.0 + 140.0 * sin(yy * 0.003), yy))
	t1.append(Vector2(rio_x(ESTRADA_Y) + 2400.0, ESTRADA_Y))
	_estradas.append({"pts": t1, "w": 120.0, "t": "trilha"})
	# trilha 3: da cidade até a trilha 1, atravessando o vau norte (água rasa)
	_estradas.append({"pts": PackedVector2Array([
		Vector2(CIDADE.end.x, 9450.0), Vector2(rio_x(9450.0) + 1500.0 + 140.0 * sin(9450.0 * 0.003), 9450.0)]),
		"w": 120.0, "t": "trilha"})
	# trilha 2: da cidade (sul) até o acampamento do vau
	_estradas.append({"pts": PackedVector2Array([
		Vector2(6000.0, CIDADE.end.y), Vector2(6800.0, 20500.0), Vector2(8200.0, 20450.0),
		Vector2(cb.x, cb.y - 520.0)]), "w": 120.0, "t": "trilha"})
	# trilha 4: do acampamento do vau, cruzando o vau sul, até a mata da margem leste
	_estradas.append({"pts": PackedVector2Array([
		Vector2(cb.x, cb.y - 520.0), Vector2(cb.x + 900.0, cb.y - 500.0), Vector2(10900.0, 21200.0),
		Vector2(rio_x(21450.0), 21450.0), Vector2(13500.0, 21450.0), Vector2(14600.0, 20800.0)]),
		"w": 120.0, "t": "trilha"})
	_aldeias = [
		_aldeia("Vilarejo da Várzea", 15500.0, 6, 0, 101),
		_aldeia("Fazenda Seca", 25400.0, 4, 1, 202),
	]
	_bloq.clear()
	for a in _aldeias:
		var ad: Dictionary = a
		for l in ad["lotes"]:
			_bloq.append(l)
		for p in ad["plantios"]:
			var pd: Dictionary = p
			var pr: Rect2 = pd["r"]
			_bloq.append(pr.grow(60.0))
	for c in _camps:
		var cd: Dictionary = c
		var cc: Vector2 = cd["c"]
		_bloq.append(Rect2(cc.x - float(cd["hw"]) - 120.0, cc.y - float(cd["hh"]) - 120.0,
			float(cd["hw"]) * 2.0 + 240.0, float(cd["hh"]) * 2.0 + 240.0))


static func estradas() -> Array:
	_dados()
	return _estradas


static func aldeias() -> Array:
	_dados()
	return _aldeias


static func acampamentos() -> Array:
	_dados()
	return _camps


static func bloqueios() -> Array:
	_dados()
	return _bloq


## Retângulo de cerca com portão: devolve segmentos [a, b, estilo].
static func _cerca_ret(r: Rect2, lado: String, centro: float, larg: float, estilo: String) -> Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var segs: Array = []
	var lados: Dictionary = {
		"n": [Vector2(x0, y0), Vector2(x1, y0)], "s": [Vector2(x0, y1), Vector2(x1, y1)],
		"w": [Vector2(x0, y0), Vector2(x0, y1)], "e": [Vector2(x1, y0), Vector2(x1, y1)]}
	for k in lados:
		var par: Array = lados[k]
		var a: Vector2 = par[0]
		var b: Vector2 = par[1]
		if k == lado:
			var horiz: bool = k == "n" or k == "s"
			var g0 := centro - larg * 0.5
			var g1 := centro + larg * 0.5
			var p0 := Vector2(g0, a.y) if horiz else Vector2(a.x, g0)
			var p1 := Vector2(g1, a.y) if horiz else Vector2(a.x, g1)
			segs.append([a, p0, estilo])
			segs.append([p1, b, estilo])
			segs.append([p0, p1, estilo, "portao"])            # o vão vira portão (V13: gate)
		else:
			segs.append([a, b, estilo])
	return segs


## Specs de um segmento devolvido por _cerca_ret: trechos de cerca de até 256 u ou o portão do vão.
## Só entra o que tiver o meio dentro de 'r' (o chunk); 'ferro' = portão de ferro do acampamento (V13).
static func _specs_cerca(seg: Array, r: Rect2, specs: Array, ferro: bool = false) -> void:
	var sa: Vector2 = seg[0]
	var sb: Vector2 = seg[1]
	if seg.size() > 3:
		var meio := (sa + sb) * 0.5
		if r.has_point(meio):
			var h := absi(int(meio.x * 0.37 + meio.y * 0.61)) % 100     # estado inicial fixo por posição
			specs.append({"k": "portao", "a": sa, "b": sb, "e": "ferro" if ferro else "madeira",
				"aberto": (not ferro) and h < 35})
		return
	for pedaco in _dividir(sa, sb, 256.0):
		var pa: Vector2 = pedaco[0]
		var pb: Vector2 = pedaco[1]
		if r.has_point((pa + pb) * 0.5):
			specs.append({"k": "cerca", "a": pa, "b": pb, "e": seg[2]})


static func _aldeia(nome: String, x0: float, n: int, bio: int, sem: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sem
	var casas: Array = []
	var cercas: Array = []
	var plantios: Array = []
	var lotes: Array = []
	var yc := ESTRADA_Y
	for i in n:
		var lx: float = x0 + i * 832.0
		for lado in [0, 1]:
			if rng.randf() < 0.10:
				continue
			var norte: bool = lado == 0
			var hy: float = (yc - 128.0 - 110.0 - 384.0) if norte else (yc + 128.0 + 110.0)
			var hx: float = lx + 128.0
			casas.append({"p": Vector2(hx, hy), "w": 7, "h": 6, "f": ("s" if norte else "n"),
				"mor": rng.randi_range(0, 1), "sem": rng.randi() % 100000})
			var ly0: float = (hy - 90.0) if norte else (yc + 128.0 + 36.0)
			var ly1: float = (yc - 128.0 - 36.0) if norte else (hy + 384.0 + 90.0)
			var lote := Rect2(lx + 60.0, ly0, 640.0, ly1 - ly0)
			lotes.append(lote)
			cercas.append_array(_cerca_ret(lote, "s" if norte else "n", hx + 224.0, 224.0, "madeira"))
	var fim: float = x0 + n * 832.0
	var py0: float = yc + 128.0 + 110.0 + 384.0 + 260.0
	var k := 0
	while x0 + 100.0 + k * 1100.0 + 960.0 < fim + 300.0:
		var pr := Rect2(x0 + 100.0 + k * 1100.0, py0, 960.0, 720.0)
		plantios.append({"r": pr, "k": ("plantio" if bio == 0 else "seco")})
		cercas.append_array(_cerca_ret(pr.grow(40.0), "n", pr.position.x + 480.0, 256.0, "arame"))
		k += 1
	return {"nome": nome, "bio": bio, "casas": casas, "cercas": cercas, "plantios": plantios, "lotes": lotes,
		"area": Rect2(x0 - 300.0, yc - 1100.0, n * 832.0 + 600.0, 2900.0)}


# ───────────────────────────── consultas ─────────────────────────────

## Segmentos de estrada/trilha perto do retângulo r: {a, b, w, t}.
static func segmentos(r: Rect2) -> Array:
	_dados()
	var res: Array = []
	for e in _estradas:
		var ed: Dictionary = e
		var pts: PackedVector2Array = ed["pts"]
		var w: float = ed["w"]
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var caixa := Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x), absf(b.y - a.y)).grow(w + 8.0)
			if caixa.intersects(r):
				res.append({"a": a, "b": b, "w": w, "t": ed["t"]})
	return res


static func dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)


static func dist_trilha(p: Vector2, segs: Array) -> float:
	var d := 99999.0
	for s in segs:
		var sd: Dictionary = s
		if sd["t"] == "trilha":
			d = minf(d, dist_segmento(p, sd["a"], sd["b"]))
	return d


## Ponto livre para colocar algo (árvore, pedra...) com folga m: fora de cidade, água, estradas e estruturas.
static func livre(p: Vector2, m: float, segs: Array) -> bool:
	if p.x < 120.0 or p.y < 120.0 or p.x > LARG - 120.0 or p.y > ALT - 120.0:
		return false
	if CIDADE.grow(m).has_point(p):
		return false
	if p.distance_to(INICIO) < 900.0:
		return false
	if p.y >= RIO_Y0 and absf(p.x - rio_x(p.y)) < rio_meia(p.y) + m + 40.0:
		return false
	if cachoeira_rect().grow(m + 60.0).has_point(p):
		return false
	for r in bloqueios():
		var rr: Rect2 = r
		if rr.grow(m).has_point(p):
			return false
	for s in segs:
		var sd: Dictionary = s
		if dist_segmento(p, sd["a"], sd["b"]) < float(sd["w"]) * 0.5 + m:
			return false
	return true


static func zona(p: Vector2) -> String:
	_dados()
	if CIDADE.has_point(p):
		return "urbano"
	for a in _aldeias:
		var ad: Dictionary = a
		var ar: Rect2 = ad["area"]
		if ar.has_point(p):
			return "aldeia"
	for c in _camps:
		var cd: Dictionary = c
		var cc: Vector2 = cd["c"]
		if p.distance_to(cc) < 900.0:
			return "acampamento"
	if RUINAS.has_point(p):
		return "ruina"
	var b := bioma_id(bioma_valor(p.x, p.y))
	return "mata" if b == 0 else ("semiarido" if b == 1 else "deserto")


static func nome_bioma(b: int) -> String:
	return "Floresta Tropical" if b == 0 else ("Semiárido" if b == 1 else "Deserto")


# ───────────────────────────── cidade ─────────────────────────────

## Faixas de rua (calçada + asfalto + calçada) que tocam o retângulo r. v = corre ao longo de y.
static func ruas(r: Rect2) -> Array:
	var res: Array = []
	if not CIDADE.intersects(r):
		return res
	for i in 4:
		var b := Rect2(CIDADE.position.x + i * BLOCO, CIDADE.position.y, RUA, CIDADE.size.y)
		if b.intersects(r):
			res.append({"r": b, "v": true})
	for j in 5:
		var b2 := Rect2(CIDADE.position.x, CIDADE.position.y + j * BLOCO, CIDADE.size.x, RUA)
		if b2.intersects(r):
			res.append({"r": b2, "v": false})
	return res



# ───────────────────────────── planejamento do chunk ─────────────────────────────

static func _dividir(a: Vector2, b: Vector2, passo: float) -> Array:
	var n: int = maxi(1, ceili(a.distance_to(b) / passo))
	var res: Array = []
	for i in n:
		res.append([a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n)])
	return res


static func _tipo_arvore(rng: RandomNumberGenerator, b: int) -> String:
	if b == 0:
		var t: float = rng.randf()
		if t < 0.33:
			return "arvore_frondosa"
		if t < 0.57:
			return "arvore_jovem"
		if t < 0.78:
			return "palmeira"
		return "arvore_fina"
	if b == 1:
		return "arvore_outono" if rng.randf() < 0.22 else "arvore_morta"
	return "arvore_morta"


## Lista de "specs" (dicionários) do que existe no chunk c. `vivos` < 0 = sorteio normal de inimigos;
## >= 0 = quantos inimigos restam (o jogador já matou o resto numa visita anterior).
static func planejar(c: Vector2i, vivos: int) -> Array:
	_dados()
	var r := Rect2(c.x * CH, c.y * CH, CH, CH)
	var rng := RandomNumberGenerator.new()
	rng.seed = ((c.x * 73856093) ^ (c.y * 19349663) ^ (SEMENTE * 83492791)) & 0x7fffffff
	var segs := segmentos(r.grow(700.0))
	var specs: Array = []
	var centro := r.get_center()
	var z := zona(centro)

	# ---- cidade: lotes (casas e prédios modulares), entulho, carros nas ruas ----
	if CIDADE.intersects(r):
		_planejar_cidade(c, r, rng, specs, vivos)
	# ---- vilarejos ----
	for a in _aldeias:
		var ad: Dictionary = a
		for cs in ad["casas"]:
			var cd: Dictionary = cs
			var cp: Vector2 = cd["p"]
			if r.has_point(cp):
				specs.append({"k": "edificio", "p": cp, "w": cd["w"], "h": cd["h"], "f": cd["f"], "sem": cd["sem"], "mor": cd["mor"]})
				if rng.randf() < 0.6:
					specs.append({"k": "prop", "n": "caixote", "p": cp + Vector2(rng.randf_range(0.0, 400.0), (6 * 64 + 40) if cd["f"] == "s" else -50), "loot": "caixa"})
		for cg in ad["cercas"]:
			_specs_cerca(cg, r, specs)
	# ---- acampamentos e cachoeira ----
	for cm in _camps:
		_planejar_acampamento(cm, r, rng, specs)
	var cach := cachoeira_pos()
	if r.has_point(cach):
		specs.append({"k": "cachoeira", "p": cach})
	# ---- casa isolada na roça (rural: margem leste e semiárido) ----
	if z == "mata" or z == "semiarido":
		_casa_isolada(c, specs)
	# ---- carros na estrada ----
	_carros_estrada(r, rng, segs, specs)
	# ---- vegetação, pedras, cactos, ruínas ----
	if z != "urbano":
		_natureza(r, rng, segs, specs, z)
	_coletas(c, r, segs, z, specs)
	# ---- inimigos por zona ----
	_inimigos(r, rng, segs, specs, z, vivos)
	return specs


static func _planejar_cidade(c: Vector2i, r: Rect2, rng: RandomNumberGenerator, specs: Array, vivos: int) -> void:
	# quarteirões especiais (Quadras: escola, hospital, comércio, igreja, posto...) e postes nas calçadas
	specs.append_array(Quadras.specs_no(r))
	Quadras.postes_no(r, specs)
	# ratos saindo dos bueiros (V13: 40%), só na primeira visita ao chunk
	if vivos < 0:
		for b in Quadras.bueiros_no(r):
			if rng.randf() < 0.4:
				specs.append({"k": "inimigo", "raca": "rat", "p": (b as Vector2) + Vector2(rng.randf_range(-80.0, 80.0), rng.randf_range(40.0, 120.0))})
	# carros abandonados e entulho nas ruas
	var faixas := ruas(r)
	if faixas.is_empty():
		return
	var colocados: Array = []
	for k in rng.randi_range(1, 3):
		var fd: Dictionary = faixas[rng.randi() % faixas.size()]
		var fr: Rect2 = fd["r"]
		var area := fr.intersection(r)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			continue
		var vertical: bool = fd["v"]
		var lado: float = 1.0 if rng.randf() < 0.5 else -1.0
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if vertical:
			p.x = fr.position.x + RUA * 0.5 + lado * 70.0
		else:
			p.y = fr.position.y + RUA * 0.5 + lado * 70.0
		var ok := not Quadras.perto_rotatoria(p, Quadras.ROT_RI + 2.5)   # nada em cima da ilha da rotatória
		for q in colocados:
			var qp: Vector2 = q
			if qp.distance_to(p) < 300.0:
				ok = false
		if not ok:
			continue
		colocados.append(p)
		var proa: float = (PI * 0.5 if lado > 0.0 else -PI * 0.5) if vertical else (0.0 if lado > 0.0 else PI)
		proa += rng.randf_range(-0.18, 0.18)
		_carro(rng, p, proa, specs)
	if rng.randf() < 0.3:
		var fd2: Dictionary = faixas[rng.randi() % faixas.size()]
		var fr2: Rect2 = fd2["r"]
		var a2 := fr2.intersection(r)
		if a2.size.x > 0.0 and a2.size.y > 0.0:
			var nome: String = ["barreira_listrada", "barreira_quebrada", "entulho_pedras"][rng.randi() % 3]
			var pb := Vector2(rng.randf_range(a2.position.x, a2.end.x), rng.randf_range(a2.position.y, a2.end.y))
			if not Quadras.perto_rotatoria(pb, Quadras.ROT_RI + 2.5):
				specs.append({"k": "prop", "n": nome, "p": pb})


static func _carro(rng: RandomNumberGenerator, p: Vector2, proa: float, specs: Array) -> void:
	if rng.randf() < 0.18:
		specs.append({"k": "prop", "n": "carro_capo_aberto", "p": p})
		return
	var modelo: String = ["kombi", "picape", "jipe", "sedan_amarelo", "sedan_enferrujado"][rng.randi() % 5]
	specs.append({"k": "carro", "n": modelo, "p": p, "proa": proa})


static func _planejar_acampamento(cm: Dictionary, r: Rect2, rng: RandomNumberGenerator, specs: Array) -> void:
	var cc: Vector2 = cm["c"]
	var hw: float = cm["hw"]
	var hh: float = cm["hh"]
	var gate: String = cm["gate"]
	var est: String = "palicada" if int(cm["est"]) == 0 else "arame"
	var ret := Rect2(cc.x - hw, cc.y - hh, hw * 2.0, hh * 2.0)
	var gc: float = cc.x
	for cg in _cerca_ret(ret, gate, gc, 300.0, est):
		_specs_cerca(cg, r, specs, true)
	var tendas: Array = [Vector2(-400, -330), Vector2(-130, -340), Vector2(150, -330), Vector2(410, -310),
		Vector2(-440, 40), Vector2(440, 60)]
	for i in tendas.size():
		var tp: Vector2 = cc + (tendas[i] as Vector2)
		if r.has_point(tp):
			specs.append({"k": "tenda", "p": tp, "cor": i % 3})
	if r.has_point(cc + Vector2(0, 40)):
		specs.append({"k": "fogueira", "p": cc + Vector2(0, 40)})
	var gy: float = (hh - 30.0) if gate == "s" else (-hh + 30.0)
	var itens: Array = [
		["caixote", Vector2(-220, 190), "caixa"], ["caixa_madeira", Vector2(250, 200), "caixa"],
		["barril_azul", Vector2(-330, -120), ""], ["caixote", Vector2(340, -140), "caixa"],
		["sacos_areia_a", Vector2(-230, gy), ""], ["sacos_areia_b", Vector2(230, gy), ""]]
	for it in itens:
		var arr: Array = it
		var ip: Vector2 = cc + (arr[1] as Vector2)
		if r.has_point(ip):
			specs.append({"k": "prop", "n": arr[0], "p": ip, "loot": arr[2]})


static func _rng_chunk(c: Vector2i, sal: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = ((c.x * 73856093) ^ (c.y * 19349663) ^ (SEMENTE * 83492791) ^ (sal * 2654435)) & 0x7fffffff
	return g


## Casa isolada na roça (7% dos chunks rurais): devolve {casa, plantio, kind} ou {} se não houver.
static func casa_isolada_em(c: Vector2i) -> Dictionary:
	_dados()
	var r := Rect2(c.x * CH, c.y * CH, CH, CH)
	var z := zona(r.get_center())
	if z != "mata" and z != "semiarido":
		return {}
	if _rng_chunk(c, 7).randf() > 0.07:
		return {}
	var segs := segmentos(r.grow(700.0))
	var casa := Rect2(r.position + Vector2(96.0, 96.0), Vector2(448.0, 384.0))
	var plantio := Rect2(r.position + Vector2(96.0, 600.0), Vector2(800.0, 330.0))
	for q in [casa.get_center(), plantio.get_center(), casa.position, casa.end, plantio.position, plantio.end]:
		var qp: Vector2 = q
		if not livre(qp, 80.0, segs):
			return {}
	return {"casa": casa, "plantio": plantio, "kind": "plantio" if z == "mata" else "seco"}


static func _casa_isolada(c: Vector2i, specs: Array) -> void:
	var d := casa_isolada_em(c)
	if d.is_empty():
		return
	var casa: Rect2 = d["casa"]
	var plantio: Rect2 = d["plantio"]
	var tudo := Rect2(-1e7, -1e7, 2e7, 2e7)        # a casa isolada inteira pertence ao chunk que a sorteou
	for cg in _cerca_ret(casa.grow(70.0), "s", casa.get_center().x, 200.0, "madeira"):
		_specs_cerca(cg, tudo, specs)
	for cg2 in _cerca_ret(plantio.grow(30.0), "n", plantio.get_center().x, 240.0, "arame"):
		_specs_cerca(cg2, tudo, specs)
	specs.append({"k": "edificio", "p": casa.position, "w": 7, "h": 6, "f": "s",
		"sem": _rng_chunk(c, 99).randi() % 100000, "mor": 1})


static func _carros_estrada(r: Rect2, rng: RandomNumberGenerator, segs: Array, specs: Array) -> void:
	var estradas_t: Array = []
	for s in segs:
		var sd: Dictionary = s
		if sd["t"] == "terra":
			estradas_t.append(sd)
	if estradas_t.is_empty() or rng.randf() > 0.30:
		return
	var s2: Dictionary = estradas_t[rng.randi() % estradas_t.size()]
	var a: Vector2 = s2["a"]
	var b: Vector2 = s2["b"]
	var t: float = rng.randf()
	var dir := (b - a).normalized()
	var lado: float = 1.0 if rng.randf() < 0.5 else -1.0
	var p: Vector2 = a.lerp(b, t) + dir.orthogonal() * 60.0 * lado
	if not r.has_point(p) or ponte().grow(300.0).has_point(p):
		return
	_carro(rng, p, dir.angle() + (0.0 if rng.randf() < 0.5 else PI) + rng.randf_range(-0.2, 0.2), specs)


static func _natureza(r: Rect2, rng: RandomNumberGenerator, segs: Array, specs: Array, z: String) -> void:
	var passo := 256.0
	for j in 4:
		for i in 4:
			var p: Vector2 = r.position + Vector2((i + rng.randf()) * passo, (j + rng.randf()) * passo)
			var dado: float = rng.randf()
			var dado2: float = rng.randf()
			var v := bioma_valor(p.x, p.y)
			var b: int
			if v <= 1.0:
				b = 1 if dado2 < v else 0
			else:
				b = 2 if dado2 < v - 1.0 else 1
			if not livre(p, 70.0, segs):
				continue
			var f := floresta(p)
			var pt := 0.0
			var pc := 0.0
			var pr := 0.0
			if b == 0:
				pt = 0.20 + 0.70 * smoothstep(0.38, 0.62, f)
				if dist_trilha(p, segs) < 520.0:
					pt = 0.97                                   # trilha fechada: mata cerrada dos dois lados
				if p.y >= RIO_Y0 and absf(p.x - rio_x(p.y)) < rio_meia(p.y) + 700.0:
					pt = minf(0.98, pt + 0.15)
			elif b == 1:
				pt = 0.05
				pc = 0.10 + 0.14 * f
				pr = 0.04
			else:
				pt = 0.012
				pc = 0.035
				pr = 0.07
			if z == "aldeia":
				pt *= 0.25
				pc *= 0.25
			if z == "ruina":
				pt = 0.05
				pr = 0.22
			if dado < pt:
				var nome := _tipo_arvore(rng, b)
				specs.append({"k": "prop", "n": nome, "p": p, "col": "arvore"})
			elif dado < pt + pc:
				specs.append({"k": "cacto", "p": p, "v": rng.randi() % 3})
			elif dado < pt + pc + pr:
				var laje: bool = rng.randf() < 0.4
				specs.append({"k": "prop", "n": "entulho_laje" if laje else "entulho_pedras", "p": p, "col": "rocha" if laje else ""})
	var passo2 := 128.0
	for j in 8:
		for i in 8:
			var q: Vector2 = r.position + Vector2((i + rng.randf()) * passo2, (j + rng.randf()) * passo2)
			var d1: float = rng.randf()
			var v2 := bioma_valor(q.x, q.y)
			var b2: int
			if v2 <= 1.0:
				b2 = 1 if rng.randf() < v2 else 0
			else:
				b2 = 2 if rng.randf() < v2 - 1.0 else 1
			var pd: float
			if b2 == 0:
				pd = 0.08 + 0.22 * floresta(q)
				if dist_trilha(q, segs) < 520.0:
					pd = 0.35
			elif b2 == 1:
				pd = 0.11
			else:
				pd = 0.02
			if z == "ruina":
				pd = 0.0
			if d1 < pd and livre(q, 30.0, segs):
				var nomes: Array
				if b2 == 0:
					nomes = ["mato_alto", "mato_fino", "capim_alto", "arbusto_largo", "arbusto_redondo", "arbusto_folhudo"]
				elif b2 == 1:
					nomes = ["mato_seco", "capim", "arbusto_baixo", "mato_rasteiro", "mato_seco"]
				else:
					nomes = ["mato_seco", "mato_rasteiro"]
				specs.append({"k": "prop", "n": nomes[rng.randi() % nomes.size()], "p": q})
	if z == "ruina":
		for k in rng.randi_range(2, 5):
			var rp: Vector2 = r.position + Vector2(rng.randf_range(80.0, 940.0), rng.randf_range(80.0, 940.0))
			if livre(rp, 90.0, segs):
				var ruina: String = ["entulho_laje", "entulho_pedras", "barreira_quebrada", "carro_capo_aberto", "arvore_morta", "sacos_areia_b"][rng.randi() % 6]
				specs.append({"k": "prop", "n": ruina, "p": rp, "col": "rocha" if ruina == "entulho_laje" else ""})


## Galhos e pedras pequenas pegos com E (V13: natural(1600, branch/pebble) e o anel em volta do início, l.967-968).
## RNG próprio por chunk, para não mexer no sorteio da vegetação.
static func _coletas(c: Vector2i, r: Rect2, segs: Array, z: String, specs: Array) -> void:
	if z != "urbano" and z != "ruina":
		var g := _rng_chunk(c, 31)
		for k in g.randi_range(2, 6):
			var p: Vector2 = r.position + Vector2(g.randf_range(24.0, CH - 24.0), g.randf_range(24.0, CH - 24.0))
			var v := bioma_valor(p.x, p.y)
			var tipo := "galho" if g.randf() < clampf(0.6 - 0.45 * v, 0.0, 0.6) else "pedrinha"
			var var_ := g.randi() % 6
			if livre(p, 20.0, segs):
				specs.append({"k": "coleta", "t": tipo, "p": p, "v": var_})
	# anel em volta do ponto inicial: o jogador nasce com material à mão para o primeiro machado
	if r.grow(700.0).has_point(INICIO):
		var g2 := RandomNumberGenerator.new()
		g2.seed = SEMENTE * 31 + 7
		for i in 24:
			var a := g2.randf() * TAU
			var d := g2.randf_range(150.0, 690.0)
			var q := INICIO + Vector2.from_angle(a) * d
			var vv := g2.randi() % 6
			if r.has_point(q) and not CIDADE.grow(20.0).has_point(q) and agua_em(q.x, q.y) == 0:
				specs.append({"k": "coleta", "t": "galho" if i % 2 == 1 else "pedrinha", "p": q, "v": vv})


static func _inimigos(r: Rect2, rng: RandomNumberGenerator, segs: Array, specs: Array, z: String, vivos: int) -> void:
	var n: int = 0
	match z:
		"urbano":
			n = rng.randi_range(1, 3)
		"aldeia":
			n = 1 if rng.randf() < 0.45 else 0
		"mata":
			n = 1 if rng.randf() < 0.40 else 0
		"semiarido":
			n = 1 if rng.randf() < 0.28 else 0
		"deserto":
			n = 1 if rng.randf() < 0.20 else 0
		"ruina":
			n = rng.randi_range(0, 2)
	if vivos >= 0:
		n = mini(n, vivos)
	var faixas := ruas(r)
	for k in n:
		var p := Vector2.ZERO
		var achou := false
		for tent in 12:
			if z == "urbano":
				if faixas.is_empty():
					break
				var fd: Dictionary = faixas[rng.randi() % faixas.size()]
				var area: Rect2 = (fd["r"] as Rect2).intersection(r)
				if area.size.x <= 0.0 or area.size.y <= 0.0:
					continue
				p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
				achou = true
				break
			p = r.position + Vector2(rng.randf_range(60.0, 960.0), rng.randf_range(60.0, 960.0))
			if livre(p, 50.0, segs) and agua_em(p.x, p.y) == 0:
				achou = true
				break
		if not achou or p.distance_to(INICIO) < 1500.0:
			continue
		var t: float = rng.randf()
		var raca: String
		if z == "urbano":
			raca = "zombie" if t < 0.72 else ("vampire" if t < 0.88 else "rat")
		elif z == "mata" or z == "aldeia":
			raca = "rat" if t < 0.45 else ("zombie" if t < 0.85 else "vampire")
		else:
			raca = "zombie" if t < 0.6 else ("rat" if t < 0.85 else "vampire")
		specs.append({"k": "inimigo", "raca": raca, "p": p})
