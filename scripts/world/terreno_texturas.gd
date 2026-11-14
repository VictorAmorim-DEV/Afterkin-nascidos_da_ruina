class_name TerrenoTexturas
extends RefCounted
## Texturas de chão desenhadas por código (sem arquivos novos): areia, solo rachado, terra, asfalto,
## calçada, concreto, água, madeira e solo lavrado. Todas repetem sem emenda: o ruído usa período
## inteiro e as rachaduras usam Voronoi "enrolado". Cada uma é gerada uma vez e fica em cache.

const N := 128                       ## lado do ladrilho, em px
const MUNDO := 384.0                 ## tamanho do ladrilho no mundo, em u

static var _cache: Dictionary = {}


static func obter(nome: String) -> Texture2D:
	if not _cache.has(nome):
		_cache[nome] = ImageTexture.create_from_image(_gerar(nome))
	return _cache[nome] as Texture2D


static func _hash(x: int, y: int, s: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Ruído de valor com período `per` (inteiro): a textura fecha sem emenda.
static func _vn(x: float, y: float, per: int, s: int) -> float:
	var xi: int = floori(x)
	var yi: int = floori(y)
	var fx: float = x - xi
	var fy: float = y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(xi, per), posmod(yi, per), s)
	var b := _hash(posmod(xi + 1, per), posmod(yi, per), s)
	var c := _hash(posmod(xi, per), posmod(yi + 1, per), s)
	var d := _hash(posmod(xi + 1, per), posmod(yi + 1, per), s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Distâncias (menor, segunda menor) aos pontos de um Voronoi com `g` x `g` células, enrolado.
static func _voronoi(x: float, y: float, g: int, s: int) -> Vector2:
	var xi: int = floori(x)
	var yi: int = floori(y)
	var d1 := 9.0
	var d2 := 9.0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx: int = xi + ox
			var cy: int = yi + oy
			var px: float = cx + _hash(posmod(cx, g), posmod(cy, g), s)
			var py: float = cy + _hash(posmod(cx, g), posmod(cy, g), s + 77)
			var d: float = (px - x) * (px - x) + (py - y) * (py - y)
			if d < d1:
				d2 = d1
				d1 = d
			elif d < d2:
				d2 = d
	return Vector2(sqrt(d1), sqrt(d2))


static func _gerar(nome: String) -> Image:
	var img := Image.create_empty(N, N, false, Image.FORMAT_RGB8)
	for py in N:
		for px in N:
			var u: float = float(px) / N
			var v: float = float(py) / N
			img.set_pixel(px, py, _cor(nome, u, v, px, py))
	return img


static func _cor(nome: String, u: float, v: float, px: int, py: int) -> Color:
	var grao: float = _hash(px, py, 5)
	match nome:
		"areia":
			var duna: float = 0.5 + 0.5 * sin((u * 6.0 + v * 2.0 + _vn(u * 4.0, v * 4.0, 4, 1) * 1.4) * TAU)
			var f: float = 0.86 + 0.10 * _vn(u * 8.0, v * 8.0, 8, 2) + 0.05 * duna + 0.05 * (grao - 0.5)
			return Color(0.88 * f, 0.76 * f, 0.52 * f)
		"rachada":
			var vo := _voronoi(u * 6.0, v * 6.0, 6, 11)
			var borda: float = vo.y - vo.x
			var f2: float = 0.9 + 0.12 * _vn(u * 8.0, v * 8.0, 8, 3) + 0.06 * (grao - 0.5)
			var c := Color(0.66 * f2, 0.50 * f2, 0.33 * f2)
			if borda < 0.07:
				c = c.lerp(Color(0.20, 0.13, 0.08), 1.0 - borda / 0.07)
			return c
		"terra":
			var f3: float = 0.82 + 0.22 * _vn(u * 8.0, v * 8.0, 8, 4) + 0.12 * (grao - 0.5)
			return Color(0.47 * f3, 0.34 * f3, 0.22 * f3)
		"lavrado":
			var sulco: float = 0.5 + 0.5 * sin(v * 16.0 * TAU)
			var f4: float = 0.80 + 0.14 * sulco + 0.10 * (grao - 0.5)
			return Color(0.36 * f4, 0.25 * f4, 0.16 * f4)
		"asfalto":
			var f5: float = 0.85 + 0.15 * _vn(u * 8.0, v * 8.0, 8, 6) + 0.16 * (grao - 0.5)
			return Color(0.23 * f5, 0.23 * f5, 0.25 * f5)
		"calcada":
			var junta: bool = posmod(px, N / 4) == 0 or posmod(py, N / 4) == 0
			var f6: float = 0.92 + 0.08 * (grao - 0.5) + 0.06 * _vn(u * 4.0, v * 4.0, 4, 7)
			var c6 := Color(0.60 * f6, 0.60 * f6, 0.56 * f6)
			return c6.darkened(0.25) if junta else c6
		"concreto":
			var musgo: float = _vn(u * 6.0, v * 6.0, 6, 8)
			var f7: float = 0.88 + 0.12 * _vn(u * 12.0, v * 12.0, 12, 9) + 0.08 * (grao - 0.5)
			var c7 := Color(0.42 * f7, 0.42 * f7, 0.38 * f7)
			return c7.lerp(Color(0.30, 0.38, 0.22), clampf((musgo - 0.55) * 2.2, 0.0, 0.6))
		"agua":
			var o: float = 0.5 + 0.5 * sin((u * 5.0 + _vn(u * 4.0, v * 4.0, 4, 10) * 1.5) * TAU)
			var f8: float = 0.85 + 0.12 * o + 0.05 * _vn(u * 8.0, v * 8.0, 8, 12)
			return Color(0.12 * f8, 0.34 * f8, 0.40 * f8).lerp(Color(0.55, 0.78, 0.82), 0.10 * o * o)
		"madeira":
			var tabua: bool = posmod(py, N / 8) == 0
			var veio: float = 0.85 + 0.18 * _vn(u * 3.0, v * 24.0, 3, 13) + 0.06 * (grao - 0.5)
			var c9 := Color(0.45 * veio, 0.31 * veio, 0.18 * veio)
			return c9.darkened(0.4) if tabua else c9
	return Color(1, 0, 1)
