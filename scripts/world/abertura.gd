extends Node2D
class_name Abertura
## Porta ou janela que abre e fecha na tecla de interação (E).
##
## Ao abrir: troca o sprite pelo da peça aberta (com um giro na dobradiça),
## desliga a colisão do vão e deixa a luz da lanterna passar.
## Quem escuta o sinal "mudou" é a construção, que revela o cômodo.

signal mudou

@export var aberta: bool = false
@export var rotulo: String = "a porta"          ## texto mostrado no HUD
@export var alcance: float = 30.0               ## distância (px de tela) para usar
@export var comodos: PackedStringArray = []     ## cômodos que esta abertura revela
@export var textura_fechada: Texture2D
@export var textura_aberta: Texture2D
@export var sprites: Array[NodePath] = []       ## sprites que desenham esta abertura
@export var colisao: NodePath                   ## CollisionPolygon2D do vão
@export var oclusor: NodePath                   ## LightOccluder2D do vão
@export var duracao: float = 0.28

var _girando: bool = false
var _escalas: Array[float] = []


func _ready() -> void:
	add_to_group("interativo")
	for p in sprites:
		var s := get_node_or_null(p) as Sprite2D
		_escalas.append(s.scale.x if s != null else 1.0)
	_aplicar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _girando and perto():
		alternar()
		get_viewport().set_input_as_handled()


func perto() -> bool:
	var jogador := get_tree().get_first_node_in_group("jogador") as Node2D
	return jogador != null and jogador.global_position.distance_to(global_position) <= alcance


## Texto que o HUD mostra quando há algo para interagir (vazio = nada).
func texto_interacao() -> String:
	if not perto():
		return ""
	return "E — fechar %s" % rotulo if aberta else "E — abrir %s" % rotulo


func alternar() -> void:
	aberta = not aberta
	mudou.emit()
	_girar()


## Gira a folha na dobradiça: encolhe até a quina, troca a arte e abre de novo.
func _girar() -> void:
	_girando = true
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for i in sprites.size():
		var s := get_node_or_null(sprites[i]) as Sprite2D
		if s != null:
			t.tween_property(s, "scale:x", _escalas[i] * 0.12, duracao * 0.5)
	await t.finished
	_aplicar()
	var v := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in sprites.size():
		var s := get_node_or_null(sprites[i]) as Sprite2D
		if s != null:
			v.tween_property(s, "scale:x", _escalas[i], duracao * 0.5)
	await v.finished
	_girando = false


func _aplicar() -> void:
	for i in sprites.size():
		var s := get_node_or_null(sprites[i]) as Sprite2D
		if s != null:
			s.texture = textura_aberta if aberta else textura_fechada
	var c := get_node_or_null(colisao) as CollisionPolygon2D
	if c != null:
		c.set_deferred("disabled", aberta)
	var o := get_node_or_null(oclusor) as LightOccluder2D
	if o != null:
		o.occluder_light_mask = 0 if aberta else 1
