class_name Fachada
extends RefCounted
## Fachada e cobertura dos prédios — tradução de fachadaPredio, janelaAndar, vitrines, placaFace, pichar,
## deteriorar, escadaIncendio, telhadoPlano e torreIgreja da V13 (docs/prototipo_html_v13/index.html, l.528-690).
##
## Tudo é Polygon2D dentro do nó de cada trecho de parede (1 tile), então a decoração fica translúcida e escurece
## junto com a parede. Elementos maiores que um trecho (placa, escada de incêndio, varanda) são desenhados pelo
## trecho onde começam. Coordenadas da face: u ao longo da parede (0..64 no trecho), v = altura em px de tela.

const TILE := 64.0
const METRO := 49.48
const VPM := 30.3

const LOJAS := ["PADARIA", "BAR DO ZÉ", "FERRAGENS", "LAVANDERIA", "BARBEARIA", "LANCHONETE", "ÓTICA", "LOTÉRICA",
	"PAPELARIA", "MERCEARIA", "PIZZARIA", "ARMARINHO", "ARMAS & CAÇA", "PET SHOP", "AÇOUGUE", "SAPATARIA", "BRECHÓ",
	"DINER 24H", "HOTEL", "CINEMA"]
const CORES_PLACA := [["#2a3a5a", "#e8dcb0"], ["#6a1e1a", "#f0e6cc"], ["#1e4a32", "#e6e2d0"], ["#3a2a1e", "#e8c060"],
	["#e0dccc", "#2a2a2a"], ["#5a3a6a", "#f0e0f0"]]
const PICHA := ["NÃO ABRA", "MORTOS DENTRO", "SOCORRO", "ELES ESTÃO AQUI", "FUJAM", "NÃO É SEGURO",
	"DEUS NOS ABANDONOU", "IIII IIII III", "VÁ PARA O SUL", "ÁGUA →", "LIMPO", "✕ INFECTADOS ✕"]
const TOLDOS := [["#8a2a22", "#e8e0cc"], ["#1e4a6a", "#e8e0cc"], ["#2a5a32", "#e8e0cc"], ["#6a4a1e", "#e8d8a0"]]


