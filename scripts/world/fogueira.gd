class_name Fogueira
extends Node2D
## Fogueira: pedras, chamas que tremem e uma luz quente (só aparece de noite).
## As dos acampamentos ficam sempre acesas; a que o jogador acende (receita "fogueira") apaga sozinha.
## Ferve água suja (docs/DECISOES_DESIGN.md Q29): uma garrafa a cada TEMPO_FERVER segundos, com o jogador perto,
## fazendo barulho (panela e fogo). No escuro, quem está ao lado dela é visto de longe (Player.alcance_ser_visto).

const DURACAO_ACESA := 300.0         ## s reais da fogueira acesa pelo jogador (~3 h de jogo)
const TEMPO_FERVER := 6.0            ## s por garrafa
const RUIDO_FERVENDO := 190.0        ## barulho mínimo do jogador enquanto ferve
const RAIO := 1.8 * IsoMath.METRO    ## distância para ferver e para "estar ao lado"

var duracao_s := -1.0                ## < 0 = não apaga (acampamentos)
var _t: float = 0.0
var _luz := PointLight2D.new()
var _fervendo := false
var _t_ferver := 0.0


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("fogueira")
	_t = randf() * 10.0
	light_mask = 2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.80, 0.45, 1.0))
	g.set_color(1, Color(1.0, 0.45, 0.15, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_luz.texture = tex
	_luz.texture_scale = 2.2
	_luz.energy = 1.2
	_luz.shadow_enabled = false
	_luz.range_item_cull_mask = 3
	_luz.position = Vector2(0, -14)
	add_child(_luz)


## Há uma fogueira acesa a menos de RAIO do nó 'quem'?
static func acesa_perto(quem: Node2D) -> bool:
	for f in quem.get_tree().get_nodes_in_group("fogueira"):
		if (f as Fogueira)._distancia(quem) < RAIO:
			return true
	return false


func _distancia(quem: Node2D) -> float:
	return IsoMath.tela_para_mundo(quem.global_position - global_position).length()


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func _perto() -> bool:
	var j := _jogador()
	return j != null and j.dirigindo == null and _distancia(j) < RAIO


func prioridade_interacao() -> int:
	return 6


func texto_interacao() -> String:
	if not _perto():
		return ""
	var n: int = _jogador().inventario.contar("agua_suja")
	if _fervendo:
		return "Fervendo água... (%d garrafa(s) restantes)" % n
	return "E — ferver água suja (%d garrafa(s))" % n if n > 0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _fervendo or texto_interacao() == "":
		return
	get_viewport().set_input_as_handled()
	_fervendo = true
	_t_ferver = 0.0
	_jogador().aviso("Você pôs a água para ferver. Fique perto: o fogo e a panela fazem barulho.")


func _physics_process(delta: float) -> void:
	if not _fervendo:
		return
	var j := _jogador()
	if not _perto() or j.inventario.contar("agua_suja") <= 0:
		_fervendo = false
		if j != null and not _perto():
			j.aviso("Você se afastou da fogueira e a fervura parou.")
		return
	j.ruido_piso = maxf(j.ruido_piso, RUIDO_FERVENDO)
	_t_ferver += delta
	if _t_ferver < TEMPO_FERVER:
		return
	_t_ferver = 0.0
	j.inventario.remover("agua_suja", 1)
	get_tree().call_group("primeiros_passos", "evento", "ferveu")
	if j.inventario.adicionar_parcial("agua_limpa", 1) > 0:
		j.largar_item("agua_limpa", 1)
	if j.inventario.contar("agua_suja") <= 0:
		_fervendo = false
		j.aviso("A água ferveu: agora é água limpa.")


func _process(delta: float) -> void:
	_t += delta
	if duracao_s >= 0.0:
		duracao_s -= delta
		if duracao_s <= 0.0:
			queue_free()
			return
	_luz.energy = 1.15 + 0.22 * sin(_t * 17.0) + 0.1 * sin(_t * 41.0)
	queue_redraw()


func _draw() -> void:
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector2.from_angle(a) * Vector2(20.0, 10.0)
		draw_circle(p, 4.5, Color(0.36, 0.35, 0.33))
	draw_line(Vector2(-14, -2), Vector2(12, 4), Color(0.25, 0.16, 0.09), 4.0)
	draw_line(Vector2(-12, 4), Vector2(14, -3), Color(0.30, 0.19, 0.10), 4.0)
	# a fogueira do jogador vai baixando nos últimos 30 s antes de apagar
	var f := (1.0 + 0.25 * sin(_t * 13.0)) * (clampf(duracao_s / 30.0, 0.3, 1.0) if duracao_s >= 0.0 else 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(0, -34 * f), Vector2(11, 0)]), Color(0.95, 0.40, 0.08, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(2, -26 * f), Vector2(8, 0)]), Color(1.0, 0.72, 0.15, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(0, -16 * f), Vector2(4, 0)]), Color(1.0, 0.95, 0.6, 0.95))
