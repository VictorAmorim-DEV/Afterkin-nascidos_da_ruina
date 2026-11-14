extends Camera2D
## Câmera que segue o jogador com suavização e zoom na rodinha do mouse.
## Valores do protótipo V13: zoom 0,55–2,6 (inicial 1,3), seguir = 7, zoom = 12.

@export var target_path: NodePath
@export var zoom_min: float = 0.55
@export var zoom_max: float = 2.6
@export var zoom_passo: float = 0.12       ## quanto cada "clique" da rodinha aproxima
@export var zoom_suavidade: float = 12.0

var _alvo: Node2D
var _zoom_alvo := 1.3


func _ready() -> void:
	add_to_group("camera_iso")
	_alvo = get_node_or_null(target_path) as Node2D
	_zoom_alvo = zoom.x
	if _alvo:
		global_position = _alvo.global_position
		reset_smoothing()
	make_current()


func _physics_process(_delta: float) -> void:
	if _alvo:
		global_position = _alvo.global_position


## Troca quem a câmera acompanha (jogador a pé, veículo...).
func seguir(no: Node2D) -> void:
	_alvo = no


func _process(delta: float) -> void:
	var z := lerpf(zoom.x, _zoom_alvo, minf(1.0, delta * zoom_suavidade))
	zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	var botao := event as InputEventMouseButton
	if botao == null or not botao.pressed:
		return
	var fator := botao.factor if botao.factor > 0.0 else 1.0
	if botao.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_alvo = clampf(_zoom_alvo * exp(zoom_passo * fator), zoom_min, zoom_max)
	elif botao.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_alvo = clampf(_zoom_alvo * exp(-zoom_passo * fator), zoom_min, zoom_max)
