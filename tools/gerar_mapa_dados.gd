extends SceneTree
## Gera data/mapa_dados.res a partir de assets/new_assets/mapa_mundi_hd.png (o mapa-múndi é o guia geográfico).
## Rodar:  godot --headless --path . -s res://tools/gerar_mapa_dados.gd  [pasta para a prévia]
##
## Cada pixel do mapa vira um pixel de dados (RGBA8):
##   R = classe do terreno (MapaMundi.OCEANO, LAGO, PRAIA, MATA, CAMPO, ROCHA, NEVE, CANION, URBANO, PANTANO,
##       DESERTO, TERRA). URBANO fora das cidades = rodovias (cinza no mapa); TERRA = estradas de terra e solo nu
##       (o tom de areia fora do deserto). Onde a rodovia cruza o rio o pixel é cinza: a ponte já vem pronta.
##   G = densidade de mata (0..255, borrada)
##   B = bioma (0 = tropical, 128 = semiárido, 255 = deserto; borrado em faixa larga: transição orgânica)
##   A = distância com sinal até a margem da água: 128 + 16 × d (d em px; positivo dentro da água)

const ORIGEM := "res://assets/new_assets/mapa_mundi_hd.png"
const DESTINO := "res://data/mapa_dados.res"

# classes (iguais às de MapaMundi)
const OCEANO := 0
const LAGO := 1
const PRAIA := 2
const MATA := 3
const CAMPO := 4
const ROCHA := 5
const NEVE := 6
const CANION := 7
const URBANO := 8
const PANTANO := 9
const DESERTO := 10
const TERRA := 11

## Retângulos do mapa que não são terreno (rosa dos ventos, barra de escala, nuvem): viram oceano.
const APAGAR := [Rect2i(1185, 0, 127, 140), Rect2i(0, 1110, 340, 133), Rect2i(280, 0, 130, 48)]

var W := 0
var H := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var img: Image = (load(ORIGEM) as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGB8)
	W = img.get_width()
	H = img.get_height()
	print("mapa ", W, "x", H)
	var cls := PackedByteArray()
	cls.resize(W * H)
	var mata := PackedFloat32Array()
	mata.resize(W * H)
	var deserto := PackedFloat32Array()
	deserto.resize(W * H)
	var agua := PackedByteArray()
	agua.resize(W * H)
	for y in H:
		for x in W:
			var c := img.get_pixel(x, y)
			var i := y * W + x
			var apagar := false
			for r in APAGAR:
				if (r as Rect2i).has_point(Vector2i(x, y)):
					apagar = true
			if apagar or _eh_agua(c):
				agua[i] = 1
				cls[i] = OCEANO
				continue
			var k := _classe_terra(c, x, y)
			cls[i] = k
			mata[i] = 1.0 if k == MATA else (0.35 if k == PANTANO else 0.0)
			deserto[i] = 1.0 if k == DESERTO or k == CANION else 0.0
	# oceano = água ligada à borda; o resto da água é lago/rio
	var oce := PackedByteArray()
	oce.resize(W * H)
	var fila: Array[int] = []
	for x in W:
		for y in [0, H - 1]:
			var i0: int = y * W + x
			if agua[i0] == 1 and oce[i0] == 0:
				oce[i0] = 1
				fila.append(i0)
	for y in H:
		for x in [0, W - 1]:
			var i1: int = y * W + x
			if agua[i1] == 1 and oce[i1] == 0:
				oce[i1] = 1
				fila.append(i1)
	var k2 := 0
	while k2 < fila.size():
		var i2 := fila[k2]
		k2 += 1
		var x2 := i2 % W
		var y2 := i2 / W
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x2 + d.x
			var ny: int = y2 + d.y
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var j := ny * W + nx
			if agua[j] == 1 and oce[j] == 0:
				oce[j] = 1
				fila.append(j)
	for i in W * H:
		if agua[i] == 1 and oce[i] == 0:
			cls[i] = LAGO
	# moda 3×3 nas classes de terra: some com estradas, rótulos e pixels soltos
	cls = _moda(cls, agua)
	# praia: terra encostada no oceano (até 2 px), fora de rocha e cidade
	var dist_oce := _distancia(oce, 1)
	for i in W * H:
		if agua[i] == 0 and dist_oce[i] <= 2.0 and cls[i] in [MATA, CAMPO, DESERTO]:
			cls[i] = PRAIA
	# pântano (delta do sudoeste): terra baixa a até 3 px de lago/rio
	var lago := PackedByteArray()
	lago.resize(W * H)
	for i in W * H:
		lago[i] = 1 if cls[i] == LAGO else 0
	var dist_lago := _distancia(lago, 1)
	for y in range(760, H):
		for x in range(0, 500):
			var i3 := y * W + x
			if agua[i3] == 0 and dist_lago[i3] <= 3.0 and cls[i3] in [MATA, CAMPO]:
				cls[i3] = PANTANO
	# campo de distância com sinal até a margem
	var d_terra := _distancia(agua, 0)        # distância de cada pixel à terra mais próxima
	var d_agua := _distancia(agua, 1)         # distância de cada pixel à água mais próxima
	var mata_b := _borrar(mata, 4)
	var des_b := _borrar(deserto, 22)
	var des_grande := _borrar(deserto, 45)
	for i in W * H:                           # areia fina = estrada de terra; mancha isolada na mata = roça
		if cls[i] == DESERTO and des_b[i] < 0.3:
			cls[i] = TERRA
		elif cls[i] == DESERTO and des_grande[i] < 0.3:
			cls[i] = CAMPO
	var so_deserto := PackedFloat32Array()
	so_deserto.resize(W * H)
	for i in W * H:
		so_deserto[i] = 1.0 if cls[i] == DESERTO or cls[i] == CANION else 0.0
	des_b = _borrar(so_deserto, 30)           # bioma: transição larga (≈ 120 m) saindo do deserto
	var dados := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var previa := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var i := y * W + x
			var sd: float = d_terra[i] - 0.5 if agua[i] == 1 else -(d_agua[i] - 0.5)
			var a := clampi(roundi(128.0 + sd * 16.0), 0, 255)
			var bio := clampf(des_b[i] * 2.2 - 0.1, 0.0, 1.0)
			if cls[i] == DESERTO or cls[i] == CANION:
				bio = maxf(bio, 0.85)
			dados.set_pixel(x, y, Color8(cls[i], roundi(clampf(mata_b[i], 0.0, 1.0) * 255.0), roundi(bio * 255.0), a))
			previa.set_pixel(x, y, _cor_previa(cls[i], mata_b[i], bio, sd))
	var err := ResourceSaver.save(dados, DESTINO)
	print("salvo ", DESTINO, " erro=", err, " em ", Time.get_ticks_msec() - t0, " ms")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		previa.save_png(args[0].path_join("mapa_previa.png"))
	quit()


