extends Node2D
class_name Edificio
## Edifício procedural — tradução do sistema de construções do protótipo V13
## (docs/prototipo_html_v13/index.html: novoEdificio, bsp, porta, mobiliar,
## edifColisoes, edifSegs, geo, EDIF_atualizar).
##
## Como na V13, nada aqui é imagem: a planta é sorteada (BSP) dentro de um retângulo
## de tiles e paredes, portas, janelas, móveis e telhado são desenhados em código.
##   1 tile = 64 u = 1,29 m     tela.x = (x - y) * 0,5     tela.y = (x + y) * 0,25
##
## Diferenças pedidas em relação à V13:
##   - o telhado é dividido por cômodo e só some o do cômodo revelado;
##   - as paredes na frente da câmera não são cortadas: ficam translúcidas
##     (opacidade_frente), com portas e janelas ainda visíveis;
##   - cômodos atrás de porta fechada ficam escuros até a porta ser aberta;
##   - janelas abrem com E e só são atravessadas pulando (Espaço) encostado nelas.

const TILE := 64.0
const METRO := 49.48                 # unidades de mundo por metro
const VPM := 30.3                    # px de tela por metro de altura
const WH := 85.0                     # altura da parede (2,8 m)
const ESP := 6.0                     # meia-espessura da parede (u)
const ALT_PORTA := 64.0              # 2,1 m
const JAN_V0 := 27.0                 # peitoril (0,9 m)
const JAN_V1 := 62.0                 # verga (2,05 m)

const PAREDES_EXT := [Color8(196, 188, 170), Color8(112, 130, 98), Color8(110, 126, 140), Color8(134, 102, 76),
	Color8(190, 170, 118), Color8(152, 74, 54), Color8(112, 64, 50), Color8(188, 174, 150), Color8(152, 150, 142), Color8(180, 148, 138)]
const TELHAS := [Color8(80, 86, 94), Color8(152, 80, 54), Color8(98, 74, 60), Color8(72, 92, 78), Color8(130, 124, 114)]
const PAPEIS := {"sala": Color8(150, 128, 98), "quarto": Color8(118, 122, 142), "cozinha": Color8(172, 168, 140),
	"banheiro": Color8(140, 172, 174), "enfermaria": Color8(170, 186, 180), "nave": Color8(176, 164, 140), "_": Color8(164, 160, 150)}
const PISOS := {"sala": Color8(112, 86, 60), "quarto": Color8(124, 98, 70), "cozinha": Color8(156, 150, 132),
	"banheiro": Color8(150, 168, 170), "loja": Color8(150, 148, 140), "escritorio": Color8(128, 124, 116),
	"enfermaria": Color8(170, 176, 172), "aula": Color8(130, 104, 74), "nave": Color8(104, 80, 58),
	"deposito": Color8(110, 108, 100), "_": Color8(120, 116, 108)}
## móveis: [largura ao longo da parede, profundidade, altura] em metros
const MOV := {"cama": [1.5, 2.05, 0.55], "sofa": [2.0, 0.9, 0.85], "estante": [1.0, 0.38, 1.9], "armario": [1.3, 0.6, 2.0],
	"comoda": [1.0, 0.5, 0.9], "geladeira": [0.75, 0.7, 1.8], "fogao": [0.65, 0.62, 0.9], "balcao": [1.9, 0.62, 0.9],
	"pia": [0.6, 0.45, 0.85], "vaso": [0.42, 0.65, 0.42], "banheira": [1.6, 0.75, 0.55], "mesa": [1.3, 0.85, 0.76],
	"maca": [0.95, 2.0, 0.7], "armario_med": [1.0, 0.45, 1.9], "prateleira": [2.4, 0.6, 1.6], "mesa_esc": [1.4, 0.75, 0.76],
	"arquivo": [0.5, 0.65, 1.3], "carteira": [0.65, 0.5, 0.72], "banco_ig": [2.6, 0.55, 0.9], "caixa": [1.0, 1.0, 0.9]}
const SALAS_MOV := {"sala": ["sofa", "estante", "comoda", "mesa"], "quarto": ["cama", "armario", "comoda"],
	"cozinha": ["balcao", "geladeira", "fogao", "mesa"], "banheiro": ["vaso", "pia", "banheira"],
	"enfermaria": ["maca", "maca", "maca", "armario_med", "armario_med"],
	"escritorio": ["mesa_esc", "mesa_esc", "arquivo", "arquivo", "estante"],
	"loja": ["prateleira", "prateleira", "prateleira", "balcao"],
	"aula": ["carteira", "carteira", "carteira", "carteira", "carteira", "carteira", "mesa_esc"],
	"nave": ["banco_ig", "banco_ig", "banco_ig", "banco_ig"], "deposito": ["caixa", "caixa", "prateleira", "caixa", "caixa"]}
## móveis enfileirados no meio do cômodo (V13: CENTRO): prateleiras, carteiras, bancos de igreja, caixas
const FILEIRA := ["prateleira", "carteira", "banco_ig", "caixa"]
## cômodos por uso do prédio (V13: USO_SALAS); o primeiro é o da porta de entrada
const USO_SALAS := {"apartamentos": ["sala", "quarto", "cozinha", "banheiro"], "loja": ["loja", "deposito"],
	"farmacia": ["loja", "enfermaria"], "posto": ["loja", "deposito"], "galpao": ["deposito"], "igreja": ["nave"],
	"hospital": ["enfermaria", "escritorio"], "delegacia": ["escritorio"], "mercado": ["loja", "deposito"],
	"oficina": ["deposito"], "escola": ["aula", "escritorio"], "banco": ["escritorio"]}
## materiais de prédio (V13: PAREDES_PREDIO, MAT_USO) — [cor, tipo]; o tipo muda o desenho da fachada
const PAREDES_PREDIO := [[Color8(152, 74, 54), "tijolo"], [Color8(112, 64, 50), "tijolo"], [Color8(176, 128, 92), "tijolo"],
	[Color8(188, 174, 150), "reboco"], [Color8(152, 150, 142), "reboco"], [Color8(206, 202, 192), "reboco"],
	[Color8(128, 146, 164), "reboco"], [Color8(146, 160, 136), "reboco"], [Color8(136, 134, 128), "reboco"]]
const MAT_USO := {"hospital": [[Color8(206, 202, 192), "reboco"]], "banco": [[Color8(186, 178, 160), "reboco"]],
	"delegacia": [[Color8(152, 74, 54), "tijolo"]], "escola": [[Color8(176, 128, 92), "tijolo"], [Color8(152, 74, 54), "tijolo"]],
	"igreja": [[Color8(196, 188, 170), "madeira"]],
	"galpao": [[Color8(128, 126, 118), "zinco"], [Color8(96, 112, 130), "zinco"], [Color8(134, 100, 78), "zinco"]],
	"oficina": [[Color8(136, 134, 128), "reboco"], [Color8(128, 126, 118), "zinco"]],
	"mercado": [[Color8(188, 174, 150), "reboco"], [Color8(206, 202, 192), "reboco"]],
	"posto": [[Color8(206, 202, 192), "reboco"]], "farmacia": [[Color8(206, 202, 192), "reboco"], [Color8(146, 160, 136), "reboco"]]}
## placas por uso (V13: PLACAS) — [texto, fundo, letra]
const PLACAS := {"hospital": ["HOSPITAL", Color("#e8e6de"), Color("#b01e1e")], "farmacia": ["FARMÁCIA", Color("#1e7a46"), Color("#f0f0e8")],
	"mercado": ["SUPERMERCADO", Color("#b42a24"), Color("#f4efe0")], "banco": ["BANCO", Color("#24385e"), Color("#e2d6a0")],
	"delegacia": ["DELEGACIA", Color("#1a326e"), Color("#eeeeee")], "escola": ["ESCOLA ESTADUAL", Color("#82281e"), Color("#ecdcb4")],
	"oficina": ["OFICINA", Color("#28282c"), Color("#e6b428")], "posto": ["CONVENIÊNCIA", Color("#c8281e"), Color("#f5f0e6")],
	"galpao": ["DEPÓSITO", Color("#3a4a3a"), Color("#d8d8c8")]}
