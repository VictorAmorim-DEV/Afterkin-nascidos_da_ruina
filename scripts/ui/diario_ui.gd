class_name DiarioUI
extends CanvasLayer
## Diário do jogador (tecla do diário, J por padrão; marco 3, etapa 3.6). Três páginas: "Agora" (objetivo atual,
## tempo vivo, inimigos mortos e "O que está acontecendo comigo?"), "Registro" (marcos, habilidades, lugares e
## rumores com [✓]) e "Raças e espécies". Não pausa o jogo. As regras e os textos ficam em Diario.
## Também vigia, aberto ou fechado, as espécies à vista e os marcos que se medem pelo estado (Diario.vigiar).

const PAGINAS := ["Agora", "Registro", "Raças e espécies"]
const COR_TITULO := "#ffe08a"
const COR_FEITO := "#7fbf7f"
const COR_FALTA := "#8a8a8a"

var _raiz := Control.new()
var _abas: Array[Button] = []
var _texto := RichTextLabel.new()
var _pagina := 0
var _t := 0.0


func _ready() -> void:
	layer = 21
	add_to_group("diario_ui")
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.visible = false
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.97)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.42, 0.33, 0.22)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	painel.add_theme_stylebox_override("panel", sb)
	painel.mouse_filter = Control.MOUSE_FILTER_STOP       # a roda do mouse rola o diário, não o zoom
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	painel.add_child(col)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	col.add_child(topo)
	var titulo := Label.new()
	titulo.text = "DIÁRIO"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	for i in PAGINAS.size():
		var b := Button.new()
		b.text = PAGINAS[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_ir.bind(i))
		topo.add_child(b)
		_abas.append(b)
	var rolar := ScrollContainer.new()
	rolar.custom_minimum_size = Vector2(620, 440)
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rolar)
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_size_override("normal_font_size", 15)
	_texto.add_theme_font_size_override("bold_font_size", 15)
	_texto.add_theme_font_size_override("italics_font_size", 15)
	rolar.add_child(_texto)
	var dica := Label.new()
	dica.text = "%s ou Esc: fechar" % Controles.nome("diario")
	dica.modulate = Color(1, 1, 1, 0.6)
	dica.add_theme_font_size_override("font_size", 12)
	col.add_child(dica)


func aberto() -> bool:
	return _raiz.visible


func alternar() -> void:
	_raiz.visible = not _raiz.visible
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _raiz.visible:
		add_to_group("janela_jogo")                   # o Esc fecha o diário, não abre o menu
		_ir(_pagina)
	elif is_in_group("janela_jogo"):
		remove_from_group("janela_jogo")


func _ir(i: int) -> void:
	_pagina = i
	for k in _abas.size():
		_abas[k].button_pressed = k == i
	_montar()


func _jogador() -> Node:
	return get_tree().get_first_node_in_group("jogador")


func _montar() -> void:
	var j := _jogador()
	if j == null:
		_texto.text = ""
		return
	match _pagina:
		0:
			_texto.text = _agora(j)
		1:
			_texto.text = _registro(j)
		_:
			_texto.text = _especies(j)


func _titulo(t: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [COR_TITULO, t]


func _agora(j: Node) -> String:
	var l: PackedStringArray = []
	l.append(_titulo("Objetivo atual"))
	l.append("▸ %s" % Diario.objetivo(j))
	l.append("")
	l.append(_titulo("O que está acontecendo comigo?"))
	for s in Diario.estado(j):
		l.append("• %s" % s)
	l.append("")
	l.append(_titulo("Sobrevivência"))
	l.append(Diario.tempo(j))
	var ab := Diario.abates(j)
	if ab.is_empty():
		l.append("[color=%s]Ainda não matei ninguém.[/color]" % COR_FALTA)
	else:
		var total := 0
		for a in ab:
			total += int((a as Array)[1])
		l.append("Inimigos mortos: %d" % total)
		for a2 in ab:
			var par: Array = a2
			l.append("   %s: %d" % [str(par[0]), int(par[1])])
	return "\n".join(l)


func _registro(j: Node) -> String:
	var l: PackedStringArray = []
	for sec in Diario.registro(j):
		var s: Array = sec
		l.append(_titulo(str(s[0])))
		var itens: Array = s[1]
		if itens.is_empty():
			l.append("[color=%s]Nada ainda.[/color]" % COR_FALTA)
		for it in itens:
			var par: Array = it
			if bool(par[0]):
				l.append("[color=%s][✓][/color] %s" % [COR_FEITO, str(par[1])])
			else:
				l.append("[color=%s][  ] %s[/color]" % [COR_FALTA, str(par[1])])
		l.append("")
	return "\n".join(l)


func _especies(j: Node) -> String:
	var l: PackedStringArray = []
	l.append("[color=%s][i]Preenchida ao ver de perto ou ouvir falar de cada uma.[/i][/color]" % COR_FALTA)
	l.append("")
	var raca_antes := ""
	for e in Diario.especies(j):
		var ed: Array = e
		var raca := str(ed[1])
		if raca != raca_antes:
			if raca_antes != "":
				l.append("")
			l.append(_titulo(raca if str(ed[2]) != "" or _raca_conhecida(j, raca) else "???"))
			raca_antes = raca
		match str(ed[2]):
			"vista":
				l.append("[color=%s][✓][/color] [b]%s[/b] — %s" % [COR_FEITO, str(ed[0]), str(ed[3])])
			"ouvida":
				l.append("[color=#c8b070][?][/color] [b]%s[/b] [i](só ouvi falar)[/i] — %s" % [str(ed[0]), str(ed[3])])
			_:
				l.append("[color=%s][  ] ???[/color]" % COR_FALTA)
	return "\n".join(l)


func _raca_conhecida(j: Node, raca: String) -> bool:
	for e in Diario.especies(j):
		var ed: Array = e
		if str(ed[1]) == raca and str(ed[2]) != "":
			return true
	return false


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var j := _jogador()
	if j == null:
		return
	if (j.diario as Dictionary).is_empty():
		Diario.iniciar(j)
	Diario.vigiar(j)
	MissaoPrincipal.vigiar(j)
	if _raiz.visible:
		_montar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("diario") and not get_tree().paused:
		if not _raiz.visible and get_tree().get_first_node_in_group("janela_jogo") != null:
			return                                    # conversa ou menu aberto: o J não abre o diário por cima
		alternar()
		get_viewport().set_input_as_handled()
	elif _raiz.visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		alternar()
		get_viewport().set_input_as_handled()
