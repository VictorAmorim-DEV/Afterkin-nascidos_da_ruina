class_name Inimigo
extends CharacterBody2D
## Zumbi ou rato gigante (V13: atualizarInimigos). Dorme até ouvir o jogador, persegue,
## abre ou arromba portas e ataca de perto. Trabalha em "mundo" (u) como o jogador.

const FRAMES := {
	"zombie": "res://resources/sprite_frames/zumbi.tres",
	"rat": "res://resources/sprite_frames/rato_gigante.tres",
	"vampire": "res://resources/sprite_frames/vampiro.tres",
}
const NOMES := {"zombie": "Zumbi", "rat": "Rato gigante", "vampire": "Vampiro"}
const M := IsoMath.METRO
const DIRECOES: Array[String] = ["frente", "lado", "costas"]

@export_enum("zombie", "rat", "vampire") var raca: String = "zombie"
@export var dorme: bool = true
var casa: Edificio = null          ## casa onde mora; o vampiro volta para ela de dia e dorme

var hp: float = 45.0
var hp_max: float = 45.0
var morto: bool = false
var alerta: float = 0.0
var passeio: bool = false
var saiu: bool = false
var ataque_t: float = 0.0
var golpe_t: float = 0.0
var _alvo_passeio := Vector2.ZERO
var _t_alvo: float = 0.0
var _lado: float = 0.0
var _desvio_t: float = 0.0
var _passo: float = 0.0
var _flip_dorme: bool = false
var _ciclo: Node = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("inimigo")
	sprite.sprite_frames = load(FRAMES[raca])
	hp_max = 25.0 if raca == "rat" else 45.0
	hp = hp_max
	_flip_dorme = randf() < 0.5
	_animar(Vector2.DOWN, false)


func _mundo() -> Vector2:
	return IsoMath.tela_para_mundo(global_position)


func _edif_em(p_mundo: Vector2) -> Edificio:
	for e in get_tree().get_nodes_in_group("edificio"):
		if e.sala_de(p_mundo - IsoMath.tela_para_mundo(e.global_position)) >= 0:
			return e
	return null


func _noite() -> bool:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	return _ciclo != null and _ciclo.eh_noite()


func _physics_process(delta: float) -> void:
	if morto:
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.vida <= 0.0:
		return
	ataque_t -= delta
	golpe_t -= delta
	var em := _mundo()
	var pm: Vector2 = IsoMath.tela_para_mundo(j.global_position)
	var d := em.distance_to(pm)
	var eb := _edif_em(em)
	var pb := _edif_em(pm)
	var ouve: float = j.ruido * (1.0 if eb == pb else 0.55)

	if dorme:
		if d < ouve:
			dorme = false
			alerta = 4.0
		elif _noite() and (raca == "rat" or raca == "vampire") and not saiu:
			dorme = false
			passeio = true
			saiu = true
		else:
			_animar(Vector2.DOWN, false)
			return
	alerta = maxf(0.0, alerta - delta)
	if d < ouve:
		alerta = 4.0

	var vel := 62.0 if raca == "rat" else 46.0
	var noite := _noite()
	if raca == "vampire" and noite:
		vel *= 1.35
	var alvo := Vector2.ZERO
	var tem_alvo := false
	if alerta > 0.0 and d < 28.0 * M:
		alvo = pm
		tem_alvo = true
	elif casa != null and raca == "vampire" and not noite:
		# de dia o vampiro volta para o primeiro cômodo da casa e volta a dormir
		var s: Dictionary = casa.salas[0]
		alvo = Vector2((s.x0 + s.x1) / 2.0 * Edificio.TILE, (s.y0 + s.y1) / 2.0 * Edificio.TILE) \
			+ IsoMath.tela_para_mundo(casa.global_position)
		tem_alvo = true
		vel *= 0.8
		if eb == casa and em.distance_to(alvo) < 1.2 * M:
			dorme = true
			saiu = false
			passeio = false
			return
	elif passeio:
		_t_alvo += delta
		if _alvo_passeio == Vector2.ZERO or em.distance_to(_alvo_passeio) < 30.0 or _t_alvo > 12.0:
			var saida := em
			if casa != null:
				var p = casa.porta_ext()
				if p != null:
					saida = p.pto[-1] + IsoMath.tela_para_mundo(casa.global_position)
			_alvo_passeio = saida + Vector2(randf_range(-18, 18), randf_range(-18, 18)) * M
			_t_alvo = 0.0
		alvo = _alvo_passeio
		tem_alvo = true
		vel *= 0.55

	var dir := Vector2.ZERO
	if tem_alvo:
		var r := _rota(em, alvo, eb, pb)
		var pt: Vector2 = r[0]
		var porta = r[1]
		var bloqueada := false
		if porta != null and not porta.open and em.distance_to(r[2] + Vector2(porta.x, porta.y)) < 1.3 * M:
			# rato e vampiro abrem a porta; zumbi arromba
			if raca == "zombie":
				bloqueada = true
				if r[3].bater_porta(porta, delta) and d < 16.0 * M:
					get_tree().call_group("hud", "aviso", "Um zumbi arrombou a porta!")
			else:
				r[3].abrir_porta(porta)
		if not bloqueada:
			var v := pt - em
			if v.length() > 2.0:
				dir = v.normalized()
	if dir != Vector2.ZERO:
		if _desvio_t > 0.0:
			_desvio_t -= delta
			dir = (dir * 0.35 + Vector2(-dir.y, dir.x) * _lado).normalized()
		var antes := global_position
		velocity = IsoMath.mundo_para_tela(dir * vel)
		move_and_slide()
		var andou := IsoMath.tela_para_mundo(global_position - antes).length()
		if andou < vel * delta * 0.35 and _desvio_t <= 0.0:
			_lado = 1.0 if randf() < 0.5 else -1.0   # preso em móvel/parede: contorna pelo lado
			_desvio_t = 0.45
		_passo += vel * delta * 0.09
	else:
		velocity = Vector2.ZERO

	if d < 24.0 and ataque_t <= 0.0 and eb == pb:
		ataque_t = 1.3
		golpe_t = 0.25
		j.receber_dano(8.0 if raca == "zombie" else 6.0, raca)
		if randf() < 0.12:
			j.infectar(raca)
	_animar(dir if dir != Vector2.ZERO else (pm - em), dir != Vector2.ZERO)


