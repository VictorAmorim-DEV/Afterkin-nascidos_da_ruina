class_name MundoGen
extends RefCounted
## Geração do mundo aberto. Tudo aqui é DETERMINÍSTICO: qualquer chunk pode ser gerado, descartado e gerado de novo
## igual, sem tabela do mapa inteiro em memória além do raster do mapa-múndi.
##
## O mapa-múndi (assets/new_assets/mapa_mundi_hd.png) é o guia geográfico: MapaMundi lê o raster derivado dele e
## responde terreno, mata, bioma e água em qualquer ponto. A ilha tem ~5 × 4,7 km (1 px do mapa = 3 tiles):
##   costa, praias e ilhotas; montanha nevada ao norte; lago com represa e cachoeira no nordeste; rio descendo até o
##   porto a oeste (as rodovias passam por pontes); delta pantanoso no sudoeste; deserto com cânion no sudeste,
##   com transição larga e orgânica pelo semiárido; rodovias e estradas de terra do próprio mapa.
## Por cima disso, o que o mapa só sugere vira conteúdo: as cidades (AREAS, quarteirões da V13), vilarejos com roças,
## casas isoladas, acampamentos com trilhas, ninhos de morcegos, carros abandonados, vegetação e inimigos.

const CH := 1024.0
const LARG := 251904.0            ## MapaMundi.largura()
const ALT := 230208.0             ## MapaMundi.altura()
const NX := 246                   ## chunks
const NY := 225
const SEMENTE := 1337

const BLOCO := 3072.0
const RUA := 512.0
const CALCADA := 128.0

## Áreas urbanas onde o mapa tem cidade (origem em px do mapa; nx × ny quarteirões de BLOCO com ruas de RUA).
## A 0 (Porto Atlântico) leva o programa da cidade da V13 (rotatória, praça, hospital, escola...) e o cais a oeste.
## "cat" (categoria, para o mapa): cidade_grande, cidade, povoado (1–2 quarteirões de asfalto) ou especial.
## Nomes e categorias de 17/11/2026 (docs/DECISOES_DESIGN.md, ajustes do playtest), sujeitos a mudança.
const AREAS := [
	{"m": Vector2(168, 488), "nx": 7, "ny": 5, "nome": "Porto Atlântico", "cat": "cidade_grande"},
	{"m": Vector2(518, 270), "nx": 5, "ny": 3, "nome": "Baía Dourada", "cat": "cidade_grande"},
	{"m": Vector2(860, 150), "nx": 2, "ny": 1, "nome": "Vila do Lago", "cat": "povoado"},
	{"m": Vector2(1063, 255), "nx": 3, "ny": 3, "nome": "Base Militar Sentinela", "cat": "especial"},
	{"m": Vector2(1060, 548), "nx": 3, "ny": 1, "nome": "Aeroporto Costa Leste", "cat": "especial"},
	{"m": Vector2(668, 548), "nx": 2, "ny": 2, "nome": "Cruz das Almas", "cat": "cidade"},
	{"m": Vector2(419, 693), "nx": 3, "ny": 2, "nome": "São Jorge", "cat": "cidade"},
	{"m": Vector2(556, 1010), "nx": 2, "ny": 1, "nome": "Enseada do Sul", "cat": "cidade"},
	{"m": Vector2(600, 955), "nx": 2, "ny": 1, "nome": "Cruzeiro", "cat": "cidade"},
	{"m": Vector2(965, 1000), "nx": 2, "ny": 1, "nome": "Poeira", "cat": "cidade"},
	{"m": Vector2(1150, 995), "nx": 1, "ny": 1, "nome": "Forte do Leste", "cat": "especial"},
	{"m": Vector2(698, 316), "nx": 1, "ny": 1, "nome": "Recanto dos Ipês", "cat": "povoado"},
	{"m": Vector2(786, 648), "nx": 1, "ny": 1, "nome": "Posto da Estrada", "cat": "povoado"},
	{"m": Vector2(917, 724), "nx": 1, "ny": 1, "nome": "Mirante do Vale", "cat": "povoado"},
	{"m": Vector2(1153, 711), "nx": 2, "ny": 1, "nome": "Areal", "cat": "povoado"},
	{"m": Vector2(343, 990), "nx": 1, "ny": 1, "nome": "Vila do Delta", "cat": "povoado"},
]
const CIDADE := Rect2(168.0 * 192.0, 488.0 * 192.0, 7.0 * 3072.0 + 512.0, 5.0 * 3072.0 + 512.0)   ## = area_rect(0)

