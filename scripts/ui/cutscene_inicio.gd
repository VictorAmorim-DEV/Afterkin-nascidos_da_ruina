class_name CutsceneInicio
extends CanvasLayer
## Cutscene provisória do começo (marco 3, etapa 3.7a; docs/DECISOES_DESIGN.md, "O começo" e Q51–Q52).
## Tela preta com textos curtos que citam as quatro raças, sons gerados no código (o jogo ainda não tem áudio) e o
## "olho" fechando e abrindo no fim: você acorda na enfermaria da Vila dos Pescadores.
## Uma vez por personagem novo. Pular: a opção aparece aos 5 s; segure Esc por 2 s (a barrinha enche).
## A cutscene completa (queda do mundo, raças, militares, resgate de carro) vem com a arte.

signal terminou

const PULAR_APOS_S := 5.0
const SEGURAR_S := 2.0
const TAXA := 22050

## [texto, segundos na tela, som ao entrar ("" = nenhum)]
const FALAS := [
	["Ninguém sabe dizer quando começou.", 4.0, "coracao"],
	["Primeiro vieram as febres. Depois, os mortos levantaram.\nOs Necróticos.", 5.0, "gemido"],
	["Nas matas e nos esgotos, gente virou fera.\nOs Bestiais.", 5.0, "rosnado"],
	["E à noite vieram eles. Os que bebem sangue.\nOs Profanos.", 5.5, "guincho"],
	["Os militares tentaram segurar as cidades.\nNós, os Humanos, nos trancamos atrás de muros.", 5.5, "tiros"],
	["Agora as raças estão em guerra.\nCada uma quer ser a última.", 5.0, "tiros"],
	["Você estava na estrada quando o carro saiu da pista.", 4.0, "batida"],
	["Sangue. Um farol. Uma voz:\n— Fica comigo, cidadão. Fica comigo...", 5.0, "coracao"],
]

var _fundo := ColorRect.new()
var _texto := Label.new()
var _dica := Label.new()
var _barra := ProgressBar.new()
var _palpebra_cima := ColorRect.new()
var _palpebra_baixo := ColorRect.new()
var _som := AudioStreamPlayer.new()
var _t := 0.0                         ## tempo desde o começo
var _segurando := 0.0
var _i := -1
var _fim_fala := 0.0
var _acabou := false
var _sons: Dictionary = {}


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fundo.color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(760, 0)
	_texto.add_theme_font_size_override("font_size", 24)
	_texto.add_theme_color_override("font_color", Color(0.88, 0.85, 0.8))
	_texto.modulate.a = 0.0
	centro.add_child(_texto)
	# pular: dica e barrinha no canto de baixo
	var canto := VBoxContainer.new()
	canto.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	canto.offset_left = -260
	canto.offset_top = -64
	canto.offset_right = -24
	canto.offset_bottom = -20
	canto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canto)
	_dica.text = "Segure Esc para pular"
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.add_theme_font_size_override("font_size", 13)
	_dica.modulate = Color(1, 1, 1, 0.0)
	canto.add_child(_dica)
	_barra.min_value = 0.0
	_barra.max_value = SEGURAR_S
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(236, 6)
	_barra.modulate = Color(1, 1, 1, 0.0)
	canto.add_child(_barra)
	# o olho: duas pálpebras que fecham e abrem sobre o jogo no fim
	for p in [_palpebra_cima, _palpebra_baixo]:
		var pr: ColorRect = p
		pr.color = Color.BLACK
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.visible = false
		add_child(pr)
	_som.process_mode = Node.PROCESS_MODE_ALWAYS
	_som.volume_db = -6.0
	add_child(_som)


func abrir() -> void:
	get_tree().paused = true
	_proxima()


## Duração total das falas (o teste usa).
static func duracao() -> float:
	var s := 0.0
	for f in FALAS:
		s += float((f as Array)[1])
	return s


func _proxima() -> void:
	_i += 1
	if _i >= FALAS.size():
		_olho()
		return
	var f: Array = FALAS[_i]
	_texto.text = str(f[0])
	_fim_fala = _t + float(f[1])
	var tw := create_tween()
	tw.tween_property(_texto, "modulate:a", 1.0, 0.8)
	tw.tween_interval(maxf(0.2, float(f[1]) - 1.6))
	tw.tween_property(_texto, "modulate:a", 0.0, 0.8)
	_tocar(str(f[2]))