## Devolve [ponto, porta|null, posição do edifício em mundo, edifício] — V13: rota().
func _rota(em: Vector2, alvo: Vector2, eb: Edificio, pb: Edificio) -> Array:
	var ed := eb if eb != null else pb
	if ed == null:
		return [alvo, null, Vector2.ZERO, null]
	var off := IsoMath.tela_para_mundo(ed.global_position)
	var r: Array
	var alvo_edif := _edif_em(alvo)
	if eb != null and eb == alvo_edif:
		r = eb.rota_interna(em - off, alvo - off)
	elif eb != null:
		r = eb.rota_saida(em - off)
	else:
		r = pb.rota_entrada(em - off) if alvo_edif == pb else [alvo - off, null]
	return [r[0] + off, r[1], off, ed]


func receber_dano(n: float) -> void:
	if morto:
		return
	hp -= n
	dorme = false
	alerta = 4.0
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	queue_redraw()
	if hp <= 0.0:
		_morrer()


func _morrer() -> void:
	morto = true
	remove_from_group("inimigo")
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.animation = &"caido"
	sprite.frame = 0
	sprite.flip_h = _flip_dorme
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.ganhar_xp(30)
		if j.inventario.adicionar_itens([["comida", 1]]):
			j.aviso("Inimigo derrotado. +30 XP e 1 comida.")
		else:
			ItemNoChao.largar(get_parent(), global_position + Vector2(0, 2), "comida", 1)
			j.aviso("Inimigo derrotado. +30 XP; a comida ficou no chão (mochila cheia).")
	queue_redraw()
	var t := create_tween()
	t.tween_interval(6.0)
	t.tween_property(self, "modulate:a", 0.0, 1.5)
	t.tween_callback(queue_free)


func _draw() -> void:
	if morto or hp >= hp_max:
		return
	draw_rect(Rect2(-12, -52, 24, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-12, -52, 24.0 * hp / hp_max, 3), Color(0.8, 0.2, 0.2))


func _animar(olhar_mundo: Vector2, andando: bool) -> void:
	if dorme:
		sprite.animation = &"deitado"
		sprite.frame = 0
		sprite.flip_h = _flip_dorme
		return
	var tela := Vector2(olhar_mundo.x - olhar_mundo.y, olhar_mundo.x + olhar_mundo.y)
	var linha := 1
	var flip := tela.x < 0.0
	if absf(tela.x) <= absf(tela.y):
		linha = 0 if tela.y > 0.0 else 2
		flip = false
	var anim := (("atacar_" if golpe_t > 0.0 else "andar_") + DIRECOES[linha])
	var quadros := sprite.sprite_frames
	if not quadros.has_animation(anim):
		anim = "andar_frente"
	var q := 0
	if golpe_t <= 0.0 and andando:
		q = int(_passo * 0.7) % quadros.get_frame_count(anim)
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.frame = mini(q, quadros.get_frame_count(anim) - 1)
	sprite.flip_h = flip
