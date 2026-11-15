class_name Quadras
extends RefCounted
## Quarteirões da cidade (V13: quadraComercial, quadraHospital, quadraMercado, quadraEscola, quadraIgreja, quadraPosto,
## quadraIndustrial, quadraPraca, quadraCasas/loteCasa, fileira/fabrica, estacionamento — l.741-912).
##
## Cada quarteirão é gerado UMA vez (semente fixa por coordenada) numa lista de specs + áreas de chão e fica em cache.
## Cada chunk pega só os specs cuja âncora cai dentro dele, então o mundo continua determinístico e sem costura.
## Coordenadas internas em tiles (0..N) a partir do canto noroeste do miolo do quarteirão (sem rua nem calçada).

const TILE := 64.0
const METRO := 49.48
const VPM := 30.3
const N := 42                       ## tiles por lado do miolo (BLOCO - RUA = 2688 u)

## Papel de cada quarteirão (coluna oeste→leste, linha norte→sul): o programa da cidade principal da V13 (cidadesTWD).
## O ponto inicial fica a oeste da linha 2, então o jogador entra pela vizinhança residencial.
const PAPEIS := {
	Vector2i(0, 0): "escola", Vector2i(1, 0): "hospital", Vector2i(2, 0): "industrial",
	Vector2i(0, 1): "comercial_banco", Vector2i(1, 1): "comercial_farmacia", Vector2i(2, 1): "mercado",
	Vector2i(0, 2): "casas", Vector2i(1, 2): "praca", Vector2i(2, 2): "comercial_delegacia",
	Vector2i(0, 3): "posto", Vector2i(1, 3): "igreja", Vector2i(2, 3): "casas"}

const CORES_CONTAINER := ["#3a5a7a", "#8a3a2a", "#3a6a4a", "#8a6a2a", "#5a5a5a"]
const TUDO := Rect2(-1.0e7, -1.0e7, 2.0e7, 2.0e7)

static var _cache: Dictionary = {}


## Estado da geração de um quarteirão.
class Q:
	const T := 64.0
	const NN := 42
	var X0: float
	var Y0: float
	var rng := RandomNumberGenerator.new()
	var specs: Array = []
	var chao: Array = []
	var ocup := PackedByteArray()

	func _init(x0: float, y0: float, sem: int) -> void:
		X0 = x0
		Y0 = y0
		rng.seed = sem
		ocup.resize(NN * NN)
		ocup.fill(0)

	## tile (pode ser fracionário) -> u de mundo
	func w(tx: float, ty: float) -> Vector2:
		return Vector2(X0 + tx * T, Y0 + ty * T)

	func livre(tx0: int, ty0: int, tx1: int, ty1: int) -> bool:
		if tx0 < 0 or ty0 < 0 or tx1 > NN or ty1 > NN:
			return false
		for ty in range(ty0, ty1):
			for tx in range(tx0, tx1):
				if ocup[ty * NN + tx] != 0:
					return false
		return true

	func ocupar(tx0: int, ty0: int, tx1: int, ty1: int) -> void:
		for ty in range(maxi(0, ty0), mini(NN, ty1)):
			for tx in range(maxi(0, tx0), mini(NN, tx1)):
				ocup[ty * NN + tx] = 1

	func ri(a: int, b: int) -> int:
		return rng.randi_range(a, b)

	func rf(a: float, b: float) -> float:
		return rng.randf_range(a, b)

	func pick(l: Array):
		return l[rng.randi() % l.size()]

	## Área de chão (desenhada pelo ChaoChunk por cima do concreto da cidade). t = textura ("" = cor lisa).
	func solo(tx0: float, ty0: float, tx1: float, ty1: float, t: String, c: Color = Color.WHITE) -> void:
		chao.append({"r": Rect2(w(tx0, ty0), Vector2((tx1 - tx0) * T, (ty1 - ty0) * T)), "t": t, "c": c})

	func urbano(tipo: String, x0: float, y0: float, x1: float, y1: float, h: float, solido: bool = true, extra: Dictionary = {}) -> void:
		var r := Rect2(x0, y0, x1 - x0, y1 - y0)
		specs.append({"k": "urbano", "t": tipo, "r": r, "h": h, "s": solido, "x": extra, "p": r.get_center()})

	func prop(nome: String, p: Vector2, extra: Dictionary = {}) -> void:
		var s := {"k": "prop", "n": nome, "p": p}
		s.merge(extra)
		specs.append(s)

	## Retângulo de cerca (u de mundo) com portão em 'lado' (centro 'gc', largura 'larg'); 'pular' = lados sem cerca.
	func cerca(r: Rect2, lado: String, gc: float, larg: float, estilo: String, pular: Array = []) -> void:
		for seg in MundoGen._cerca_ret(r, lado, gc, larg, estilo):
			var sg: Array = seg
			if not pular.is_empty() and _lado_do(r, sg[0], sg[1]) in pular:
				continue
			MundoGen._specs_cerca(sg, Quadras.TUDO, specs)

	static func _lado_do(r: Rect2, a: Vector2, b: Vector2) -> String:
		if is_equal_approx(a.y, r.position.y) and is_equal_approx(b.y, r.position.y):
			return "n"
		if is_equal_approx(a.y, r.end.y) and is_equal_approx(b.y, r.end.y):
			return "s"
		if is_equal_approx(a.x, r.position.x) and is_equal_approx(b.x, r.position.x):
			return "w"
		return "e"


