class_name SelecaoRaca
extends CanvasLayer
## Tela inicial de escolha de raça (V13: #startCard). O jogo fica pausado até confirmar.
## F9 abre de novo durante a partida para trocar de raça nos testes (mantém mochila e posição).

## Título da próxima abertura (ex.: depois de morrer). Sobrevive ao recarregamento da cena.
static var titulo_proximo: String = ""

const RACAS := ["human", "rat", "vampire", "zombie"]
const NOMES := {"human": "Humano", "rat": "Rato", "vampire": "Vampiro", "zombie": "Zumbi"}
const RESUMOS := {
	"human": "Versátil, construtor e resistente ao sol.",
	"rat": "Forma pequena, esgoto e mobilidade.",
	"vampire": "Forte à noite; vulnerável ao sol.",
	"zombie": "Resistente no corpo e imune a algumas doenças.",
}
const DESCRICOES := {
	"human": "Humanos fabricam equipamentos com 20% menos materiais. Construções e defesas são mais resistentes, mas doenças são mais perigosas.",
	"rat": "Pode alternar entre humano e rato (tecla Q). Na forma de rato move-se 25% mais rápido e ataca 30% mais rápido, mas tem 40% menos vida.",
	"vampire": "À noite recebe bônus de força (+30% de dano). De dia, a céu aberto, acumula exposição ao sol e depois sofre dano; dentro de casa fica abrigado.",
	"zombie": "É lento (−15%), bate forte e é imune à leptospirose e à mordida do rato.",
}

@export var abrir_ao_iniciar: bool = true

var escolhida: String = "human"
var _reiniciar: bool = true
var _botoes: Dictionary = {}
var _titulo := Label.new()
var _descricao := Label.new()
var _comecar := Button.new()
var _continuar := Button.new()
var _raiz := Control.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_montar()
	_raiz.visible = false
	if not SaveJogo.pendente.is_empty():
		call_deferred("_retomar")                # partida carregada: nada de escolher raça
	elif abrir_ao_iniciar:
		call_deferred("abrir", true)


func _montar() -> void:
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.06, 0.1, 0.93)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.17)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.38, 0.5)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 12)
	painel.add_child(col)
	_titulo.add_theme_font_size_override("font_size", 24)
	col.add_child(_titulo)
	var sub := Label.new()
	sub.text = "Escolha sua origem. Suas ações, mordidas e decisões podem mudar sua raça para sempre."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(1, 1, 1, 0.65)
	col.add_child(sub)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	col.add_child(grade)
	var grupo := ButtonGroup.new()
	for r in RACAS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo
		b.text = "%s\n%s" % [NOMES[r], RESUMOS[r]]
		b.custom_minimum_size = Vector2(300, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_escolher.bind(r))
		grade.add_child(b)
		_botoes[r] = b
	_descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descricao.custom_minimum_size = Vector2(0, 60)
	col.add_child(_descricao)
	_comecar.text = "COMEÇAR SOBREVIVÊNCIA"
	_comecar.custom_minimum_size = Vector2(0, 44)
	_comecar.pressed.connect(confirmar)
	col.add_child(_comecar)
	_continuar.text = "CONTINUAR PARTIDA SALVA"
	_continuar.custom_minimum_size = Vector2(0, 40)
	_continuar.pressed.connect(func(): SaveJogo.carregar(get_tree()))
	col.add_child(_continuar)


func _retomar() -> void:
	SaveJogo.aplicar_resto(get_tree())
	_raiz.visible = false
	get_tree().paused = false


func _escolher(r: String) -> void:
	escolhida = r
	_descricao.text = DESCRICOES[r]


func abrir(reiniciar: bool) -> void:
	_reiniciar = reiniciar
	_titulo.text = titulo_proximo if titulo_proximo != "" else \
		("O mundo não acabou. Ele mudou." if reiniciar else "Trocar de raça (teste)")
	_comecar.text = "TENTAR NOVAMENTE" if titulo_proximo != "" else ("COMEÇAR SOBREVIVÊNCIA" if reiniciar else "TROCAR DE RAÇA")
	titulo_proximo = ""
	var j := get_tree().get_first_node_in_group("jogador")
	escolhida = j.raca if (j != null and not reiniciar) else "human"
	_botoes[escolhida].button_pressed = true
	_escolher(escolhida)
	_continuar.visible = reiniciar and SaveJogo.existe()
	_raiz.visible = true
	get_tree().paused = true


func confirmar() -> void:
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.definir_raca(escolhida, _reiniciar)
		j.aviso("Você acordou no meio do colapso. Encontre recursos e sobreviva." if _reiniciar else "Agora você é %s." % NOMES[escolhida])
	_raiz.visible = false
	get_tree().paused = false


func esta_aberta() -> bool:
	return _raiz.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and not _raiz.visible and not get_tree().paused:
		abrir(false)
		get_viewport().set_input_as_handled()
