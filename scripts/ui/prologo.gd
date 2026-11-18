class_name Prologo
extends CanvasLayer
## Prólogo do começo da partida (docs/DECISOES_DESIGN.md, ajustes do playtest, item 5): três telas curtas que
## contam o colapso, quem você era e onde estava, e o pouco que se sabe sobre o mundo. Não ensina tecla nenhuma
## (isso é dos PrimeirosPassos). Pode pular. O jogo fica pausado enquanto ele está aberto.
## Desligável em Configurações > Partida ("Introdução e primeiros passos").

signal terminou

const ORIGEM := {
	"policial": "Você era policial. Passou anos jurando proteger esta cidade; agora não sabe nem se a delegacia ainda tem gente lá dentro.",
	"mecanico": "Você era mecânico. Sabia consertar qualquer motor que entrasse na oficina. O mundo, nem tanto.",
	"enfermeiro": "Você era enfermeiro(a). Viu as primeiras mordidas chegarem ao pronto-socorro antes de qualquer um, e viu o que veio depois.",
	"mestre_obras": "Você era mestre de obras. Levantou casa a vida inteira; hoje só precisa de quatro paredes que aguentem uma noite.",
}

var _paginas: PackedStringArray = []
var _i := 0
var _texto := Label.new()
var _botao := Button.new()
var _contador := Label.new()


## Abre o prólogo para a combinação dada. 'onde' é a frase do Inicio ("numa casa de Porto Atlântico").
func abrir(origem: String, local_id: String, onde: String) -> void:
	_paginas = paginas(origem, local_id, onde)
	_i = 0
	_mostrar()
	get_tree().paused = true


## As três páginas do prólogo (estático: o teste usa sem abrir a tela).
static func paginas(origem: String, local_id: String, onde: String) -> PackedStringArray:
	var tipo := Inicio.tipo(local_id)
	var lugar := ""
	match tipo:
		"acampamento":
			lugar = "Quando tudo desabou, você estava %s. Os outros desceram até a cidade atrás de remédio e não voltaram. A fogueira ainda fumega." % onde
		"vilarejo":
			lugar = "Quando tudo desabou, você estava %s. O vilarejo esvaziou numa só noite: carros saindo sem farol, portas batendo, depois nada." % onde
		_:
			lugar = "Quando tudo desabou, você estava %s. Trancou a porta e esperou o barulho passar. Faz dias que ninguém passa pela rua." % onde
	return PackedStringArray([
		"Ninguém sabe dizer quando começou.\n\nPrimeiro vieram as febres: gente que não acordava, e gente que acordava diferente. Em três semanas as cidades pararam. O rádio virou estática. As estradas viraram fila de carros abandonados.",
		"%s\n\n%s" % [ORIGEM.get(origem, "Você era só mais um sobrevivente."), lugar],
		"O que você aprendeu até aqui:\n\n•  Os mortos andam, e ouvem tudo. Barulho atrai.\n•  Há outros que só saem à noite. De dia dormem dentro das casas. Dizem que a mordida deles muda as pessoas.\n•  Água parada adoece. Ferva antes de beber.\n•  A noite é deles. Esteja em lugar seguro quando escurecer.\n\nVocê começa humano. O que vai se tornar depende do que fizer daqui para frente.",
	])


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.025, 0.035, 0.97)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 22)
	centro.add_child(col)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(640, 260)
	_texto.add_theme_font_size_override("font_size", 19)
	_texto.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	col.add_child(_texto)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	col.add_child(linha)
	_contador.modulate = Color(1, 1, 1, 0.5)
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(_contador)
	var pular := Button.new()
	pular.text = "Pular introdução"
	pular.flat = true
	pular.pressed.connect(_fim)
	linha.add_child(pular)
	_botao.custom_minimum_size = Vector2(160, 40)
	_botao.pressed.connect(_avancar)
	linha.add_child(_botao)


func _mostrar() -> void:
	_texto.text = _paginas[_i]
	_contador.text = "%d / %d" % [_i + 1, _paginas.size()]
	_botao.text = "Começar" if _i == _paginas.size() - 1 else "Continuar"
	_texto.modulate.a = 0.0
	create_tween().tween_property(_texto, "modulate:a", 1.0, 0.5)


func _avancar() -> void:
	_i += 1
	if _i >= _paginas.size():
		_fim()
	else:
		_mostrar()


func _fim() -> void:
	get_tree().paused = false
	terminou.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_avancar()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			_fim()
			get_viewport().set_input_as_handled()