static func zm(m: float) -> float:
	return m * VPM


static func mt(m: float) -> float:
	return m * METRO


# ═════════════════════════════════ consulta pelos chunks ═════════════════════════════════

static func _bloco_rect(i: int, j: int) -> Rect2:
	var x := MundoGen.CIDADE.position.x + i * MundoGen.BLOCO + MundoGen.RUA
	var y := MundoGen.CIDADE.position.y + j * MundoGen.BLOCO + MundoGen.RUA
	return Rect2(x, y, N * TILE, N * TILE)


static func _bloco(i: int, j: int) -> Dictionary:
	var k := Vector2i(i, j)
	if _cache.has(k):
		return _cache[k]
	var r := _bloco_rect(i, j)
	var q := Q.new(r.position.x, r.position.y, (((i * 7919) ^ (j * 104729)) + MundoGen.SEMENTE * 31337) & 0x7fffffff)
	match PAPEIS.get(k, "casas"):
		"escola": _escola(q)
		"hospital": _hospital(q)
		"industrial": _industrial(q, true)
		"comercial_banco": _comercial(q, {"s": ["banco", "apto"], "e": ["apto"]}, ["apto", "apto", "loja"])
		"comercial_farmacia": _comercial(q, {"s": ["apto", "farmacia", "apto"], "w": ["loja"]}, ["apto", "apto", "loja"])
		"comercial_delegacia": _comercial(q, {"s": ["delegacia", "loja"]}, ["apto", "loja"])
		"mercado": _mercado(q)
		"praca":
			_praca(q, 0, 0, N / 2 - 1, N)
			_casas(q, N / 2 + 1, 0, N, N)
		"posto": _posto(q)
		"igreja": _igreja(q)
		_: _casas(q, 0, 0, N, N)
	var d := {"specs": q.specs, "chao": q.chao}
	_cache[k] = d
	return d


static func _ancora(s: Dictionary) -> Vector2:
	if s.has("p"):
		return s["p"]
	if s.has("a"):
		return (s["a"] + s["b"]) * 0.5
	return Vector2.ZERO


## Specs dos quarteirões cuja âncora cai no retângulo 'r' (o chunk).
static func specs_no(r: Rect2) -> Array:
	var out: Array = []
	for i in 3:
		for j in 4:
			if not _bloco_rect(i, j).grow(4.0 * TILE).intersects(r):
				continue
			for s in _bloco(i, j)["specs"]:
				if r.has_point(_ancora(s)):
					out.append((s as Dictionary).duplicate(true))
	return out


## Áreas de chão que tocam 'r'.
static func chao_no(r: Rect2) -> Array:
	var out: Array = []
	for i in 3:
		for j in 4:
			if not _bloco_rect(i, j).intersects(r):
				continue
			for c in _bloco(i, j)["chao"]:
				if (c["r"] as Rect2).intersects(r):
					out.append(c)
	return out


## Postes nas calçadas a cada 16 tiles, alternando o lado, fora dos cruzamentos (V13: mobiliarioUrbano/LAMP).
static func postes_no(r: Rect2, specs: Array) -> void:
	var C := MundoGen.CIDADE
	var B := MundoGen.BLOCO
	var R := MundoGen.RUA
	var lado_calcada := [32.0, R - 32.0]
	for i in 4:                                       # ruas norte-sul
		var x := C.position.x + i * B
		if x + R < r.position.x or x > r.end.x:
			continue
		var k := 0
		var y := C.position.y + 512.0
		while y < C.end.y:
			var m := fposmod(y - C.position.y, B)
			if m > R + 160.0 and m < B - 160.0:
				_poste(Vector2(x + lado_calcada[k % 2], y), r, specs)
			y += 1024.0
			k += 1
	for j in 5:                                       # ruas leste-oeste
		var y2 := C.position.y + j * B
		if y2 + R < r.position.y or y2 > r.end.y:
			continue
		var k2 := 1
		var x2 := C.position.x + 512.0
		while x2 < C.end.x:
			var m2 := fposmod(x2 - C.position.x, B)
			if m2 > R + 160.0 and m2 < B - 160.0:
				_poste(Vector2(x2, y2 + lado_calcada[k2 % 2]), r, specs)
			x2 += 1024.0
			k2 += 1


static func _poste(p: Vector2, r: Rect2, specs: Array) -> void:
	if not r.has_point(p):
		return
	var fp := Rect2(p - Vector2(6, 6), Vector2(12, 12))
	specs.append({"k": "urbano", "t": "poste", "r": fp, "h": zm(6.0), "s": true, "x": {"semente": p.x * 0.013 + p.y * 0.007}, "p": p})


# ═════════════════════════════════ peças ═════════════════════════════════

