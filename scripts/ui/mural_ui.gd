class_name MuralUI
extends CanvasLayer
## O que está pregado no mural de uma comunidade (MuralNo). Ler anota os rumores dos recados.
## Recados: o horário do portão, os pedidos que saem da Simulacao (comida, remédio, quem saiba tratar ferida), os
## recados fixos do arquivo da comunidade ("mural"), quem morreu e as últimas novidades. Não pausa o jogo.

var mural: MuralNo = null
var _texto := RichTextLabel.new()


func _ready() -> void:
	layer = 34
	add_to_group("janela_jogo")
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.97)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.3, 0.2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	painel.add_child(col)
	var titulo := Label.new()
	titulo.text = "Mural %s" % Comunidades.de(mural.comunidade)
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	col.add_child(titulo)
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.custom_minimum_size = Vector2(520, 0)
	_texto.add_theme_font_size_override("normal_font_size", 15)
	col.add_child(_texto)
	var fechar := Button.new()
	fechar.text = "Fechar (E)"
	fechar.pressed.connect(_fechar)
	col.add_child(fechar)
	_ler()


func _ler() -> void:
	var com := mural.comunidade
	var j := get_tree().get_first_node_in_group("jogador")
	var linhas: PackedStringArray = []
	var avisos: PackedStringArray = []
	var pd: Dictionary = Comunidades.dados(com).get("portao", {})
	linhas.append("• Portão: abre às %dh, fecha às %dh. Depois disso, não abre para ninguém." % [int(pd.get("abre", 6)), int(pd.get("fecha", 18))])
	var c := Simulacao.estado(com)
	if not c.is_empty():
		if float(c["comida"]) < 2.5:
			linhas.append("• Precisa-se de comida. Troca-se por munição.")
		var sem_trato := false
		for f in c["feridos"]:
			if not bool((f as Dictionary)["tratado"]):
				sem_trato = true
		if sem_trato:
			linhas.append("• Precisa-se de remédio: temos gente ferida.")
			if not (c["hab"] as Array).has("medicina"):
				linhas.append("• Procura-se quem saiba tratar ferida.")
	for r in Comunidades.dados(com).get("mural", []):
		var rd: Dictionary = r
		if Consequencias.cita_morto(str(rd["texto"])):
			continue
		linhas.append("• %s" % Conversas.texto(str(rd["texto"]), {"com": com, "npc": "", "jogador": j}))
		if rd.has("rumor"):
			var a := Rumores.conhecer(str(rd["rumor"]))
			if a != "":
				avisos.append(a)
	for m in Reputacao.mortos:
		var partes := str(m).split("/")
		if partes.size() == 2 and partes[0] == com:
			linhas.append("• Em memória de %s." % Simulacao._nome_npc(com, partes[1]))
	for k in 2:
		var n := Rumores.novidade_para(com)
		if n.is_empty() or str(n["com"]) != com:
			break
		linhas.append("• %s" % str(n["texto"]))
		var a2 := Rumores.ouvir(n)
		if a2 != "":
			avisos.append(a2)
	_texto.text = "\n".join(linhas)
	if j != null and not avisos.is_empty():
		j.aviso(avisos[0] if avisos.size() == 1 else "%d rumores anotados do mural." % avisos.size())


func _fechar() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _process(_delta: float) -> void:
	if not is_instance_valid(mural) or mural._dist() > MuralNo.ALCANCE * 2.0:
		_fechar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_fechar()