## Vilarejos (V13: vilarejo): casas dos dois lados de uma estrada de terra leste–oeste e roças cercadas ao sul.
## [nome, px do mapa do começo da rua, nº de lotes, bioma das roças (0 verde, 1 seco)]
const VILAREJOS := [["Vila das Roças", Vector2(196, 712), 6, 0], ["Vila Nova da Serra", Vector2(380, 230), 5, 0],
	["Sítio da Serra", Vector2(300, 340), 4, 0], ["Vila dos Pescadores", Vector2(1180, 420), 4, 0],
	["Fazenda Seca", Vector2(760, 700), 4, 1], ["Rancho do Cânion", Vector2(880, 790), 3, 1]]
## Acampamentos (V13: acampamento) perto da água: [nome, px aproximado; o ponto exato é achado na margem]
const ACAMPAMENTOS := [["Acampamento Lago da Águia", Vector2(815, 250)], ["Acampamento Santuário do Sol", Vector2(565, 445)],
	["Acampamento Mangue Vermelho", Vector2(265, 845)]]
## Cachoeira na saída do lago norte (px do mapa).
const CACHOEIRA_M := Vector2(820, 175)

const INICIO := Vector2(335.5 * 192.0, 527.5 * 192.0)   ## na rodovia, saindo do Porto para leste

static var _rf: FastNoiseLite = null
static var _rp: FastNoiseLite = null
static var _estradas: Array = []
static var _aldeias: Array = []
static var _camps: Array = []
static var _bloq: Array = []
static var _cach: Dictionary = {}
static var _pronto := false


# ───────────────────────────── ruído, biomas e terreno ─────────────────────────────

static func _ruidos() -> void:
	if _rf != null:
		return
	_rf = FastNoiseLite.new()
	_rf.seed = SEMENTE + 1
	_rf.frequency = 0.0007
	_rp = FastNoiseLite.new()
	_rp.seed = SEMENTE + 2
	_rp.frequency = 0.0016


## 0 = tropical, 1 = semiárido, 2 = deserto; contínuo nas transições (do mapa).
static func bioma_valor(x: float, y: float) -> float:
	return MapaMundi.bioma(x, y)


static func bioma_id(v: float) -> int:
	if v < 0.5:
		return 0
	return 1 if v < 1.5 else 2


## Densidade da mata: o mapa dá a mancha, o ruído varia dentro dela.
static func floresta(p: Vector2) -> float:
	_ruidos()
	return clampf(MapaMundi.mata(p.x, p.y) * 0.85 + (_rf.get_noise_2d(p.x, p.y) + 1.0) * 0.15, 0.0, 1.0)


static func ruido_mancha(x: float, y: float) -> float:
	_ruidos()
	return (_rp.get_noise_2d(x, y) + 1.0) * 0.5


## 0 = seco, 1 = raso (anda devagar), 2 = fundo (bloqueado por colisão). Pontes já são terra no mapa.
static func agua_em(x: float, y: float) -> int:
	return MapaMundi.agua(x, y)


## Fator de velocidade a pé no ponto de mundo p (água rasa atrapalha).
static func fator_terreno(p: Vector2) -> float:
	var a := agua_em(p.x, p.y)
	if a == 1:
		return 0.62
	if a == 2:
		return 0.4
	return 1.0


## Estrada do mapa (rodovia ou terra) sob o ponto, fora das cidades.
static func na_estrada(p: Vector2) -> bool:
	var k := MapaMundi.classe(p.x, p.y)
	return (k == MapaMundi.URBANO or k == MapaMundi.TERRA) and not urbano_em(p, 0.0)