## Prédio (V13: predio). Devolve false se o espaço não estiver livre.
static func _predio(q: Q, tx0: int, ty0: int, tx1: int, ty1: int, o: Dictionary) -> bool:
	if tx1 - tx0 < 5 or ty1 - ty0 < 5 or not q.livre(tx0, ty0, tx1, ty1):
		return false
	q.ocupar(tx0, ty0, tx1, ty1)
	var op := o.duplicate(true)
	op["tipo"] = "predio"
	if not op.has("cobertura"):
		op["cobertura"] = "plana"
	if not op.has("dano"):
		op["dano"] = q.rf(0.2, 0.75)
	var f: String = op.get("frente", "s")
	op.erase("frente")
	var w := tx1 - tx0
	var h := ty1 - ty0
	q.specs.append({"k": "edificio", "p": q.w(tx0, ty0), "w": w, "h": h, "f": f, "sem": q.rng.randi() % 100000,
		"mor": mini(3, q.ri(0, 1 + (w * h) / 70)), "o": op})
	if float(op["dano"]) > 0.55:                      # entulho caído na frente
		for k in 3:
			var fx := q.rf(tx0 + 1, tx1 - 1)
			var fy := q.rf(ty0 + 1, ty1 - 1)
			match f:
				"s": fy = ty1 + q.rf(0.3, 0.8)
				"n": fy = ty0 - q.rf(0.3, 0.8)
				"e": fx = tx1 + q.rf(0.3, 0.8)
				_: fx = tx0 - q.rf(0.3, 0.8)
			q.prop("entulho_pedras" if k % 2 else "entulho_laje", q.w(fx, fy))
	return true


## Tipos de prédio das fileiras (V13: fabrica), medidas ajustadas ao miolo de 42 tiles.
static func _fabrica(q: Q, tipo: String) -> Dictionary:
	match tipo:
		"apto":
			var loja := q.rng.randf() < 0.55
			var cs: Array = q.pick(Fachada.CORES_PLACA)
			return {"w": q.ri(9, 13), "d": q.ri(9, 11), "o": {"uso": "apartamentos", "andares": q.ri(3, 5), "loja": loja,
				"placa": [q.pick(Fachada.LOJAS), cs[0], cs[1]] if loja else [],
				"extras": {"varanda": q.rng.randf() < 0.6, "incendio": q.pick(["s", "e"]) if q.rng.randf() < 0.55 else ""}}}
		"loja":
			var cs2: Array = q.pick(Fachada.CORES_PLACA)
			return {"w": q.ri(7, 10), "d": q.ri(8, 10), "o": {"uso": "loja", "andares": q.ri(1, 2), "loja": true, "placa": [q.pick(Fachada.LOJAS), cs2[0], cs2[1]]}}
		"banco":
			return {"w": 13, "d": 11, "o": {"uso": "banco", "andares": 2, "pe_direito_m": 3.6}}
		"farmacia":
			return {"w": 10, "d": 9, "o": {"uso": "farmacia", "andares": 1, "pe_direito_m": 3.8, "loja": true}}
		"delegacia":
			return {"w": 16, "d": 11, "o": {"uso": "delegacia", "andares": 2, "pe_direito_m": 3.4}}
		"oficina":
			return {"w": 13, "d": 10, "o": {"uso": "oficina", "andares": 1, "pe_direito_m": 5.2}}
		_:
			return {"w": 20, "d": 14, "o": {"uso": "mercado", "andares": 1, "pe_direito_m": 5.4, "loja": true}}


## Fileira de prédios encostada num lado do quarteirão, de 'a' a 'b' (V13: fileira). 'lista' = forçados, em ordem.
static func _fileira(q: Q, lado: String, a: int, b: int, borda: int, prof: int, lista: Array, pool: Array) -> void:
	var s := a
	var tent := 0
	while s < b - 6:
		var forcado := not lista.is_empty()
		var tipo: String = lista[0] if forcado else q.pick(pool)
		var f := _fabrica(q, tipo)
		var w: int = mini(f["w"], b - s)
		if w < 6:
			if forcado and tent < 40:
				tent += 1
				s += 1
				continue
			break
		var d: int = mini(f["d"], prof)
		var r: Array
		match lado:
			"n": r = [s, borda, s + w, borda + d]
			"s": r = [s, borda - d, s + w, borda]
			"w": r = [borda, s, borda + d, s + w]
			_: r = [borda - d, s, borda, s + w]
		if not q.livre(r[0], r[1], r[2], r[3]):
			s += 1
			continue
		if forcado:
			lista.pop_front()
		var o: Dictionary = f["o"]
		o["frente"] = lado
		if _predio(q, r[0], r[1], r[2], r[3], o) and tipo == "farmacia":
			var pt: Vector2
			match lado:                                # totem da farmácia na calçada, no canto
				"s": pt = q.w(r[2], r[3]) + Vector2(-14, 44)
				"n": pt = q.w(r[2], r[1]) + Vector2(-14, -44)
				"e": pt = q.w(r[2], r[3]) + Vector2(44, -14)
				_: pt = q.w(r[0], r[3]) + Vector2(-44, -14)
			q.urbano("totem", pt.x - 10, pt.y - 10, pt.x + 10, pt.y + 10, zm(4.2), true, {"txt": "FARMÁCIA", "bg": "#1e7a46", "fg": "#ffffff"})
		s += w + 1


