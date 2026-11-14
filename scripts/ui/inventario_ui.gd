class_name InventarioUI
extends CanvasLayer
## Tela da mochila (V13: renderInventory). Abre com I ou Tab, fecha com I, Tab ou Esc.
## Enquanto aberta, o jogo fica pausado (a própria tela continua funcionando).

var _jogador: Node
var _inv: Inventario
var _sel: int = -1
var _slots: Array[SlotInv] = []

var _painel := PanelContainer.new()
var _contagem := Label.new()
var _equip := Label.new()
var _info := VBoxContainer.new()
var _botoes := HBoxContainer.new()
var _receitas := VBoxContainer.new()
var _status := Label.new()
var _terr_info := Label.new()
var _terr_botoes := HBoxContainer.new()
var _cartoes := GridContainer.new()      ## V13: aba Status (statusItems)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_montar()
	_painel.visible = true
	call_deferred("_ligar")


func _ligar() -> void:
	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador == null:
		return
	_inv = _jogador.inventario
	_inv.mudou.connect(_atualizar)
	_atualizar()


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.06, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.4, 0.3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	_painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(_painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_painel.add_child(col)

	var topo := HBoxContainer.new()
	var titulo := Label.new()
	titulo.text = "MOCHILA"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	_contagem.add_theme_font_size_override("font_size", 14)
	topo.add_child(_contagem)
	col.add_child(topo)

	var meio := HBoxContainer.new()
	meio.add_theme_constant_override("separation", 18)
	col.add_child(meio)

	var grade := GridContainer.new()
	grade.columns = 5
	grade.add_theme_constant_override("h_separation", 6)
	grade.add_theme_constant_override("v_separation", 6)
	meio.add_child(grade)
	for i in Inventario.TAMANHO:
		var s := SlotInv.new()
		s.indice = i
		s.clicado.connect(_selecionar)
		s.soltou.connect(func(de: int, para: int): _inv.mover(de, para))
		grade.add_child(s)
		_slots.append(s)

	var lado := VBoxContainer.new()
	lado.custom_minimum_size = Vector2(300, 0)
	lado.add_theme_constant_override("separation", 8)
	meio.add_child(lado)
	_equip.add_theme_font_size_override("font_size", 14)
	lado.add_child(_equip)
	lado.add_child(HSeparator.new())
	_info.custom_minimum_size = Vector2(300, 90)
	lado.add_child(_info)
	lado.add_child(_botoes)
	lado.add_child(HSeparator.new())
	var tr := Label.new()
	tr.text = "FABRICAR"
	tr.add_theme_font_size_override("font_size", 14)
	lado.add_child(tr)
	lado.add_child(_receitas)
	lado.add_child(HSeparator.new())
	var tt := Label.new()
	tt.text = "TERRITÓRIO"
	tt.add_theme_font_size_override("font_size", 14)
	lado.add_child(tt)
	_terr_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terr_info.custom_minimum_size = Vector2(300, 0)
	_terr_info.add_theme_font_size_override("font_size", 12)
	lado.add_child(_terr_info)
	lado.add_child(_terr_botoes)

	var te := Label.new()
	te.text = "ESTADO"
	te.add_theme_font_size_override("font_size", 14)
	col.add_child(te)
	_cartoes.columns = 4
	_cartoes.add_theme_constant_override("h_separation", 6)
	_cartoes.add_theme_constant_override("v_separation", 6)
	col.add_child(_cartoes)

	_status.text = "Arraste para reorganizar · I / Tab / Esc fecha"
	_status.modulate = Color(1, 1, 1, 0.6)
	_status.add_theme_font_size_override("font_size", 12)
	col.add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	var tab: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if event.is_action_pressed("inventory") or tab:
		alternar()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("menu"):
		alternar()
		get_viewport().set_input_as_handled()


func alternar() -> void:
	if not visible and get_tree().paused:
		return                                   # a seleção de raça está aberta
	visible = not visible
	get_tree().paused = visible
	if visible:
		_atualizar()


func _selecionar(i: int) -> void:
	_sel = i
	_atualizar()


func _atualizar() -> void:
	if _inv == null:
		return
	for i in _slots.size():
		_slots[i].selecionado = (i == _sel)
		_slots[i].equipado = (i == _inv.equipado)
		_slots[i].mostrar(_inv.slots[i])
	_contagem.text = "%d / %d slots" % [Inventario.TAMANHO - _inv.vazios(), Inventario.TAMANHO]
	var e := _inv.id_equipado()
	_equip.text = ("Equipado: " + Itens.nome(e)) if e != "" else "Mãos livres"
	_montar_info()
	_montar_receitas()
	_montar_territorio()
	_montar_cartoes()


## Cartões de estado do jogador (V13: statusItems — raça, forma, nível, vida, fome, sol, doença, totem).
func _montar_cartoes() -> void:
	for c in _cartoes.get_children():
		c.queue_free()
	var j := _jogador
	var t: Territorio = j.territorio
	var dados := [
		["Raça", j.NOMES_RACA[j.raca]], ["Forma", "Rato" if j.forma_rato() else "Humano"], ["Nível", str(j.nivel)],
		["Vida", "%d / %d" % [ceili(j.vida), int(j.vida_max)]], ["Fome", "%d%%" % int(j.fome)],
		["Exposição solar", "%d / 60 min" % int(j.sol)], ["Doença", j.doenca.tipo if not j.doenca.is_empty() else "Nenhuma"],
		["Totem", ("Nível %d" % t.totem.nivel) if t.tem_totem() else "Nenhum"]]
	for d in dados:
		var cartao := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6)
		cartao.add_theme_stylebox_override("panel", sb)
		cartao.custom_minimum_size = Vector2(150, 0)
		var v := VBoxContainer.new()
		var n := Label.new()
		n.text = d[0]
		n.add_theme_font_size_override("font_size", 12)
		n.modulate = Color(1, 1, 1, 0.6)
		var val := Label.new()
		val.text = d[1]
		val.add_theme_font_size_override("font_size", 14)
		v.add_child(n)
		v.add_child(val)
		cartao.add_child(v)
		_cartoes.add_child(cartao)


