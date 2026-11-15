class_name MapaMundi
extends RefCounted
## Dados geográficos do mundo, tirados do mapa-múndi (assets/new_assets/mapa_mundi_hd.png → tools/gerar_mapa_dados.gd
## → data/mapa_dados.res). 1 pixel do mapa = ESCALA u de mundo (3 tiles ≈ 3,9 m): a ilha fica com ~5 × 4,7 km.
##
## Canais: R = classe do terreno, G = densidade de mata, B = bioma, A = distância com sinal até a margem da água
## (128 + 16 × d px, positivo dentro da água). As consultas interpolam (bilinear) para bordas suaves.

const ARQUIVO := "res://data/mapa_dados.res"
const ESCALA := 192.0                ## u de mundo por pixel do mapa

# classes (as mesmas de tools/gerar_mapa_dados.gd)
const OCEANO := 0
const LAGO := 1
const PRAIA := 2
const MATA := 3
const CAMPO := 4
const ROCHA := 5
const NEVE := 6
const CANION := 7
const URBANO := 8                    ## fora das cidades geradas: rodovias (e as pontes delas sobre os rios)
const PANTANO := 9
const DESERTO := 10
const TERRA := 11                    ## estradas de terra e solo nu

## Profundidade (px do mapa) a partir da qual a água é funda: a faixa da margem fica rasa (~4 m).
const FUNDO := 1.1

static var W := 0
static var H := 0
static var _d := PackedByteArray()


static func carregar() -> void:
	if not _d.is_empty():
		return
	var img: Image = load(ARQUIVO)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	W = img.get_width()
	H = img.get_height()
	_d = img.get_data()


static func largura() -> float:
	carregar()
	return W * ESCALA


static func altura() -> float:
	carregar()
	return H * ESCALA


## Pixel do mapa (pode ser fracionário) do ponto de mundo p.
static func px(p: Vector2) -> Vector2:
	return p / ESCALA


static func mundo(pm: Vector2) -> Vector2:
	return pm * ESCALA


## Byte cru do pixel (x, y) do mapa, canal 0 classe · 1 mata · 2 bioma · 3 distância à água (sem interpolação).
static func byte(x: int, y: int, canal: int) -> int:
	carregar()
	return _byte(x, y, canal)


static func _byte(x: int, y: int, canal: int) -> int:
	x = clampi(x, 0, W - 1)
	y = clampi(y, 0, H - 1)
	return _d[(y * W + x) * 4 + canal]


## Interpolação bilinear de um canal (0..255) em coordenadas de mundo.
static func _bil(wx: float, wy: float, canal: int) -> float:
	carregar()
	var fx := wx / ESCALA - 0.5
	var fy := wy / ESCALA - 0.5
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	var a := float(_byte(x0, y0, canal))
	var b := float(_byte(x0 + 1, y0, canal))
	var c := float(_byte(x0, y0 + 1, canal))
	var d := float(_byte(x0 + 1, y0 + 1, canal))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Classe do pixel sob o ponto (sem interpolação).
static func classe(wx: float, wy: float) -> int:
	carregar()
	return _byte(floori(wx / ESCALA), floori(wy / ESCALA), 0)


## Quanto do entorno do ponto é da classe k (0..1, bilinear): bordas suaves entre terrenos.
static func fracao(wx: float, wy: float, k: int) -> float:
	carregar()
	var fx := wx / ESCALA - 0.5
	var fy := wy / ESCALA - 0.5
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	var a := 1.0 if _byte(x0, y0, 0) == k else 0.0
	var b := 1.0 if _byte(x0 + 1, y0, 0) == k else 0.0
	var c := 1.0 if _byte(x0, y0 + 1, 0) == k else 0.0
	var d := 1.0 if _byte(x0 + 1, y0 + 1, 0) == k else 0.0
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Densidade de mata (0..1).
static func mata(wx: float, wy: float) -> float:
	return _bil(wx, wy, 1) / 255.0


## Bioma: 0 = tropical, 1 = semiárido, 2 = deserto (contínuo nas transições).
static func bioma(wx: float, wy: float) -> float:
	return _bil(wx, wy, 2) / 255.0 * 2.0


## Distância com sinal até a margem, em px do mapa (> 0 dentro da água).
static func sd(wx: float, wy: float) -> float:
	return (_bil(wx, wy, 3) - 128.0) / 16.0


## 0 = seco, 1 = raso (anda devagar), 2 = fundo (bloqueia).
static func agua(wx: float, wy: float) -> int:
	var s := sd(wx, wy)
	if s <= 0.0:
		return 0
	return 2 if s >= FUNDO else 1


## Mar (e não lago ou rio) sob o ponto.
static func eh_mar(wx: float, wy: float) -> bool:
	return classe(wx, wy) == OCEANO


# ───────────────────────────── água em polígonos (marching squares) ─────────────────────────────

## Polígonos (u de mundo) onde sd >= limiar dentro do retângulo r, numa grade de 'passo' u. Células cheias da
## mesma linha viram um retângulo só; as de borda, o polígono recortado pela interpolação das quinas.
static func poligonos(r: Rect2, limiar: float, passo: float = 64.0) -> Array:
	carregar()
	var nx := int(ceil(r.size.x / passo))
	var ny := int(ceil(r.size.y / passo))
	var v := PackedFloat32Array()
	v.resize((nx + 1) * (ny + 1))
	var algum := false
	var todos := true
	for j in ny + 1:
		for i in nx + 1:
			var s := sd(r.position.x + i * passo, r.position.y + j * passo) - limiar
			v[j * (nx + 1) + i] = s
			if s >= 0.0:
				algum = true
			else:
				todos = false
	var out: Array = []
	if not algum:
		return out
	if todos:
		out.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		return out
	for j in ny:
		var ini := -1
		for i in nx + 1:
			var cheia := false
			if i < nx:
				cheia = v[j * (nx + 1) + i] >= 0.0 and v[j * (nx + 1) + i + 1] >= 0.0 \
					and v[(j + 1) * (nx + 1) + i] >= 0.0 and v[(j + 1) * (nx + 1) + i + 1] >= 0.0
			if cheia and ini < 0:
				ini = i
			elif not cheia and ini >= 0:
				var a := r.position + Vector2(ini * passo, j * passo)
				var b := r.position + Vector2(i * passo, (j + 1) * passo)
				out.append(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]))
				ini = -1
			if i < nx and not cheia:
				var cel := _celula(r.position + Vector2(i * passo, j * passo), passo, v[j * (nx + 1) + i],
					v[j * (nx + 1) + i + 1], v[(j + 1) * (nx + 1) + i + 1], v[(j + 1) * (nx + 1) + i])
				if cel.size() >= 3:
					out.append(cel)
	return out


## Parte da célula (quinas a, b, c, d no sentido horário a partir do canto noroeste) com valor >= 0.
static func _celula(o: Vector2, passo: float, a: float, b: float, c: float, d: float) -> PackedVector2Array:
	var q := [o, o + Vector2(passo, 0.0), o + Vector2(passo, passo), o + Vector2(0.0, passo)]
	var val := [a, b, c, d]
	var pts := PackedVector2Array()
	for k in 4:
		var k2 := (k + 1) % 4
		var va: float = val[k]
		var vb: float = val[k2]
		if va >= 0.0:
			pts.append(q[k])
		if (va >= 0.0) != (vb >= 0.0):
			var t := va / (va - vb)
			pts.append((q[k] as Vector2).lerp(q[k2], t))
	return pts