## Chão que levanta poeira atrás das rodas: estrada de terra, areia, rocha e o mato seco do semiárido.
static func poeira_em(p: Vector2) -> bool:
	if urbano_em(p, 0.0) or MapaMundi.sd(p.x, p.y) > -0.2:
		return false
	match MapaMundi.classe(p.x, p.y):
		MapaMundi.TERRA, MapaMundi.DESERTO, MapaMundi.PRAIA, MapaMundi.CANION, MapaMundi.ROCHA:
			return true
		MapaMundi.URBANO:
			return false
	return bioma_valor(p.x, p.y) > 0.7


# ───────────────────────────── cachoeira ─────────────────────────────

## {p: base do paredão no meio do rio, meia: meia largura do rio ali}.
static func cachoeira() -> Dictionary:
	if not _cach.is_empty():
		return _cach
	var c := MapaMundi.mundo(CACHOEIRA_M + Vector2(0.5, 0.5))
	var esq := c.x
	var dir := c.x
	while MapaMundi.sd(esq - 32.0, c.y) > 0.0 and c.x - esq < 3000.0:
		esq -= 32.0
	while MapaMundi.sd(dir + 32.0, c.y) > 0.0 and dir - c.x < 3000.0:
		dir += 32.0
	_cach = {"p": Vector2((esq + dir) * 0.5, c.y), "meia": (dir - esq) * 0.5}
	return _cach


static func cachoeira_pos() -> Vector2:
	return cachoeira()["p"]


## Paredão da cachoeira (bloqueia a passagem): faixa de rocha atravessando o rio e as margens.
static func cachoeira_rect() -> Rect2:
	var c := cachoeira_pos()
	var w: float = float(cachoeira()["meia"]) + 500.0
	return Rect2(c.x - w, c.y - 200.0, w * 2.0, 264.0)


# ───────────────────────────── vilarejos, acampamentos, trilhas ─────────────────────────────

static func _dados() -> void:
	if _pronto:
		return
	_pronto = true
	_ruidos()
	MapaMundi.carregar()
	for v in VILAREJOS:
		var vd: Array = v
		var a := _aldeia(vd[0], MapaMundi.mundo(vd[1]), vd[2], vd[3], 101 + _aldeias.size() * 101)
		if not (a["casas"] as Array).is_empty():
			var com := Comunidades.do_local(str(vd[0]))
			if com != "":
				_murar_aldeia(a, com)
			_aldeias.append(a)
	for k in ACAMPAMENTOS.size():
		var cd: Array = ACAMPAMENTOS[k]
		var c := _margem(MapaMundi.mundo(cd[1]), 60)
		if c == Vector2.INF:
			continue
		var gate := "s" if k % 2 == 0 else "n"
		var camp := {"c": c, "hw": 640.0, "hh": 512.0, "est": k % 2, "gate": gate, "nome": cd[0]}
		_camps.append(camp)
		# trilha fechada na mata: do portão até a estrada do mapa mais próxima
		var portao := c + Vector2(0.0, 520.0 if gate == "s" else -520.0)
		var fim := _estrada_mais_proxima(portao, 90)
		if fim != Vector2.INF:
			var pts := PackedVector2Array([portao])
			var n := maxi(2, int(portao.distance_to(fim) / 900.0))
			var g := RandomNumberGenerator.new()
			g.seed = SEMENTE + k * 17
			var lado := (fim - portao).normalized().orthogonal()
			for i in range(1, n):
				pts.append(portao.lerp(fim, float(i) / n) + lado * g.randf_range(-260.0, 260.0))
			pts.append(fim)
			_estradas.append({"pts": pts, "w": 120.0, "t": "trilha"})
	_bloq.clear()
	for a2 in _aldeias:
		var ad: Dictionary = a2
		for l in ad["lotes"]:
			_bloq.append(l)
		for p in ad["plantios"]:
			_bloq.append(((p as Dictionary)["r"] as Rect2).grow(60.0))
		if ad.has("muro"):
			_bloq.append((ad["muro"] as Rect2).grow(60.0))       # nada de mato e árvore dentro da comunidade
	for c2 in _camps:
		var cdd: Dictionary = c2
		var cc: Vector2 = cdd["c"]
		_bloq.append(Rect2(cc.x - float(cdd["hw"]) - 120.0, cc.y - float(cdd["hh"]) - 120.0,
			float(cdd["hw"]) * 2.0 + 240.0, float(cdd["hh"]) * 2.0 + 240.0))