## Estacionamento com vagas pintadas e carros (V13: estacionamento). eixo "x" = fileiras ao longo de x.
static func _estacionamento(q: Q, tx0: int, ty0: int, tx1: int, ty1: int, eixo: String, taxa: float) -> void:
	if not q.livre(tx0, ty0, tx1, ty1):
		return
	q.ocupar(tx0, ty0, tx1, ty1)
	q.solo(tx0, ty0, tx1, ty1, "asfalto", Color(0.82, 0.8, 0.78))
	var X := eixo == "x"
	var A0 := tx0 if X else ty0
	var A1 := tx1 if X else ty1
	var B0 := ty0 if X else tx0
	var B1 := ty1 if X else tx1
	var filas: Array = [B0 + 0.2, B1 - 4.2] if B1 - B0 >= 8 else [B0 + 0.2]
	var branco := Color(0.86, 0.85, 0.8, 0.75)
	for fila in filas:
		var a := A0 + 1
		while a < A1 - 1:
			if X:
				q.solo(a, fila, a + 0.07, fila + 4.0, "", branco)
			else:
				q.solo(fila, a, fila + 4.0, a + 0.07, "", branco)
			if q.rng.randf() < taxa and a + 2 < A1:
				var p: Vector2 = q.w(a + 1, fila + 2.0) if X else q.w(fila + 2.0, a + 1)
				var proa: float = (PI * 0.5 if q.rng.randf() < 0.5 else -PI * 0.5) if X else (0.0 if q.rng.randf() < 0.5 else PI)
				MundoGen._carro(q.rng, p, proa + q.rf(-0.06, 0.06), q.specs)
			a += 2
	for k in 3:                                       # manchas de óleo
		var mx := q.rf(tx0 + 1, tx1 - 2)
		var my := q.rf(ty0 + 1, ty1 - 2)
		q.solo(mx, my, mx + q.rf(0.4, 1.0), my + q.rf(0.3, 0.7), "", Color(0.05, 0.05, 0.06, 0.3))


static func _arvore(q: Q, tx: float, ty: float, morta: bool = false) -> void:
	if not q.livre(int(tx), int(ty), int(tx) + 1, int(ty) + 1):
		return
	var nome: String = "arvore_morta" if morta else q.pick(["arvore_frondosa", "arvore_jovem", "arvore_fina", "arvore_outono"])
	q.prop(nome, q.w(tx, ty), {"col": "arvore"})


# ═════════════════════════════════ quarteirões ═════════════════════════════════

static func _comercial(q: Q, forc: Dictionary, pool: Array) -> void:
	var dN := q.ri(9, 11)
	var dS := q.ri(9, 11)
	var dW := q.ri(8, 10)
	var dE := q.ri(8, 10)
	# beco norte-sul cortando o quarteirão, com caçambas e lixo
	var bx := q.ri(int(N * 0.38), int(N * 0.62))
	q.ocupar(bx - 1, 0, bx + 2, N)
	q.solo(bx - 1, 0, bx + 2, N, "asfalto", Color(0.72, 0.68, 0.62))
	for k in 3:
		if q.rng.randf() < 0.7:
			var cx := (bx - 0.9) if q.rng.randf() < 0.5 else (bx + 1.1)      # encostada numa parede do beco
			var cy := q.rf(2.0, N - 3.0)
			var p := q.w(cx, cy)
			q.urbano("cacamba", p.x, p.y, p.x + mt(1.1), p.y + mt(1.8), zm(1.3), true, {"semente": q.rng.randf()})
	for k in 5:
		var p2 := q.w(bx + q.rf(-0.5, 1.5), q.rf(1.0, N - 1.0))
		q.prop(q.pick(["entulho_pedras", "barril_azul", "caixote", "sacos_areia_b"]), p2, {"loot": "caixa"} if k == 0 else {})
	_fileira(q, "s", 0, N, N, dS, (forc.get("s", []) as Array).duplicate(), pool)
	_fileira(q, "n", 0, N, 0, dN, (forc.get("n", []) as Array).duplicate(), pool)
	_fileira(q, "w", dN + 1, N - dS - 1, 0, dW, (forc.get("w", []) as Array).duplicate(), pool)
	_fileira(q, "e", dN + 1, N - dS - 1, N, dE, (forc.get("e", []) as Array).duplicate(), pool)
	var iy0 := dN + 2
	var iy1 := N - dS - 2
	if iy1 - iy0 >= 8:
		_estacionamento(q, dW + 2, iy0, bx - 1, iy1, "y", 0.4)
		_estacionamento(q, bx + 2, iy0, N - dE - 2, iy1, "y", 0.4)
	for k in 6:
		var tx := q.ri(1, N - 2)
		var ty := q.ri(1, N - 2)
		if q.livre(tx, ty, tx + 1, ty + 1):
			q.prop(q.pick(["entulho_pedras", "barreira_quebrada", "caixote"]), q.w(tx + 0.5, ty + 0.5), {"loot": "scrap"} if k % 3 == 0 else {})


