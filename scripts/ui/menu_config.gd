class_name MenuConfig
extends CanvasLayer
## Menu de configurações (V13: showModal("settings"), renderBindings, setBinding, abas Controles/Vídeo/Áudio).
## Abre com a ação "menu" (ESC) quando nenhuma outra tela está aberta; o jogo fica pausado enquanto isso.
## Controles: clique numa ação e aperte a tecla ou o botão do mouse (ESC cancela). Tudo vai para user://.

signal mudou                                      ## controles trocados (o HUD refaz a linha de ajuda)

var _painel := PanelContainer.new()
var _abas := TabContainer.new()
var _linhas := VBoxContainer.new()
var _botoes: Dictionary = {}                      ## ação -> Button
var _capturando := ""                             ## ação esperando a tecla nova
var _cheia := CheckBox.new()
var _vsync := CheckBox.new()
var _sombras := CheckBox.new()
var _volume := HSlider.new()
var _volume_txt := Label.new()
var _status := Label.new()
var _info_save := Label.new()
var _carregar := Button.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	visible = false
	Controles.iniciar()
	_montar()


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.06, 0.97)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.4, 0.3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	_painel.add_theme_stylebox_override("panel", sb)
	_painel.custom_minimum_size = Vector2(560, 520)
	centro.add_child(_painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_painel.add_child(col)

	var topo := HBoxContainer.new()
	var titulo := Label.new()
	titulo.text = "CONFIGURAÇÕES"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	var fechar := Button.new()
	fechar.text = "Fechar ✕"
	fechar.pressed.connect(fechar_menu)
	topo.add_child(fechar)
	col.add_child(topo)

	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_abas)

	# ---------- Partida (save/load) ----------
	var aba_p := VBoxContainer.new()
	aba_p.name = "Partida"
	aba_p.add_theme_constant_override("separation", 10)
	var salvar := Button.new()
	salvar.text = "Salvar partida"
	salvar.custom_minimum_size = Vector2(0, 40)
	salvar.focus_mode = Control.FOCUS_NONE
	salvar.pressed.connect(_salvar_partida)
	aba_p.add_child(salvar)
	_carregar.text = "Carregar partida salva"
	_carregar.custom_minimum_size = Vector2(0, 40)
	_carregar.focus_mode = Control.FOCUS_NONE
	_carregar.pressed.connect(_carregar_partida)
	aba_p.add_child(_carregar)
	_info_save.add_theme_font_size_override("font_size", 13)
	_info_save.modulate = Color(1, 1, 1, 0.7)
	aba_p.add_child(_info_save)
	var intro := CheckBox.new()
	intro.text = "Introdução e primeiros passos (prólogo e lista de objetivos no começo da partida)"
	intro.focus_mode = Control.FOCUS_NONE
	intro.button_pressed = SelecaoRaca.introducao_ligada()
	intro.toggled.connect(func(v: bool):
		_salvar_opcao("jogo", "introducao", v)
		var j := get_tree().get_first_node_in_group("jogador")
		if j != null and not v and j.passos.has("_ativo"):
			j.passos["_ativo"] = false
			get_tree().call_group("primeiros_passos", "_atualizar"))
	aba_p.add_child(intro)
	var nota_p := Label.new()
	nota_p.text = "Atalhos durante o jogo: salvar e carregar (veja a aba Controles). Carregar descarta o progresso não salvo."
	nota_p.add_theme_font_size_override("font_size", 12)
	nota_p.modulate = Color(1, 1, 1, 0.6)
	nota_p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aba_p.add_child(nota_p)
	_abas.add_child(aba_p)

	# ---------- Controles ----------
	var aba_c := VBoxContainer.new()
	aba_c.name = "Controles"
	aba_c.add_theme_constant_override("separation", 8)
	var dica := Label.new()
	dica.text = "Clique numa ação e aperte a tecla ou o botão do mouse. ESC cancela."
	dica.add_theme_font_size_override("font_size", 12)
	dica.modulate = Color(1, 1, 1, 0.6)
	aba_c.add_child(dica)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.add_child(_linhas)
	_linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aba_c.add_child(rolagem)
	for a in Controles.ACOES:
		var acao: String = a[0]
		var linha := HBoxContainer.new()
		var rot := Label.new()
		rot.text = a[1]
		rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(rot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_comecar_captura.bind(acao))
		linha.add_child(b)
		_botoes[acao] = b
		_linhas.add_child(linha)
	var restaurar := Button.new()
	restaurar.text = "Restaurar padrões"
	restaurar.focus_mode = Control.FOCUS_NONE
	restaurar.pressed.connect(func():
		Controles.restaurar()
		_capturando = ""
		_atualizar()
		mudou.emit()
		_aviso("Controles restaurados."))
	aba_c.add_child(restaurar)
	_abas.add_child(aba_c)

	# ---------- Vídeo ----------
	var aba_v := VBoxContainer.new()
	aba_v.name = "Vídeo"
	aba_v.add_theme_constant_override("separation", 10)
	var cfg := Controles.ler_cfg()
	_cheia.text = "Tela cheia"
	_cheia.button_pressed = cfg.get_value("video", "tela_cheia", false)
	_cheia.toggled.connect(func(v: bool): _salvar_opcao("video", "tela_cheia", v))
	_vsync.text = "Sincronização vertical (V-Sync)"
	_vsync.button_pressed = cfg.get_value("video", "vsync", true)
	_vsync.toggled.connect(func(v: bool): _salvar_opcao("video", "vsync", v))
	_sombras.text = "Sombras da lanterna (desligue em PCs mais fracos)"
	_sombras.button_pressed = cfg.get_value("video", "sombras_lanterna", true)
	_sombras.toggled.connect(func(v: bool):
		_salvar_opcao("video", "sombras_lanterna", v)
		var j := get_tree().get_first_node_in_group("jogador")
		if j != null and j.has_method("aplicar_sombras_lanterna"):
			j.aplicar_sombras_lanterna(v))
	for c: CheckBox in [_cheia, _vsync, _sombras]:
		c.focus_mode = Control.FOCUS_NONE
		aba_v.add_child(c)
	_abas.add_child(aba_v)

	# ---------- Áudio ----------
	var aba_a := VBoxContainer.new()
	aba_a.name = "Áudio"
	aba_a.add_theme_constant_override("separation", 10)
	var linha_v := HBoxContainer.new()
	var rot_v := Label.new()
	rot_v.text = "Volume geral"
	rot_v.custom_minimum_size = Vector2(130, 0)
	linha_v.add_child(rot_v)
	_volume.min_value = 0.0
	_volume.max_value = 100.0
	_volume.step = 1.0
	_volume.value = float(cfg.get_value("audio", "volume", 0.7)) * 100.0
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.value_changed.connect(func(v: float):
		_volume_txt.text = "%d%%" % int(v)
		_salvar_opcao("audio", "volume", v / 100.0))
	linha_v.add_child(_volume)
	_volume_txt.custom_minimum_size = Vector2(48, 0)
	_volume_txt.text = "%d%%" % int(_volume.value)
	linha_v.add_child(_volume_txt)
	aba_a.add_child(linha_v)
	var nota := Label.new()
	nota.text = "O jogo ainda não tem sons; o volume já fica salvo para quando tiver."
	nota.add_theme_font_size_override("font_size", 12)
	nota.modulate = Color(1, 1, 1, 0.6)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aba_a.add_child(nota)
	_abas.add_child(aba_a)
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color(0.75, 1.0, 0.75)
	col.add_child(_status)
	_atualizar()


