extends CharacterBody2D
## Jogador — movimentação migrada do protótipo V13.
## As teclas indicam a direção NA TELA; a velocidade é calculada em unidades de
## mundo (como no protótipo) e depois projetada em isométrico 2:1.
## Animações: SpriteFrames da raça (resources/sprite_frames/), com andar_frente,
## andar_lado, andar_costas e correr (só de lado).

@export var walk_speed: float = 78.0     ## u/s andando (protótipo: 78)
@export var run_speed: float = 128.0     ## u/s correndo (protótipo: 128)
@export var aceleracao: float = 300.0    ## u/s² ao acelerar
@export var frenagem: float = 420.0      ## u/s² ao parar

var world_vel := Vector2.ZERO            ## velocidade em unidades de mundo
var _direcao := "frente"                 ## frente, lado ou costas

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var tecla := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := IsoMath.tela_para_mundo(tecla)
	var movendo := dir != Vector2.ZERO
	if movendo:
		dir = dir.normalized()
	var correndo := Input.is_action_pressed("run")
	var alvo := run_speed if correndo else walk_speed
	world_vel = world_vel.move_toward(dir * alvo, (aceleracao if movendo else frenagem) * delta)

	velocity = IsoMath.mundo_para_tela(world_vel)
	move_and_slide()
	# se bateu em algo, a velocidade real mudou: mantém a de mundo em sincronia
	world_vel = IsoMath.tela_para_mundo(velocity)
	_animar(correndo)


func _animar(correndo: bool) -> void:
	var rapidez := world_vel.length()
	if rapidez <= 10.0:
		# parado: primeiro quadro da caminhada na última direção
		sprite.animation = "andar_" + _direcao
		sprite.stop()
		return
	if absf(velocity.x) >= absf(velocity.y) * 0.9:
		_direcao = "lado"
		sprite.flip_h = velocity.x < 0.0
	else:
		_direcao = "frente" if velocity.y > 0.0 else "costas"
		sprite.flip_h = false
	var anim := "andar_" + _direcao
	var referencia := walk_speed
	if correndo and _direcao == "lado" and rapidez > walk_speed * 1.15 \
			and sprite.sprite_frames.has_animation("correr"):
		anim = "correr"
		referencia = run_speed
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
	sprite.speed_scale = rapidez / referencia