const CORES_MOV := {"cama": [Color8(122, 90, 58), Color8(94, 74, 60)], "sofa": [Color8(106, 74, 58), Color8(76, 90, 70), Color8(90, 78, 102)],
	"estante": [Color8(110, 78, 52)], "armario": [Color8(110, 78, 52), Color8(124, 96, 68)], "comoda": [Color8(124, 90, 62)],
	"geladeira": [Color8(200, 198, 188)], "fogao": [Color8(184, 180, 170)], "balcao": [Color8(138, 106, 72), Color8(196, 188, 168)],
	"mesa": [Color8(122, 90, 62)], "pia": [Color8(216, 216, 208)], "vaso": [Color8(224, 224, 216)], "banheira": [Color8(220, 220, 210)],
	"maca": [Color8(192, 196, 196)], "armario_med": [Color8(212, 216, 212)], "prateleira": [Color8(138, 142, 144)],
	"mesa_esc": [Color8(110, 84, 64), Color8(138, 128, 112)], "arquivo": [Color8(126, 132, 134)], "carteira": [Color8(138, 106, 72)],
	"banco_ig": [Color8(106, 74, 48)], "caixa": [Color8(154, 122, 82), Color8(138, 108, 72)]}

@export_group("Planta")
@export var largura_tiles: int = 10
@export var altura_tiles: int = 8
@export_enum("s", "e", "n", "w") var frente: String = "s"
@export var semente: int = 7
@export_group("Prédio")
## "casa" (V13: casaProc) ou "predio" (V13: predio — vários andares, uso, fachada decorada).
@export_enum("casa", "predio") var tipo: String = "casa"
@export var uso: String = "apartamentos"
@export_range(1, 8) var andares: int = 1
@export var pe_direito_m: float = 3.0         ## altura de cada andar
@export var altura_m: float = 0.0             ## > 0 substitui andares × pé-direito (igreja, galpão)
@export_enum("duas_aguas", "plana", "galpao", "igreja") var cobertura: String = "duas_aguas"
@export var loja: bool = false                ## térreo com vitrines e toldo na frente
@export var dano: float = -1.0                ## 0..1 (< 0 = sorteado); quebra janelas, abre buracos, apaga a placa
## [texto, fundo, letra] da placa da fachada; vazio = a do uso (PLACAS) ou nenhuma
@export var placa: Array = []
@export var extras: Dictionary = {}           ## {varanda: bool, incendio: "s"/"e", socorro: bool}
@export var bsp_prof: int = 4
@export var bsp_min: int = 4
@export_group("Moradores")
## Inimigos que dormem dentro da casa ao começar (V13: povoarEdificios).
@export var moradores: int = 0
@export_group("Visibilidade")
## Opacidade das paredes que ficam na frente da câmera quando o cômodo atrás delas está revelado.
@export_range(0.0, 1.0, 0.01) var opacidade_frente: float = 0.2
@export var velocidade_fade: float = 7.0
## Opacidade das paredes e telhados que ficam na frente do jogador quando ele passa por trás do edifício.
@export_range(0.0, 1.0, 0.01) var opacidade_oclusao: float = 0.28
## Tamanho (px de tela) da área em volta do jogador que fica visível através do edifício.
@export var janela_oclusao := Vector2(240.0, 220.0)

var salas: Array = []          ## {x0, y0, x1, y1 (tiles), tipo}
var paredes: Array = []        ## {eixo, c, a, b, lado, ab: [{t, tipo, ref}]}
var portas: Array = []         ## {parede, t, eixo, x, y, ext, open, quebrada, salas, col, no_col, no_ocl, seg}
var janelas: Array = []        ## {parede, t, x, y, estado, aberta, no_ocl, seg}
var moveis: Array = []         ## {x0, y0, x1, y1 (u), tipo, h, sala, cor, no}
var grafo: Array = []          ## por cômodo: portas internas ligadas a ele

var _rng := RandomNumberGenerator.new()
var _segs: Array = []          ## trechos de parede (1 tile): {no, parede, t, sala_cam, cobre, alfa}
var _telhados: Array = []      ## por cômodo: {no, cobre, alfa}
var _escuros: Array = []       ## por cômodo: Polygon2D
var _revelado: Array = []      ## por cômodo: bool
var _sala_jogador: int = -1
var _eixo: String = "x"
var _cor_parede: Color
var _cor_telha: Color
var _cor_porta: Color
var _R: float = 40.0
var _wh: float = WH            ## altura das paredes (casa: WH; prédio: andares × pé-direito)
var _ph: float = WH            ## altura de um andar
var mat_tipo: String = "reboco"
var musgo: float = 0.0
var _corpo: StaticBody2D
var _sujo: bool = true
var _rng_loot := RandomNumberGenerator.new()
## Construção fatiada: todos os edifícios dividem um orçamento por quadro, para um hospital de 4 andares
## (~27 ms) não travar o jogo ao entrar no raio de carregamento. Fica invisível até terminar.
const ORCAMENTO_US := 3500
static var _quadro: int = -1
static var _gasto_us: int = 0
var pronto := false
var _animando := true                ## fades ainda convergindo: só então _aplicar roda
var _ocluindo := false               ## alguma parede/telhado está na frente do jogador
var _ps_ultima := Vector2(INF, INF)  ## posição do jogador (tela local) na última checagem de oclusão
var _zona := Rect2()                 ## onde o jogador precisa estar para este edifício mudar algo (dentro ou atrás)
var _t_fatia: int = 0
var _grade := PackedInt32Array()   ## índice do cômodo por tile (-1 = fora): sala_idx em O(1)
var _hs_cobre: Array = []


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("interativo")
	add_to_group("edificio")
	_rng.seed = semente
	_rng_loot.randomize()
	visible = false
	set_physics_process(false)
	_t_fatia = Time.get_ticks_usec()
	_gerar_planta()
	if _estourou():
		await _pausa()
	await _construir()
	for seg in _segs:
		seg.caixa = (seg.no as Desenho).caixa()
		seg.ocl_j = false
	for t in _telhados:
		t.caixa = (t.no as Desenho).caixa()
		t.ocl_j = false
	# atrás do edifício: um ponto à altura h aparece sobre o chão em (x - 2h, y - 2h)
	var m := 2.0 * _wh + 2.0 * _R + 128.0
	_zona = Rect2(-m, -m, largura_tiles * TILE + m + 128.0, altura_tiles * TILE + m + 128.0)
	_recalcular()
	_aplicar(1000.0)
	visible = true
	pronto = true
	set_physics_process(true)
	if moradores > 0:
		_povoar()


## Soma o tempo desde a última fatia ao gasto do quadro; true = estourou o orçamento comum.
func _estourou() -> bool:
	var f := Engine.get_process_frames()
	if f != _quadro:
		_quadro = f
		_gasto_us = 0
	var agora := Time.get_ticks_usec()
	_gasto_us += agora - _t_fatia
	_t_fatia = agora
	return _gasto_us > ORCAMENTO_US


func _pausa() -> void:
	await get_tree().process_frame
	_t_fatia = Time.get_ticks_usec()


# =====================================================================
# GERAÇÃO (novoEdificio / bsp / porta / mobiliar da V13)
# =====================================================================
## Opções de prédio vindas do MundoGen (spec "o"). Chamar antes de entrar na árvore.
func configurar(o: Dictionary) -> void:
	for k in o:
		if k in self:
			set(k, o[k])


func predio() -> bool:
	return tipo == "predio"


func altura_paredes() -> float:
	return _wh


func altura_andar() -> float:
	return _ph


func cor_parede() -> Color:
	return _cor_parede


func cor_porta() -> Color:
	return _cor_porta


