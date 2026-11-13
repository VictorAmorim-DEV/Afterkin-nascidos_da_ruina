extends CharacterBody2D
## Jogador — movimentação migrada do protótipo V13.
## As teclas indicam a direção NA TELA; a velocidade é calculada em unidades de
## mundo (como no protótipo) e depois projetada em isométrico 2:1.

@export var walk_speed: float = 78.0     ## u/s andando (protótipo: 78)
@export var run_speed: float = 128.0     ## u/s correndo (protótipo: 128)
@export var aceleracao: float = 300.0    ## u/s² ao acelerar
@export var frenagem: float = 420.0      ## u/s² ao parar

var world_vel := Vector2.ZERO            ## velocidade em unidades de mundo
var _passo := 0.0
var _linha := 0                          ## 0 = frente, 1 = lado, 2 = costas

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	var tecla := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := IsoMath.tela_para_mundo(tecla)
	var movendo := dir != Vector2.ZERO
	if movendo:
		dir = dir.normalized()
	var alvo := run_speed if Input.is_action_pressed("run") else walk_speed
	world_vel = world_vel.move_toward(dir * alvo, (aceleracao if movendo else frenagem) * delta)

	velocity = IsoMath.mundo_para_tela(world_vel)
	move_and_slide()
	# se bateu em algo, a velocidade real mudou: mantém a de mundo em sincronia
	world_vel = IsoMath.tela_para_mundo(velocity)
	_animar(delta)


func _animar(delta: float) -> void:
	var rapidez := world_vel.length()
	var coluna := 0
	if rapidez > 10.0:
		_passo += rapidez * delta * 0.09
		coluna = int(_passo * 0.7) % sprite.hframes
		if absf(velocity.x) >= absf(velocity.y) * 0.9:
			_linha = 1
			sprite.flip_h = velocity.x < 0.0
		else:
			_linha = 0 if velocity.y > 0.0 else 2
			sprite.flip_h = false
	sprite.frame_coords = Vector2i(coluna, _linha)
