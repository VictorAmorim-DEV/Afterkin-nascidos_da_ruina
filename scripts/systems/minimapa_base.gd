class_name MinimapaBase
extends RefCounted
## Mapa-base do minimapa (V13: construirMinimapa, l.1763): 1 px por tile (64 u), gerado das mesmas funções
## determinísticas que geram o mundo — bioma, mata, rio, ponte, estradas e trilhas, vilarejos, roças,
## acampamentos, cidade com o chão dos quarteirões e edifícios pintados pelo uso (V13: MMU).
##
## Roda numa Thread (≈1-2 s): antes de começar, chame preparar() na thread principal, que enche os caches de
## MundoGen e Quadras; a thread então só lê.

const PX := 64.0                                  ## u de mundo por pixel
const W := 960                                    ## MundoGen.LARG / PX
const H := 448                                    ## MundoGen.ALT / PX

const COR_TROPICAL := Color("#557238")
const COR_MATA := Color("#35501f")
const COR_SEMI := Color("#a28a56")
const COR_DESERTO := Color("#cdb47c")
const COR_FUNDA := Color("#2c5a7a")
const COR_RASA := Color("#5d92a8")
const COR_PONTE := Color("#7a5a3a")
const COR_TERRA := Color("#8c6e4a")
const COR_TRILHA := Color("#6e5a3c")
const COR_CONCRETO := Color("#6e6e68")
const COR_ASFALTO := Color("#38393c")
const COR_CASA := Color("#b9644e")
const COR_ACAMPAMENTO := Color("#d99a3a")
const COR_ROCA := Color("#8a7a3e")
const COR_SECO := Color("#9a7e52")
const COR_LOTE := Color("#6a7f45")
## edifícios por uso (V13: MMU)
const COR_USO := {"hospital": Color("#e6e4dc"), "farmacia": Color("#4fc3d9"), "delegacia": Color("#4a6ab8"),
	"igreja": Color("#efe4c4"), "galpao": Color("#7d8c8c"), "mercado": Color("#d6a24e"), "banco": Color("#c8b890"),
	"escola": Color("#c87a4a"), "posto": Color("#d84a3a"), "oficina": Color("#8a8a6a"), "loja": Color("#b08a6a"),
	"apartamentos": Color("#a08878")}
const COR_CHAO := {"grama": Color("#5a7a3a"), "asfalto": Color("#3c3d40"), "concreto": Color("#7a7a74"),
	"calcada": Color("#8e8e88"), "terra": Color("#8a6e4c")}


## Enche os caches na thread principal (a thread de geração só lê).
static func preparar() -> void:
	MundoGen.estradas()
	for i in 3:
		for j in 4:
			Quadras._bloco(i, j)


