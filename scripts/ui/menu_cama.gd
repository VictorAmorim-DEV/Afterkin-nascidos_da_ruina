class_name MenuCama
extends CanvasLayer
## Menu da cama (E perto dela): deitar e descansar, deitar e dormir, recolher ou cancelar.
## O jogo NÃO pausa: o mundo segue enquanto você escolhe. ESC, E, clicar fora ou se afastar da cama fecha.

var cama: Node2D = null
var hospede := false                   ## cama de hóspede da comunidade: sem "Recolher"


func _ready() -> void:
	layer = 35
	add_to_group("janela_jogo")
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.12)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_fechar())
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.97)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.35, 0.4, 0.5)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)
	var j := get_tree().get_first_node_in_group("jogador")
	var titulo := Label.new()
	titulo.text = "Cama de hóspede" if hospede else "Cama"
	titulo.add_theme_font_size_override("font_size", 20)
	col.add_child(titulo)
	var estado := Label.new()
	estado.text = "Descanso %d%% (%s)" % [int(j.descanso), j.nome_cansaco().to_lower()] if j != null else ""
	estado.modulate = Color(1, 1, 1, 0.7)
	col.add_child(estado)
	var b1 := _botao(col, "Deitar e descansar", "O tempo corre normal; o cansaço passa aos poucos.")
	b1.pressed.connect(func(): _fechar(); j.descansar_na_cama(cama))
	var b2 := _botao(col, "Deitar e dormir (6–7 h)", "O tempo passa e você acorda descansado.")
	b2.pressed.connect(func(): _fechar(); j.dormir_na_cama(cama))
	if not hospede:
		var b3 := _botao(col, "Recolher a cama", "Guarda a cama de volta na mochila.")
		b3.pressed.connect(func(): _fechar(); Respawn.recolher(j, cama))
	var b4 := Button.new()
	b4.text = "Cancelar"
	b4.flat = true
	b4.pressed.connect(_fechar)
	col.add_child(b4)
	b1.grab_focus()


func _botao(col: VBoxContainer, texto: String, dica: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.custom_minimum_size = Vector2(0, 38)
	col.add_child(b)
	return b


func _fechar() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _process(_delta: float) -> void:
	var j: Node2D = get_tree().get_first_node_in_group("jogador")
	if j == null or bool(j.get("morto")) or not is_instance_valid(cama):
		_fechar()
	elif IsoMath.tela_para_mundo(cama.global_position - j.global_position).length() > CamaNo.ALCANCE * 1.5:
		_fechar()                                  # o jogo não pausa: andou para longe, o menu some


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_fechar()