static func _hospital(q: Q) -> void:
	var w := mini(30, N - 4)
	_predio(q, 2, N - 15, 2 + w, N - 1, {"uso": "hospital", "andares": 4, "frente": "s", "dano": 0.55})
	_estacionamento(q, 1, 1, N - 1, 13, "x", 0.35)
	for i in 4:                                       # tendas do atendimento de emergência
		q.specs.append({"k": "tenda", "p": q.w(5.0 + i * 9.0, N - 18.0), "cor": i % 3})
	for i in 5:
		var p := q.w(4.0 + i * 8.0, 14.2)
		q.urbano("barricada", p.x, p.y, p.x + mt(3.0), p.y + mt(0.7), zm(0.9))
	var cerca := Rect2(q.w(0.4, 0.4), Vector2((N - 0.8) * TILE, 13.6 * TILE))
	q.cerca(cerca, "n", cerca.get_center().x, mt(6.0), "alambrado")
	for i in 3:
		q.prop("barreira_listrada", q.w(q.rf(3.0, N - 3.0), N - 0.4))


static func _mercado(q: Q) -> void:
	var mx1 := N - 1
	_predio(q, mx1 - 21, N - 15, mx1, N - 1, {"uso": "mercado", "andares": 1, "pe_direito_m": 5.4, "loja": true, "frente": "s"})
	_estacionamento(q, 1, 1, N - 1, 12, "x", 0.5)
	_fileira(q, "w", 14, N - 1, 0, 10, ["farmacia", "loja"], ["loja"])


static func _escola(q: Q) -> void:
	var w := mini(30, N - 6)
	var ex := (N - w) / 2
	_predio(q, ex, N - 12, ex + w, N - 1, {"uso": "escola", "andares": 2, "pe_direito_m": 3.4, "frente": "s"})
	# quadra de esportes cercada
	var qx0 := 3
	var qy0 := 3
	var qx1 := 24
	var qy1 := 15
	q.ocupar(qx0, qy0, qx1, qy1)
	q.solo(qx0, qy0, qx1, qy1, "concreto", Color(0.6, 0.72, 0.66))
	var linha := Color(0.92, 0.9, 0.84, 0.8)
	q.solo(qx0 + 0.5, qy0 + 0.5, qx1 - 0.5, qy0 + 0.58, "", linha)
	q.solo(qx0 + 0.5, qy1 - 0.58, qx1 - 0.5, qy1 - 0.5, "", linha)
	q.solo(qx0 + 0.5, qy0 + 0.5, qx0 + 0.58, qy1 - 0.5, "", linha)
	q.solo(qx1 - 0.58, qy0 + 0.5, qx1 - 0.5, qy1 - 0.5, "", linha)
	q.solo((qx0 + qx1) * 0.5 - 0.04, qy0 + 0.5, (qx0 + qx1) * 0.5 + 0.04, qy1 - 0.5, "", linha)
	var cy := (qy0 + qy1) * 0.5
	for x in [qx0 + 1.0, qx1 - 1.3]:
		var p := q.w(x, cy)
		q.urbano("cesta", p.x - 10, p.y - 10, p.x + 10, p.y + 10, zm(4.0))
	var rc := Rect2(q.w(qx0 - 0.3, qy0 - 0.3), Vector2((qx1 - qx0 + 0.6) * TILE, (qy1 - qy0 + 0.6) * TILE))
	q.cerca(rc, "s", rc.get_center().x, mt(2.4), "alambrado")
	for k in 8:
		_arvore(q, q.rf(qx1 + 2.0, N - 2.0), q.rf(2.0, N - 16.0))
	MundoGen._carro(q.rng, q.w(N - 6.0, 10.0), PI * 0.5, q.specs)