static func gerar() -> Image:
	var dados := PackedByteArray()
	dados.resize(W * H * 3)
	var C := MundoGen.CIDADE
	var B := MundoGen.BLOCO
	var R := MundoGen.RUA
	var k := 0
	for iy in H:
		var y := (iy + 0.5) * PX
		for ix in W:
			var x := (ix + 0.5) * PX
			var c: Color
			if C.has_point(Vector2(x, y)):
				var na_rua: bool = fposmod(x - C.position.x, B) < R or fposmod(y - C.position.y, B) < R \
					or x >= C.end.x - R or y >= C.end.y - R
				c = COR_ASFALTO if na_rua else COR_CONCRETO
			else:
				var v := MundoGen.bioma_valor(x, y)
				if v <= 1.0:
					c = COR_TROPICAL.lerp(COR_SEMI, clampf(v, 0.0, 1.0))
					if v < 0.6:
						var f := MundoGen.floresta(Vector2(x, y))
						c = c.lerp(COR_MATA, smoothstep(0.45, 0.7, f) * (1.0 - v / 0.6))
				else:
					c = COR_SEMI.lerp(COR_DESERTO, clampf(v - 1.0, 0.0, 1.0))
			dados[k] = int(c.r8)
			dados[k + 1] = int(c.g8)
			dados[k + 2] = int(c.b8)
			k += 3
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGB8, dados)
	# estradas e trilhas
	for e in MundoGen.estradas():
		var ed: Dictionary = e
		var pts: PackedVector2Array = ed["pts"]
		var cor := COR_TERRA if ed["t"] == "terra" else COR_TRILHA
		var esp: int = maxi(1, roundi(float(ed["w"]) / PX))
		for i in range(pts.size() - 1):
			_linha(img, pts[i], pts[i + 1], esp, cor)
	# rio (depois das estradas: os vaus continuam água rasa) e ponte
	for iy in H:
		var y2 := (iy + 0.5) * PX
		if y2 < MundoGen.RIO_Y0:
			continue
		var rx := MundoGen.rio_x(y2)
		var meia := MundoGen.rio_meia(y2) + PX
		for ix in range(maxi(0, int((rx - meia) / PX)), mini(W, int((rx + meia) / PX) + 1)):
			var a := MundoGen.agua_em((ix + 0.5) * PX, y2)
			if a > 0:
				img.set_pixel(ix, iy, COR_FUNDA if a == 2 else COR_RASA)
	_ret(img, MundoGen.ponte(), COR_PONTE)
	# vilarejos: lotes, roças, casas
	for a in MundoGen.aldeias():
		var ad: Dictionary = a
		for l in ad["lotes"]:
			_ret(img, l, COR_LOTE)
		for p in ad["plantios"]:
			var pd: Dictionary = p
			_ret(img, pd["r"], COR_ROCA if pd["k"] == "plantio" else COR_SECO)
		for cs in ad["casas"]:
			var cd: Dictionary = cs
			_casa(img, Rect2(cd["p"], Vector2(cd["w"], cd["h"]) * 64.0), COR_CASA)
	# casas isoladas na roça
	for cy in MundoGen.NY:
		for cx in MundoGen.NX:
			var d := MundoGen.casa_isolada_em(Vector2i(cx, cy))
			if not d.is_empty():
				_ret(img, d["plantio"], COR_ROCA if d["kind"] == "plantio" else COR_SECO)
				_casa(img, Rect2((d["casa"] as Rect2).position, Vector2(7, 6) * 64.0), COR_CASA)
	# acampamentos
	for cm in MundoGen.acampamentos():
		var cmd: Dictionary = cm
		var cc: Vector2 = cmd["c"]
		var hw: float = cmd["hw"]
		var hh: float = cmd["hh"]
		_ret(img, Rect2(cc.x - hw, cc.y - hh, hw * 2.0, hh * 2.0), COR_ACAMPAMENTO.darkened(0.35))
		_ret(img, Rect2(cc.x - hw * 0.7, cc.y - hh * 0.75, hw * 1.4, hh * 0.5), COR_ACAMPAMENTO)
	# cidade: chão dos quarteirões e edifícios pelo uso
	for i in 3:
		for j in 4:
			var bd: Dictionary = Quadras._bloco(i, j)
			for ch in bd["chao"]:
				var chd: Dictionary = ch
				var t: String = chd["t"]
				if COR_CHAO.has(t) and (chd["r"] as Rect2).get_area() > 64.0 * 64.0 * 2.0:
					_ret(img, chd["r"], COR_CHAO[t])
			for s in bd["specs"]:
				var sd: Dictionary = s
				if sd["k"] == "edificio":
					var uso: String = (sd["o"] as Dictionary).get("uso", "casa") if sd.has("o") else "casa"
					_casa(img, Rect2(sd["p"], Vector2(sd["w"], sd["h"]) * 64.0), COR_USO.get(uso, COR_CASA))
	# rotatória: anel de asfalto e ilha gramada
	var rc := Quadras.centro_rotatoria()
	var ro := Quadras.ROT_RO * Quadras.TILE
	for iy in range(int((rc.y - ro) / PX), int((rc.y + ro) / PX) + 1):
		for ix in range(int((rc.x - ro) / PX), int((rc.x + ro) / PX) + 1):
			var d := Vector2((ix + 0.5) * PX, (iy + 0.5) * PX).distance_to(rc)
			if d <= ro:
				img.set_pixel(ix, iy, COR_CHAO["grama"] if d < (Quadras.ROT_RI - 0.5) * Quadras.TILE else COR_ASFALTO)
	return img


## Retângulo do mundo (u) pintado no mapa.
static func _ret(img: Image, r: Rect2, cor: Color) -> void:
	var x0 := clampi(int(r.position.x / PX), 0, W)
	var y0 := clampi(int(r.position.y / PX), 0, H)
	var x1 := clampi(ceili(r.end.x / PX), 0, W)
	var y1 := clampi(ceili(r.end.y / PX), 0, H)
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), cor)


## Edifício: preenchido com borda escura (V13: strokeRect).
static func _casa(img: Image, r: Rect2, cor: Color) -> void:
	_ret(img, r, cor.darkened(0.45))
	_ret(img, r.grow(-PX * 0.9), cor)


static func _linha(img: Image, a: Vector2, b: Vector2, esp: int, cor: Color) -> void:
	var n: int = maxi(1, ceili(a.distance_to(b) / (PX * 0.5)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n) / PX
		var x := int(p.x) - esp / 2
		var y := int(p.y) - esp / 2
		var r := Rect2i(x, y, esp, esp).intersection(Rect2i(0, 0, W, H))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, cor)
