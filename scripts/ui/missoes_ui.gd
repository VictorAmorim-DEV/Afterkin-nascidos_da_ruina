class_name MissoesUI
extends Control
## Painel "Missões" à direita, embaixo do minimapa (25/11/2026; substitui os primeiros passos). Mostra o passo atual da
## missão principal (MissaoPrincipal) sem precisar abrir o diário. Passo cumprido: aparece "concluída" por alguns
## segundos e some, dando lugar ao próximo. Sem missão ativa, o painel fica vazio.
## Clicar no título recolhe (só "Missões ▼") e expande ("Missões ▲").

const MOSTRA_CONCLUIDA_S := 4.0
const LARGURA := 314.0

var _titulo := Button.new()
var _corpo := RichTextLabel.new()
var _recolhido := false
var _ultimo_passo := -1
var _ultimo_texto := ""
var _concluida := ""                 ## texto do passo que acabou de ser cumprido
var _concluida_t := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("missoes_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -LARGURA - 16.0
	offset_right = -16.0
	offset_top = 250.0
	offset_bottom = 520.0
	var fundo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	fundo.add_theme_stylebox_override("panel", sb)
	fundo.custom_minimum_size = Vector2(LARGURA, 0)      # a altura acompanha o conteúdo
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(col)
	_titulo.flat = true
	_titulo.focus_mode = Control.FOCUS_NONE
	_titulo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_titulo.add_theme_font_size_override("font_size", 14)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54))
	_titulo.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	_titulo.pressed.connect(alternar)
	col.add_child(_titulo)
	_corpo.custom_minimum_size = Vector2(LARGURA - 16.0, 0)
	_corpo.bbcode_enabled = true
	_corpo.fit_content = true
	_corpo.scroll_active = false
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corpo.add_theme_font_size_override("normal_font_size", 13)
	_corpo.add_theme_font_size_override("bold_font_size", 13)
	col.add_child(_corpo)
	_atualizar()


func recolhido() -> bool:
	return _recolhido


func alternar() -> void:
	_recolhido = not _recolhido
	_atualizar()


func _atualizar() -> void:
	_titulo.text = "Missões  %s" % ("▼" if _recolhido else "▲")
	_corpo.visible = not _recolhido
	var linhas: PackedStringArray = []
	if _concluida != "":
		linhas.append("[color=#7fbf7f]✓ %s — concluída[/color]" % _concluida)
	elif _ultimo_texto != "":
		linhas.append("[color=#ffe08a]▸[/color] %s" % _ultimo_texto)
	_corpo.text = "\n".join(linhas)
	_corpo.visible = not _recolhido and not linhas.is_empty()


func _process(delta: float) -> void:
	if _concluida != "":
		_concluida_t -= delta
		if _concluida_t <= 0.0:
			_concluida = ""
			_ultimo_texto = MissaoPrincipal.objetivo()
			_atualizar()
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var p := MissaoPrincipal.passo
	if p == _ultimo_passo:
		return
	var antes := _ultimo_texto
	var primeira := _ultimo_passo < 0
	_ultimo_passo = p
	if not primeira and antes != "" and _concluida == "":
		_concluida = _tirar_prefixo(antes)       # o passo anterior foi cumprido: mostra "concluída" e some
		_concluida_t = MOSTRA_CONCLUIDA_S
	else:
		_ultimo_texto = MissaoPrincipal.objetivo()
	if _concluida == "":
		_ultimo_texto = MissaoPrincipal.objetivo()
	_atualizar()


## "Veja com seus olhos: encontrar o ninho..." → "Veja com seus olhos" (o nome curto do passo, quando tem).
static func _tirar_prefixo(t: String) -> String:
	var i := t.find(":")
	return t.substr(0, i) if i > 0 and i < 32 else t