static func _igreja(q: Q) -> void:
	_predio(q, 5, N - 18, 15, N - 2, {"uso": "igreja", "andares": 1, "altura_m": 5.6, "cobertura": "igreja", "frente": "s",
		"dano": 0.35, "bsp_prof": 1, "bsp_min": 4})
	q.solo(2, 2, 16, 14, "calcada", Color(0.9, 0.9, 0.88))       # adro
	# cemitério com muro baixo e portão a oeste
	var gx0 := 18
	var gy0 := 4
	var gx1 := N - 3
	var gy1 := N - 4
	q.ocupar(gx0, gy0, gx1, gy1)
	q.solo(gx0, gy0, gx1, gy1, "grama", Color(0.82, 0.88, 0.74))
	for k in 6:
		var tx := q.rf(gx0 + 1.0, gx1 - 3.0)
		var ty := q.rf(gy0 + 1.0, gy1 - 3.0)
		q.solo(tx, ty, tx + q.rf(1.0, 2.5), ty + q.rf(0.6, 1.6), "terra", Color(1, 1, 1, 0.7))
	var rm := Rect2(q.w(gx0, gy0), Vector2((gx1 - gx0) * TILE, (gy1 - gy0) * TILE))
	q.cerca(rm, "w", rm.get_center().y, mt(3.0), "muro")
	var y := gy0 + 2
	while y < gy1 - 2:
		var x := gx0 + 2
		while x < gx1 - 1:
			if q.rng.randf() >= 0.2:
				var p := q.w(x, y) + Vector2(q.rf(-6.0, 6.0), 0.0)
				q.urbano("lapide", p.x, p.y, p.x + mt(0.6), p.y + mt(0.2), zm(0.75), true, {"cova": q.rng.randf() < 0.15})
			x += 2
		y += 3
	for k in 4:
		var tx2 := q.rf(gx0 + 2.0, gx1 - 2.0)
		var ty2 := q.rf(gy0 + 2.0, gy1 - 2.0)
		q.prop("arvore_morta" if k % 2 else "arvore_frondosa", q.w(tx2, ty2), {"col": "arvore"})
	MundoGen._carro(q.rng, q.w(9.0, 8.0), PI, q.specs)


static func _posto(q: Q) -> void:
	# posto no canto nordeste: loja de conveniência ao fundo, cobertura, bombas e totem
	var px0 := N - 24
	var py0 := 0
	q.solo(px0, py0, px0 + 24, py0 + 20, "concreto", Color(1.0, 1.0, 0.97))
	_predio(q, px0 + 13, py0 + 12, px0 + 22, py0 + 19, {"uso": "posto", "andares": 1, "pe_direito_m": 3.4, "loja": true, "frente": "n"})
	q.ocupar(px0, py0, px0 + 24, py0 + 20)
	var c0 := q.w(px0 + 3, py0 + 3)
	var c1 := q.w(px0 + 13, py0 + 10)
	q.urbano("cobertura", c0.x, c0.y, c1.x, c1.y, zm(4.6), false)
	for p in [Vector2(c0.x + mt(1.0), c0.y + mt(1.0)), Vector2(c1.x - mt(1.5), c0.y + mt(1.0)), Vector2(c0.x + mt(1.0), c1.y - mt(1.5)), Vector2(c1.x - mt(1.5), c1.y - mt(1.5))]:
		q.urbano("pilar", p.x, p.y, p.x + mt(0.5), p.y + mt(0.5), zm(4.6))
	for fy in [c0.y + mt(3.0), c1.y - mt(3.4)]:
		for fx in [c0.x + mt(4.0), c1.x - mt(5.0)]:
			q.urbano("bomba", fx, fy, fx + mt(0.9), fy + mt(0.5), zm(1.8))
	var tp := q.w(px0 + 1, py0 + 18)
	q.urbano("totem", tp.x, tp.y, tp.x + 20, tp.y + 20, zm(6.0), true, {"txt": "POSTO", "precos": true})
	MundoGen._carro(q.rng, Vector2((c0.x + c1.x) * 0.5, c0.y + mt(5.0)), PI, q.specs)
	for k in 6:
		var mx := q.rf(px0 + 3.0, px0 + 13.0)
		var my := q.rf(py0 + 3.0, py0 + 10.0)
		q.solo(mx, my, mx + q.rf(0.3, 0.9), my + q.rf(0.3, 0.6), "", Color(0.05, 0.05, 0.06, 0.3))
	_fileira(q, "s", 0, N - 26, N, 11, ["apto"], ["apto", "loja"])
	_fileira(q, "w", 0, N - 13, 0, 10, ["loja"], ["loja", "apto"])
	_estacionamento(q, N - 24, 22, N - 1, N - 1, "x", 0.3)          # pátio de trás vira estacionamento
	for k in 5:
		var tx := q.ri(11, N - 26)
		var ty := q.ri(2, N - 13)
		if q.livre(tx, ty, tx + 1, ty + 1):
			q.prop(q.pick(["barril_azul", "entulho_pedras", "caixote", "barreira_listrada"]), q.w(tx + 0.5, ty + 0.5), {"loot": "scrap"} if k == 0 else {})


