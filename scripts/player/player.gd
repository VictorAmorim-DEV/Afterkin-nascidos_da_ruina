extends CharacterBody2D
## Jogador base: movimento em 8 direções (as ações vêm do Mapa de Entrada do projeto).

@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity = dir * speed
	move_and_slide()
