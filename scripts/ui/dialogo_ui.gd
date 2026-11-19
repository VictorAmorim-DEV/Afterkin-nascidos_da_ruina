class_name DialogoUI
extends CanvasLayer
## Janela de conversa com um NPC (Conversas): nome, a fala e as respostas possíveis (clique ou teclas 1–9).
## O jogo não pausa, como no menu da cama: o NPC para e olha para você; afastar-se, ESC ou "Até mais" encerra.

const LONGE := 3.5 * IsoMath.METRO

var npc: Npc = null
var _ctx: Dictionary = {}
var _arvore: Dictionary = {}
var _nome := Label.new()
var _fala := Label.new()
var _opcoes := VBoxContainer.new()
var _botoes: Array = []                ## [Button, opção] na ordem das teclas
var _msgs: PackedStringArray = []


func _ready() -> void:
	layer = 34
	add_to_group("janela_jogo")
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = -380
	painel.offset_right = 380
	painel.offset_bottom = -24
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.42, 0.38, 0.3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	painel.add_theme_stylebox_override("panel", sb)
	raiz.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	painel.add_child(col)
	_nome.add_theme_font_size_override("font_size", 17)
	_nome.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	col.add_child(_nome)
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.custom_minimum_size = Vector2(700, 0)
	_fala.add_theme_font_size_override("font_size", 16)
	col.add_child(_fala)
	_opcoes.add_theme_constant_override("separation", 4)
	col.add_child(_opcoes)
	_ctx = {"com": npc.comunidade, "npc": str(npc.dados.get("id", "")), "jogador": get_tree().get_first_node_in_group("jogador")}
	_arvore = Conversas.arvore(npc.comunidade, _ctx["npc"])
	npc.conversando = true
	var abertura := "fim"
	for e in _arvore.get("inicio", []):
		var ed: Dictionary = e
		if Conversas.vale(ed.get("se", {}), _ctx):
			abertura = str(ed["no"])
			break
	Conversas.vistos["%s/%s" % [_ctx["com"], _ctx["npc"]]] = true
	_ir(abertura)


func _ir(id: String) -> void:
	var nos: Dictionary = _arvore.get("nos", {})
	if id == "fim" or not nos.has(id):
		_fechar()
		return
	var no: Dictionary = nos[id]
	_msgs.append_array(Conversas.aplicar(no.get("efeitos", []), _ctx))
	var titulo: String = str(npc.dados.get("titulo", npc.dados.get("papel", "morador")))
	_nome.text = "%s — %s, %s" % [npc.nome(), titulo, Comunidades.nome(npc.comunidade)]
	_fala.text = Conversas.texto(str(no.get("fala", "...")), _ctx)
	for b in _opcoes.get_children():
		b.queue_free()
	_botoes.clear()
	var lista: Array = []
	for o in no.get("opcoes", []):
		if Conversas.vale((o as Dictionary).get("se", {}), _ctx):
			lista.append(o)
	if not bool(no.get("sem_sair", false)):
		lista.append({"texto": "Até mais.", "vai": "fim"})
	for i in lista.size():
		var o: Dictionary = lista[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, Conversas.texto(str(o["texto"]), _ctx)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_escolher.bind(o))
		_opcoes.add_child(b)
		_botoes.append(b)
	_avisar()


func _escolher(o: Dictionary) -> void:
	_msgs.append_array(Conversas.aplicar(o.get("efeitos", []), _ctx))
	_ir(str(o.get("vai", "fim")))


func _avisar() -> void:
	var j: Node = _ctx["jogador"]
	for m in _msgs:
		if j != null:
			j.aviso(m)
	_msgs.clear()


func _fechar() -> void:
	_avisar()
	if is_instance_valid(npc):
		npc.conversando = false
	if not is_queued_for_deletion():
		queue_free()


func _process(_delta: float) -> void:
	var j: Node2D = _ctx.get("jogador")
	if j == null or bool(j.get("morto")) or not is_instance_valid(npc) or npc.dormindo:
		_fechar()
	elif IsoMath.tela_para_mundo(npc.global_position - j.global_position).length() > LONGE:
		_fechar()                                  # o jogo não pausa: andou para longe, a conversa acaba


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var i := int(k - KEY_1)
			if i < _botoes.size():
				get_viewport().set_input_as_handled()
				(_botoes[i] as Button).pressed.emit()
