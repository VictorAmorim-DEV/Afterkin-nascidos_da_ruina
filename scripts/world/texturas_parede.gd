class_name TexturasParede
extends RefCounted
## Materiais de parede e telhado desenhados por código (V13: tex/GTEX — madeira, tijolo, reboco, telha, zinco, papel),
## no estilo dos atlas de referência (concept_art/novo teste: "Atlas de Fachadas em Ruínas" e "Atlas de Texturas
## Urbanas Desgastadas"): tijolo gasto, reboco descascando com o tijolo aparecendo, painéis de concreto manchados,
## tábuas pintadas descascando, zinco ondulado enferrujado, papel de parede manchado, telha de barro, ardósia e laje.
##
## Tudo fica num ATLAS só: o Desenho continua sendo um draw call por nó (os pedaços sem material usam o texel branco
## da célula 0). Cada célula repete sem emenda (ruído com período inteiro) e vale 64 u de largura por PERIODO px
## de altura numa parede (64 × 64 u num telhado). As texturas são quase neutras: a cor do vértice dá o tom
## (cor da parede, do papel do cômodo, da telha), como os padrões da V13 recebiam a cor base.

const C := 96                        ## lado da célula, em px
const COLS := 4
const MATERIAIS := ["branco", "tijolo", "reboco", "concreto", "madeira", "zinco", "papel_listras", "papel_motivo",
	"telha", "ardosia", "zinco_telhado", "laje", "reboco_liso"]
const PERIODO := 64.0                ## altura (px de tela) que uma célula cobre numa parede
## As texturas escurecem em média ~12%: a cor do vértice é clareada na mesma medida para manter o tom de antes.
const REALCE := 1.12

static var _atlas: ImageTexture = null
static var _relevo: CanvasTexture = null
static var _tam := Vector2.ZERO


static func atlas() -> Texture2D:
	if _atlas == null:
		var linhas: int = ceili(MATERIAIS.size() / float(COLS))
		var img := Image.create_empty(C * COLS, C * linhas, false, Image.FORMAT_RGB8)
		for i in MATERIAIS.size():
			var ox: int = (i % COLS) * C
			var oy: int = (i / COLS) * C
			for py in C:
				for px in C:
					img.set_pixel(ox + px, oy + py, _cor(MATERIAIS[i], float(px) / C, float(py) / C, px, py))
		_atlas = ImageTexture.create_from_image(img)
		_tam = Vector2(img.get_width(), img.get_height())
	return _atlas


## O atlas com o normal map (Relevo): juntas de tijolo, ondas do zinco e frestas das tábuas reagem à lanterna.
static func atlas_relevo() -> Texture2D:
	if _relevo == null:
		_relevo = CanvasTexture.new()
		_relevo.diffuse_texture = atlas()
		_relevo.normal_texture = ImageTexture.create_from_image(Relevo.gerar(atlas().get_image(), 1.6))
	return _relevo


## UV no atlas do ponto (fu, fv) ∈ [0, 1] da célula do material (1 texel para dentro: sem vazar para a vizinha).
static func uv(mat: String, fu: float, fv: float) -> Vector2:
	atlas()
	var i: int = maxi(0, MATERIAIS.find(mat))
	var o := Vector2((i % COLS) * C, (i / COLS) * C)
	return (o + Vector2(1.0, 1.0) + Vector2(clampf(fu, 0.0, 1.0), clampf(fv, 0.0, 1.0)) * (C - 2.0)) / _tam


static func uv_branco() -> Vector2:
	return uv("branco", 0.5, 0.5)


static func tinta(cor: Color) -> Color:
	return Color(cor.r * REALCE, cor.g * REALCE, cor.b * REALCE, cor.a)


# ───────────────────────────── geração ─────────────────────────────

static func _h(x: int, y: int, s: int) -> float:
	return TerrenoTexturas._hash(x, y, s)


static func _vn(x: float, y: float, per: int, s: int) -> float:
	return TerrenoTexturas._vn(x, y, per, s)