## Ponto de mata perto (10–20 m) da água, buscando em anéis em volta de p (raio em px do mapa); INF se não achar.
static func _margem(p: Vector2, raio: int) -> Vector2:
	for r in range(0, raio):
		for k in 24:
			var q := p + Vector2.from_angle(TAU * k / 24.0) * r * MapaMundi.ESCALA
			var s := MapaMundi.sd(q.x, q.y)
			var ok := s < -2.6 and s > -5.0
			for d in [Vector2(-700, -600), Vector2(700, -600), Vector2(-700, 600), Vector2(700, 600)]:
				var qd: Vector2 = q + d
				if MapaMundi.sd(qd.x, qd.y) > -0.3 or urbano_em(qd, 200.0) or na_estrada(qd):
					ok = false
			if ok:
				return q
	return Vector2.INF


## Ponto de estrada do mapa (rodovia ou terra) mais próximo de p, num raio em px do mapa; INF se não houver.
static func _estrada_mais_proxima(p: Vector2, raio: int) -> Vector2:
	for r in range(1, raio):
		for k in 32:
			var q := p + Vector2.from_angle(TAU * k / 32.0) * r * MapaMundi.ESCALA
			if na_estrada(q):
				return q
	return Vector2.INF


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


## Terreno firme e livre de cidade num retângulo (cantos e centro)?
static func _terra_firme(r: Rect2) -> bool:
	for q in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]:
		var qp: Vector2 = q
		if MapaMundi.sd(qp.x, qp.y) > -0.6 or urbano_em(qp, 100.0):
			return false
	return true


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
			var sp := {"k": "portao", "a": sa, "b": sb, "e": "ferro" if ferro else "madeira",
				"aberto": (not ferro) and h < 35}
			if seg.size() > 4:
				sp["com"] = seg[4]                 # portão de comunidade: abre e fecha pelo horário (Comunidades)
				sp["e"] = "ferro"
			specs.append(sp)
		return
	for pedaco in _dividir(sa, sb, 256.0):
		var pa: Vector2 = pedaco[0]
		var pb: Vector2 = pedaco[1]
		if r.has_point((pa + pb) * 0.5):
			specs.append({"k": "cerca", "a": pa, "b": pb, "e": seg[2]})


