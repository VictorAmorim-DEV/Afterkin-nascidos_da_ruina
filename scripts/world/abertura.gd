extends Node2D
class_name Abertura
## Porta ou janela encaixada no vão de uma parede modular.
##
## PORTA:  E abre/fecha (gira na dobradiça). Aberta, libera a colisão do vão.
## JANELA: E abre/fecha. A parede continua sólida: para passar por uma janela ABERTA
##         o jogador precisa estar encostado nela e apertar Espaço (pular).
## Fechadas, as duas bloqueiam a luz da lanterna; abertas, deixam passar.

signal mudou

@export_enum("porta", "janela") var tipo: String = "porta"
@export var aberta: bool = false
@export var rotulo: String = "a porta"
@export var alcance: float = 30.0                ## distância (px) para usar com E / Espaço
@export var comodos: PackedStringArray = []      ## cômodos dos dois lados desta abertura
@export var no_fechada: NodePath                 ## sprite da peça fechada
@export var no_aberta: NodePath                  ## sprite da peça aberta
@export var colisao: NodePath                    ## colisão do vão (só porta)
@export var oclusor: NodePath                    ## oclusor de luz do vão
@export var lado_a: Vector2 = Vector2.ZERO       ## ponto de pouso de um lado da parede (local)
@export var lado_b: Vector2 = Vector2.ZERO       ## ponto de pouso do outro lado
@export var duracao: float = 0.28

var _girando: bool = false
var _fechada: Sprite2D
var _aberta: Sprite2D
var _escala_fechada: float = 1.0
var _escala_aberta: float = 1.0


func _ready() -> void:
	add_to_group("interativo")
	_fechada = get_node_or_null(no_fechada) as Sprite2D
	_aberta = get_node_or_null(no_aberta) as Sprite2D
	if _fechada != null:
		_escala_fechada = _fechada.scale.x
	if _aberta != null:
		_escala_aberta = _aberta.scale.x
	_aplicar()


func _unhandled_input(event: InputEvent) -> void:
	if _girando or not perto():
		return
	if event.is_action_pressed("interact"):
		alternar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") and tipo == "janela" and aberta:
		_pular_janela()
		get_viewport().set_input_as_handled()


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func perto(raio: float = -1.0) -> bool:
	var jogador := _jogador()
	if jogador == null:
		return false
	return jogador.global_position.distance_to(global_position) <= (alcance if raio < 0.0 else raio)


## Texto que o HUD mostra quando há algo para interagir (vazio = nada).
func texto_interacao() -> String:
	if not perto():
		return ""
	if not aberta:
		return "E — abrir %s" % rotulo
	if tipo == "janela":
		return "Espaço — pular a janela · E — fechar"
	return "E — fechar %s" % rotulo


func alternar() -> void:
	aberta = not aberta
	mudou.emit()
	_girar()


## Salta para o outro lado da parede (o lado mais longe de onde o jogador está).
func _pular_janela() -> void:
	var jogador := _jogador()
	if jogador == null or not jogador.has_method("saltar_para"):
		return
	var a := to_global(lado_a)
	var b := to_global(lado_b)
	var destino := a if jogador.global_position.distance_squared_to(a) > jogador.global_position.distance_squared_to(b) else b
	jogador.saltar_para(destino)


## Gira a folha na dobradiça: a peça atual encolhe até a quina, troca, e a outra abre.
func _girar() -> void:
	_girando = true
	var sai := _fechada if aberta else _aberta         # 'aberta' já tem o estado novo
	var entra := _aberta if aberta else _fechada
	var esc_sai := _escala_fechada if aberta else _escala_aberta
	var esc_entra := _escala_aberta if aberta else _escala_fechada
	if sai != null:
		var t := create_tween().set_trans(Tween.TRANS_SINE)
		t.tween_property(sai, "scale:x", esc_sai * 0.12, duracao * 0.5)
		await t.finished
		sai.scale.x = esc_sai
	_aplicar()
	if entra != null:
		entra.scale.x = esc_entra * 0.12
		var v := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		v.tween_property(entra, "scale:x", esc_entra, duracao * 0.5)
		await v.finished
	_girando = false


func _aplicar() -> void:
	if _fechada != null:
		_fechada.visible = not aberta
	if _aberta != null:
		_aberta.visible = aberta
	var c := get_node_or_null(colisao) as CollisionPolygon2D
	if c != null:
		c.set_deferred("disabled", aberta)
	var o := get_node_or_null(oclusor) as LightOccluder2D
	if o != null:
		o.occluder_light_mask = 0 if aberta else 1