## Texto (com ou sem fundo) num plano qualquer: quem cria define 'transform' (eixo x = direção de leitura).
class TextoFace extends Node2D:
	var txt := ""
	var cor := Color.WHITE
	var fundo := Color(0, 0, 0, 0)
	var largura := 100.0              ## no espaço local (u da parede)
	var altura := 20.0                ## px
	var escala_x := 1.75              ## compensa o achatamento do eixo isométrico (letras proporcionais)
	var giro := 0.0
	var escorrido := false            ## pichação: pingos de tinta

	func _ready() -> void:
		light_mask = 2

	func _draw() -> void:
		if fundo.a > 0.0:
			draw_rect(Rect2(4, 4, largura, altura), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(0, 0, largura, altura), fundo)
			draw_rect(Rect2(0, 0, largura, altura), Color(0, 0, 0, 0.55), false, 2.0)
		var f := ThemeDB.fallback_font
		var fs: int = maxi(6, int(altura * 0.62))
		var tam := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var sx := escala_x
		if tam.x * sx > largura * 0.9:
			sx = largura * 0.9 / maxf(1.0, tam.x)
		draw_set_transform(Vector2(largura * 0.5, altura * 0.5), giro, Vector2(sx, 1.0))
		draw_string(f, Vector2(-tam.x * 0.5, (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cor)
		if escorrido:
			for k in 6:
				var x := (Fachada.h(k, txt.length()) - 0.5) * tam.x * 0.8
				draw_rect(Rect2(x, altura * 0.3, 1.6, 4.0 + Fachada.h(txt.length(), k) * 12.0), Color(cor, 0.5))
		draw_set_transform(Vector2.ZERO)


## Base linear de uma face de parede: P(u, v, w) = o + u·du + w·dw − (0, v). Muito mais barato que chamar o
## Callable P do Edificio milhares de vezes (a fachada de um hospital tem uns 3600 quadriláteros).
class Face:
	var e: Edificio
	var no: Node2D
	var o: Vector2
	var du: Vector2
	var dw: Vector2

	func _init(e_: Edificio, no_: Node2D, P: Callable) -> void:
		e = e_
		no = no_
		o = P.call(0.0, 0.0, 0.0)
		du = P.call(1.0, 0.0, 0.0) - o
		dw = P.call(0.0, 0.0, 1.0) - o

	func p(u: float, v: float, w: float = 6.6) -> Vector2:
		return o + du * u + dw * w - Vector2(0.0, v)

	func q(u0: float, v0: float, u1: float, v1: float, c: Color, w: float = 6.6) -> void:
		var b := o + dw * w
		var a0 := b + du * u0
		var a1 := b + du * u1
		var pts := PackedVector2Array([a0 - Vector2(0.0, v0), a1 - Vector2(0.0, v0), a1 - Vector2(0.0, v1), a0 - Vector2(0.0, v1)])
		if no is Desenho:
			(no as Desenho).poli(pts, c)
		else:
			e._poli(no, pts, c)

	func poli(pts: Array, c: Color) -> void:
		e._poli(no, pts, c)


static func zm(m: float) -> float:
	return m * VPM


## Hash determinístico 0..1 (V13: hsh).
static func h(a: float, b: float) -> float:
	var x := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - floorf(x)


static func cor(hex: String) -> Color:
	return Color(hex)


static func _texto(no: Node2D, F: Face, X: bool, u0: float, u1: float, v_topo: float, alt: float, txt: String,
		fg: Color, bg: Color = Color(0, 0, 0, 0)) -> TextoFace:
	var tx := TextoFace.new()
	tx.txt = txt
	tx.cor = fg
	tx.fundo = bg
	tx.largura = u1 - u0
	tx.altura = alt
	var d: Vector2 = F.p(1.0, 0.0, 7.0) - F.p(0.0, 0.0, 7.0)
	# face sul: lê no sentido de +x; face leste: no sentido de -y (senão o texto sai espelhado)
	var ox: Vector2 = F.p(u0 if X else u1, v_topo, 7.0)
	tx.transform = Transform2D(d if X else -d, Vector2(0, 1), ox)
	no.add_child(tx)
	return tx


# ═════════════════════════════════ fachada ═════════════════════════════════

## Decora o trecho 't' da parede externa 'p' (lado s ou e) do prédio 'e'. 'ab' = abertura do trecho (porta/janela) ou null.
static func trecho(e: Edificio, no: Node2D, p: Dictionary, t: int, P_parede: Callable, ab) -> void:
	var F := Face.new(e, no, P_parede)
	var X: bool = p.eixo == "x"
	var U: float = (t - p.a) * TILE                  # início do trecho na fachada
	var L: float = (p.b - p.a) * TILE                # comprimento da fachada
	var H: float = e.altura_paredes()
	var ph: float = e.altura_andar()
	var n: int = e.andares
	var frente: bool = p.lado == e.frente
	var gal: bool = e.cobertura == "galpao"
	var igr: bool = e.cobertura == "igreja"
	var sd: float = e.semente + (0.0 if X else 41.0)
	var dm: float = e.dano
	var porta: bool = ab != null and ab.tipo == "porta"
	var dentro := func(a: float) -> bool: return a >= U and a < U + TILE

	# material
	if e.mat_tipo == "zinco":
		for k in 4:
			F.q(k * 16.0 + 6.0, 0.0, k * 16.0 + 9.0, H, Color(0, 0, 0, 0.13))
	elif e.mat_tipo == "tijolo":
		for k in 3:
			var bx := h(sd + U, k) * 52.0
			var by := h(k, sd + U) * (H - 20.0)
			F.q(bx, by, bx + 12.0, by + 6.0, Color(0, 0, 0, 0.08))
	elif e.mat_tipo == "madeira":
		var v := 12.0
		while v < H:
			F.q(0.0, v, 64.0, v + 1.5, Color(0, 0, 0, 0.12))
			v += 12.0
	# embasamento escuro (0,45 m)
	F.q(0.0, 0.0, 64.0, zm(0.45), Color(0.23, 0.21, 0.19, 0.85))
	if not gal and not igr:
		for k in range(1, n):                         # faixas entre os andares
			F.q(0.0, k * ph - 5.0, 64.0, k * ph, Color(0, 0, 0, 0.22))
			F.q(0.0, k * ph, 64.0, k * ph + 3.0, Color(1, 1, 1, 0.09))
		if n > 1 and (t - p.a) % 4 == 0:              # pilastras
			F.q(0.0, 0.0, 6.0, H, Color(0, 0, 0, 0.09))
		F.q(0.0, H - zm(0.4), 64.0, H, Color(1, 1, 1, 0.1))          # cimalha
		F.q(0.0, H - zm(0.45), 64.0, H - zm(0.45) + 3.0, Color(0, 0, 0, 0.25))
	# térreo da loja: vitrine e toldo
	if e.loja and frente:
		if not porta:
			_vitrine(e, no, F, U, sd, dm)
		var cs: Array = TOLDOS[int(h(e.semente + 1, 0.5) * TOLDOS.size()) % TOLDOS.size()]
		for k in 4:
			if h(e.semente + U + k * 16.0, 2.0) < dm * 0.3:
				continue                              # toldo rasgado
			F.q(k * 16.0, zm(2.62), k * 16.0 + 16.0, zm(3.04), cor(cs[k % 2]), 9.0)
		F.q(0.0, zm(2.5), 64.0, zm(2.62), Color(0, 0, 0, 0.35))
	# janelas dos andares de cima
	if not gal and not igr and t >= p.a + 1 and t < p.b - 1:
		var passo: int = 1 if (e.uso == "hospital" or e.uso == "escola") else 2
		if (t - p.a) % passo == 0:
			for k in range(1, n):
				_janela_andar(e, no, F, 10.0, k * ph + zm(0.85), 44.0, zm(1.35), h(sd + t * 3.1, k * 7.7), dm)
	if gal and (t - p.a) % 3 == 1:                    # galpão: venezianas altas
		F.q(4.0, H - zm(1.5), 60.0, H - zm(0.7), Color(0, 0, 0, 0.25))
	if igr and t >= p.a + 1 and t < p.b - 1 and (t - p.a - 1) % 3 == 0:
		_vitral(e, no, F, h(e.semente, t) < dm * 0.5)
	# portões de enrolar (oficina e galpão)
	if (e.uso == "oficina" or gal) and frente:
		var np: int = 2 if gal else maxi(1, int(L / (TILE * 5.0)))
		for i in np:
			var w := zm(4.6 if gal else 3.2)
			var a0 := L * (i + 1) / (np + 1) - w * 0.5
			if dentro.call(a0) or (i == 0 and U == 0.0 and a0 < 0.0):
				_portao_enrolar(e, no, F, a0 - U, w, zm(4.4 if gal else 3.2), h(e.semente, i + 5))
	# escada de incêndio (residencial, 3+ andares)
	if str(e.extras.get("incendio", "")) == p.lado and n >= 3:
		var u0 := L * 0.18 + h(e.semente, 4) * L * 0.4
		if dentro.call(u0):
			_escada_incendio(e, no, F, u0 - U, ph, n)
	# varandas
	if e.extras.get("varanda", false) and n >= 2 and frente and t >= p.a + 1 and t < p.b - 1 and (t - p.a - 1) % 4 == 0:
		for k in range(1, n):
			if h(e.semente + t, k) < 0.3:
				continue
			_varanda(e, no, F, k * ph + zm(0.1), h(t, k + e.semente))
	# delegacia: faixa azul
	if e.uso == "delegacia":
		F.q(0.0, ph - zm(0.6), 64.0, ph - zm(0.25), Color8(30, 60, 120))
		F.q(0.0, ph - zm(0.25), 64.0, ph - zm(0.17), Color8(232, 232, 232))
	# marquise sobre a entrada dos prédios públicos
	if frente and porta and ab.ref.ext and e.uso in ["hospital", "escola", "delegacia", "banco", "mercado"]:
		var w2 := zm(6.0 if e.uso == "mercado" else 4.5)
		F.q(32.0 - w2 * 0.5, zm(2.85), 32.0 + w2 * 0.5, zm(2.97), Color(0, 0, 0, 0.4), 14.0)
		F.q(32.0 - w2 * 0.5, zm(2.95), 32.0 + w2 * 0.5, zm(3.4),
			Color8(232, 230, 222) if e.uso == "hospital" else Color8(138, 135, 128), 14.0)
		if e.uso == "banco":
			for i in 4:
				var cx := 32.0 - w2 * 0.5 + w2 * (i + 0.5) / 4.0
				F.q(cx - 7.0, zm(0.45), cx + 7.0, zm(2.95), Color8(216, 208, 188), 16.0)
				F.q(cx + 3.0, zm(0.45), cx + 7.0, zm(2.95), Color(0, 0, 0, 0.2), 16.2)
	# placa
	if frente and not e.placa.is_empty() and t == int((p.a + p.b) / 2):
		var v := (ph - zm(0.15)) if n > 1 else minf(H - zm(1.05), zm(3.1))
		_placa(e, no, F, X, L * 0.5 - U, v, L)
	if e.uso == "hospital" and n > 2 and frente and dentro.call(L * 0.85):
		var cx2 := L * 0.85 - U
		var cy := H - zm(2.2)
		var sz := zm(0.9)
		F.q(cx2 - sz * 1.2, cy - sz * 1.2, cx2 + sz * 1.2, cy + sz * 1.2, Color8(240, 238, 232))
		F.q(cx2 - sz, cy - sz / 3.0, cx2 + sz, cy + sz / 3.0, Color8(192, 30, 30), 6.8)
		F.q(cx2 - sz / 3.0, cy - sz, cx2 + sz / 3.0, cy + sz, Color8(192, 30, 30), 6.8)
	_deteriorar(e, no, F, p, t, U, L, H, sd, dm, X)


static func _janela_andar(e: Edificio, no: Node2D, F: Face, u: float, v: float, w: float, hh: float, s: float, dm: float) -> void:
	F.q(u - 4.0, v - 5.0, u + w + 4.0, v, Color(0, 0, 0, 0.32))          # peitoril
	F.q(u - 2.0, v, u + w + 2.0, v + hh, Color8(184, 176, 154))          # moldura
	if s < dm * 0.22:                                 # vidro estilhaçado
		F.q(u, v + 2.0, u + w, v + hh - 2.0, Color8(7, 9, 11))
		F.poli([F.p(u, v + 2.0, 7.0), F.p(u + w * 0.35, v + 2.0, 7.0), F.p(u, v + hh * 0.55, 7.0)], Color(0.59, 0.67, 0.7, 0.35))
		F.poli([F.p(u + w, v + hh - 2.0, 7.0), F.p(u + w * 0.7, v + hh - 2.0, 7.0), F.p(u + w, v + hh * 0.7, 7.0)], Color(0.59, 0.67, 0.7, 0.35))
		return
	if s < dm * 0.42:                                 # tábuas
		F.q(u, v + 2.0, u + w, v + hh - 2.0, Color8(20, 16, 12))
		for k in 3:
			var vb := v + 8.0 + k * (hh - 14.0) / 2.0
			var inc := (h(s * 99.0, k) - 0.5) * 8.0
			F.poli([F.p(u - 4.0, vb - 4.0 + inc, 7.2), F.p(u + w + 4.0, vb - 4.0 - inc, 7.2),
				F.p(u + w + 4.0, vb + 4.0 - inc, 7.2), F.p(u - 4.0, vb + 4.0 + inc, 7.2)],
				Color8(110, 82, 54) if k % 2 else Color8(128, 98, 68))
		return
	if s < dm * 0.5:                                  # incendiada: fuligem acima
		F.q(u, v + 2.0, u + w, v + hh - 2.0, Color8(5, 5, 5))
		F.q(u - 8.0, v + hh, u + w + 8.0, v + hh + zm(1.0), Color(0.05, 0.035, 0.03, 0.55))
		F.q(u - 4.0, v + hh + zm(1.0), u + w + 4.0, v + hh + zm(1.7), Color(0.05, 0.035, 0.03, 0.25))
		return
	F.q(u, v + 2.0, u + w, v + hh - 2.0, Color8(29, 40, 49))
	F.poli([F.p(u + 4.0, v + hh - 4.0, 7.0), F.p(u + 15.0, v + hh - 4.0, 7.0), F.p(u + 6.0, v + 6.0, 7.0), F.p(u + 2.0, v + 6.0, 7.0)], Color(1, 1, 1, 0.14))
	if s > 0.8:                                       # cortina
		var cc: Array = [Color8(122, 74, 58), Color8(74, 90, 122), Color8(138, 122, 90), Color8(90, 106, 74)]
		var uc := u + (w * 0.55 if s > 0.9 else 0.0)
		F.q(uc, v + 2.0, uc + w * 0.45, v + hh - 2.0, cc[int(s * 997.0) % 4], 7.0)
	F.q(u + w * 0.5 - 1.3, v + 2.0, u + w * 0.5 + 1.3, v + hh - 2.0, Color8(184, 176, 154), 7.2)


static func _vitrine(e: Edificio, no: Node2D, F: Face, U: float, sd: float, dm: float) -> void:
	var v0 := zm(0.45)
	var v1 := zm(2.55)
	F.q(0.0, v0 - 3.0, 64.0, v1 + 3.0, Color8(42, 42, 44))
	var s := h(sd + floorf(U / 128.0) * 128.0, 3.3)                # uma vitrine a cada 2 tiles
	if s < dm * 0.45:                                 # quebrada
		F.q(2.0, v0, 60.0, v1, Color8(5, 6, 7), 7.0)
		F.poli([F.p(2.0, v0, 7.2), F.p(20.0, v0, 7.2), F.p(2.0, v0 + zm(0.9), 7.2)], Color(0.63, 0.7, 0.75, 0.35))
		F.poli([F.p(60.0, v1, 7.2), F.p(46.0, v1, 7.2), F.p(60.0, v1 - zm(0.7), 7.2)], Color(0.63, 0.7, 0.75, 0.35))
	elif s < dm * 0.75:                               # compensado pregado
		F.q(2.0, v0, 60.0, v1, Color8(138, 110, 74), 7.0)
		for k in [21.0, 42.0]:
			F.q(k, v0, k + 1.5, v1, Color(0.16, 0.11, 0.06, 0.5), 7.2)
	else:
		F.q(2.0, v0, 60.0, v1, Color8(30, 42, 50), 7.0)
		F.poli([F.p(10.0, v1 - 4.0, 7.2), F.p(30.0, v1 - 4.0, 7.2), F.p(14.0, v0 + 4.0, 7.2), F.p(4.0, v0 + 4.0, 7.2)], Color(1, 1, 1, 0.12))
		for k in 2:                                   # prateleiras vistas pelo vidro
			F.q(8.0 + k * 26.0, v0 + zm(0.5), 28.0 + k * 26.0, v0 + zm(1.6), Color(0, 0, 0, 0.35), 7.1)
	F.q(60.0, v0, 64.0, v1, Color8(58, 58, 60), 7.4)


static func _vitral(e: Edificio, no: Node2D, F: Face, quebrado: bool) -> void:
	var u := 12.0
	var w := 40.0
	var v := zm(1.2)
	var hh := zm(2.6)
	F.q(u - 3.0, v - 3.0, u + w + 3.0, v + hh + 3.0, Color8(42, 32, 24))
	if quebrado:
		F.q(u, v, u + w, v + hh, Color8(10, 10, 10), 6.8)
	else:
		F.q(u, v, u + w, v + hh * 0.33, Color8(200, 160, 80), 6.8)
		F.q(u, v + hh * 0.33, u + w, v + hh * 0.66, Color8(138, 74, 90), 6.8)
		F.q(u, v + hh * 0.66, u + w, v + hh, Color8(58, 90, 122), 6.8)
	F.poli([F.p(u, v + hh, 6.8), F.p(u + w * 0.5, v + hh + zm(0.6), 6.8), F.p(u + w, v + hh, 6.8)],
		Color8(10, 10, 10) if quebrado else Color8(58, 90, 122))
	F.q(u + w * 0.5 - 1.5, v, u + w * 0.5 + 1.5, v + hh, Color8(42, 32, 24), 7.0)
	F.q(u, v + hh * 0.5 - 1.5, u + w, v + hh * 0.5 + 1.5, Color8(42, 32, 24), 7.0)


static func _portao_enrolar(e: Edificio, no: Node2D, F: Face, u: float, w: float, hh: float, ab: float) -> void:
	F.q(u, 0.0, u + w, hh, Color8(11, 11, 11), 7.0)
	var ya := hh * (0.2 if ab < 0.35 else (0.65 if ab < 0.7 else 1.0))          # quanto da porta está abaixada
	F.q(u, hh - ya, u + w, hh, Color8(140, 138, 130), 7.2)
	var y := hh - ya + 10.0
	while y < hh:
		F.q(u, y, u + w, y + 1.2, Color(0, 0, 0, 0.3), 7.3)
		y += 10.0
	F.q(u, hh - ya, u + w, hh - ya + ya * 0.3, Color(0.47, 0.24, 0.09, 0.35), 7.3)
	F.q(u - 4.0, 0.0, u, hh + 4.0, Color8(58, 58, 58), 7.5)
	F.q(u + w, 0.0, u + w + 4.0, hh + 4.0, Color8(58, 58, 58), 7.5)
	F.q(u - 4.0, hh, u + w + 4.0, hh + 6.0, Color8(58, 58, 58), 7.5)


static func _escada_incendio(e: Edificio, no: Node2D, F: Face, u0: float, ph: float, n: int) -> void:
	var W := zm(2.4)
	var ferro := Color8(32, 33, 36)
	for k in range(1, n):
		var v := k * ph + zm(0.05)
		F.q(u0, v, u0 + W, v + 5.0, ferro, 22.0)                       # patamar
		F.q(u0, v + zm(1.0) - 1.5, u0 + W, v + zm(1.0), ferro, 22.0)   # guarda-corpo
		var x := u0
		while x <= u0 + W:
			F.q(x, v, x + 1.5, v + zm(1.0), ferro, 22.0)
			x += 9.0
		if k < n - 1:                                 # lance de escada até o patamar de cima
			F.poli([F.p(u0 + 6.0, v + 5.0, 22.0), F.p(u0 + 10.0, v + 5.0, 22.0),
				F.p(u0 + W - 6.0, v + ph, 22.0), F.p(u0 + W - 10.0, v + ph, 22.0)], ferro)
	F.q(u0 + W - 11.0, ph - zm(1.6), u0 + W - 9.0, ph, ferro, 22.0)    # escada retrátil
	F.q(u0 + W - 3.0, ph - zm(1.6), u0 + W - 1.0, ph, ferro, 22.0)


static func _varanda(e: Edificio, no: Node2D, F: Face, v: float, s: float) -> void:
	var u := 2.0
	var w := TILE * 1.5
	F.q(u, v, u + w, v + 6.0, Color8(108, 106, 100), 20.0)
	F.q(u, v + zm(1.0) - 1.4, u + w, v + zm(1.0), Color8(32, 34, 36), 20.0)
	var x := u
	while x <= u + w:
		F.q(x, v + 6.0, x + 1.4, v + zm(1.0), Color8(32, 34, 36), 20.0)
		x += 8.0
	if s < 0.25:                                      # roupa no varal
		var cc: Array = [Color8(138, 58, 58), Color8(58, 90, 138), Color8(200, 176, 112)]
		F.q(u + 8.0, v + zm(0.55), u + 8.0 + w * 0.5, v + zm(1.05), cc[int(s * 40.0) % 3], 20.5)


static func _placa(e: Edificio, no: Node2D, F: Face, X: bool, uc: float, v: float, L: float) -> void:
	var txt: String = e.placa[0]
	var bg: Color = e.placa[1] if e.placa[1] is Color else Color(e.placa[1])
	var fg: Color = e.placa[2] if e.placa[2] is Color else Color(e.placa[2])
	var alt := zm(0.8)
	var w := minf(L * 0.7, maxf(zm(2.4), txt.length() * zm(0.36) + zm(0.8)))
	if e.dano > 0.6:                                  # letras caídas
		var ch := ""
		for i in txt.length():
			ch += " " if h(e.semente, i) < 0.12 else txt[i]
		txt = ch
	_texto(no, F, X, uc - w * 0.5, uc + w * 0.5, v + alt, alt, txt, fg, bg)
	if e.uso == "hospital" or e.uso == "farmacia":   # cruz ao lado da placa
		var cx := uc - w * 0.5 - alt * 0.7
		var cy := v + alt * 0.5
		var sz := alt * 0.42
		var cruz := Color8(192, 30, 30) if e.uso == "hospital" else Color8(30, 138, 74)
		F.q(cx - alt * 0.55, cy - alt * 0.55, cx + alt * 0.55, cy + alt * 0.55, Color8(244, 242, 236), 8.0)
		F.q(cx - sz, cy - sz / 3.0, cx + sz, cy + sz / 3.0, cruz, 8.2)
		F.q(cx - sz / 3.0, cy - sz, cx + sz / 3.0, cy + sz, cruz, 8.2)
	for k in 4:                                       # escorrido de ferrugem
		var rx := uc - w * 0.5 + h(e.semente, k + 3) * w
		F.q(rx, v - zm(0.8), rx + 2.5, v, Color(0.35, 0.19, 0.09, 0.35), 7.5)


static func _deteriorar(e: Edificio, no: Node2D, F: Face, p: Dictionary, t: int, U: float, L: float, H: float,
		sd: float, dm: float, X: bool) -> void:
	# sujeira subindo do chão e escorridos de chuva
	F.q(0.0, 0.0, 64.0, zm(0.65), Color(0.15, 0.12, 0.09, 0.3))
	F.q(0.0, zm(0.65), 64.0, zm(1.3), Color(0.15, 0.12, 0.09, 0.14))
	for i in 2:
		var x := h(sd + U, i) * 60.0
		var l := zm(0.4) + h(i, sd + U) * H * 0.45
		F.q(x, H - l, x + 2.0 + h(i, 3.0) * 4.0, H, Color(0.11, 0.09, 0.07, 0.13))
	# buracos (dano alto)
	var nr: int = int((dm - 0.35) * 5.0) if dm > 0.45 else 0
	for i in nr:
		var cx := zm(1.0) + h(sd, i + 70) * (L - zm(2.0))
		if cx < U or cx >= U + TILE:
			continue
		var cy := zm(1.2) + h(i + 70, sd) * (H - zm(2.4))
		var r := zm(0.45) + h(i, 71) * zm(0.6)
		var borda: Array = []
		var miolo: Array = []
		for k in 9:
			var a := k / 9.0 * TAU
			var rr := r * (0.6 + h(i + k, sd) * 0.6)
			borda.append(F.p(cx - U + cos(a) * (rr + 4.0), cy + sin(a) * (rr + 4.0) * 0.85, 7.0))
			miolo.append(F.p(cx - U + cos(a) * rr, cy + sin(a) * rr * 0.85, 7.1))
		e._poli(no, borda, Color8(138, 90, 64))
		e._poli(no, miolo, Color8(18, 15, 13))
	# hera
	if e.musgo > 0.5:
		var nv: int = ceili(L / 90.0)
		for i in nv:
			var x := h(sd, i + 9) * L
			if x < U or x >= U + TILE:
				continue
			var comp := minf(H - 8.0, zm(1.5 + h(i, sd + 3) * 5.0))
			var y := 0.0
			while y < comp:
				var xx := x - U + sin(y / comp * 10.4 + i) * 7.0 + (h(y, i) - 0.5) * 18.0
				var vv := H - y
				var folha: Array = []
				for k in 6:
					var a2 := k / 6.0 * TAU
					folha.append(F.p(xx + cos(a2) * 4.5, vv + sin(a2) * 3.0, 7.4))
				e._poli(no, folha, Color8(79, 122, 44) if h(y, i + 1) > 0.5 else Color8(61, 100, 36))
				y += 7.0
	# pichação (uma por fachada, 55%)
	if h(sd, 120) < 0.55:
		var px := zm(1.5) + h(sd, 121) * (L - zm(3.0))
		if px >= U and px < U + TILE:
			var txt: String = PICHA[int(h(sd, 125) * PICHA.size()) % PICHA.size()]
			var c := Color8(168, 26, 18) if h(sd, 123) < 0.6 else (Color8(18, 18, 18) if h(sd, 124) < 0.5 else Color8(232, 232, 224))
			var alt := zm(0.62)
			var w := minf(L * 0.5, txt.length() * zm(0.32) + zm(0.6))
			var v := zm(1.3) + h(sd, 122) * zm(0.5)
			var tx := _texto(no, F, X, px - U - w * 0.5, px - U + w * 0.5, v + alt, alt, txt, Color(c, 0.85))
			tx.giro = (h(px, v) - 0.5) * 0.18
			tx.escorrido = true


# ═════════════════════════════════ cobertura ═════════════════════════════════

## Caixa isométrica (x0..x1 × y0..y1 × z0..z1) com faces sul e leste e tampo. 'S' = ponto 3D -> tela local.
static func caixa(e: Edificio, no: Node2D, S: Callable, x0: float, y0: float, x1: float, y1: float, z0: float, z1: float,
		topo: Color, sul: Color = Color(0, 0, 0, 0), leste: Color = Color(0, 0, 0, 0)) -> void:
	if sul.a == 0.0:
		sul = topo.darkened(0.15)
	if leste.a == 0.0:
		leste = topo.darkened(0.32)
	e._poli(no, [S.call(x0, y1, z0), S.call(x1, y1, z0), S.call(x1, y1, z1), S.call(x0, y1, z1)], sul)
	e._poli(no, [S.call(x1, y1, z0), S.call(x1, y0, z0), S.call(x1, y0, z1), S.call(x1, y1, z1)], leste)
	e._poli(no, [S.call(x0, y0, z1), S.call(x1, y0, z1), S.call(x1, y1, z1), S.call(x0, y1, z1)], topo)


## Cômodos que um volume (x0..x1 × y0..y1 até a altura z) tapa na tela.
static func _cobre(e: Edificio, x0: float, y0: float, x1: float, y1: float, z: float, cobre: Dictionary) -> void:
	for kx in 5:
		for ky in 5:
			var px := lerpf(x0, x1, kx / 4.0)
			var py := lerpf(y0, y1, ky / 4.0)
			for baixo in [0.0, 28.0, 54.0]:
				var si := e.sala_de(Vector2(px - 2.0 * (z - baixo), py - 2.0 * (z - baixo)))
				if si >= 0:
					cobre[si] = true


## Laje de um cômodo (V13: telhadoPlano): mureta na borda do prédio, aparelhos de ar, casa de máquinas, caixa d'água.
static func telhado_plano(e: Edificio, i: int) -> Dictionary:
	var s: Dictionary = e.salas[i]
	var x0: float = s.x0 * TILE
	var y0: float = s.y0 * TILE
	var x1: float = s.x1 * TILE
	var y1: float = s.y1 * TILE
	var H := e.altura_paredes()
	var hp := zm(0.9)
	var t := 0.3 * METRO
	var no := Desenho.new()
	no.position = e._s3(x1, y1) + Vector2(0, 2)
	e.add_child(no)
	var o := no.position
	var S := func(x: float, y: float, z: float) -> Vector2: return e._s3(x, y, z) - o
	var sd: float = e.semente + i * 13.0
	var laje := Color8(96, 95, 90).lerp(Color8(84, 86, 80), h(sd, 1))
	e._poli(no, [S.call(x0, y0, H), S.call(x1, y0, H), S.call(x1, y1, H), S.call(x0, y1, H)], laje)
	for k in 2:                                       # manchas de umidade e limo
		var cx := lerpf(x0, x1, h(sd, k + 30))
		var cy := lerpf(y0, y1, h(sd, k + 40))
		var pts: Array = []
		for a in 8:
			var ang := a / 8.0 * TAU
			pts.append(S.call(cx + cos(ang) * (30.0 + h(sd, k) * 50.0), cy + sin(ang) * (20.0 + h(sd, k + 1) * 30.0), H))
		e._poli(no, pts, Color(0.08, 0.09, 0.1, 0.28) if k % 2 else Color(0.27, 0.36, 0.2, 0.3))
	var mureta := e.cor_parede().darkened(0.1)
	if s.y0 == 0:
		caixa(e, no, S, x0, y0, x1, y0 + t, H, H + hp, mureta)
	if s.x0 == 0:
		caixa(e, no, S, x0, y0, x0 + t, y1, H, H + hp, mureta)
	# equipamentos (ordenados de trás para a frente)
	var itens: Array = []
	var area_m2 := (x1 - x0) * (y1 - y0) / (METRO * METRO)
	for k in mini(1, int(area_m2 / 30.0)):
		if h(sd, k + 50) > 0.45:
			continue
		itens.append([x0 + METRO + h(sd, k + 1) * maxf(1.0, x1 - x0 - 3.0 * METRO), y0 + METRO + h(sd, k + 11) * maxf(1.0, y1 - y0 - 3.0 * METRO),
			1.2 * METRO, METRO, zm(0.9), Color8(168, 170, 164), "ar"])
	var maior := 0
	for j in e.salas.size():
		if e._area(e.salas[j]) > e._area(e.salas[maior]):
			maior = j
	if i == maior and e.andares >= 2 and x1 - x0 > 5.0 * METRO and y1 - y0 > 4.5 * METRO:
		itens.append([x0 + 1.5 * METRO, y0 + 1.5 * METRO, 3.0 * METRO, 2.4 * METRO, zm(2.5), Color8(138, 133, 122), "maquinas"])
	if i == (maior + 1) % e.salas.size() and h(e.semente, 70) < 0.6 and x1 - x0 > 3.0 * METRO and y1 - y0 > 3.0 * METRO:
		itens.append([x0 + METRO, y0 + METRO, 1.7 * METRO, 1.7 * METRO, zm(2.2), Color8(122, 98, 72), "tanque"])
	itens.sort_custom(func(a, b): return a[0] + a[1] < b[0] + b[1])
	for it in itens:
		var ix: float = it[0]
		var iy: float = it[1]
		var iw: float = it[2]
		var idp: float = it[3]
		var ih: float = it[4]
		if it[6] == "tanque":
			for d in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var px: float = ix + d.x * (iw - 6.0)
				var py: float = iy + d.y * (idp - 6.0)
				caixa(e, no, S, px, py, px + 6.0, py + 6.0, H, H + zm(1.0), Color8(42, 42, 42))
			caixa(e, no, S, ix, iy, ix + iw, iy + idp, H + zm(1.0), H + zm(1.0) + ih, it[5])
			continue
		caixa(e, no, S, ix, iy, ix + iw, iy + idp, H, H + ih, it[5])
		if it[6] == "maquinas":                       # porta da escada
			e._poli(no, [S.call(ix + iw * 0.3, iy + idp, H), S.call(ix + iw * 0.55, iy + idp, H),
				S.call(ix + iw * 0.55, iy + idp, H + zm(2.0)), S.call(ix + iw * 0.3, iy + idp, H + zm(2.0))], Color8(58, 46, 36))
	if (e.uso == "hospital" or e.extras.get("socorro", false)) and i == maior:
		var tx := TextoFace.new()                     # "SOCORRO" pintado na laje
		tx.txt = "SOCORRO"
		tx.cor = Color(0.69, 0.09, 0.07, 0.85)
		tx.largura = (x1 - x0) * 0.8
		tx.altura = minf(2.4 * METRO, (y1 - y0) * 0.5)
		tx.escala_x = 1.0
		var org: Vector2 = S.call((x0 + x1) * 0.5 - tx.largura * 0.5, (y0 + y1) * 0.5 - tx.altura * 0.5, H)
		tx.transform = Transform2D(Vector2(0.5, 0.25), Vector2(-0.5, 0.25), org)
		no.add_child(tx)
	if not e.placa.is_empty() and (e.frente == "n" or e.frente == "w"):
		_placa_telhado(e, no, S, s, H)
	if s.y1 == e.altura_tiles:
		caixa(e, no, S, x0, y1 - t, x1, y1, H, H + hp, mureta)
	if s.x1 == e.largura_tiles:
		caixa(e, no, S, x1 - t, y0, x1, y1, H, H + hp, mureta)
	var cobre := {i: true}
	_cobre(e, x0, y0, x1, y1, H + hp, cobre)
	return {"no": no, "cobre": cobre, "alfa": 1.0}


## Placa em pé na beira da laje quando a frente do prédio fica de costas para a câmera (V13: placaTelhado).
static func _placa_telhado(e: Edificio, no: Node2D, S: Callable, s: Dictionary, H: float) -> void:
	var n_lado: bool = e.frente == "n"
	var borda_ok: bool = (s.y0 == 0) if n_lado else (s.x0 == 0)
	var meio: float = (e.largura_tiles if n_lado else e.altura_tiles) * TILE * 0.5
	var a0: float = (s.x0 if n_lado else s.y0) * TILE
	var a1: float = (s.x1 if n_lado else s.y1) * TILE
	if not borda_ok or meio < a0 or meio >= a1:
		return
	var txt: String = e.placa[0]
	var w := minf(9.0 * METRO, maxf(3.0 * METRO, txt.length() * 0.5 * METRO))
	var c := 1.2 * METRO
	var hp := H + zm(0.9)
	var alt := zm(1.1)
	for a in [meio - w * 0.5 + 0.6 * METRO, meio + w * 0.5 - 0.6 * METRO]:
		var base: Vector2 = S.call(a, c, hp) if n_lado else S.call(c, a, hp)
		e._poli(no, [base + Vector2(-2, 0), base + Vector2(2, 0), base + Vector2(2, -zm(1.2)), base + Vector2(-2, -zm(1.2))], Color8(42, 42, 42))
	var tx := TextoFace.new()
	tx.txt = txt
	tx.cor = e.placa[2] if e.placa[2] is Color else Color(e.placa[2])
	tx.fundo = e.placa[1] if e.placa[1] is Color else Color(e.placa[1])
	tx.largura = w
	tx.altura = alt
	var d: Vector2 = (S.call(1.0, 0.0, 0.0) - S.call(0.0, 0.0, 0.0)) if n_lado else -(S.call(0.0, 1.0, 0.0) - S.call(0.0, 0.0, 0.0))
	var ox: Vector2 = S.call(meio - w * 0.5, c, hp + zm(1.2) + alt) if n_lado else S.call(c, meio + w * 0.5, hp + zm(1.2) + alt)
	tx.transform = Transform2D(d, Vector2(0, 1), ox)
	no.add_child(tx)


## Torre da igreja na fachada da frente, com campanário, pirâmide e cruz (V13: torreIgreja).
static func torre_igreja(e: Edificio) -> Dictionary:
	var W: float = e.largura_tiles * TILE
	var D: float = e.altura_tiles * TILE
	var s := 3.6 * METRO
	var cx := W * 0.5
	var cy := D * 0.5
	var T: Rect2
	match e.frente:
		"s": T = Rect2(cx - s * 0.5, D - s, s, s)
		"n": T = Rect2(cx - s * 0.5, 0.0, s, s)
		"e": T = Rect2(W - s, cy - s * 0.5, s, s)
		_: T = Rect2(0.0, cy - s * 0.5, s, s)
	var H := e.altura_paredes()
	var hT := H + zm(4.0)
	var no := Desenho.new()
	no.position = e._s3(T.end.x, T.end.y) + Vector2(0, 4)
	e.add_child(no)
	var o := no.position
	var S := func(x: float, y: float, z: float) -> Vector2: return e._s3(x, y, z) - o
	var x0 := T.position.x
	var y0 := T.position.y
	var x1 := T.end.x
	var y1 := T.end.y
	caixa(e, no, S, x0, y0, x1, y1, 0.0, hT, Color8(200, 192, 176), e.cor_parede(), e.cor_parede().darkened(0.2))
	# campanário: aberturas nas faces sul e leste
	for face in ["s", "e"]:
		var A := func(u: float, v: float) -> Vector2:
			return S.call(x0 + u * (x1 - x0), y1, v) if face == "s" else S.call(x1, y1 - u * (y1 - y0), v)
		e._poli(no, [A.call(0.25, hT - zm(2.6)), A.call(0.75, hT - zm(2.6)), A.call(0.75, hT - zm(1.0)), A.call(0.5, hT - zm(0.55)), A.call(0.25, hT - zm(1.0))], Color8(12, 10, 8))
		e._poli(no, [A.call(0.0, hT - zm(0.3)), A.call(1.0, hT - zm(0.3)), A.call(1.0, hT), A.call(0.0, hT)], Color(0, 0, 0, 0.35))
	var ap: Vector2 = S.call((x0 + x1) * 0.5, (y0 + y1) * 0.5, hT + zm(5.0))
	e._poli(no, [S.call(x0, y1, hT), S.call(x1, y1, hT), ap], Color8(74, 78, 86))
	e._poli(no, [S.call(x1, y0, hT), S.call(x1, y1, hT), ap], Color8(56, 59, 66))
	e._poli(no, [ap + Vector2(-1.5, 0), ap + Vector2(1.5, 0), ap + Vector2(1.5, -zm(1.4)), ap + Vector2(-1.5, -zm(1.4))], Color8(26, 26, 26))
	e._poli(no, [ap + Vector2(-zm(0.45), -zm(1.0) - 1.5), ap + Vector2(zm(0.45), -zm(1.0) - 1.5), ap + Vector2(zm(0.45), -zm(1.0) + 1.5), ap + Vector2(-zm(0.45), -zm(1.0) + 1.5)], Color8(26, 26, 26))
	var cobre := {}
	_cobre(e, x0, y0, x1, y1, hT, cobre)
	var si := e.sala_de(Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5))
	if si >= 0:
		cobre[si] = true
	return {"no": no, "cobre": cobre, "alfa": 1.0}
