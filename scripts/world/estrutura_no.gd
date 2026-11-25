class_name EstruturaNo
extends Node2D
## Estrutura de uma comunidade que o jogador pode usar (etapa 12, VidaComunidade): o barril de água limpa e a bancada.
## - "agua": E com garrafa vazia enche de água limpa (de graça com reputação; senão custa 1 comida por garrafa).
## - "bancada": perto dela, com reputação, as receitas da mochila ficam 25% mais baratas (Itens.custo_receita).
## Desenhada com polígonos, sem colisão (como o mural).

const ALCANCE := 1.8 * IsoMath.METRO
const VPM := 30.3

var comunidade: String = ""
var tipo: String = "agua"


func _ready() -> void:
	add_to_group("interativo")
	y_sort_enabled = true
	light_mask = 2
	queue_redraw()


func _p(x: float, y: float, z: float) -> Vector2:
	return IsoMath.mundo_para_tela(Vector2(x, y)) - Vector2(0.0, z)


func _caixa(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_p(x0, y1, z0), _p(x1, y1, z0), _p(x1, y1, z1), _p(x0, y1, z1)]), cor.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([_p(x1, y1, z0), _p(x1, y0, z0), _p(x1, y0, z1), _p(x1, y1, z1)]), cor.darkened(0.42))
	draw_colored_polygon(PackedVector2Array([_p(x0, y0, z1), _p(x1, y0, z1), _p(x1, y1, z1), _p(x0, y1, z1)]), cor)


func _draw() -> void:
	var m := IsoMath.METRO
	draw_colored_polygon(PackedVector2Array([_p(-0.7 * m, -0.6 * m, 0), _p(0.7 * m, -0.6 * m, 0), _p(0.7 * m, 0.6 * m, 0),
		_p(-0.7 * m, 0.6 * m, 0)]), Color(0, 0, 0, 0.25))
	if tipo == "agua":
		# barril de madeira com aros de ferro e uma caneca pendurada
		var r := 0.38 * m
		var madeira := Color8(122, 86, 52)
		for k in 3:
			var z0 := k * 0.32 * VPM
			_caixa(-r, r, -r, r, z0, z0 + 0.32 * VPM, madeira if k != 1 else madeira.darkened(0.08))
			_caixa(-r - 1, r + 1, -r - 1, r + 1, z0 + 0.28 * VPM, z0 + 0.33 * VPM, Color8(70, 70, 74))
		_caixa(-r + 4, r - 4, -r + 4, r - 4, 0.95 * VPM, 0.97 * VPM, Color8(60, 90, 120))   # água
	else:
		# bancada: tampo de tábua sobre quatro pés, com serrote e martelo
		var madeira := Color8(132, 100, 66)
		for x in [-0.6, 0.5]:
			for y in [-0.3, 0.2]:
				_caixa(x * m, x * m + 6, y * m, y * m + 6, 0.0, 0.85 * VPM, madeira.darkened(0.2))
		_caixa(-0.65 * m, 0.65 * m, -0.35 * m, 0.3 * m, 0.85 * VPM, 0.95 * VPM, madeira)
		_caixa(-0.3 * m, 0.1 * m, -0.1 * m, -0.02 * m, 0.95 * VPM, 0.98 * VPM, Color8(170, 172, 176))   # serrote
		_caixa(0.25 * m, 0.45 * m, 0.0, 0.05 * m, 0.95 * VPM, 1.0 * VPM, Color8(90, 70, 50))           # martelo


func _dist() -> float:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	return INF if j == null else IsoMath.tela_para_mundo(j.global_position - global_position).length()


func prioridade_interacao() -> int:
	return 5


func texto_interacao() -> String:
	if _dist() > ALCANCE:
		return ""
	var rep := Reputacao.valor(comunidade)
	if Vigilancia.em_quarentena(comunidade):
		return "%s %s: fechado para você (quarentena)" % ["Barril" if tipo == "agua" else "Bancada", Comunidades.de(comunidade)]
	if tipo == "agua":
		return "E — encher garrafas com água limpa%s" % ("" if rep >= VidaComunidade.REP_AGUA else " (1 comida por garrafa)")
	return "Bancada %s: receitas 25%% mais baratas aqui (abra a mochila)" % Comunidades.de(comunidade) \
		if rep >= VidaComunidade.REP_BANCADA else "Bancada %s: só para quem a gente conhece" % Comunidades.de(comunidade)


func _process(_delta: float) -> void:
	if tipo == "bancada" and _dist() < ALCANCE * 1.5 and Reputacao.valor(comunidade) >= VidaComunidade.REP_BANCADA 			and not Vigilancia.em_quarentena(comunidade):
		Itens.bancada_ate = Time.get_ticks_msec() + 400


func _unhandled_input(event: InputEvent) -> void:
	if tipo != "agua" or not event.is_action_pressed("interact") or _dist() > ALCANCE or Vigilancia.em_quarentena(comunidade):
		return
	if get_tree().get_first_node_in_group("janela_jogo") != null:
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	var garrafas: int = j.inventario.contar("garrafa")
	if garrafas <= 0:
		j.aviso("Você não tem garrafa vazia.")
		return
	var paga := Reputacao.valor(comunidade) < VidaComunidade.REP_AGUA
	var n := garrafas if not paga else mini(garrafas, j.inventario.contar("comida"))
	if n <= 0:
		j.aviso("A água daqui é da comunidade. Para quem é de fora, custa 1 comida por garrafa.")
		return
	j.inventario.remover("garrafa", n)
	if paga:
		j.inventario.remover("comida", n)
		Simulacao.ajustar(comunidade, "comida", n)
	var resto: int = j.inventario.adicionar_parcial("agua_limpa", n)
	if resto > 0:
		j.largar_item("agua_limpa", resto)
	j.aviso("Você encheu %d garrafa%s com água limpa%s." % [n, "s" if n > 1 else "", " (pagou %d comida)" % n if paga else ""])