static func _industrial(q: Q, chamine: bool) -> void:
	q.solo(0, 0, N, N, "terra", Color(0.95, 0.92, 0.88))
	for k in 8:
		var tx := q.rf(0.0, N - 8.0)
		var ty := q.rf(0.0, N - 6.0)
		q.solo(tx, ty, tx + q.rf(3.0, 8.0), ty + q.rf(2.0, 6.0), "concreto", Color(0.92, 0.9, 0.86))
	var x := 2
	while x < N - 10:
		var w := mini(q.ri(15, 22), N - 2 - x)
		if w < 11:
			break
		var d := q.ri(13, 18)
		_predio(q, x, N - 1 - d, x + w, N - 1, {"uso": "galpao", "andares": 1, "altura_m": float(q.ri(6, 8)), "cobertura": "galpao",
			"frente": "s", "bsp_prof": 1, "bsp_min": 6, "dano": q.rf(0.35, 0.75)})
		x += w + 3
	if chamine:
		var ct := N - 5
		q.ocupar(ct, 3, ct + 3, 6)
		var a := q.w(ct, 3)
		var b := q.w(ct + 3, 6)
		q.urbano("chamine", a.x, a.y, b.x, b.y, zm(20.0))
	for k in 9:                                       # contêineres no pátio
		var vert := q.rng.randf() < 0.3
		var cw := 2 if vert else 5
		var ch := 5 if vert else 2
		var tx2 := q.ri(3, N - 9)
		var ty2 := q.ri(2, 11)
		if not q.livre(tx2, ty2, tx2 + cw, ty2 + ch):
			continue
		q.ocupar(tx2, ty2, tx2 + cw, ty2 + ch)
		var p := q.w(tx2, ty2)
		q.urbano("container", p.x, p.y, p.x + cw * TILE - 6.0, p.y + ch * TILE - 6.0, zm(2.6), true, {"cor": q.pick(CORES_CONTAINER)})
	for k in 2:
		MundoGen._carro(q.rng, q.w(q.rf(6.0, N - 6.0), q.rf(4.0, 12.0)), q.rf(-PI, PI), q.specs)
	for k in 8:
		var tx3 := q.ri(2, N - 3)
		var ty3 := q.ri(2, 14)
		if q.livre(tx3, ty3, tx3 + 1, ty3 + 1):
			q.prop(q.pick(["entulho_pedras", "barril_azul", "barreira_quebrada"]), q.w(tx3 + 0.5, ty3 + 0.5), {"loot": "scrap"} if k % 2 == 0 else {})
	var rc := Rect2(q.w(0.3, 0.3), Vector2((N - 0.6) * TILE, (N - 0.6) * TILE))
	q.cerca(rc, "n", q.w(N * 0.3, 0).x, mt(8.0), "alambrado")


static func _praca(q: Q, x0: int, y0: int, x1: int, y1: int) -> void:
	q.solo(x0, y0, x1, y1, "grama", Color(0.9, 1.0, 0.86))
	var cx := (x0 + x1) / 2
	var cy := (y0 + y1) / 2
	q.solo(x0, cy - 1, x1, cy + 1, "calcada")        # caminhos em cruz
	q.solo(cx - 1, y0, cx + 1, y1, "calcada")
	q.ocupar(x0, cy - 1, x1, cy + 1)
	q.ocupar(cx - 1, y0, cx + 1, y1)
	q.ocupar(cx - 2, cy - 2, cx + 2, cy + 2)
	var a := q.w(cx - 1.5, cy - 1.5)
	var b := q.w(cx + 1.5, cy + 1.5)
	q.urbano("estatua", a.x, a.y, b.x, b.y, zm(3.4))
	for d in [Vector2(3.5, 1.3), Vector2(-5.0, 1.3), Vector2(1.3, 3.5), Vector2(1.3, -5.0)]:
		var p := q.w(cx + d.x, cy + d.y)
		var deitado: bool = absf(d.x) > 2.0
		q.urbano("banco", p.x, p.y, p.x + (mt(1.6) if deitado else mt(0.5)), p.y + (mt(0.5) if deitado else mt(1.6)), zm(0.9))
	for k in 20:
		var tx := q.rf(x0 + 1.0, x1 - 1.0)
		var ty := q.rf(y0 + 1.0, y1 - 1.0)
		if absf(tx - cx) < 2.5 or absf(ty - cy) < 2.5:
			continue
		if k % 4 == 0:
			if q.livre(int(tx), int(ty), int(tx) + 1, int(ty) + 1):
				q.prop(q.pick(["arbusto_redondo", "arbusto_folhudo", "arbusto_largo"]), q.w(tx, ty))
		else:
			_arvore(q, tx, ty)
	for p2 in [q.w(cx + 1.6, y0 + 3.0), q.w(cx + 1.6, y1 - 3.0), q.w(x0 + 3.0, cy + 1.6), q.w(x1 - 3.0, cy + 1.6)]:
		q.specs.append({"k": "urbano", "t": "poste", "r": Rect2(p2 - Vector2(6, 6), Vector2(12, 12)), "h": zm(5.0), "s": true,
			"x": {"semente": p2.x * 0.011 + p2.y * 0.005}, "p": p2})


## Quarteirão de casas: duas fileiras de lotes de costas uma para a outra (V13: quadraCasas/loteCasa).
static func _casas(q: Q, x0: int, y0: int, x1: int, y1: int) -> void:
	var W := x1 - x0
	var nl: int = maxi(1, roundi(W / 11.0))
	var lw: int = W / nl
	var half: int = (y1 - y0) / 2
	var estilo: String = q.pick(["madeira", "madeira", "alambrado", "muro", "madeira"])
	for r in 2:
		for i in nl:
			var lx0 := x0 + i * lw
			var lx1 := x1 if i == nl - 1 else lx0 + lw
			var ly0 := (y0 + half) if r == 1 else y0
			var ly1 := y1 if r == 1 else y0 + half
			_lote(q, lx0, ly0, lx1, ly1, "s" if r == 1 else "n", estilo, i == nl - 1, r == 0)


