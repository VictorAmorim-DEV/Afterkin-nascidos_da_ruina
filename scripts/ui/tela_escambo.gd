class_name TelaEscambo
extends CanvasLayer
## Tela de escambo (Escambo): sua mochila à esquerda, o estoque do comerciante à direita e, no meio, o que você
## oferece, a balança e o que vai levar. Clique passa 1 unidade (Shift + clique: 5); clique no meio devolve.
## A balança não mostra números, só o humor do comerciante. O jogo não pausa: afastar-se ou ESC fecha.

const LONGE := 3.5 * IsoMath.METRO

var npc: Npc = null
var _j: Node2D = null
var _oferta: Dictionary = {}
var _pedido: Dictionary = {}
var _col_mochila := VBoxContainer.new()
var _col_oferta := VBoxContainer.new()
var _col_pedido := VBoxContainer.new()
var _col_estoque := VBoxContainer.new()
var _juizo := Label.new()
var _balanca := Control.new()
var _inclinacao := 0.0
var _trocar := Button.new()


func _ready() -> void:
	layer = 34
	add_to_group("janela_jogo")
	_j = get_tree().get_first_node_in_group("jogador")
	npc.conversando = true
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 0.96)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.45, 0.4, 0.3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	painel.add_child(col)
	var titulo := Label.new()
	titulo.text = "Trocas com %s — %s" % [npc.nome(), Comunidades.nome(npc.comunidade)]
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	col.add_child(titulo)
	var dica := Label.new()
	dica.text = "Clique passa 1 · Shift + clique passa 5 · clique no meio devolve"
	dica.modulate = Color(1, 1, 1, 0.55)
	dica.add_theme_font_size_override("font_size", 12)
	col.add_child(dica)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	col.add_child(linha)
	linha.add_child(_coluna("Sua mochila", _col_mochila, 210))
	var meio := VBoxContainer.new()
	meio.add_theme_constant_override("separation", 8)
	meio.custom_minimum_size = Vector2(300, 0)
	meio.add_child(_coluna("Você oferece", _col_oferta, 300, 110))
	_balanca.custom_minimum_size = Vector2(300, 46)
	_balanca.draw.connect(_desenhar_balanca)
	meio.add_child(_balanca)
	_juizo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_juizo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_juizo.custom_minimum_size = Vector2(300, 40)
	meio.add_child(_juizo)
	meio.add_child(_coluna("Você leva", _col_pedido, 300, 110))
	linha.add_child(meio)
	linha.add_child(_coluna("Estoque de %s" % npc.nome(), _col_estoque, 210))
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_END
	botoes.add_theme_constant_override("separation", 10)
	var sair := Button.new()
	sair.text = "Sair"
	sair.pressed.connect(_fechar)
	botoes.add_child(sair)
	_trocar.text = "TROCAR"
	_trocar.custom_minimum_size = Vector2(140, 36)
	_trocar.pressed.connect(_fazer_troca)
	botoes.add_child(_trocar)
	col.add_child(botoes)
	_atualizar()


func _coluna(titulo: String, lista: VBoxContainer, largura: float, altura: float = 330.0) -> Control:
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = titulo
	l.add_theme_font_size_override("font_size", 14)
	v.add_child(l)
	var rol := ScrollContainer.new()
	rol.custom_minimum_size = Vector2(largura, altura)
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(lista)
	v.add_child(rol)
	return v


## Quantas unidades do item o jogador ainda tem fora da oferta.
func _na_mochila(item: String) -> int:
	return int(_j.inventario.contar(item)) - int(_oferta.get(item, 0))


func _no_estoque(item: String) -> int:
	return int((Escambo.loja(npc)["estoque"] as Dictionary).get(item, 0)) - int(_pedido.get(item, 0))


