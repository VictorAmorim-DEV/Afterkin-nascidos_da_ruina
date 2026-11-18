class_name TelaRespawn
extends CanvasLayer
## Tela de renascimento (docs/DECISOES_DESIGN.md, Q51 e Q55), aberta alguns segundos depois da morte.
## Lista as camas do jogador (Respawn) e os lugares de início (Inicio, casa sorteada), com o mapa do mundo ao lado,
## como a tela de criação, mas sem escolher a origem de novo. O mundo continua: a mochila ficou no corpo.

var _lista := VBoxContainer.new()
var _mapa := MapaMundo.new()
var _descricao := Label.new()
var _renascer := Button.new()
var _escolha: Array = []              ## ["cama", índice] ou ["lugar", id de Inicio]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_montar()
	_preencher()
	get_tree().paused = true


func _montar() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.02, 0.02, 0.9)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.09)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.3, 0.3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var lado := HBoxContainer.new()
	lado.add_theme_constant_override("separation", 16)
	painel.add_child(lado)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 0)
	col.add_theme_constant_override("separation", 10)
	lado.add_child(col)
	_mapa.custom_minimum_size = Vector2(480, 520)
	lado.add_child(_mapa)
	var titulo := Label.new()
	titulo.text = "Você não sobreviveu"
	titulo.add_theme_font_size_override("font_size", 26)
	col.add_child(titulo)
	var sub := Label.new()
	sub.text = "O mundo continuou sem você. Sua mochila ficou com o corpo, onde você caiu (marcada no mapa)."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(1, 1, 1, 0.7)
	col.add_child(sub)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 330)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rolagem)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	rolagem.add_child(_lista)
	_descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descricao.custom_minimum_size = Vector2(0, 44)
	col.add_child(_descricao)
	_renascer.text = "RENASCER AQUI"
	_renascer.custom_minimum_size = Vector2(0, 44)
	_renascer.pressed.connect(_confirmar)
	col.add_child(_renascer)


func _secao(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 15)
	l.modulate = Color(1.0, 0.85, 0.6)
	_lista.add_child(l)


func _botao(grupo: ButtonGroup, texto: String, escolha: Array) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = grupo
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(_escolher.bind(escolha))
	_lista.add_child(b)
	return b


func _preencher() -> void:
	var grupo := ButtonGroup.new()
	var primeiro: Button = null
	var primeira: Array = []
	Respawn._limpar_camas()
	_secao("Suas camas")
	if Respawn.camas.is_empty():
		var l := Label.new()
		l.text = "Nenhuma. Fabrique uma cama e monte-a num lugar coberto para renascer nela."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(1, 1, 1, 0.55)
		_lista.add_child(l)
	for i in Respawn.camas.size():
		var b := _botao(grupo, "Cama %d — %s" % [i + 1, str(Respawn.camas[i]["nome"])], ["cama", i])
		if primeiro == null:
			primeiro = b
			primeira = ["cama", i]
	_secao("Lugares de início (uma casa qualquer)")
	var j := get_tree().get_first_node_in_group("jogador")
	var preferido: String = j.local_inicio if j != null and j.local_inicio in Inicio.IDS else Inicio.IDS[0]
	for id in Inicio.IDS:
		var b := _botao(grupo, "%s — %s" % [Inicio.nome(id), Inicio.tipo(id)], ["lugar", id])
		if primeiro == null and id == preferido:
			primeiro = b
			primeira = ["lugar", id]
	if primeiro != null:
		primeiro.button_pressed = true
		_escolher(primeira)


func _escolher(escolha: Array) -> void:
	_escolha = escolha
	if escolha[0] == "cama":
		var c: Dictionary = Respawn.camas[int(escolha[1])]
		_mapa.destaque = ""
		_mapa.destaque_ponto = c["p"]
		_mapa.focar(c["p"], 5.0)
		_descricao.text = "Renascer na sua cama, %s. Ninguém garante que o lugar continua seguro." % str(c["nome"])
	else:
		var id: String = escolha[1]
		_mapa.destaque_ponto = Vector2.INF
		_mapa.destaque = id
		var r := _mapa._area_destaque()
		if r.has_area():
			_mapa.focar(r.get_center(), 3.0)
		_descricao.text = "Renascer numa casa qualquer de %s, sem nada na mochila." % Inicio.nome(id)


func _confirmar() -> void:
	if _escolha.is_empty():
		return
	var frase := ""
	if _escolha[0] == "cama":
		frase = Respawn.renascer_na_cama(get_tree(), int(_escolha[1]))
	else:
		frase = Respawn.renascer_no_lugar(get_tree(), str(_escolha[1]))
	if frase == "":
		_descricao.text = "Não foi possível renascer aí. Escolha outro lugar."
		return
	get_tree().paused = false
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.aviso(frase)
	queue_free()
