class_name Veiculo
extends CharacterBody2D
## Veículo dirigível (RECURSO NOVO: a V13 só tem carros de cenário, sem dirigir nem combustível).
## E perto dele entra/sai. W/S aceleram e dão ré, A/D esterçam, Espaço é o freio de mão, F liga/desliga os faróis.
##
## Física em "mundo" (u/s), como o jogador: ângulo de proa + velocidade com sinal. A arte só existe de um
## lado (vista da frente em +Y); a proa mais próxima de X espelha o sprite. Colisão e luz seguem a proa real.
## Queimado (V13: queimar/queimado): carcaça escurecida, que não liga nem anda.

@export var nome: String = "Veículo"
@export var textura: Texture2D
@export var escala: float = 1.0
@export var pivo := Vector2.ZERO            ## vértice de baixo da base, em px da imagem
@export var comprimento: float = 167.0      ## u de mundo, ao longo da arte (eixo Y)
@export var largura: float = 90.0
@export_group("Dinâmica (u/s)")
@export var vel_max: float = 520.0          ## ≈ 38 km/h na escala do jogo
@export var vel_max_re: float = 160.0
@export var aceleracao: float = 230.0
@export var freio: float = 520.0
@export var atrito: float = 140.0
@export var freio_mao: float = 700.0
@export var esterco: float = 1.9            ## rad/s com a velocidade de curva cheia
@export_group("Faróis")
@export var alcance_farol: float = 900.0    ## u de mundo
@export var energia_farol: float = 1.3

const M := IsoMath.METRO

var proa: float = PI / 2.0                  ## ângulo no mundo; a arte original olha para +Y
var vel: float = 0.0
var motorista: Node2D = null
var farol_ligado: bool = true
var queimado: bool = false

## V13 (queimar): pinta o sprite com rgba(20, 15, 12, .72) por cima, mantendo a transparência.
const SHADER_QUEIMADO := "shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(0.078, 0.059, 0.047), 0.72), c.a);
}
"
static var _mat_queimado: ShaderMaterial = null

var _sprite := Sprite2D.new()
var _col := CollisionPolygon2D.new()
var _ocl := LightOccluder2D.new()
var _farol_chao := PointLight2D.new()
var _farol_obj := PointLight2D.new()
var _proa_desenhada: float = 99.0
var _ciclo: Node = null


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("veiculo")
	y_sort_enabled = true
	_sprite.centered = false
	_sprite.texture = textura
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.light_mask = 2
	if queimado:
		if _mat_queimado == null:
			var sh := Shader.new()
			sh.code = SHADER_QUEIMADO
			_mat_queimado = ShaderMaterial.new()
			_mat_queimado.shader = sh
		_sprite.material = _mat_queimado
		nome = "Carcaça queimada"
	add_child(_sprite)
	add_child(_col)
	_ocl.occluder = OccluderPolygon2D.new()
	add_child(_ocl)
	var luz_tex: Texture2D = load("res://assets/luzes/lanterna.png")
	for l: PointLight2D in [_farol_chao, _farol_obj]:
		l.texture = luz_tex
		l.color = Color(1.0, 0.95, 0.8)
		l.enabled = false
		add_child(l)
	_farol_chao.range_item_cull_mask = 1
	_farol_chao.shadow_enabled = true
	_farol_chao.shadow_filter = 1
	_farol_chao.shadow_item_cull_mask = 1
	_farol_chao.height = 18.0
	_farol_obj.range_item_cull_mask = 2
	_farol_obj.height = 18.0
	_atualizar_forma()


## Retângulo da carroceria no mundo, relativo ao centro, na proa atual (encolhido um pouco).
func _retangulo(folga: float = 0.92) -> PackedVector2Array:
	var d := Vector2.from_angle(proa)
	var p := Vector2(-d.y, d.x)
	var hl := comprimento * 0.5 * folga
	var hw := largura * 0.5 * folga
	var pts := PackedVector2Array()
	for c in [d * hl + p * hw, d * hl - p * hw, -d * hl - p * hw, -d * hl + p * hw]:
		pts.append(IsoMath.mundo_para_tela(c))
	return pts


func _atualizar_forma() -> void:
	_proa_desenhada = proa
	var espelhado := absf(cos(proa)) > absf(sin(proa))     # proa mais perto de ±X: arte espelhada
	if espelhado:
		var p0 := IsoMath.mundo_para_tela(Vector2(comprimento / 2.0, largura / 2.0))
		_sprite.scale = Vector2(-escala, escala)
		_sprite.position = Vector2(p0.x + pivo.x * escala, p0.y - pivo.y * escala)
	else:
		var p1 := IsoMath.mundo_para_tela(Vector2(largura / 2.0, comprimento / 2.0))
		_sprite.scale = Vector2(escala, escala)
		_sprite.position = p1 - pivo * escala
	var r := _retangulo()
	_col.polygon = r
	_ocl.occluder.polygon = _retangulo(1.0)


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


## Distância do jogador à carroceria (u de mundo), no referencial do carro.
func _distancia_jogador() -> float:
	var j := _jogador()
	if j == null:
		return INF
	var v := IsoMath.tela_para_mundo(j.global_position - global_position).rotated(-proa)
	var dx := maxf(absf(v.x) - comprimento * 0.5, 0.0)
	var dy := maxf(absf(v.y) - largura * 0.5, 0.0)
	return Vector2(dx, dy).length()