## Fiadas de tijolo: devolve [é argamassa, tom do tijolo]. 'linhas' fiadas e 'por' tijolos por fiada na célula.
static func _tijolos(u: float, v: float, linhas: int, por: int, s: int) -> Array:
	var fy: float = v * linhas
	var row: int = floori(fy)
	var fx: float = u * por + (0.5 if row % 2 == 1 else 0.0)
	var col: int = posmod(floori(fx), por)
	var dy: float = (fy - row) * (float(C) / linhas)               # px dentro da fiada
	var dx: float = (fx - floorf(fx)) * (float(C) / por)
	var junta: bool = dy < 1.3 or dx < 1.3
	var tom: float = 0.78 + 0.26 * _h(col, row, s)
	return [junta, tom]


static func _cor(nome: String, u: float, v: float, px: int, py: int) -> Color:
	var grao: float = _h(px, py, 3) - 0.5
	match nome:
		"branco":
			return Color.WHITE
		"tijolo":
			var t: Array = _tijolos(u, v, 12, 4, 21)
			var sujo: float = _vn(u * 4.0, v * 4.0, 4, 22)
			var f: float = (0.55 if t[0] else float(t[1])) * (0.92 + 0.1 * grao) * (1.0 - 0.18 * clampf(sujo - 0.45, 0.0, 1.0))
			var c := Color(f, f * 0.96, f * 0.92)
			if not t[0] and _h(px / 3, py / 3, 23) < 0.03:            # lascas
				c = c.darkened(0.25)
			return c
		"reboco", "reboco_liso":
			# buracos no reboco: manchas irregulares longe das bordas da célula (senão viram faixas a cada trecho)
			var borda: float = minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) * 2.0
			var desc: float = (0.6 * _vn(u * 4.0, v * 4.0, 4, 35) + 0.4 * _vn(u * 8.0, v * 8.0, 8, 36)) * smoothstep(0.0, 0.35, borda)
			var mancha: float = _vn(u * 6.0, v * 2.0, 6, 33)
			var f2: float = (0.95 + 0.06 * grao) * (1.0 - 0.14 * clampf(mancha - 0.5, 0.0, 1.0) * 2.0)
			if nome == "reboco_liso":
				desc = 0.0
			if desc > 0.66:                                             # caiu o reboco: tijolo aparecendo
				var t2: Array = _tijolos(u, v, 12, 4, 34)
				var g: float = 0.5 if t2[0] else float(t2[1]) * 0.9
				return Color(0.92 * g, 0.55 * g, 0.42 * g)
			if desc > 0.62:                                             # borda do buraco
				return Color(0.62, 0.58, 0.52)
			return Color(f2, f2 * 0.98, f2 * 0.94)
		"concreto":
			var junta2: bool = px < 1 or py < 1                         # um painel por célula
			var escorrido: float = _vn(u * 10.0, v * 1.5, 10, 41)       # manchas de água escorrendo
			var limo: float = _vn(u * 3.0, v * 3.0, 3, 42)
			var f3: float = (0.9 + 0.08 * grao + 0.06 * _vn(u * 12.0, v * 12.0, 12, 43)) * (1.0 - 0.12 * clampf(escorrido - 0.55, 0.0, 1.0) * 2.0)
			var c3 := Color(f3, f3, f3 * 0.97)
			c3 = c3.lerp(Color(0.62, 0.72, 0.5), clampf((limo - 0.7) * 3.0, 0.0, 0.25))
			return c3.darkened(0.35) if junta2 else c3
		"madeira":
			var tab: float = v * 8.0                                    # 8 tábuas por célula
			var it: int = floori(tab)
			var dt: float = (tab - it) * (float(C) / 8.0)
			var veio: float = _vn(u * 2.0, v * 24.0, 2, 51)
			var f4: float = (0.84 + 0.14 * _h(it, 0, 52) + 0.08 * veio + 0.05 * grao)
			if dt < 1.6:
				f4 *= 0.55                                              # sombra da tábua de cima
			elif dt < 3.0:
				f4 *= 1.08
			var c4 := Color(f4, f4, f4)
			if _vn(u * 4.0, v * 8.0, 4, 53) > 0.7:                      # tinta descascada: madeira crua
				c4 = Color(0.72, 0.6, 0.48) * (0.85 + 0.15 * veio)
			return c4
		"zinco", "zinco_telhado":
			var onda: float = 0.5 + 0.5 * sin(u * TAU * 6.0)
			var f5: float = 0.62 + 0.42 * onda * onda + 0.04 * grao
			var c5 := Color(f5, f5, f5)
			# ferrugem escorrida: listras verticais finas mais algumas manchas
			var ferr: float = _vn(u * 24.0, v * 2.0, 24, 62) * 0.65 + _vn(u * 6.0, v * 6.0, 6, 61) * 0.35
			c5 = c5.lerp(Color(0.7, 0.4, 0.22) * (0.75 + 0.3 * onda), clampf((ferr - 0.56) * 2.4, 0.0, 0.7))
			if nome == "zinco_telhado" and posmod(py, C / 2) < 1:      # emenda das chapas
				c5 = c5.darkened(0.35)
			return c5
		"papel_listras", "papel_motivo":
			var f6: float = 0.95 + 0.04 * grao
			if nome == "papel_listras":
				if posmod(px, 12) < 5:
					f6 *= 0.87
			else:
				var mx: int = posmod(px + (6 if posmod(py / 12, 2) == 1 else 0), 12) - 6
				var my: int = posmod(py, 12) - 6
				if absi(mx) + absi(my) < 3:
					f6 *= 0.8
			var c6 := Color(f6, f6, f6)
			var umidade: float = _vn(u * 3.0, v * 3.0, 3, 71)
			c6 = c6.lerp(Color(0.62, 0.52, 0.36), clampf((umidade - 0.7) * 2.5, 0.0, 0.35))
			if _vn(u * 5.0, v * 5.0, 5, 72) > 0.8:                      # papel rasgado: reboco por baixo
				c6 = Color(0.82, 0.8, 0.74) * (0.95 + 0.05 * grao)
			return c6
		"telha":
			var fy7: float = v * 6.0                                    # 6 fiadas, 4 telhas por fiada
			var r7: int = floori(fy7)
			var dy7: float = fy7 - r7
			var fx7: float = u * 4.0 + (0.5 if r7 % 2 == 1 else 0.0)
			var c7i: int = posmod(floori(fx7), 4)
			var curva: float = sin((fx7 - floorf(fx7)) * PI)            # telha canal: claro no meio
			var f7: float = (0.62 + 0.38 * curva) * (0.85 + 0.2 * _h(c7i, r7, 73)) * (0.75 + 0.25 * dy7)
			if dy7 > 0.9:
				f7 *= 0.45                                              # sombra da fiada de cima
			if _h(c7i, r7, 74) < 0.025:
				return Color(0.12, 0.1, 0.09)                           # telha faltando
			var c7 := Color(f7, f7 * 0.95, f7 * 0.9)
			return c7.lerp(Color(0.5, 0.6, 0.35), clampf((_vn(u * 4.0, v * 4.0, 4, 75) - 0.7) * 2.5, 0.0, 0.5))
		"ardosia":
			var fy8: float = v * 8.0
			var r8: int = floori(fy8)
			var dy8: float = fy8 - r8
			var fx8: float = u * 3.0 + (0.5 if r8 % 2 == 1 else 0.0)
			var dx8: float = (fx8 - floorf(fx8)) * (float(C) / 3.0)
			var c8i: int = posmod(floori(fx8), 3)
			var f8: float = (0.78 + 0.26 * _h(c8i, r8, 81)) * (0.9 + 0.1 * dy8) + 0.04 * grao
			if dx8 < 1.4 or dy8 > 0.92:
				f8 *= 0.45
			var c8 := Color(f8, f8, f8)
			return c8.lerp(Color(0.45, 0.58, 0.3), clampf((_vn(u * 3.0, v * 3.0, 3, 82) - 0.66) * 2.5, 0.0, 0.6))
		"laje":
			var junta9: bool = px < 1 or py < 1 or posmod(px, C / 2) < 1 or posmod(py, C / 2) < 1
			var poca: float = _vn(u * 2.0, v * 2.0, 2, 91)
			var f9: float = 0.9 + 0.08 * _vn(u * 10.0, v * 10.0, 10, 92) + 0.06 * grao
			var c9 := Color(f9, f9, f9 * 0.98)
			c9 = c9.lerp(Color(0.45, 0.47, 0.48), clampf((poca - 0.62) * 3.0, 0.0, 0.6))
			c9 = c9.lerp(Color(0.55, 0.65, 0.42), clampf((_vn(u * 4.0, v * 4.0, 4, 93) - 0.7) * 2.5, 0.0, 0.5))
			return c9.darkened(0.25) if junta9 else c9
	return Color(1, 0, 1)