func _salvar_opcao(secao: String, chave: String, valor: Variant) -> void:
	var cfg := Controles.ler_cfg()
	cfg.set_value(secao, chave, valor)
	cfg.save(Controles.ARQUIVO)
	Controles.aplicar_video_audio(cfg)


func _atualizar() -> void:
	for acao in _botoes:
		var b: Button = _botoes[acao]
		b.text = "Aperte…" if acao == _capturando else Controles.nome(acao)
	var q := SaveJogo.quando()
	_info_save.text = ("Último save: " + q.replace("T", " ")) if q != "" else "Nenhuma partida salva ainda."
	_carregar.disabled = q == ""


func _salvar_partida() -> void:
	_aviso(SaveJogo.salvar(get_tree()))
	_atualizar()


func _carregar_partida() -> void:
	visible = false
	var erro := SaveJogo.carregar(get_tree())
	if erro != "":
		visible = true
		_aviso(erro)


func _comecar_captura(acao: String) -> void:
	_capturando = acao
	_atualizar()


func abrir() -> void:
	if visible or get_tree().paused:
		return                                    # outra tela (mochila, seleção de raça) já está aberta
	visible = true
	get_tree().paused = true
	_status.text = ""
	_capturando = ""
	_atualizar()


func fechar_menu() -> void:
	visible = false
	_capturando = ""
	get_tree().paused = false


## Captura antes de todo mundo: a tecla nova não pode virar pulo, ataque...
func _input(event: InputEvent) -> void:
	if not visible or _capturando == "":
		return
	var tecla: bool = event is InputEventKey and event.pressed and not event.echo
	var mouse: bool = event is InputEventMouseButton and event.pressed
	if not tecla and not mouse:
		return
	get_viewport().set_input_as_handled()
	if tecla and (event as InputEventKey).keycode == KEY_ESCAPE:
		_capturando = ""
		_atualizar()
		return
	if mouse and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return                                    # rodinha é o zoom
	var acao := _capturando
	_capturando = ""
	var tirada := Controles.trocar(acao, event)
	_atualizar()
	mudou.emit()
	_aviso("Controle atualizado." if tirada == "" else "Controle atualizado (a tecla saiu de \"%s\")." % tirada)


func _unhandled_input(event: InputEvent) -> void:
	if not visible and not get_tree().paused:            # atalhos de salvar/carregar durante o jogo
		var j := get_tree().get_first_node_in_group("jogador")
		if event.is_action_pressed("salvar_rapido") and j != null:
			j.aviso(SaveJogo.salvar(get_tree()))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("carregar_rapido") and j != null:
			var erro := SaveJogo.carregar(get_tree())
			if erro != "":
				j.aviso(erro)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("menu"):
		if visible:
			fechar_menu()
			get_viewport().set_input_as_handled()
		elif not get_tree().paused:
			var mapa := get_tree().get_first_node_in_group("tela_mapa")
			if mapa != null and mapa.aberto():
				return                                # o Esc fecha o mapa (TelaMapa), não abre o menu
			if get_tree().get_first_node_in_group("janela_jogo") != null:
				return                                # o Esc fecha a conversa ou o menu da cama
			abrir()
			get_viewport().set_input_as_handled()


## Mensagem no rodapé do menu (o aviso do HUD ficaria atrás do fundo escuro, com o jogo pausado).
func _aviso(t: String) -> void:
	_status.text = t
