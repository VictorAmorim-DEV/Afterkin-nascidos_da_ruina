extends CanvasLayer
## HUD: relógio, barra de fôlego e estado do jogador.
## Fica em um CanvasLayer, então não é escurecido pelo ciclo de dia e noite.

@export var jogador_path: NodePath
@export var ciclo_path: NodePath

const COR_FOLEGO := Color(0.56, 0.78, 0.42)
const COR_CORRENDO := Color(0.93, 0.76, 0.33)
const COR_EXAUSTO := Color(0.84, 0.33, 0.29)

var _jogador: Node
var _ciclo: Node
var _preenchimento := StyleBoxFlat.new()

@onready var relogio: Label = $Painel/Relogio
@onready var folego_texto: Label = $Painel/FolegoTexto
@onready var folego: ProgressBar = $Painel/Folego
@onready var estado: Label = $Painel/Estado
@onready var ajuda: Label = $Painel/Ajuda


func _ready() -> void:
	_jogador = get_node_or_null(jogador_path)
	_ciclo = get_node_or_null(ciclo_path)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	fundo.set_corner_radius_all(4)
	_preenchimento.bg_color = COR_FOLEGO
	_preenchimento.set_corner_radius_all(4)
	folego.add_theme_stylebox_override("background", fundo)
	folego.add_theme_stylebox_override("fill", _preenchimento)
	for rotulo: Label in [relogio, folego_texto, estado, ajuda]:
		rotulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		rotulo.add_theme_constant_override("outline_size", 4)
		rotulo.add_theme_font_size_override("font_size", 14)
	relogio.add_theme_font_size_override("font_size", 17)
	ajuda.add_theme_font_size_override("font_size", 12)
	ajuda.modulate = Color(1.0, 1.0, 1.0, 0.7)


func _process(_delta: float) -> void:
	if _ciclo != null:
		relogio.text = _ciclo.texto_relogio()
	if _jogador == null:
		return
	folego.max_value = _jogador.stamina_max
	folego.value = _jogador.stamina
	folego_texto.text = "FÔLEGO %d%%%s" % [int(_jogador.stamina), " · EXAUSTO" if _jogador.exausto else ""]
	if _jogador.exausto:
		_preenchimento.bg_color = COR_EXAUSTO
	elif _jogador.correndo:
		_preenchimento.bg_color = COR_CORRENDO
	else:
		_preenchimento.bg_color = COR_FOLEGO
	estado.text = "%s · Lanterna %s" % [_jogador.nome_postura(), "ligada" if _jogador.lanterna_ligada else "desligada"]