static func _eh_agua(c: Color) -> bool:
	# azul/ciano dominante; o mar raso perto da costa é ciano-esverdeado
	return c.b > c.r + 0.06 and c.b > c.g - 0.02 and c.s > 0.18


func _classe_terra(c: Color, x: int, y: int) -> int:
	var h := c.h
	var s := c.s
	var v := c.v
	var montanha := y < 235 and x > 270 and x < 700
	if s < 0.2 and v > 0.5:
		if montanha:
			return NEVE if v > 0.78 else ROCHA
		return URBANO
	if s < 0.22 and v <= 0.5:
		return ROCHA if montanha else URBANO
	# laranjas e ocres: areia do deserto; o vermelho-escuro bem saturado é o paredão do cânion
	if (h < 0.115 or h > 0.96) and s > 0.32 and v > 0.3:
		if h < 0.075 and s > 0.5 and v < 0.52:
			return CANION
		return DESERTO
	# verdes: mata (escura) ou campo (claro); amarelos e verde-claros também são campo/roça
	if h >= 0.115 and h < 0.45:
		return MATA if v < 0.42 else CAMPO
	return CAMPO


func _moda(cls: PackedByteArray, agua: PackedByteArray) -> PackedByteArray:
	var out := cls.duplicate()
	var cont := PackedInt32Array()
	cont.resize(16)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := y * W + x
			if agua[i] == 1:
				continue
			cont.fill(0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var j := (y + dy) * W + x + dx
					if agua[j] == 0:
						cont[cls[j]] += 1
			var melhor := cls[i]
			for k in 16:
				if cont[k] > cont[melhor]:
					melhor = k
			out[i] = melhor
	return out


## Distância (px, chanfro 3-4) de cada pixel ao pixel mais próximo com máscara == alvo.
func _distancia(mascara: PackedByteArray, alvo: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(W * H)
	var inf := 1.0e6
	for i in W * H:
		d[i] = 0.0 if mascara[i] == alvo else inf
	for y in H:
		for x in W:
			var i := y * W + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - W] + 1.0)
				if x > 0:
					v = minf(v, d[i - W - 1] + 1.4142)
				if x < W - 1:
					v = minf(v, d[i - W + 1] + 1.4142)
			d[i] = v
	for y in range(H - 1, -1, -1):
		for x in range(W - 1, -1, -1):
			var i := y * W + x
			var v := d[i]
			if x < W - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < H - 1:
				v = minf(v, d[i + W] + 1.0)
				if x < W - 1:
					v = minf(v, d[i + W + 1] + 1.4142)
				if x > 0:
					v = minf(v, d[i + W - 1] + 1.4142)
			d[i] = v
	return d


## Desfoque de caixa separável com raio r (duas passadas = quase gaussiano).
func _borrar(v: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var a := v
	for passo in 2:
		var b := PackedFloat32Array()
		b.resize(W * H)
		for y in H:
			var soma := 0.0
			for x in range(-r, r + 1):
				soma += a[y * W + clampi(x, 0, W - 1)]
			for x in W:
				b[y * W + x] = soma / (2 * r + 1)
				soma += a[y * W + clampi(x + r + 1, 0, W - 1)] - a[y * W + clampi(x - r, 0, W - 1)]
		var c := PackedFloat32Array()
		c.resize(W * H)
		for x in W:
			var soma2 := 0.0
			for y in range(-r, r + 1):
				soma2 += b[clampi(y, 0, H - 1) * W + x]
			for y in H:
				c[y * W + x] = soma2 / (2 * r + 1)
				soma2 += b[clampi(y + r + 1, 0, H - 1) * W + x] - b[clampi(y - r, 0, H - 1) * W + x]
		a = c
	return a


static func _cor_previa(k: int, mata: float, bio: float, sd: float) -> Color:
	var c: Color
	match k:
		OCEANO: c = Color("#1d3d5c") if sd > 1.0 else Color("#3d7c9c")
		LAGO: c = Color("#2b5d8a") if sd > 1.0 else Color("#5a9cc0")
		PRAIA: c = Color("#d8c690")
		MATA: c = Color("#2f5a22")
		CAMPO: c = Color("#7ea04a")
		ROCHA: c = Color("#7a7468")
		NEVE: c = Color("#e8eef0")
		CANION: c = Color("#8a3e24")
		URBANO: c = Color("#5c5c5c")
		PANTANO: c = Color("#5f7a4c")
		DESERTO: c = Color("#d6a35a")
		TERRA: c = Color("#8c6a42")
		_: c = Color.MAGENTA
	if k == MATA or k == CAMPO:
		c = c.lerp(Color("#c2a35a"), bio * 0.6)
	return c
