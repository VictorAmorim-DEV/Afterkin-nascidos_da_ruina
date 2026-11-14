class_name SlotInv
extends PanelContainer
## Um slot da mochila: ícone, quantidade, borda de seleção e arrastar-e-soltar.

signal clicado(indice: int)
signal soltou(de: int, para: int)

var indice: int = 0
var selecionado: bool = false
var equipado: bool = false

var _icone := TextureRect.new()
var _qtd := Label.new()
var _marca := Label.new()


func _init() -> void:
	custom_minimum_size = Vector2(68, 68)
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone.custom_minimum_size = Vector2(52, 52)
	add_child(_icone)
	_qtd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qtd.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_qtd.add_theme_font_size_override("font_size", 14)
	_qtd.add_theme_color_override("font_outline_color", Color.BLACK)
	_qtd.add_theme_constant_override("outline_size", 4)
	add_child(_qtd)
	_marca.text = "EQUIP."
	_marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca.add_theme_font_size_override("font_size", 9)
	_marca.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_marca.visible = false
	add_child(_marca)


func mostrar(item) -> void:
	if item == null:
		_icone.texture = null
		_qtd.text = ""
		tooltip_text = ""
	else:
		_icone.texture = Itens.icone(item.id)
		_qtd.text = str(item.quantidade) if item.maximo > 1 else ""
		tooltip_text = "%s (%d/%d)" % [Itens.nome(item.id), item.quantidade, item.maximo]
	_marca.visible = equipado and item != null
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.09, 0.9) if not selecionado else Color(0.2, 0.2, 0.15, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.35) if (selecionado or equipado) else Color(0.32, 0.31, 0.27)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", sb)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicado.emit(indice)


func _get_drag_data(_pos: Vector2) -> Variant:
	if _icone.texture == null:
		return null
	var prev := TextureRect.new()
	prev.texture = _icone.texture
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.custom_minimum_size = Vector2(44, 44)
	prev.modulate.a = 0.8
	set_drag_preview(prev)
	clicado.emit(indice)
	return {"slot": indice}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("slot")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	soltou.emit(data.slot, indice)