static func _lote(q: Q, lx0: int, ly0: int, lx1: int, ly1: int, frente: String, estilo: String, ultimo: bool, fundo: bool) -> void:
	if not q.livre(lx0, ly0, lx1, ly1):
		return
	q.ocupar(lx0, ly0, lx1, ly1)
	q.solo(lx0, ly0, lx1, ly1, "grama", Color(0.86, 0.92, 0.8))
	var lw := lx1 - lx0
	var N_ := frente == "n"
	var y_frente: float = ly0 if N_ else ly1
	var gx: float = (lx0 + lx1) * 0.5
	if q.rng.randf() < 0.07:                          # lote tomado pelo mato
		for k in 7:
			var tx := q.rf(lx0 + 0.6, lx1 - 0.6)
			var ty := q.rf(ly0 + 0.6, ly1 - 0.6)
			if k % 3:
				q.prop(q.pick(["arbusto_largo", "mato_alto", "capim_alto"]), q.w(tx, ty))
			else:
				q.prop(q.pick(["arvore_jovem", "arvore_frondosa"]), q.w(tx, ty), {"col": "arvore"})
	else:
		var hw := mini(lw - 4, q.ri(6, 8))
		var hd := q.ri(6, 7)
		var lado := q.rng.randf() < 0.5
		var garagem := lw - hw >= 6
		var hx0: int = ((lx0 + 1) if lado else (lx1 - 1 - hw)) if garagem else (lx0 + (lw - hw) / 2)
		var hy0: int = (ly0 + q.ri(3, 4)) if N_ else (ly1 - q.ri(3, 4) - hd)
		q.specs.append({"k": "edificio", "p": q.w(hx0, hy0), "w": hw, "h": hd, "f": frente, "sem": q.rng.randi() % 100000,
			"mor": q.ri(0, 2)})
		gx = hx0 + hw * 0.5
		if garagem:                                   # entrada de carro e carro
			var dx0: int = (hx0 + hw + 1) if lado else (hx0 - 3)
			var ya: float = ly0 if N_ else hy0 + hd - 2
			var yb: float = hy0 + 2 if N_ else ly1
			q.solo(dx0, ya, dx0 + 2, yb, "concreto", Color(0.96, 0.95, 0.92))
			if q.rng.randf() < 0.45:
				MundoGen._carro(q.rng, q.w(dx0 + 1.0, (ly0 + 2.5) if N_ else (ly1 - 2.5)), -PI * 0.5 if N_ else PI * 0.5, q.specs)
		for k in q.ri(2, 4):                          # jardim na frente
			var by := (hy0 - 0.6) if N_ else (hy0 + hd + 1.2)
			q.prop(q.pick(["arbusto_redondo", "arbusto_folhudo", "arbusto_baixo"]), q.w(q.rf(hx0, hx0 + hw), by))
		if q.rng.randf() < 0.35:
			q.prop(q.pick(["arvore_jovem", "arvore_frondosa"]), q.w((lx0 + 1.5) if lado else (lx1 - 1.5), (ly0 + 1.8) if N_ else (ly1 - 1.2)), {"col": "arvore"})
		var fy0: float = (hy0 + hd + 1) if N_ else (ly0 + 1)  # quintal dos fundos
		var fy1: float = (ly1 - 1) if N_ else (hy0 - 1)
		if fy1 - fy0 > 2.0:
			if q.rng.randf() < 0.7:
				q.prop(q.pick(["arvore_frondosa", "arvore_jovem", "arvore_outono"]), q.w(q.rf(lx0 + 1.5, lx1 - 1.5), q.rf(fy0, fy1)), {"col": "arvore"})
			if q.rng.randf() < 0.5:
				q.prop(q.pick(["arbusto_largo", "arbusto_redondo"]), q.w(q.rf(lx0 + 1.0, lx1 - 1.0), q.rf(fy0, fy1)))
			if q.rng.randf() < 0.3:
				q.prop("entulho_pedras", q.w(q.rf(lx0 + 1.0, lx1 - 1.0), q.rf(fy0, fy1)), {"loot": "scrap"})
		var cp := q.w(gx + 1.2 * METRO / TILE, y_frente + (0.4 if N_ else -0.4))
		q.urbano("correio", cp.x - 8, cp.y - 8, cp.x + 8, cp.y + 8, zm(1.25), false, {"cor": q.pick(["#5a6a7a", "#8a2a22", "#3a3a3a", "#4a5a3a"])})
	# cercas: laterais e fundos conforme o estilo do quarteirão; frente com portão (55%) ou aberta
	var rl := Rect2(q.w(lx0, ly0) + Vector2(10, 10), Vector2(lw * TILE - 20.0, (ly1 - ly0) * TILE - 20.0))
	var pular: Array = []
	if not ultimo:
		pular.append("e")
	if not fundo:
		pular.append("s" if N_ else "n")
	if q.rng.randf() >= 0.55:
		pular.append(frente)
	q.cerca(rl, frente, q.w(gx, 0).x, 150.0, estilo, pular)