func _e_o_alvo() -> bool:
	var j := _jogador()
	if queimado or j == null or j.dirigindo != null or j.morto:
		return false
	var d := _distancia_jogador()
	if d > 1.2 * M:
		return false
	for o in get_tree().get_nodes_in_group("veiculo"):
		if o != self and o._distancia_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 8


func texto_interacao() -> String:
	if motorista != null:
		return "E — sair · W/S acelera e ré · A/D esterça · Espaço freia · F faróis"
	return "E — entrar na %s" % nome.to_lower() if _e_o_alvo() else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if motorista != null:
			sair()
			get_viewport().set_input_as_handled()
		elif _e_o_alvo():
			entrar(_jogador())
			get_viewport().set_input_as_handled()
	elif motorista != null and event.is_action_pressed("flashlight"):
		farol_ligado = not farol_ligado
		get_viewport().set_input_as_handled()


func entrar(j: Node2D) -> void:
	motorista = j
	j.dirigindo = self
	j.visible = false
	j.world_vel = Vector2.ZERO
	get_tree().call_group("camera_iso", "seguir", self)
	j.aviso("Você entrou na %s." % nome.to_lower())


func sair() -> void:
	var j := motorista
	if j == null:
		return
	var d := Vector2.from_angle(proa)
	var p := Vector2(-d.y, d.x)
	var h := comprimento * 0.5 + 0.9 * M
	var w := largura * 0.5 + 0.9 * M
	var destino := global_position + IsoMath.mundo_para_tela(p * w)
	for c in [p * w, -p * w, -d * h, d * h]:
		var pos: Vector2 = global_position + IsoMath.mundo_para_tela(c)
		if not j.test_move(Transform2D(0.0, pos), Vector2(0.1, 0.1)):
			destino = pos
			break
	motorista = null
	j.dirigindo = null
	j.global_position = destino
	j.visible = true
	get_tree().call_group("camera_iso", "seguir", j)
	j.aviso("Você saiu da %s." % nome.to_lower())


func velocidade_kmh() -> int:
	return roundi(absf(vel) / M * 3.6)


func _physics_process(delta: float) -> void:
	if motorista != null:
		var acel := Input.get_axis("move_down", "move_up")
		if acel > 0.0:
			vel += (aceleracao if vel >= 0.0 else freio) * acel * delta
		elif acel < 0.0:
			vel -= (aceleracao if vel <= 0.0 else freio) * -acel * delta
		else:
			vel = move_toward(vel, 0.0, atrito * delta)
		if Input.is_action_pressed("jump"):
			vel = move_toward(vel, 0.0, freio_mao * delta)
		vel = clampf(vel, -vel_max_re, vel_max)
		var curva := Input.get_axis("move_left", "move_right")
		proa += curva * esterco * clampf(vel / 150.0, -1.0, 1.0) * delta
		proa = wrapf(proa, -PI, PI)
		motorista.global_position = global_position
		motorista.ruido = 160.0 + 220.0 * absf(vel) / vel_max          # motor: os inimigos ouvem de longe
	else:
		vel = move_toward(vel, 0.0, atrito * 2.5 * delta)               # solto, ele só desliza até parar
	if absf(vel) > 0.5:
		var antes := global_position
		velocity = IsoMath.mundo_para_tela(Vector2.from_angle(proa) * vel)
		var sentido := velocity.normalized()
		move_and_slide()
		var impacto := 0.0
		for i in get_slide_collision_count():
			impacto = maxf(impacto, sentido.dot(-get_slide_collision(i).get_normal()))
		if impacto > 0.25:
			vel *= clampf(1.0 - impacto * 0.85, 0.15, 1.0)             # bateu: perde velocidade (e raspa se for de lado)
		var andou := IsoMath.tela_para_mundo(global_position - antes).length()
		if andou < absf(vel) * delta * 0.4:
			vel *= 0.35
	if not is_equal_approx(proa, _proa_desenhada):
		_atualizar_forma()
	_atualizar_farois()


func _atualizar_farois() -> void:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	var escuro := 1.0
	if _ciclo != null and _ciclo.has_method("escuridao"):
		escuro = _ciclo.escuridao()
	var ligado := motorista != null and farol_ligado and escuro > 0.03
	_farol_chao.enabled = ligado
	_farol_obj.enabled = ligado
	if not ligado:
		return
	var d := Vector2.from_angle(proa)
	var frente := IsoMath.mundo_para_tela(d)
	var lado := IsoMath.mundo_para_tela(Vector2(-d.y, d.x))
	var k := alcance_farol / 256.0
	var nariz := IsoMath.mundo_para_tela(d * comprimento * 0.45)
	var energia := energia_farol * clampf(escuro * 1.8, 0.0, 1.0)
	_farol_chao.energy = energia
	_farol_chao.transform = Transform2D(frente * k, lado * k * 1.3, nariz)
	_farol_obj.energy = energia
	_farol_obj.transform = Transform2D(frente * k, lado * k * 1.3, nariz + Vector2(0.0, -18.0))