func _atualizar() -> void:
	for c in [_col_mochila, _col_oferta, _col_pedido, _col_estoque]:
		for b in (c as Node).get_children():
			b.queue_free()
	var vistos: Dictionary = {}
	for x in _j.inventario.slots:
		if x == null or vistos.has(x.id):
			continue
		vistos[x.id] = true
		var n := _na_mochila(str(x.id))
		if n > 0:
			var troca: bool = Escambo.paga(npc, str(x.id)) > 0.0
			_item(_col_mochila, str(x.id), n, _mover.bind(_oferta, str(x.id), true), not troca)
	for item in _oferta:
		_item(_col_oferta, str(item), int(_oferta[item]), _mover.bind(_oferta, str(item), false))
	for item in _pedido:
		_item(_col_pedido, str(item), int(_pedido[item]), _mover.bind(_pedido, str(item), false))
	var est: Dictionary = Escambo.loja(npc)["estoque"]
	for item in est:
		var n2 := _no_estoque(str(item))
		if n2 > 0:
			_item(_col_estoque, str(item), n2, _mover.bind(_pedido, str(item), true), Escambo.cobra(npc, str(item)) == INF)
	var j := Escambo.julgar(npc, _oferta, _pedido)
	_juizo.text = "%s: “%s”" % [npc.nome(), j[0]]
	_trocar.disabled = not bool(j[1])
	_inclinacao = float(j[2])
	_balanca.queue_redraw()


func _item(lista: VBoxContainer, item: String, qtd: int, acao: Callable, apagado: bool = false) -> void:
	var b := Button.new()
	b.text = "%s ×%d" % [Itens.nome(item), qtd]
	b.icon = Itens.icone(item)
	b.expand_icon = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = apagado
	if apagado:
		b.tooltip_text = "Não troca isso." if lista == _col_mochila else "Ainda não troca isso com você."
	b.pressed.connect(acao)
	lista.add_child(b)


## Passa unidades para (ou tira de) 'alvo' (_oferta ou _pedido).
func _mover(alvo: Dictionary, item: String, por: bool) -> void:
	var n := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
	if por:
		var livre := _na_mochila(item) if alvo == _oferta else _no_estoque(item)
		n = mini(n, livre)
		if n > 0:
			alvo[item] = int(alvo.get(item, 0)) + n
	else:
		alvo[item] = int(alvo.get(item, 0)) - n
		if int(alvo[item]) <= 0:
			alvo.erase(item)
	_atualizar()


func _fazer_troca() -> void:
	var msg := Escambo.trocar(npc, _j, _oferta, _pedido)
	_j.aviso(msg)
	if msg.begins_with("Troca feita"):
		_oferta.clear()
		_pedido.clear()
	_atualizar()


## A balança: um travessão que pende para o lado mais pesado (verde quando ele aceita).
func _desenhar_balanca() -> void:
	var w := _balanca.size.x
	var c := Vector2(w * 0.5, 30.0)
	var ang := -_inclinacao * 0.35                 # sobra do seu lado = o seu prato desce (esquerda)
	var meia := w * 0.38
	var a := c + Vector2(-meia, 0).rotated(ang)
	var b := c + Vector2(meia, 0).rotated(ang)
	var cor := Color(0.45, 0.85, 0.45) if not _trocar.disabled else Color(0.85, 0.6, 0.35)
	_balanca.draw_line(c, c + Vector2(0, 14), Color(0.6, 0.6, 0.6), 3.0)
	_balanca.draw_line(a, b, cor, 4.0)
	_balanca.draw_circle(c, 5.0, Color(0.7, 0.7, 0.7))
	for p in [a, b]:
		_balanca.draw_line(p, p + Vector2(0, 8), Color(0.6, 0.6, 0.6), 1.5)
		_balanca.draw_rect(Rect2(p + Vector2(-22, 8), Vector2(44, 5)), cor)
	_balanca.draw_string(ThemeDB.fallback_font, a + Vector2(-22, -6), "você", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 1, 1, 0.6))
	_balanca.draw_string(ThemeDB.fallback_font, b + Vector2(-8, -6), npc.nome().split(" ")[-1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 1, 1, 0.6))


func _fechar() -> void:
	if is_instance_valid(npc):
		npc.conversando = false
	if not is_queued_for_deletion():
		queue_free()


func _process(_delta: float) -> void:
	if _j == null or bool(_j.get("morto")) or not is_instance_valid(npc) or npc.morto or npc.dormindo:
		_fechar()
	elif IsoMath.tela_para_mundo(npc.global_position - _j.global_position).length() > LONGE:
		_fechar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()
