class_name TelaMapa
extends CanvasLayer
## Mapa do mundo no meio da tela (tecla do mapa, M por padrão), com legenda. Não pausa o jogo: o mundo segue
## andando enquanto você olha o mapa.
## Também cuida das descobertas o tempo todo (aberta ou fechada): revela a névoa em volta do jogador e avisa
## "Local descoberto: ..." ao chegar perto de um acampamento (Descobertas).

var _raiz := Control.new()
var _mapa := MapaMundo.new()
var _legenda := Control.new()
var _t := 0.0


func _ready() -> void:
	layer = 20
	add_to_group("tela_mapa")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.visible = false
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.05, 0.96)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 28)
	_raiz.add_child(margem)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margem.add_child(col)
	var titulo := Label.new()
	titulo.text = "MAPA"
	titulo.add_theme_font_size_override("font_size", 20)
	col.add_child(titulo)
	var linha := HBoxContainer.new()
	linha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	linha.add_theme_constant_override("separation", 10)
	col.add_child(linha)
	_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	linha.add_child(_mapa)
	_legenda.custom_minimum_size = Vector2(200, 0)
	_legenda.draw.connect(_desenhar_legenda)
	linha.add_child(_legenda)
	var dica := Label.new()
	dica.text = "Roda do mouse: aproximar · Arrastar: mover · Botão direito: pôr/tirar marcador · %s: fechar" % \
		Controles.nome("minimapa")
	dica.modulate = Color(1, 1, 1, 0.65)
	dica.add_theme_font_size_override("font_size", 12)
	col.add_child(dica)


func aberto() -> bool:
	return _raiz.visible


func alternar() -> void:
	_raiz.visible = not _raiz.visible
	if _raiz.visible:
		var j := get_tree().get_first_node_in_group("jogador") as Node2D
		if j != null:
			_mapa.focar(IsoMath.tela_para_mundo(j.global_position), 4.0)
		_legenda.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("minimapa") and not get_tree().paused:
		alternar()
		get_viewport().set_input_as_handled()
	elif _raiz.visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		alternar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null or j.morto:
		return
	var alvo: Node2D = j.dirigindo if j.dirigindo != null else j
	var w := IsoMath.tela_para_mundo(alvo.global_position)
	Descobertas.revelar(w)
	var nome := Descobertas.descobrir_acampamento(w)
	if nome != "":
		j.aviso("Local descoberto: %s" % nome)


func _desenhar_legenda() -> void:
	var fonte := _legenda.get_theme_default_font()
	var y := 14.0
	_legenda.draw_string(fonte, Vector2(4, y), "LEGENDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
	y += 22.0
	for k in MapaMundo.ORDEM_LEGENDA:
		var d: Array = MapaMundo.ICONES[k]
		MapaMundo.icone(_legenda, Vector2(14, y), k, 8.0, fonte)
		var cor := Color(1, 1, 1, 0.45) if k == "npc" else Color(1, 1, 1, 0.9)
		_legenda.draw_string(fonte, Vector2(30, y + 5), str(d[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cor)
		y += 24.0
	y += 8.0
	_legenda.draw_string(fonte, Vector2(4, y), "Cidades e vilarejos: nome", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1, 1, 1, 0.6))
	_legenda.draw_string(fonte, Vector2(4, y + 16), "Escuro: ainda não explorado", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1, 1, 1, 0.6))
	_legenda.draw_string(fonte, Vector2(4, y + 32), "Ícones aparecem de perto (zoom)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1, 1, 1, 0.6))
	# rumores conhecidos (os mais recentes primeiro)
	y += 62.0
	_legenda.draw_string(fonte, Vector2(4, y), "RUMORES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.75, 1.0))
	y += 18.0
	var ids: Array = Conversas.rumores.keys()
	ids.reverse()
	if ids.is_empty():
		_legenda.draw_string(fonte, Vector2(4, y), "Nenhum ainda. Converse, ouça, leia.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 1, 1, 0.5))
	for rid in ids.slice(0, 10):
		var t := Rumores.titulo(str(rid))
		if t.length() > 30:
			t = t.substr(0, 29) + "…"
		var marca := "• " if Rumores.regiao(str(rid)).is_empty() else "R "
		_legenda.draw_string(fonte, Vector2(4, y), marca + t, HORIZONTAL_ALIGNMENT_LEFT, 196, 12, Color(1, 1, 1, 0.8))
		y += 16.0
