class_name SelecaoRaca
extends CanvasLayer
## Tela inicial (V13: #startCard). O jogo fica pausado até confirmar.
## Toda partida começa como Humano (docs/DECISOES_DESIGN.md, Q3): na abertura se escolhe a ORIGEM (Origens, Q5/Q18)
## e a grade de raças fica escondida. Todos começam na enfermaria da Vila dos Pescadores (marco 3, etapa 3.7a): a
## origem muda só o kit; não se escolhe mais o lugar.
## F9 abre de novo durante a partida, com a grade, para trocar de raça nos testes (mantém mochila e posição).

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
	"human": "Você começa humano. Mordidas, doenças e escolhas podem mudar o que você é.",
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
var _grade := GridContainer.new()       ## botões de raça: só aparecem no F9 (teste)
var _grade_origem := GridContainer.new()  ## botões de origem: só no começo da partida
var _botoes_origem: Dictionary = {}
var origem: String = "policial"
var genero: String = "m"
var _linha_genero := HBoxContainer.new()  ## homem ou mulher (só no começo da partida)
var _botoes_genero: Dictionary = {}
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
	sub.text = "Suas ações, mordidas e decisões podem mudar o que você é para sempre."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(1, 1, 1, 0.65)
	col.add_child(sub)
	var grade := _grade
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
	_grade_origem.columns = 2
	_grade_origem.add_theme_constant_override("h_separation", 10)
	_grade_origem.add_theme_constant_override("v_separation", 10)
	col.add_child(_grade_origem)
	var grupo_o := ButtonGroup.new()
	for o in Origens.IDS:
		var d: Dictionary = Origens.DADOS[o]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo_o
		b.text = "%s\n%s" % [d["nome"], d["resumo"]]
		b.custom_minimum_size = Vector2(300, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_escolher_origem.bind(o))
		_grade_origem.add_child(b)
		_botoes_origem[o] = b
	_linha_genero.add_theme_constant_override("separation", 10)
	var rot_g := Label.new()
	rot_g.text = "Você é:"
	_linha_genero.add_child(rot_g)
	var grupo_g := ButtonGroup.new()
	for g in [["m", "Homem"], ["f", "Mulher"]]:
		var bg := Button.new()
		bg.toggle_mode = true
		bg.button_group = grupo_g
		bg.text = g[1]
		bg.custom_minimum_size = Vector2(120, 34)
		bg.pressed.connect(func(): genero = g[0])
		_linha_genero.add_child(bg)
		_botoes_genero[g[0]] = bg
	col.add_child(_linha_genero)
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


func _escolher_origem(o: String) -> void:
	origem = o
	_atualizar_descricao()


func _atualizar_descricao() -> void:
	_descricao.text = "%s: %s" % [Origens.nome(origem), str((Origens.DADOS[origem] as Dictionary)["descricao"])]


func abrir(reiniciar: bool) -> void:
	_reiniciar = reiniciar
	_titulo.text = titulo_proximo if titulo_proximo != "" else \
		("O mundo não acabou. Ele mudou." if reiniciar else "Trocar de raça (teste)")
	_comecar.text = "TENTAR NOVAMENTE" if titulo_proximo != "" else ("COMEÇAR SOBREVIVÊNCIA" if reiniciar else "TROCAR DE RAÇA")
	titulo_proximo = ""
	var j := get_tree().get_first_node_in_group("jogador")
	escolhida = j.raca if (j != null and not reiniciar) else "human"
	_grade.visible = not reiniciar
	_grade_origem.visible = reiniciar
	_linha_genero.visible = reiniciar
	_botoes[escolhida].button_pressed = true
	_escolher(escolhida)
	if reiniciar:
		_botoes_origem[origem].button_pressed = true
		_escolher_origem(origem)
		_botoes_genero[genero].button_pressed = true
	_continuar.visible = reiniciar and SaveJogo.existe()
	_raiz.visible = true
	get_tree().paused = true


func confirmar() -> void:
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.definir_raca(escolhida, _reiniciar)
		if _reiniciar:
			j.definir_origem(origem)
			j.genero = genero
			_levar_ao_inicio(j)
			_raiz.visible = false
			if introducao_ligada():
				var c := CutsceneInicio.new()
				get_parent().add_child(c)
				c.terminou.connect(_comecar_partida.bind(j))
				c.abrir()
			else:
				_comecar_partida(j)
			return
		j.aviso("Agora você é %s." % NOMES[escolhida])
	_raiz.visible = false
	get_tree().paused = false


## Opção "Introdução" (Configurações > Partida): a cutscene do começo; ligada por padrão.
static func introducao_ligada() -> bool:
	return bool(Controles.ler_cfg().get_value("jogo", "introducao", true))


## Depois da cutscene (ou sem ela): solta o jogo e o personagem acorda na enfermaria.
func _comecar_partida(j: Node) -> void:
	get_tree().paused = false
	MissaoPrincipal.acordar(j)


## Começo da partida: zera o mundo e leva o jogador à enfermaria da Vila dos Pescadores (a casa do Dr. Heitor), às 08:00.
func _levar_ao_inicio(j: Node) -> void:
	j.local_inicio = ""
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	if ciclo != null:
		ciclo.minutos = 480.0
	Inicio.zona_segura = Rect2()
	Descobertas.zerar()
	Respawn.zerar()
	Conversas.zerar()
	Reputacao.zerar()
	Escambo.zerar()
	Simulacao.zerar()
	Rumores.zerar()
	Errantes.zerar()
	Medicina.zerar()
	Consequencias.zerar()
	VidaComunidade.zerar()
	MaeColonia.zerar()
	Portaria.zerar()
	Vigilancia.zerar()
	MissaoPrincipal.zerar()
	NoiteDoAtaque.zerar()
	DiarioPartida.iniciar(str(j.origem), str(j.genero), Comunidades.nome(MissaoPrincipal.COM))
	MissaoPrincipal.levar_a_enfermaria(j)


func esta_aberta() -> bool:
	return _raiz.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and not _raiz.visible and not get_tree().paused:
		abrir(false)
		get_viewport().set_input_as_handled()