## O olho: a tela preta vira duas pálpebras que abrem um pouco, fecham, e abrem de vez sobre a enfermaria.
func _olho() -> void:
	_texto.visible = false
	_dica.visible = false
	_barra.visible = false
	var tam := get_viewport().get_visible_rect().size
	var meio := tam.y * 0.5
	_palpebra_cima.position = Vector2.ZERO
	_palpebra_cima.size = Vector2(tam.x, meio)
	_palpebra_baixo.position = Vector2(0, meio)
	_palpebra_baixo.size = Vector2(tam.x, meio)
	_palpebra_cima.visible = true
	_palpebra_baixo.visible = true
	_fundo.visible = false
	get_tree().paused = false                    # o mundo aparece por trás das pálpebras
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(_tocar.bind("coracao"))
	tw.set_parallel(true)
	tw.tween_property(_palpebra_cima, "position:y", -meio * 0.55, 1.2)
	tw.tween_property(_palpebra_baixo, "position:y", meio + meio * 0.55, 1.2)
	tw.set_parallel(false)
	tw.tween_interval(0.5)
	tw.set_parallel(true)
	tw.tween_property(_palpebra_cima, "position:y", 0.0, 0.5)
	tw.tween_property(_palpebra_baixo, "position:y", meio, 0.5)
	tw.set_parallel(false)
	tw.tween_interval(0.9)
	tw.set_parallel(true)
	tw.tween_property(_palpebra_cima, "position:y", -meio, 1.6)
	tw.tween_property(_palpebra_baixo, "position:y", meio * 2.0, 1.6)
	tw.set_parallel(false)
	tw.tween_callback(_fim)


func _fim() -> void:
	if _acabou:
		return
	_acabou = true
	get_tree().paused = false
	terminou.emit()
	queue_free()


func _process(delta: float) -> void:
	if _acabou:
		return
	_t += delta
	if _i >= 0 and _i < FALAS.size() and _t >= _fim_fala:
		_proxima()
	if _i >= FALAS.size():
		return
	if _t >= PULAR_APOS_S:
		_dica.modulate.a = minf(0.7, _dica.modulate.a + delta)
		_barra.modulate.a = _dica.modulate.a
		if Input.is_key_pressed(KEY_ESCAPE):
			_segurando += delta
		else:
			_segurando = maxf(0.0, _segurando - delta * 2.0)
		_barra.value = _segurando
		if _segurando >= SEGURAR_S:
			_fim()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()     # o Esc segurado não abre o menu por baixo


# ───────────────────────────── sons gerados ─────────────────────────────

func _tocar(nome: String) -> void:
	if nome == "" or DisplayServer.get_name() == "headless":
		return
	if not _sons.has(nome):
		_sons[nome] = gerar(nome)
	_som.stream = _sons[nome]
	_som.play()


## Sons provisórios (PCM 16 bits mono): batida do coração, gemido, rosnado, guincho, tiros ao longe e a batida do carro.
static func gerar(nome: String) -> AudioStreamWAV:
	var dur := 1.6
	match nome:
		"tiros":
			dur = 2.4
		"gemido", "rosnado":
			dur = 2.0
	var n := int(dur * TAXA)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nome)
	var ruido := 0.0
	for i in n:
		var t := float(i) / TAXA
		var v := 0.0
		ruido = ruido * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3    # ruído abafado
		match nome:
			"coracao":
				for b in [0.0, 0.28, 0.9, 1.18]:
					var dt := t - float(b)
					if dt >= 0.0 and dt < 0.18:
						v += sin(TAU * 55.0 * dt) * exp(-dt * 22.0) * 0.9
			"gemido":
				var f := 110.0 + sin(TAU * 0.7 * t) * 18.0
				v = (sin(TAU * f * t) * 0.5 + ruido * 0.25) * sin(PI * t / dur) * 0.6
			"rosnado":
				var am := 0.5 + 0.5 * sin(TAU * 23.0 * t)
				v = (sin(TAU * 70.0 * t) * 0.4 + ruido * 0.6) * am * sin(PI * t / dur) * 0.7
			"guincho":
				var f2 := 1800.0 + 900.0 * sin(TAU * 3.0 * t)
				v = sin(TAU * f2 * t) * exp(-t * 2.2) * 0.35
			"tiros":
				for b2 in [0.1, 0.55, 0.75, 1.6, 2.0]:
					var dt2 := t - float(b2)
					if dt2 >= 0.0 and dt2 < 0.35:
						v += ruido * exp(-dt2 * 18.0) * 0.8
			"batida":
				v = ruido * exp(-t * 4.0) * 1.0 + sin(TAU * 40.0 * t) * exp(-t * 6.0) * 0.6
		var s := clampi(int(v * 32767.0), -32768, 32767)
		dados.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w