func _ri(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func _pick(lista: Array):
	return lista[_rng.randi_range(0, lista.size() - 1)]


func _bsp(r: Dictionary, d: int, internas: Array, max_d: int, min_t: int) -> void:
	var w: int = r.x1 - r.x0
	var h: int = r.y1 - r.y0
	var pode_v := w >= 2 * min_t
	var pode_h := h >= 2 * min_t
	if d >= max_d or (not pode_v and not pode_h) or (w * h <= min_t * min_t * 2.2 and _rng.randf() < 0.5):
		salas.append(r)
		return
	var prop := float(w) / float(h)
	var vert := pode_v and (not pode_h or prop > 1.15 or (prop > 0.87 and _rng.randf() < 0.5))
	if vert:
		var k: int = r.x0 + _ri(min_t, w - min_t)
		internas.append({"eixo": "y", "c": k, "a": r.y0, "b": r.y1})
		_bsp({"x0": r.x0, "y0": r.y0, "x1": k, "y1": r.y1}, d + 1, internas, max_d, min_t)
		_bsp({"x0": k, "y0": r.y0, "x1": r.x1, "y1": r.y1}, d + 1, internas, max_d, min_t)
	else:
		var k2: int = r.y0 + _ri(min_t, h - min_t)
		internas.append({"eixo": "x", "c": k2, "a": r.x0, "b": r.x1})
		_bsp({"x0": r.x0, "y0": r.y0, "x1": r.x1, "y1": k2}, d + 1, internas, max_d, min_t)
		_bsp({"x0": r.x0, "y0": k2, "x1": r.x1, "y1": r.y1}, d + 1, internas, max_d, min_t)


func sala_idx(tx: int, ty: int) -> int:
	if not _grade.is_empty():
		if tx < 0 or ty < 0 or tx >= largura_tiles or ty >= altura_tiles:
			return -1
		return _grade[ty * largura_tiles + tx]
	for i in salas.size():
		var s: Dictionary = salas[i]
		if tx >= s.x0 and tx < s.x1 and ty >= s.y0 and ty < s.y1:
			return i
	return -1


## Cômodo que contém o ponto (unidades de mundo locais); -1 = fora.
func sala_de(p: Vector2) -> int:
	return sala_idx(int(floor(p.x / TILE)), int(floor(p.y / TILE)))


func _montar_grade() -> void:
	_grade.resize(largura_tiles * altura_tiles)
	_grade.fill(-1)
	for i in salas.size():
		var s: Dictionary = salas[i]
		for ty in range(s.y0, s.y1):
			for tx in range(s.x0, s.x1):
				_grade[ty * largura_tiles + tx] = i


func _parede(eixo: String, c: int, a: int, b: int, lado: String) -> Dictionary:
	var p := {"eixo": eixo, "c": c, "a": a, "b": b, "lado": lado, "ab": []}
	paredes.append(p)
	return p


## Tile livre para porta/janela: não fica em cima do encontro com uma parede interna.
func _livre(p: Dictionary, t: int) -> bool:
	for q in paredes:
		if q != p and q.lado == "i" and q.eixo != p.eixo and (q.c == t or q.c == t + 1) and p.c >= q.a and p.c <= q.b:
			return false
	return true


func _porta(p: Dictionary, t: int, ext: bool) -> Dictionary:
	var r := _rng.randf()
	var cx: float = t * TILE + 32.0 if p.eixo == "x" else p.c * TILE
	var cy: float = p.c * TILE if p.eixo == "x" else t * TILE + 32.0
	var o := 0.75 * METRO
	var d := {"parede": p, "t": t, "eixo": p.eixo, "x": cx, "y": cy, "ext": ext,
		"open": (r < 0.3) if ext else (r < 0.55), "quebrada": ext and r > 0.85}
	if d.quebrada:
		d.open = true
	d.col = Rect2(cx - 24, cy - 6, 48, 12) if p.eixo == "x" else Rect2(cx - 6, cy - 24, 12, 48)
	var a := Vector2(cx, cy - o) if p.eixo == "x" else Vector2(cx - o, cy)
	var b := Vector2(cx, cy + o) if p.eixo == "x" else Vector2(cx + o, cy)
	d.salas = [sala_de(a), sala_de(b)]
	d.hp = 6.0                                   ## segundos de pancada de zumbi até arrombar
	d.pto = {d.salas[0]: a, d.salas[1]: b}       ## ponto de passagem de cada lado
	if ext:
		d.sala = d.salas[0] if d.salas[0] >= 0 else d.salas[1]
	p.ab.append({"t": t, "tipo": "porta", "ref": d})
	portas.append(d)
	return d


func _area(s: Dictionary) -> int:
	return (s.x1 - s.x0) * (s.y1 - s.y0)


func _gerar_planta() -> void:
	var internas: Array = []
	if predio():
		_bsp({"x0": 0, "y0": 0, "x1": largura_tiles, "y1": altura_tiles}, 0, internas, bsp_prof, bsp_min)
	else:
		_bsp({"x0": 0, "y0": 0, "x1": largura_tiles, "y1": altura_tiles}, 0, internas, 3, 3)
	_montar_grade()
	var pn := _parede("x", 0, 0, largura_tiles, "n")
	var ps := _parede("x", altura_tiles, 0, largura_tiles, "s")
	var pw := _parede("y", 0, 0, altura_tiles, "w")
	var pe := _parede("y", largura_tiles, 0, altura_tiles, "e")
	for i in internas:
		_parede(i.eixo, i.c, i.a, i.b, "i")
	# portas internas
	for p in paredes:
		if p.lado != "i":
			continue
		var cand: Array = []
		for t in range(p.a, p.b):
			if _livre(p, t):
				cand.append(t)
		if cand.is_empty():
			continue
		var k := int(cand.size() / 2.0 + (_rng.randf() - 0.5) * cand.size() * 0.6)
		_porta(p, cand[clampi(k, 0, cand.size() - 1)], false)
	# porta da frente
	var pf: Dictionary = {"n": pn, "s": ps, "w": pw, "e": pe}[frente]
	var cand_f: Array = []
	for t in range(pf.a + 1, pf.b - 1):
		if _livre(pf, t):
			cand_f.append(t)
	var meio: float = (pf.a + pf.b) / 2.0
	cand_f.sort_custom(func(u, v): return absf(u - meio) < absf(v - meio))
	var tf: int = int(meio)
	if not cand_f.is_empty():
		tf = cand_f[mini(cand_f.size() - 1, _ri(0, mini(3, cand_f.size()) - 1))]
	var porta_ext := _porta(pf, tf, true)
	# janelas (loja: vitrine na frente; igreja: vitrais desenhados na fachada)
	for p in [pn, ps, pw, pe]:
		if predio() and (cobertura == "igreja" or (loja and p == pf)):
			continue
		var t: int = p.a + 1
		while t < p.b - 1:
			var ocupado := false
			for a in p.ab:
				if absi(a.t - t) <= 1:
					ocupado = true
			if _livre(p, t) and not ocupado and _rng.randf() >= (0.12 if predio() else 0.2):
				var r := _rng.randf()
				var j := {"parede": p, "t": t, "estado": "ok" if r < 0.45 else ("quebrada" if r < 0.8 else "tabuas"), "aberta": false}
				j.x = t * TILE + 32.0 if p.eixo == "x" else p.c * TILE
				j.y = p.c * TILE if p.eixo == "x" else t * TILE + 32.0
				p.ab.append({"t": t, "tipo": "janela", "ref": j})
				janelas.append(j)
			t += 2
	# tipos de cômodo
	var ent: int = porta_ext.sala
	if predio() and uso != "apartamentos":
		var us: Array = USO_SALAS.get(uso, ["escritorio", "deposito"])
		for i in salas.size():
			salas[i].tipo = us[0] if i == ent else _pick(us)
	else:
		var ordem: Array = []
		for i in salas.size():
			salas[i].tipo = "quarto"
			if i != ent:
				ordem.append(i)
		ordem.sort_custom(func(i, j): return _area(salas[i]) < _area(salas[j]))
		if ent >= 0:
			salas[ent].tipo = "sala"
		if ordem.size() >= 3 and _area(salas[ordem[0]]) <= 12:
			salas[ordem.pop_front()].tipo = "banheiro"
		if not ordem.is_empty():
			salas[ordem.pop_back()].tipo = "cozinha"
	# grafo de cômodos (portas internas)
	for i in salas.size():
		grafo.append([])
	for d in portas:
		if not d.ext and d.salas[0] >= 0 and d.salas[1] >= 0:
			grafo[d.salas[0]].append(d)
			grafo[d.salas[1]].append(d)
	for i in salas.size():
		_mobiliar(i)
	# materiais e telhado
	_cor_parede = _pick(PAREDES_EXT)
	_cor_telha = _pick(TELHAS)
	_cor_porta = _pick([Color8(58, 63, 68), Color8(90, 58, 42), Color8(46, 74, 58), Color8(106, 42, 34)])
	_eixo = "x" if largura_tiles >= altura_tiles else "y"
	var meia: float = (altura_tiles if _eixo == "x" else largura_tiles) * TILE / 2.0 / METRO
	_R = roundf(meia * 0.55 * VPM)
	if predio():
		var m: Array = _pick(MAT_USO.get(uso, PAREDES_PREDIO))
		_cor_parede = m[0]
		mat_tipo = m[1]
		_ph = pe_direito_m * VPM
		_wh = altura_m * VPM if altura_m > 0.0 else andares * _ph
		if dano < 0.0:
			dano = _rng.randf_range(0.2, 0.75)
		musgo = _rng.randf()
		if placa.is_empty() and PLACAS.has(uso):
			placa = PLACAS[uso]
		if cobertura == "galpao":
			_cor_telha = Color8(130, 124, 114)
			_R = roundf(meia * 0.22 * VPM)
		elif cobertura == "igreja":
			_cor_telha = Color8(80, 86, 94)
			_R = roundf(meia * 0.95 * VPM)


func _sobrepoe(a: Rect2, b: Rect2, m: float) -> bool:
	return a.grow(m).intersects(b)


func _mobiliar(i: int) -> void:
	var s: Dictionary = salas[i]
	var x0: float = s.x0 * TILE + 8
	var y0: float = s.y0 * TILE + 8
	var x1: float = s.x1 * TILE - 8
	var y1: float = s.y1 * TILE - 8
	var zonas: Array = []
	for d in portas:
		if d.salas.has(i):
			zonas.append(Rect2(d.x - 0.75 * METRO, d.y - 0.75 * METRO, 1.5 * METRO, 1.5 * METRO))
	var filas := 0
	for tipo in SALAS_MOV.get(s.tipo, []):
		var w: float = MOV[tipo][0] * METRO
		var dd: float = MOV[tipo][1] * METRO
		for k in 24:
			var r: Rect2
			if tipo in FILEIRA:               # V13: fileiras de prateleiras, carteiras, bancos e caixas
				var cols: int = maxi(1, int((x1 - x0) / (w + METRO)))
				var col: int = filas % cols
				var lin: int = filas / cols
				filas += 1
				r = Rect2(x0 + 0.9 * METRO + col * (w + METRO) + _rng.randf_range(-4.0, 4.0), y0 + METRO + lin * (dd + 1.1 * METRO), w, dd)
			elif tipo == "mesa":
				var giro := _rng.randf() < 0.5
				var tam := Vector2(dd, w) if giro else Vector2(w, dd)
				var c := Vector2((x0 + x1) / 2 + _rng.randf_range(-0.6, 0.6) * METRO, (y0 + y1) / 2 + _rng.randf_range(-0.6, 0.6) * METRO)
				r = Rect2(c - tam / 2, tam)
			else:
				var lado: String = _pick(["n", "s", "w", "e"])
				var ao := lado == "n" or lado == "s"
				var comp := (x1 - x0) if ao else (y1 - y0)
				if comp < w:
					continue
				var p0 := (x0 if ao else y0) + _rng.randf() * (comp - w)
				match lado:
					"n": r = Rect2(p0, y0, w, dd)
					"s": r = Rect2(p0, y1 - dd, w, dd)
					"w": r = Rect2(x0, p0, dd, w)
					_: r = Rect2(x1 - dd, p0, dd, w)
			var ok := r.position.x >= x0 and r.position.y >= y0 and r.end.x <= x1 and r.end.y <= y1
			for z in zonas:
				if ok and r.intersects(z):
					ok = false
			for m in moveis:
				if ok and _sobrepoe(r, Rect2(m.x0, m.y0, m.x1 - m.x0, m.y1 - m.y0), 0.15 * METRO):
					ok = false
			if ok:
				moveis.append({"x0": r.position.x, "y0": r.position.y, "x1": r.end.x, "y1": r.end.y, "tipo": tipo,
					"h": MOV[tipo][2] * VPM, "sala": i, "usado": false, "cor": _pick(CORES_MOV.get(tipo, [Color8(107, 74, 51)]))})
				break


# =====================================================================
# CONSTRUÇÃO DOS NÓS
# =====================================================================
## Ponto 3D (u, u, px de altura) -> px de tela locais.
func _s3(x: float, y: float, z: float = 0.0) -> Vector2:
	return Vector2((x - y) * 0.5, (x + y) * 0.25 - z)


## Polígono em 'pai': num Desenho vira mais uma peça do mesmo _draw (barato); noutro nó, um Polygon2D.
func _poli(pai: Node, pts: Array, cor: Color) -> void:
	if pai is Desenho:
		(pai as Desenho).poli(PackedVector2Array(pts), cor)
		return
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color = cor
	p.light_mask = 2
	pai.add_child(p)


func _ret_iso(r: Rect2, rel: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([_s3(r.position.x, r.position.y) - rel, _s3(r.end.x, r.position.y) - rel,
		_s3(r.end.x, r.end.y) - rel, _s3(r.position.x, r.end.y) - rel])


func _colisor(r: Rect2) -> CollisionPolygon2D:
	var c := CollisionPolygon2D.new()
	c.polygon = _ret_iso(r)
	_corpo.add_child(c)
	return c


func _oclusor(r: Rect2) -> LightOccluder2D:
	var o := LightOccluder2D.new()
	var pol := OccluderPolygon2D.new()
	pol.polygon = _ret_iso(r)
	o.occluder = pol
	add_child(o)
	return o


func _subtrair(a: float, b: float, vaos: Array) -> Array:
	var out: Array = []
	var c := a
	vaos.sort_custom(func(u, v): return u[0] < v[0])
	for g in vaos:
		if g[0] > c:
			out.append([c, g[0]])
		c = maxf(c, g[1])
	if c < b:
		out.append([c, b])
	return out


## Altura do telhado sobre o ponto (x, y): duas águas com a cumeeira no meio.
func _alt_telhado(x: float, y: float) -> float:
	if cobertura == "plana" and predio():
		return _wh
	var ov := 0.42 * METRO
	if _eixo == "x":
		var meia := altura_tiles * TILE / 2.0
		return _wh + _R * (1.0 - absf(y - meia) / (meia + ov))
	var meia_x := largura_tiles * TILE / 2.0
	return _wh + _R * (1.0 - absf(x - meia_x) / (meia_x + ov))


func _construir() -> void:
	_corpo = StaticBody2D.new()
	add_child(_corpo)
	# ---------- colisão primeiro: o edifício já é sólido no primeiro quadro ----------
	for p in paredes:
		var vaos: Array = []
		for a in p.ab:
			if a.tipo == "porta":
				vaos.append([a.t * TILE + 3, a.t * TILE + 61])
		for u in _subtrair(p.a * TILE - ESP, p.b * TILE + ESP, vaos):
			if p.eixo == "x":
				_colisor(Rect2(u[0], p.c * TILE - ESP, u[1] - u[0], ESP * 2))
			else:
				_colisor(Rect2(p.c * TILE - ESP, u[0], ESP * 2, u[1] - u[0]))
	for d in portas:
		d.no_col = _colisor(d.col)
		d.no_col.disabled = d.open
	for m in moveis:
		if m.tipo != "carteira":                     # V13: carteiras não bloqueiam
			_colisor(Rect2(m.x0, m.y0, m.x1 - m.x0, m.y1 - m.y0))
	if _estourou():
		await _pausa()
	# ---------- pisos e sombras dos cômodos ----------
	for i in salas.size():
		var s: Dictionary = salas[i]
		var r := Rect2(s.x0 * TILE, s.y0 * TILE, (s.x1 - s.x0) * TILE, (s.y1 - s.y0) * TILE)
		var piso := Polygon2D.new()
		piso.polygon = _ret_iso(r)
		piso.color = PISOS.get(s.tipo, PISOS["_"])
		piso.z_index = -1
		add_child(piso)
	for i in salas.size():
		var s2: Dictionary = salas[i]
		var e := Polygon2D.new()
		e.polygon = _ret_iso(Rect2(s2.x0 * TILE, s2.y0 * TILE, (s2.x1 - s2.x0) * TILE, (s2.y1 - s2.y0) * TILE))
		e.color = Color(0.02, 0.02, 0.03, 0.94)
		e.z_index = -1
		e.modulate.a = 0.0
		add_child(e)
		_escuros.append(e)
		_revelado.append(false)
	# ---------- paredes (desenho), fatiado ----------
	for p in paredes:
		for t in range(p.a, p.b):
			_trecho(p, t)
			if _estourou():
				await _pausa()
	# ---------- móveis ----------
	for m in moveis:
		_movel(m)
		if _estourou():
			await _pausa()
	# ---------- telhado, um pedaço por cômodo ----------
	for i in salas.size():
		if predio() and cobertura == "plana":
			_telhados.append(Fachada.telhado_plano(self, i))
		else:
			_telhado(i)
		if _estourou():
			await _pausa()
	if predio() and cobertura == "igreja":
		_telhados.append(Fachada.torre_igreja(self))


## Um tile de parede: face, topo e a porta/janela que houver nele.
func _trecho(p: Dictionary, t: int) -> void:
	var eh_x: bool = p.eixo == "x"
	var centro := Vector2(t * TILE + 32.0, p.c * TILE) if eh_x else Vector2(p.c * TILE, t * TILE + 32.0)
	var dir := Vector2(1, 0) if eh_x else Vector2(0, 1)
	var cam := Vector2(0, 1) if eh_x else Vector2(1, 0)          # lado da parede virado para a câmera
	var no := Desenho.new()
	no.position = _s3(centro.x, centro.y)
	add_child(no)
	# ponto da face: u ao longo da parede (0..64), v = altura (px), w = afastamento para a câmera (u)
	var P := func(u: float, v: float, w: float = ESP) -> Vector2:
		var q := dir * (u - 32.0) + cam * w
		return _s3(q.x, q.y, v)
	var sala_cam: int = sala_idx(t, p.c) if eh_x else sala_idx(p.c, t)
	var cor: Color = _cor_parede
	if sala_cam >= 0:
		cor = PAPEIS.get(salas[sala_cam].tipo, PAPEIS["_"])
	if not eh_x:
		cor = cor.darkened(0.16)
	var ab = null
	for a in p.ab:
		if a.t == t:
			ab = a
	var seg := {"no": no, "parede": p, "t": t, "sala_cam": sala_cam, "alfa": 1.0, "cobre": {}}
	if ab == null:
		_poli(no, [P.call(0, 0), P.call(64, 0), P.call(64, _wh), P.call(0, _wh)], cor)
		_poli(no, [P.call(0, 0), P.call(64, 0), P.call(64, 7), P.call(0, 7)], cor.darkened(0.22))     # rodapé
		seg.ocl = _oclusor(_ret_parede(p, t * TILE, t * TILE + TILE))
	elif ab.tipo == "porta":
		var d: Dictionary = ab.ref
		d.seg = seg
		_poli(no, [P.call(0, 0), P.call(8, 0), P.call(8, _wh), P.call(0, _wh)], cor)
		_poli(no, [P.call(56, 0), P.call(64, 0), P.call(64, _wh), P.call(56, _wh)], cor)
		_poli(no, [P.call(8, ALT_PORTA), P.call(56, ALT_PORTA), P.call(56, _wh), P.call(8, _wh)], cor)
		_poli(no, [P.call(6, 0), P.call(8, 0), P.call(8, ALT_PORTA + 2), P.call(6, ALT_PORTA + 2)], Color8(74, 52, 36))
		_poli(no, [P.call(56, 0), P.call(58, 0), P.call(58, ALT_PORTA + 2), P.call(56, ALT_PORTA + 2)], Color8(74, 52, 36))
		_poli(no, [P.call(6, ALT_PORTA), P.call(58, ALT_PORTA), P.call(58, ALT_PORTA + 3), P.call(6, ALT_PORTA + 3)], Color8(74, 52, 36))
		# folha fechada (no plano da parede) e folha aberta (girada 90° para dentro, na dobradiça)
		d.folha_fechada = Desenho.new()
		no.add_child(d.folha_fechada)
		_poli(d.folha_fechada, [P.call(8, 0, 0), P.call(56, 0, 0), P.call(56, ALT_PORTA, 0), P.call(8, ALT_PORTA, 0)], _cor_porta)
		_poli(d.folha_fechada, [P.call(13, 6, 0), P.call(51, 6, 0), P.call(51, 28, 0), P.call(13, 28, 0)], _cor_porta.darkened(0.18))
		_poli(d.folha_fechada, [P.call(13, 34, 0), P.call(51, 34, 0), P.call(51, 58, 0), P.call(13, 58, 0)], _cor_porta.darkened(0.18))
		_poli(d.folha_fechada, [P.call(48, 30, 0), P.call(52, 30, 0), P.call(52, 34, 0), P.call(48, 34, 0)], Color8(200, 180, 110))
		d.folha_aberta = Desenho.new()
		no.add_child(d.folha_aberta)
		_poli(d.folha_aberta, [P.call(8, 0, 0), P.call(8, 0, -46), P.call(8, ALT_PORTA, -46), P.call(8, ALT_PORTA, 0)], _cor_porta.darkened(0.3))
		d.no_ocl = _oclusor(d.col)
		seg.ocl = null
	else:
		var j: Dictionary = ab.ref
		j.seg = seg
		_poli(no, [P.call(0, 0), P.call(64, 0), P.call(64, JAN_V0), P.call(0, JAN_V0)], cor)
		_poli(no, [P.call(0, JAN_V1), P.call(64, JAN_V1), P.call(64, _wh), P.call(0, _wh)], cor)
		_poli(no, [P.call(0, JAN_V0), P.call(12, JAN_V0), P.call(12, JAN_V1), P.call(0, JAN_V0 + (JAN_V1 - JAN_V0))], cor)
		_poli(no, [P.call(52, JAN_V0), P.call(64, JAN_V0), P.call(64, JAN_V1), P.call(52, JAN_V1)], cor)
		_poli(no, [P.call(0, 0), P.call(64, 0), P.call(64, 7), P.call(0, 7)], cor.darkened(0.22))
		_poli(no, [P.call(10, JAN_V0 - 3), P.call(54, JAN_V0 - 3), P.call(54, JAN_V0), P.call(10, JAN_V0)], Color8(184, 176, 154))   # peitoril
		j.no_vidro = Desenho.new()
		no.add_child(j.no_vidro)
		j.no_aberta = Desenho.new()
		no.add_child(j.no_aberta)
		var v0 := JAN_V0
		var v1 := JAN_V1
		if j.estado == "tabuas":
			_poli(j.no_vidro, [P.call(12, v0, 2), P.call(52, v0, 2), P.call(52, v1, 2), P.call(12, v1, 2)], Color8(20, 16, 12))
			for k in 3:
				var vb := v0 + 4 + k * 11.0
				var inc := (_rng.randf() - 0.5) * 5.0
				_poli(j.no_vidro, [P.call(8, vb + inc), P.call(56, vb - inc), P.call(56, vb - inc + 7), P.call(8, vb + inc + 7)],
					Color8(128, 98, 68) if k % 2 == 0 else Color8(110, 82, 54))
		else:
			_poli(j.no_vidro, [P.call(12, v0, 2), P.call(52, v0, 2), P.call(52, v1, 2), P.call(12, v1, 2)],
				Color(0.11, 0.16, 0.19, 0.9) if j.estado == "ok" else Color(0.03, 0.04, 0.05, 0.9))
			_poli(j.no_vidro, [P.call(31, v0, 2), P.call(33, v0, 2), P.call(33, v1, 2), P.call(31, v1, 2)], Color8(184, 176, 154))
			if j.estado == "ok":
				_poli(j.no_vidro, [P.call(15, v1 - 3, 2), P.call(24, v1 - 3, 2), P.call(18, v0 + 4, 2), P.call(14, v0 + 4, 2)], Color(1, 1, 1, 0.14))
			else:      # cacos
				_poli(j.no_vidro, [P.call(12, v0, 2), P.call(26, v0, 2), P.call(12, v0 + 16, 2)], Color(0.6, 0.68, 0.72, 0.4))
				_poli(j.no_vidro, [P.call(52, v1, 2), P.call(40, v1, 2), P.call(52, v1 - 12, 2)], Color(0.6, 0.68, 0.72, 0.4))
		# aberta: vão livre e as duas folhas viradas para dentro
		_poli(j.no_aberta, [P.call(12, v0, 0), P.call(12, v0, -18), P.call(12, v1, -18), P.call(12, v1, 0)], Color8(150, 142, 122))
		_poli(j.no_aberta, [P.call(52, v0, 0), P.call(52, v0, -18), P.call(52, v1, -18), P.call(52, v1, 0)], Color8(150, 142, 122))
		j.no_aberta.visible = false
		j.no_ocl = _oclusor(_ret_parede(p, t * TILE + 5, t * TILE + 59))
		seg.ocl = null
	if predio() and (p.lado == "s" or p.lado == "e"):
		Fachada.trecho(self, no, p, t, P, ab)       # fachada visível: andares, vitrines, placa, desgaste
	# topo da parede
	_poli(no, [P.call(0, _wh, -ESP), P.call(64, _wh, -ESP), P.call(64, _wh, ESP), P.call(0, _wh, ESP)], cor.lightened(0.18))
	# cômodos que esta parede taparia na tela: um ponto à altura h aparece sobre o piso em (x - 2h, y - 2h)
	for u in [6.0, 32.0, 58.0]:
		for h in _alturas_cobre():
			var q: Vector2 = centro + dir * (u - 32.0) - Vector2(2.0 * h, 2.0 * h)
			var si := sala_de(q)
			if si >= 0:
				seg.cobre[si] = true
	_segs.append(seg)


## Alturas testadas para saber que cômodos uma parede tapa na tela (paredes altas tapam mais longe).
func _alturas_cobre() -> Array:
	if not _hs_cobre.is_empty():
		return _hs_cobre
	_hs_cobre = [14.0, 36.0, 60.0]
	var h := 120.0
	while h < _wh:
		_hs_cobre.append(h)
		h += 96.0
	_hs_cobre.append(_wh)
	return _hs_cobre


func _ret_parede(p: Dictionary, u0: float, u1: float) -> Rect2:
	if p.eixo == "x":
		return Rect2(u0, p.c * TILE - 3, u1 - u0, 6)
	return Rect2(p.c * TILE - 3, u0, 6, u1 - u0)


func _movel(m: Dictionary) -> void:
	var no := Desenho.new()
	var base := Vector2((m.x0 + m.x1) / 2.0, (m.y0 + m.y1) / 2.0)
	no.position = _s3(base.x, base.y)
	add_child(no)
	var o: Vector2 = no.position
	var c: Color = m.cor
	var h: float = m.h
	_poli(no, [_s3(m.x0, m.y1) - o, _s3(m.x1, m.y1) - o, _s3(m.x1, m.y1, h) - o, _s3(m.x0, m.y1, h) - o], c.darkened(0.22))   # face sul
	_poli(no, [_s3(m.x1, m.y1) - o, _s3(m.x1, m.y0) - o, _s3(m.x1, m.y0, h) - o, _s3(m.x1, m.y1, h) - o], c.darkened(0.38))   # face leste
	_poli(no, [_s3(m.x0, m.y0, h) - o, _s3(m.x1, m.y0, h) - o, _s3(m.x1, m.y1, h) - o, _s3(m.x0, m.y1, h) - o], c)            # tampo
	if m.tipo == "cama":
		var k := 0.72
		_poli(no, [_s3(m.x0 + 3, m.y0 + (m.y1 - m.y0) * (1 - k), h + 1) - o, _s3(m.x1 - 3, m.y0 + (m.y1 - m.y0) * (1 - k), h + 1) - o,
			_s3(m.x1 - 3, m.y1 - 3, h + 1) - o, _s3(m.x0 + 3, m.y1 - 3, h + 1) - o], Color8(150, 150, 160))
	m.no = no


func _telhado(i: int) -> void:
	var s: Dictionary = salas[i]
	var ov := 0.42 * METRO
	var x0: float = s.x0 * TILE - (ov if s.x0 == 0 else 0.0)
	var y0: float = s.y0 * TILE - (ov if s.y0 == 0 else 0.0)
	var x1: float = s.x1 * TILE + (ov if s.x1 == largura_tiles else 0.0)
	var y1: float = s.y1 * TILE + (ov if s.y1 == altura_tiles else 0.0)
	var no := Desenho.new()
	no.position = _s3(s.x1 * TILE, s.y1 * TILE) + Vector2(0, 2)
	add_child(no)
	var o: Vector2 = no.position
	var T := func(x: float, y: float) -> Vector2:
		return _s3(x, y, _alt_telhado(x, y)) - o
	var faixas: Array = []       # [a0, a1, escurecer] ao longo do eixo que cruza a cumeeira
	if _eixo == "x":
		var m := altura_tiles * TILE / 2.0
		if y0 < m:
			faixas.append([y0, minf(y1, m), 0.32])
		if y1 > m:
			faixas.append([maxf(y0, m), y1, 0.03])
		for f in faixas:
			_poli(no, [T.call(x0, f[0]), T.call(x1, f[0]), T.call(x1, f[1]), T.call(x0, f[1])], _cor_telha.darkened(f[2]))
			_fiadas(no, T, true, x0, x1, f[0], f[1])
		if s.x1 == largura_tiles:          # oitão na parede leste
			var X := largura_tiles * TILE + ESP
			var pts: Array = [_s3(X, s.y0 * TILE, _wh) - o, _s3(X, s.y1 * TILE, _wh) - o, T.call(X, s.y1 * TILE)]
			if s.y0 * TILE < m and s.y1 * TILE > m:
				pts.append(T.call(X, m))
			pts.append(T.call(X, s.y0 * TILE))
			_poli(no, pts, _cor_parede.darkened(0.16))
	else:
		var mx := largura_tiles * TILE / 2.0
		if x0 < mx:
			faixas.append([x0, minf(x1, mx), 0.3])
		if x1 > mx:
			faixas.append([maxf(x0, mx), x1, 0.12])
		for f in faixas:
			_poli(no, [T.call(f[0], y1), T.call(f[0], y0), T.call(f[1], y0), T.call(f[1], y1)], _cor_telha.darkened(f[2]))
			_fiadas(no, T, false, f[0], f[1], y0, y1)
		if s.y1 == altura_tiles:           # oitão na parede sul
			var Y := altura_tiles * TILE + ESP
			var pts2: Array = [_s3(s.x0 * TILE, Y, _wh) - o, _s3(s.x1 * TILE, Y, _wh) - o, T.call(s.x1 * TILE, Y)]
			if s.x0 * TILE < mx and s.x1 * TILE > mx:
				pts2.append(T.call(mx, Y))
			pts2.append(T.call(s.x0 * TILE, Y))
			_poli(no, pts2, _cor_parede)
	# cômodos que este pedaço de telhado taparia (o piso e quem estiver em pé nele)
	var cobre := {i: true}
	for kx in 5:
		for ky in 5:
			var px := lerpf(x0, x1, kx / 4.0)
			var py := lerpf(y0, y1, ky / 4.0)
			var h := _alt_telhado(px, py)
			for baixo in [0.0, 28.0, 54.0]:
				var si := sala_de(Vector2(px - 2.0 * (h - baixo), py - 2.0 * (h - baixo)))
				if si >= 0:
					cobre[si] = true
	_telhados.append({"no": no, "cobre": cobre, "alfa": 1.0})


## Linhas das fiadas de telha, para o telhado não ficar chapado.
func _fiadas(no: Desenho, T: Callable, ao_longo_x: bool, a0: float, a1: float, b0: float, b1: float) -> void:
	var passo := 22.0
	var v := (b0 if ao_longo_x else a0) + passo
	var fim := b1 if ao_longo_x else a1
	while v < fim - 4.0:
		if ao_longo_x:
			no.linha(PackedVector2Array([T.call(a0, v), T.call(a1, v)]), Color(0, 0, 0, 0.22))
		else:
			no.linha(PackedVector2Array([T.call(v, b0), T.call(v, b1)]), Color(0, 0, 0, 0.22))
		v += passo


# =====================================================================
# VISIBILIDADE (EDIF_atualizar da V13, por cômodo)
# =====================================================================
func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


## Posição do jogador em unidades de mundo locais do edifício.
func _pos_jogador() -> Vector2:
	var j := _jogador()
	if j == null:
		return Vector2(-99999, -99999)
	return IsoMath.tela_para_mundo(to_local(j.global_position))


func jogador_dentro() -> bool:
	return _sala_jogador >= 0


func revelado(i: int) -> bool:
	return i >= 0 and i < _revelado.size() and _revelado[i]


## Cômodos revelados: o do jogador e os ligados a ele por portas internas ABERTAS.
func _recalcular() -> void:
	for i in _revelado.size():
		_revelado[i] = false
	if _sala_jogador < 0:
		return
	var fila: Array = [_sala_jogador]
	_revelado[_sala_jogador] = true
	while not fila.is_empty():
		var a: int = fila.pop_back()
		for d in grafo[a]:
			if not d.open:
				continue
			var b: int = d.salas[1] if d.salas[0] == a else d.salas[0]
			if not _revelado[b]:
				_revelado[b] = true
				fila.append(b)


func _physics_process(delta: float) -> void:
	var j := _jogador()
	if j == null:
		return
	var ps := to_local(j.global_position)              # tela local
	var p := IsoMath.tela_para_mundo(ps)               # mundo local
	var na_zona := _zona.has_point(p)
	# longe e parado: nada a fazer (antes cada edifício recalculava tudo a cada tick e derrubava o FPS na cidade)
	if not na_zona and not _animando and not _ocluindo and not _sujo:
		return
	if na_zona and pronto:
		_ima_de_porta(j, p, delta)
	var sala := sala_de(p) if na_zona else -1
	if sala != _sala_jogador or _sujo:
		_sala_jogador = sala
		_sujo = false
		_recalcular()
		_animando = true
	if ps.distance_squared_to(_ps_ultima) > 4.0 or not na_zona:
		_ps_ultima = ps
		if _atualizar_oclusao(ps if (na_zona and sala < 0) else Vector2(INF, INF)):
			_animando = true
	if _animando:
		_animando = _aplicar(delta)


## Ímã de porta (V13, l.1184): andando em direção a um vão aberto, o jogador é puxado para o meio dele,
## em vez de raspar no batente. p = posição do jogador no mundo local do edifício.
func _ima_de_porta(j: Node2D, p: Vector2, delta: float) -> void:
	if not "world_vel" in j or ("dirigindo" in j and j.dirigindo != null):
		return
	var v: Vector2 = j.world_vel
	if v.length() < 8.0:
		return
	var d = _porta_perto(p)
	if d == null or not d.open:
		return
	var X: bool = d.eixo == "x"                        # parede ao longo de x: atravessa-se em y
	var perp: float = p.y - d.y if X else p.x - d.x
	var lat: float = p.x - d.x if X else p.y - d.y
	var vp: float = v.y if X else v.x
	if absf(perp) >= 1.1 * METRO or absf(lat) >= 0.75 * METRO or vp * perp >= 0.0:
		return                                         # longe, fora do vão ou se afastando da porta
	var k := minf(1.0, delta * 9.0)
	var novo := p - (Vector2(lat, 0.0) if X else Vector2(0.0, lat)) * k
	j.global_position = to_global(IsoMath.mundo_para_tela(novo))


## Paredes e telhados desenhados por cima do jogador (ele está fora, atrás deles na tela). true = mudou algo.
func _atualizar_oclusao(ps: Vector2) -> bool:
	# janela em volta do boneco: larga o bastante para ver o entorno, não só o personagem
	var corpo := Rect2(ps.x - janela_oclusao.x * 0.5, ps.y - janela_oclusao.y * 0.75, janela_oclusao.x, janela_oclusao.y)
	var fora := ps.x == INF
	var mudou := false
	var algum := false
	for seg in _segs:
		var o: bool = not fora and seg.no.position.y > ps.y + 2.0 and (seg.caixa as Rect2).intersects(corpo)
		if o != seg.ocl_j:
			seg.ocl_j = o
			mudou = true
		algum = algum or o
	for t in _telhados:
		var o2: bool = not fora and t.no.position.y > ps.y + 2.0 and (t.caixa as Rect2).intersects(corpo)
		if o2 != t.ocl_j:
			t.ocl_j = o2
			mudou = true
		algum = algum or o2
	_ocluindo = algum
	return mudou


## Aproxima 'a' de 'b' e encosta quando a diferença fica imperceptível.
static func _rumo(a: float, b: float, k: float) -> float:
	var r := lerpf(a, b, k)
	return b if absf(r - b) < 0.01 else r


## Aplica (com fade) telhados, escuro dos cômodos, móveis e paredes translúcidas. true = ainda convergindo.
func _aplicar(delta: float) -> bool:
	var k := minf(1.0, delta * velocidade_fade)
	var mexendo := false
	var sem_teto: Array = []
	# telhado: some o do cômodo revelado (e o que taparia um cômodo revelado na tela); fica translúcido sobre o jogador
	for i in _telhados.size():
		var t: Dictionary = _telhados[i]
		var alvo := 1.0
		for c in t.cobre:
			if _revelado[c]:
				alvo = 0.0
		sem_teto.append(alvo < 0.5)
		if t.get("ocl_j", false):
			alvo = minf(alvo, opacidade_oclusao)
		var a := _rumo(t.alfa, alvo, k)
		if a != t.alfa or t.no.modulate.a != a:
			t.alfa = a
			t.no.modulate.a = a
			t.no.visible = a > 0.01
		mexendo = mexendo or a != alvo
	# cômodo sem telhado mas ainda não revelado: fica escuro, sem mostrar os móveis
	for i in _escuros.size():
		var e: Polygon2D = _escuros[i]
		var alvo_e := 1.0 if (sem_teto[i] and not _revelado[i]) else 0.0
		var ae := _rumo(e.modulate.a, alvo_e, k)
		if ae != e.modulate.a:
			e.modulate.a = ae
		mexendo = mexendo or ae != alvo_e
	for mv in moveis:
		var no_m: Node2D = mv.no
		var alvo_m := 1.0 if _revelado[mv.sala] else 0.0
		var am := _rumo(no_m.modulate.a, alvo_m, k)
		if am != no_m.modulate.a:
			no_m.modulate.a = am
			no_m.visible = am > 0.01
		mexendo = mexendo or am != alvo_m
	# paredes na frente da câmera: translúcidas (portas e janelas continuam visíveis)
	for seg in _segs:
		var alvo_s := 1.0
		for c in seg.cobre:
			if _revelado[c]:
				alvo_s = opacidade_frente
		if seg.ocl_j:
			alvo_s = minf(alvo_s, opacidade_oclusao)
		var escuro: bool = seg.sala_cam >= 0 and sem_teto[seg.sala_cam] and not _revelado[seg.sala_cam]
		var brilho := 0.12 if escuro else 1.0
		var cor: Color = seg.no.modulate
		var nova := Color(_rumo(cor.r, brilho, k), _rumo(cor.g, brilho, k), _rumo(cor.b, brilho, k), _rumo(seg.alfa, alvo_s, k))
		seg.alfa = nova.a
		if nova != cor:
			seg.no.modulate = nova
		mexendo = mexendo or nova.a != alvo_s or nova.r != brilho
	for d in portas:
		d.folha_fechada.visible = not d.open
		d.folha_aberta.visible = d.open and not d.quebrada
		d.no_ocl.occluder_light_mask = 0 if d.open else 1
	for jn in janelas:
		jn.no_vidro.visible = not jn.aberta
		jn.no_aberta.visible = jn.aberta
		# como na V13, vidro deixa a luz passar; só as tábuas bloqueiam
		jn.no_ocl.occluder_light_mask = 1 if (jn.estado == "tabuas" and not jn.aberta) else 0
	return mexendo


# =====================================================================
# INTERAÇÃO (portaPerto / EDIF_interagir da V13 + janelas)
# =====================================================================
func _porta_perto(p: Vector2):
	var melhor = null
	var dist := 1.15 * METRO
	for d in portas:
		var dd := p.distance_to(Vector2(d.x, d.y))
		if dd < dist:
			dist = dd
			melhor = d
	return melhor


# =====================================================================
# INIMIGOS: moradores, rotas e portas (V13: povoarEdificios, proxPorta, rota)
# =====================================================================
func _povoar() -> void:
	var cena: PackedScene = load("res://scenes/enemies/inimigo.tscn")
	for k in moradores:
		var sorteio := _rng.randf()
		var raca := "zombie" if sorteio < 0.58 else ("vampire" if sorteio < 0.8 else "rat")
		var s: Dictionary = _pick(salas)
		for t in 10:
			var x: float = (s.x0 + 0.5 + _rng.randf() * (s.x1 - s.x0 - 1)) * TILE
			var y: float = (s.y0 + 0.5 + _rng.randf() * (s.y1 - s.y0 - 1)) * TILE
			var livre := true
			for m in moveis:
				if x > m.x0 - 14 and x < m.x1 + 14 and y > m.y0 - 14 and y < m.y1 + 14:
					livre = false
			if not livre:
				continue
			var e: Node2D = cena.instantiate()
			e.raca = raca
			e.dorme = true
			e.casa = self
			get_parent().add_child(e)
			e.global_position = to_global(IsoMath.mundo_para_tela(Vector2(x, y)))
			break


## Porta de entrada da casa (a primeira externa).
func porta_ext():
	for d in portas:
		if d.ext:
			return d
	return null


## Menor caminho de portas internas entre os cômodos 'ra' e 'rb'; devolve a primeira porta.
func proxima_porta(ra: int, rb: int):
	if ra < 0 or rb < 0 or ra == rb:
		return null
	var prev := {ra: null}
	var fila := [ra]
	while not fila.is_empty():
		var c: int = fila.pop_front()
		if c == rb:
			break
		for d in grafo[c]:
			var o: int = d.salas[1] if d.salas[0] == c else d.salas[0]
			if not prev.has(o):
				prev[o] = [c, d]
				fila.append(o)
	if not prev.has(rb):
		return null
	var cur := rb
	var porta = null
	while prev[cur] != null:
		porta = prev[cur][1]
		if prev[cur][0] == ra:
			break
		cur = prev[cur][0]
	return porta


## Atravessa uma porta de A para B sem oscilar: longe -> ponto de entrada; perto do vão -> centro; no centro -> saída.
func _cruza(d: Dictionary, pos: Vector2, a: Vector2, b: Vector2) -> Array:
	var centro := Vector2(d.x, d.y)
	var dc := pos.distance_to(centro)
	if dc < 16.0:
		return [b, d]
	if dc < 44.0 or pos.distance_to(a) < 26.0:
		return [centro, d]
	return [a, d]


func _passar(d: Dictionary, de: int, pos: Vector2) -> Array:
	var o: int = d.salas[1] if d.salas[0] == de else d.salas[0]
	return _cruza(d, pos, d.pto[de], d.pto[o])


## Próximo ponto de passagem (e a porta, se houver) para ir de 'pos' a 'alvo', ambos locais e dentro da casa.
func rota_interna(pos: Vector2, alvo: Vector2) -> Array:
	var d = proxima_porta(sala_de(pos), sala_de(alvo))
	if d != null:
		return _passar(d, sala_de(pos), pos)
	return [alvo, null]


## De dentro da casa para fora: passa pelas portas internas até o cômodo da porta de entrada e sai.
func rota_saida(pos: Vector2) -> Array:
	var p = porta_ext()
	if p == null:
		return [pos, null]
	var ra := sala_de(pos)
	if ra != p.sala:
		var d = proxima_porta(ra, p.sala)
		if d != null:
			return _passar(d, ra, pos)
	return _cruza(p, pos, p.pto[p.sala], p.pto[-1])


## De fora para dentro: vai até a porta de entrada e entra.
func rota_entrada(pos: Vector2) -> Array:
	var p = porta_ext()
	if p == null:
		return [pos, null]
	return _cruza(p, pos, p.pto[-1], p.pto[p.sala])


func abrir_porta(d: Dictionary) -> void:
	if d.open:
		return
	d.open = true
	if d.has("no_col"):
		d.no_col.set_deferred("disabled", true)
	_sujo = true


## Pancada de zumbi na porta fechada. Devolve true quando ela cedeu.
func bater_porta(d: Dictionary, delta: float) -> bool:
	d.hp -= delta
	if d.hp > 0.0:
		return false
	d.quebrada = true
	abrir_porta(d)
	return true


## Móvel vasculhável (V13: movelPerto): só dentro da casa, ainda não vasculhado, a até 0,95 m.
func _movel_perto(p: Vector2):
	if not jogador_dentro():
		return null
	var melhor = null
	var dist := 0.95 * METRO
	for m in moveis:
		if m.usado or not Itens.CONTEM.has(m.tipo):
			continue
		var dx := maxf(maxf(m.x0 - p.x, 0.0), p.x - m.x1)
		var dy := maxf(maxf(m.y0 - p.y, 0.0), p.y - m.y1)
		var dd := Vector2(dx, dy).length()
		if dd < dist:
			dist = dd
			melhor = m
	return melhor


func prioridade_interacao() -> int:
	return 1


func _item_no_chao_perto() -> bool:
	return get_tree().get_nodes_in_group("item_chao").any(func(i): return i.texto_interacao() != "")


func _janela_perto(p: Vector2):
	var melhor = null
	var dist := 0.95 * METRO
	for j in janelas:
		var dd := p.distance_to(Vector2(j.x, j.y))
		if dd < dist:
			dist = dd
			melhor = j
	return melhor


## Texto que o HUD mostra quando há algo para interagir (vazio = nada).
func texto_interacao() -> String:
	if not pronto:
		return ""
	var p := _pos_jogador()
	var mv = _movel_perto(p)
	if mv != null:
		return "E — vasculhar " + Itens.CONTEM[mv.tipo]
	var d = _porta_perto(p)
	if d != null:
		if d.quebrada:
			return "Porta arrombada"
		return "E — fechar a porta" if d.open else "E — abrir a porta"
	var j = _janela_perto(p)
	if j != null:
		if j.estado == "tabuas":
			return "Janela tapada com tábuas"
		return "Espaço — pular a janela · E — fechar" if j.aberta else "E — abrir a janela"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	var interagir := event.is_action_pressed("interact")
	var pular := event.is_action_pressed("jump")
	if not pronto or (not interagir and not pular):
		return
	var jg := _jogador()
	if jg != null and "dirigindo" in jg and jg.dirigindo != null:
		return
	var p := _pos_jogador()
	if interagir and _item_no_chao_perto():
		return                                  # pegar do chão tem prioridade
	var mv = _movel_perto(p)
	if interagir and mv != null:
		var jog := _jogador()
		if jog != null and "inventario" in jog:
			Loot.vasculhar(jog, mv.tipo, _rng_loot, func(): mv.usado = true)
			get_viewport().set_input_as_handled()
		return
	var d = _porta_perto(p)
	var j = _janela_perto(p)
	if interagir and d != null:
		if d.quebrada:
			return
		if d.open and d.col.grow(10).has_point(p):
			return                              # tem alguém no vão: não fecha
		d.open = not d.open
		d.no_col.set_deferred("disabled", d.open)
		_sujo = true
		get_viewport().set_input_as_handled()
	elif interagir and j != null and j.estado != "tabuas":
		j.aberta = not j.aberta
		_sujo = true
		get_viewport().set_input_as_handled()
	elif pular and d == null and j != null and j.aberta:
		# a janela aberta não é um vão para andar: o jogador salta para o outro lado da parede
		var jogador := _jogador()
		if jogador != null and jogador.has_method("saltar_para"):
			var eh_x: bool = j.parede.eixo == "x"
			var lado := signf((p.y - j.y) if eh_x else (p.x - j.x))
			if lado == 0.0:
				lado = 1.0
			var o := 0.8 * METRO * -lado
			var destino := Vector2(j.x, j.y + o) if eh_x else Vector2(j.x + o, j.y)
			jogador.saltar_para(to_global(_s3(destino.x, destino.y)))
			get_viewport().set_input_as_handled()