func _montar_territorio() -> void:
	var t: Territorio = _jogador.territorio
	_terr_info.text = "Totem: %s\nAbrigo básico: requer totem, 8 madeira e 4 sucata." % t.resumo()
	for c in _terr_botoes.get_children():
		c.queue_free()
	var b1 := Button.new()
	b1.text = "Construir abrigo"
	b1.disabled = not t.tem_totem() or t.abrigo
	b1.pressed.connect(func(): t.construir_abrigo(); _atualizar())
	_terr_botoes.add_child(b1)
	var b2 := Button.new()
	b2.text = "Remover totem"
	b2.disabled = not t.tem_totem()
	b2.pressed.connect(func(): t.remover_totem(); _atualizar())
	_terr_botoes.add_child(b2)


func _montar_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	for c in _botoes.get_children():
		c.queue_free()
	var x = _inv.slots[_sel] if _sel >= 0 else null
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	if x == null:
		l.text = "Selecione um slot."
		l.modulate = Color(1, 1, 1, 0.6)
		_info.add_child(l)
		return
	var d: Dictionary = Itens.DB[x.id]
	l.text = "%s × %d / %d\n%s" % [d.nome, x.quantidade, x.maximo, d.desc]
	_info.add_child(l)
	if d.get("ferramenta", false):
		_botao("Desequipar" if _sel == _inv.equipado else "Equipar", func(): _inv.alternar_equipado(_sel))
	if d.get("uso", false):
		_botao("Usar", func(): _inv.usar(_sel))
	_botao("Largar 1", func(): _jogador.largar_slot(_sel, 1), x.quantidade > 1)
	_botao("Largar tudo", func(): _jogador.largar_slot(_sel, 0))


func _botao(texto: String, acao: Callable, ativo: bool = true) -> void:
	if not ativo:
		return
	var b := Button.new()
	b.text = texto
	b.pressed.connect(acao)
	_botoes.add_child(b)


func _montar_receitas() -> void:
	for c in _receitas.get_children():
		c.queue_free()
	for r in Itens.RECEITAS:
		var custo := Itens.custo_receita(r.id, _jogador.nivel, _jogador.raca)
		var linha := HBoxContainer.new()
		var txt := Label.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.custom_minimum_size = Vector2(210, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var partes: PackedStringArray = []
		for c in custo:
			partes.append("%s %d/%d" % [Itens.nome(c[0]), _inv.contar(c[0]), c[1]])
		txt.text = "%s\n%s" % [Itens.nome(r.id), " · ".join(partes)]
		txt.add_theme_font_size_override("font_size", 12)
		linha.add_child(txt)
		var b := Button.new()
		b.text = "Fabricar"
		var id: String = r.id
		b.pressed.connect(func(): _inv.fabricar(id))
		linha.add_child(b)
		_receitas.add_child(linha)
