extends Node2D
## Construção em camadas, sem troca de tela.
##
## Camadas (ver tools/gerar_construcao.py):
##   Chao      piso e móveis pintados do interior
##   Interior  Y-Sort com móveis soltos e a folha da porta
##   Fachada   teto e paredes externas — some quando o jogador entra
## Quando o jogador entra na AreaInterior (interior + soleira) a Fachada perde a
## opacidade e o interior aparece; ao sair, tudo volta. A porta abre e fecha na tecla
## de interação (E) quando o jogador está perto dela.

@export var duracao_transicao: float = 0.35
@export var alcance_porta: float = 48.0        ## distância (px de tela) para usar a porta
@export var porta_aberta: bool = false

var _dentro: int = 0
var _transicao: Tween

@onready var chao: Sprite2D = $Chao
@onready var interior: Node2D = $Interior
@onready var fachada: Node2D = $Fachada
@onready var vao_da_porta: Polygon2D = $Fachada/VaoDaPorta
@onready var porta_fechada: Polygon2D = $Interior/PortaFechada
@onready var porta_aberta_visual: Polygon2D = $Interior/PortaAberta
@onready var porta_colisao: CollisionPolygon2D = $Paredes/Porta
@onready var porta_oclusor: LightOccluder2D = $Oclusores/Porta
@onready var area: Area2D = $AreaInterior
@onready var ponto_da_porta: Marker2D = $PontoDaPorta


func _ready() -> void:
	add_to_group("interativo")
	chao.modulate.a = 0.0
	interior.modulate.a = 0.0
	area.body_entered.connect(_ao_entrar)
	area.body_exited.connect(_ao_sair)
	_aplicar_porta()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _jogador_perto_da_porta():
		porta_aberta = not porta_aberta
		_aplicar_porta()
		get_viewport().set_input_as_handled()


## Texto mostrado pelo HUD quando há algo para interagir (vazio = nada).
func texto_interacao() -> String:
	if _jogador_perto_da_porta():
		return "E — fechar a porta" if porta_aberta else "E — abrir a porta"
	return ""


func jogador_dentro() -> bool:
	return _dentro > 0


func _jogador_perto_da_porta() -> bool:
	var jogador := get_tree().get_first_node_in_group("jogador") as Node2D
	if jogador == null:
		return false
	return jogador.global_position.distance_to(ponto_da_porta.global_position) <= alcance_porta


func _aplicar_porta() -> void:
	porta_colisao.set_deferred("disabled", porta_aberta)
	porta_oclusor.occluder_light_mask = 0 if porta_aberta else 1   # porta aberta deixa a luz passar
	porta_fechada.visible = not porta_aberta
	porta_aberta_visual.visible = porta_aberta
	vao_da_porta.visible = porta_aberta


func _ao_entrar(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador"):
		_dentro += 1
		_revelar(true)


func _ao_sair(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador"):
		_dentro = maxi(0, _dentro - 1)
		if _dentro == 0:
			_revelar(false)


func _revelar(mostrar_interior: bool) -> void:
	if _transicao != null and _transicao.is_valid():
		_transicao.kill()
	_transicao = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_transicao.tween_property(fachada, "modulate:a", 0.0 if mostrar_interior else 1.0, duracao_transicao)
	_transicao.tween_property(interior, "modulate:a", 1.0 if mostrar_interior else 0.0, duracao_transicao)
	_transicao.tween_property(chao, "modulate:a", 1.0 if mostrar_interior else 0.0, duracao_transicao)