## Vilarejo (V13: vilarejo): rua de terra leste–oeste em 'o.y' a partir de 'o.x'; lotes que caem na água ou numa
## cidade ficam de fora.
static func _aldeia(nome: String, o: Vector2, n: int, bio: int, sem: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sem
	var casas: Array = []
	var cercas: Array = []
	var plantios: Array = []
	var lotes: Array = []
	var yc := o.y
	var x0 := o.x
	for i in n:
		var lx: float = x0 + i * 832.0
		for lado in [0, 1]:
			if rng.randf() < 0.10:
				continue
			var norte: bool = lado == 0
			var hy: float = (yc - 128.0 - 110.0 - 384.0) if norte else (yc + 128.0 + 110.0)
			var hx: float = lx + 128.0
			var ly0: float = (hy - 90.0) if norte else (yc + 128.0 + 36.0)
			var ly1: float = (yc - 128.0 - 36.0) if norte else (hy + 384.0 + 90.0)
			var lote := Rect2(lx + 60.0, ly0, 640.0, ly1 - ly0)
			if not _terra_firme(lote):
				continue
			casas.append({"p": Vector2(hx, hy), "w": 7, "h": 6, "f": ("s" if norte else "n"),
				"mor": rng.randi_range(0, 1), "sem": rng.randi() % 100000})
			lotes.append(lote)
			cercas.append_array(_cerca_ret(lote, "s" if norte else "n", hx + 224.0, 224.0, "madeira"))
	var fim: float = x0 + n * 832.0
	var py0: float = yc + 128.0 + 110.0 + 384.0 + 260.0
	var k := 0
	while x0 + 100.0 + k * 1100.0 + 960.0 < fim + 300.0:
		var pr := Rect2(x0 + 100.0 + k * 1100.0, py0, 960.0, 720.0)
		if _terra_firme(pr.grow(40.0)):
			plantios.append({"r": pr, "k": ("plantio" if bio == 0 else "seco")})
			cercas.append_array(_cerca_ret(pr.grow(40.0), "n", pr.position.x + 480.0, 256.0, "arame"))
		k += 1
	return {"nome": nome, "bio": bio, "casas": casas, "cercas": cercas, "plantios": plantios, "lotes": lotes,
		"area": Rect2(x0 - 300.0, yc - 1100.0, n * 832.0 + 600.0, 2900.0), "rua_y": yc, "x0": x0, "n": n}


## Vilarejo onde mora uma comunidade (Comunidades): muro de paliçada em volta das casas e da rua, com um portão
## em cada ponta da rua (oeste e leste), e a fogueira na praça. As roças ficam do lado de fora.
static func _murar_aldeia(a: Dictionary, com: String) -> void:
	var yc: float = a["rua_y"]
	var x0: float = a["x0"]
	var n: int = a["n"]
	var muro := Rect2(x0 - 150.0, yc - 800.0, n * 832.0 + 200.0, 1600.0)
	var y0 := muro.position.y
	var y1 := muro.end.y
	var portoes: Array = []
	var segs: Array = [[Vector2(muro.position.x, y0), Vector2(muro.end.x, y0), "palicada"],
		[Vector2(muro.position.x, y1), Vector2(muro.end.x, y1), "palicada"]]
	for x in [muro.position.x, muro.end.x]:
		var g0 := Vector2(x, yc - 150.0)
		var g1 := Vector2(x, yc + 150.0)
		segs.append([Vector2(x, y0), g0, "palicada"])
		segs.append([g1, Vector2(x, y1), "palicada"])
		segs.append([g0, g1, "palicada", "portao", com])
		portoes.append([g0, g1])
	(a["cercas"] as Array).append_array(segs)
	a["com"] = com
	a["muro"] = muro
	a["portoes"] = portoes
	a["fogueira"] = Vector2(muro.get_center().x, yc)


# ───────────────────────────── consultas ─────────────────────────────

## Segmentos de trilha perto do retângulo r: {a, b, w, t}.
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
	if MapaMundi.sd(p.x, p.y) > -0.35 - m / MapaMundi.ESCALA:
		return false
	if na_estrada(p) or urbano_em(p, m):
		return false
	if p.distance_to(INICIO) < 900.0:
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
	if urbano_em(p, 0.0):
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
	var b := bioma_id(bioma_valor(p.x, p.y))
	return "mata" if b == 0 else ("semiarido" if b == 1 else "deserto")


static func nome_bioma(b: int) -> String:
	return "Floresta Tropical" if b == 0 else ("Semiárido" if b == 1 else "Deserto")


## Nome do lugar para o HUD: cidade, vilarejo ou acampamento; "" no meio do mato.
static func nome_lugar(p: Vector2) -> String:
	_dados()
	for a in AREAS.size():
		if area_rect(a).grow(400.0).has_point(p):
			return AREAS[a]["nome"]
	for v in _aldeias:
		if ((v as Dictionary)["area"] as Rect2).has_point(p):
			return (v as Dictionary)["nome"]
	for c in _camps:
		if p.distance_to((c as Dictionary)["c"]) < 1100.0:
			return (c as Dictionary)["nome"]
	return ""


# ───────────────────────────── áreas urbanas ─────────────────────────────

static func area_rect(a: int) -> Rect2:
	var m: Vector2 = AREAS[a]["m"]
	var nx: int = AREAS[a]["nx"]
	var ny: int = AREAS[a]["ny"]
	return Rect2(m * MapaMundi.ESCALA, Vector2(nx * BLOCO + RUA, ny * BLOCO + RUA))


## Faixas de rua (calçada + asfalto + calçada) que tocam o retângulo r. v = corre ao longo de y; asf = retângulo do
## asfalto; sec = rua secundária (Quadras.RUAS_SECUNDARIAS: sem faixa central nem faixa de pedestre).
static func ruas(r: Rect2) -> Array:
	var res: Array = []
	if not toca_urbano(r):
		return res
	for a in AREAS.size():
		var ar := area_rect(a)
		if not ar.intersects(r):
			continue
		var nx: int = AREAS[a]["nx"]
		var ny: int = AREAS[a]["ny"]
		for i in nx + 1:
			var b := Rect2(ar.position.x + i * BLOCO, ar.position.y, RUA, ar.size.y)
			if b.intersects(r):
				res.append({"r": b, "v": true, "asf": b.grow(-CALCADA), "sec": false})
		for j in ny + 1:
			var b2 := Rect2(ar.position.x, ar.position.y + j * BLOCO, ar.size.x, RUA)
			if b2.intersects(r):
				res.append({"r": b2, "v": false, "asf": b2.grow(-CALCADA), "sec": false})
	for s in Quadras.ruas_secundarias():
		var sd: Dictionary = s
		if (sd["r"] as Rect2).intersects(r):
			res.append(sd)
	return res


## p está numa área urbana (com folga m)?
static func urbano_em(p: Vector2, m: float) -> bool:
	for a in AREAS.size():
		if area_rect(a).grow(m).has_point(p):
			return true
	return false


## r toca alguma área urbana?
static func toca_urbano(r: Rect2) -> bool:
	for a in AREAS.size():
		if area_rect(a).intersects(r):
			return true
	return false


# ───────────────────────────── ninhos de morcegos ─────────────────────────────

static var _ninhos := PackedVector2Array()


## Ninhos de morcegos (antídoto da mutação vampírica): até 10 tocas na mata fechada tropical, longe umas das
## outras, das estradas, da água e das cidades. Posições fixas pela semente.
static func ninhos() -> PackedVector2Array:
	if not _ninhos.is_empty():
		return _ninhos
	var g := RandomNumberGenerator.new()
	g.seed = SEMENTE * 977 + 13
	var tent := 0
	while _ninhos.size() < 10 and tent < 6000:
		tent += 1
		var p := Vector2(g.randf_range(2000.0, LARG - 2000.0), g.randf_range(2000.0, ALT - 2000.0))
		if MapaMundi.classe(p.x, p.y) != MapaMundi.MATA or MapaMundi.mata(p.x, p.y) < 0.75 or bioma_valor(p.x, p.y) > 0.4:
			continue
		if not livre(p, 260.0, segmentos(Rect2(p - Vector2(600, 600), Vector2(1200, 1200)))):
			continue
		var perto := false
		for q in _ninhos:
			if q.distance_to(p) < 30000.0:
				perto = true
		if not perto:
			_ninhos.append(p)
	return _ninhos


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
	# mar aberto: nada a planejar
	if MapaMundi.sd(r.get_center().x, r.get_center().y) > 6.0:
		return specs
	var z := zona(r.get_center())

	# ---- cidades: quarteirões, postes, carros nas ruas ----
	if toca_urbano(r):
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
		if ad.has("fogueira") and r.has_point(ad["fogueira"]):
			specs.append({"k": "fogueira", "p": ad["fogueira"]})
		for cg in ad["cercas"]:
			_specs_cerca(cg, r, specs)
		for p in ad["plantios"]:
			_plantacao(p, r, specs)
	# ---- acampamentos e cachoeira ----
	for cm in _camps:
		_planejar_acampamento(cm, r, rng, specs)
	var cach := cachoeira_pos()
	if r.has_point(cach):
		specs.append({"k": "cachoeira", "p": cach})
	# ---- ninhos de morcegos, com vampiros dormindo perto na primeira visita ----
	for nh in ninhos():
		var np: Vector2 = nh
		if r.has_point(np):
			specs.append({"k": "ninho", "p": np})
			if vivos < 0:
				for k in 2:
					specs.append({"k": "inimigo", "raca": "vampire", "p": np + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(260.0, 420.0)})
	# ---- casa isolada na roça ----
	if z == "mata" or z == "semiarido":
		_casa_isolada(c, specs)
	# ---- carros abandonados nas rodovias e estradas de terra do mapa ----
	_carros_estrada(r, rng, specs)
	# ---- vegetação, pedras, cactos ----
	if z != "urbano":
		_natureza(r, rng, segs, specs, z)
	_coletas(c, r, segs, z, specs)
	# ---- inimigos por zona ----
	_inimigos(r, rng, segs, specs, z, vivos)
	return specs


## Plantação (roça) com pés que balançam ao vento: um nó por roça, no chunk onde ela começa.
static func _plantacao(p: Dictionary, r: Rect2, specs: Array) -> void:
	var pr: Rect2 = p["r"]
	if r.has_point(pr.position):
		specs.append({"k": "plantacao", "r": pr, "seco": p["k"] == "seco", "p": pr.position})


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
		var mao: float = 50.0 if fd["sec"] else 70.0          # meio de cada mão
		if vertical:
			p.x = fr.get_center().x + lado * mao
		else:
			p.y = fr.get_center().y + lado * mao
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
		_carro(rng, p, proa, specs, 0.22)
	if rng.randf() < 0.3:
		var fd2: Dictionary = faixas[rng.randi() % faixas.size()]
		var fr2: Rect2 = fd2["r"]
		var a2 := fr2.intersection(r)
		if a2.size.x > 0.0 and a2.size.y > 0.0:
			var nome: String = ["barreira_listrada", "barreira_quebrada", "entulho_pedras"][rng.randi() % 3]
			var pb := Vector2(rng.randf_range(a2.position.x, a2.end.x), rng.randf_range(a2.position.y, a2.end.y))
			if not Quadras.perto_rotatoria(pb, Quadras.ROT_RI + 2.5):
				specs.append({"k": "prop", "n": nome, "p": pb})


## 'queimado' = chance de ser uma carcaça queimada (V13: 22% dos carros das vias; estacionamentos não).
static func _carro(rng: RandomNumberGenerator, p: Vector2, proa: float, specs: Array, queimado: float = 0.0) -> void:
	if rng.randf() < 0.18:
		specs.append({"k": "prop", "n": "carro_capo_aberto", "p": p})
		return
	var modelo: String = ["kombi", "picape", "jipe", "sedan_amarelo", "sedan_enferrujado"][rng.randi() % 5]
	var s := {"k": "carro", "n": modelo, "p": p, "proa": proa}
	if queimado > 0.0 and rng.randf() < queimado:
		s["queimado"] = true
	specs.append(s)


static func _planejar_acampamento(cm: Dictionary, r: Rect2, rng: RandomNumberGenerator, specs: Array) -> void:
	var cc: Vector2 = cm["c"]
	var hw: float = cm["hw"]
	var hh: float = cm["hh"]
	if not Rect2(cc.x - hw - 300.0, cc.y - hh - 300.0, hw * 2.0 + 600.0, hh * 2.0 + 600.0).intersects(r):
		return
	var gate: String = cm["gate"]
	var est: String = "palicada" if int(cm["est"]) == 0 else "arame"
	var ret := Rect2(cc.x - hw, cc.y - hh, hw * 2.0, hh * 2.0)
	var gc: float = cc.x
	var com := Comunidades.do_local(str(cm["nome"]))
	for cg in _cerca_ret(ret, gate, gc, 300.0, est):
		var seg: Array = cg
		if seg.size() > 3 and com != "":
			seg = seg + [com]                      # portão da comunidade
		_specs_cerca(seg, r, specs, true)
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


## Casa isolada na roça (8% dos chunks de campo, fora das cidades): {casa, plantio, kind} ou {} se não houver.
static func casa_isolada_em(c: Vector2i) -> Dictionary:
	var r := Rect2(c.x * CH, c.y * CH, CH, CH)
	var cen := r.get_center()
	if MapaMundi.fracao(cen.x, cen.y, MapaMundi.CAMPO) < 0.5:
		return {}
	if _rng_chunk(c, 7).randf() > 0.08:
		return {}
	_dados()
	var z := zona(cen)
	if z != "mata" and z != "semiarido":
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
	specs.append({"k": "plantacao", "r": plantio, "seco": d["kind"] == "seco", "p": plantio.position})


## Carro abandonado numa rodovia ou estrada de terra do mapa (30% dos chunks com estrada), alinhado com ela.
static func _carros_estrada(r: Rect2, rng: RandomNumberGenerator, specs: Array) -> void:
	if rng.randf() > 0.3:
		return
	for tent in 8:
		var p := r.position + Vector2(rng.randf_range(100.0, CH - 100.0), rng.randf_range(100.0, CH - 100.0))
		if not na_estrada(p):
			continue
		# direção da estrada: o eixo em que ela continua por mais tempo
		var h := 0
		var v := 0
		for k in range(-3, 4):
			if na_estrada(p + Vector2(k * 120.0, 0.0)):
				h += 1
			if na_estrada(p + Vector2(0.0, k * 120.0)):
				v += 1
		var proa: float = (0.0 if h >= v else PI * 0.5) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.2, 0.2)
		_carro(rng, p, proa, specs, 0.22)
		return


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
			var k := MapaMundi.classe(p.x, p.y)
			var f := floresta(p)
			var pt := 0.0
			var pc := 0.0
			var pr := 0.0
			var arvore := ""
			match k:
				MapaMundi.MATA:
					pt = 0.25 + 0.72 * smoothstep(0.3, 0.8, f)
				MapaMundi.CAMPO:
					pt = 0.05 + 0.1 * f
				MapaMundi.PANTANO:
					pt = 0.18
				MapaMundi.PRAIA:
					pt = 0.08
					arvore = "palmeira"
				MapaMundi.ROCHA:
					pt = 0.04
					pr = 0.16
					arvore = "arvore_morta"
				MapaMundi.NEVE:
					pr = 0.08
				MapaMundi.CANION:
					pr = 0.2
					pc = 0.03
				MapaMundi.DESERTO:
					pt = 0.012
					pc = 0.035
					pr = 0.07
			if b == 1 and (k == MapaMundi.MATA or k == MapaMundi.CAMPO):
				pt *= 0.35
				pc = 0.10 + 0.14 * f
				pr = 0.04
			if dist_trilha(p, segs) < 520.0 and b == 0:
				pt = 0.97                                   # trilha fechada: mata cerrada dos dois lados
			if z == "aldeia":
				pt *= 0.25
				pc *= 0.25
			if dado < pt:
				var nome := arvore if arvore != "" else _tipo_arvore(rng, b)
				specs.append({"k": "prop", "n": nome, "p": p, "col": "arvore"})
			elif dado < pt + pc:
				specs.append({"k": "cacto", "p": p, "v": rng.randi() % 3})
			elif dado < pt + pc + pr:
				var laje: bool = rng.randf() < 0.45
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
			var k2 := MapaMundi.classe(q.x, q.y)
			var pd: float
			if b2 == 0:
				pd = 0.08 + 0.22 * floresta(q)
				if dist_trilha(q, segs) < 520.0:
					pd = 0.35
			elif b2 == 1:
				pd = 0.11
			else:
				pd = 0.02
			if k2 == MapaMundi.PANTANO:
				pd = 0.45
			elif k2 == MapaMundi.NEVE or k2 == MapaMundi.ROCHA or k2 == MapaMundi.CANION:
				pd = 0.03
			if d1 < pd and livre(q, 30.0, segs):
				var nomes: Array
				if k2 == MapaMundi.PANTANO:
					nomes = ["capim_alto", "mato_alto", "capim_alto", "arbusto_folhudo"]
				elif b2 == 0:
					nomes = ["mato_alto", "mato_fino", "capim_alto", "arbusto_largo", "arbusto_redondo", "arbusto_folhudo"]
				elif b2 == 1:
					nomes = ["mato_seco", "capim", "arbusto_baixo", "mato_rasteiro", "mato_seco"]
				else:
					nomes = ["mato_seco", "mato_rasteiro"]
				specs.append({"k": "prop", "n": nomes[rng.randi() % nomes.size()], "p": q})


## Galhos e pedras pequenas pegos com E (V13: natural(1600, branch/pebble) e o anel em volta do início, l.967-968).
## RNG próprio por chunk, para não mexer no sorteio da vegetação.
static func _coletas(c: Vector2i, r: Rect2, segs: Array, z: String, specs: Array) -> void:
	if z != "urbano":
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
			if r.has_point(q) and not urbano_em(q, 20.0) and agua_em(q.x, q.y) == 0:
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
