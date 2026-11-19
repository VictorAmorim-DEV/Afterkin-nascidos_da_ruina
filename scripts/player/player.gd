extends CharacterBody2D
## Jogador — movimentação, posturas, fôlego, mira e lanterna migrados do protótipo V13.
##
## As teclas indicam a direção NA TELA; a velocidade é calculada em unidades de mundo
## (como no protótipo) e depois projetada em isométrico 2:1.
## O corpo vira para o cursor do mouse; andar contra a mira mostra a caminhada de ré
## e andar de lado em relação à mira mostra o passo lateral.

enum Postura { EM_PE, AGACHADO, DEITADO }

const DIRECOES: Array[String] = ["frente", "lado", "costas"]

@export_group("Velocidade (u/s)")
@export var walk_speed: float = 78.0
@export var run_speed: float = 128.0
@export var crouch_speed: float = 42.0
@export var prone_speed: float = 19.0
@export var aceleracao: float = 300.0    ## u/s² ao acelerar
@export var frenagem: float = 420.0      ## u/s² ao parar

@export_group("Fôlego")
@export var stamina_max: float = 100.0
@export var gasto_correr: float = 20.0   ## por segundo correndo
@export var gasto_pulo: float = 10.0     ## por pulo
@export var limite_exaustao: float = 30.0  ## fôlego para deixar de estar exausto

@export_group("Fome e sede (por hora de jogo)")
## Cheias, a fome zera em ~1,5 dia de jogo e a sede em ~0,75 dia (docs/DECISOES_DESIGN.md Q29).
@export var fome_por_hora: float = 2.78
@export var sede_por_hora: float = 5.56
@export var sede_no_calor: float = 0.5        ## +50% de sede no calor máximo (tarde)
@export var sede_correndo: float = 0.3        ## +30% de sede correndo
@export var folego_no_calor: float = 0.3      ## correr no calor máximo gasta +30% de fôlego

@export_group("Cansaço (por hora de jogo)")
## Descanso 100 = descansado. Acordado, zera em ~20 h de jogo (meio dia real); quanto mais cansado, menos o fôlego
## recarrega (TETOS_FOLEGO). Deitar e descansar na cama recupera aos poucos; dormir recupera tudo (6–7 h).
@export var cansaco_por_hora: float = 5.0
@export var cansaco_correndo: float = 0.6     ## +60% de cansaço correndo
@export var descanso_na_cama: float = 14.0    ## quanto volta por hora deitado descansando na cama

@export_group("Pulo")
@export var impulso_pulo: float = 260.0
@export var gravidade: float = 900.0

@export_group("Mira e lanterna")
@export var mirar_com_mouse: bool = true
@export var alcance_lanterna: float = 742.0   ## unidades de mundo (15 m no protótipo)
@export var energia_lanterna: float = 1.1
## Altura da mão que segura a lanterna, em px de tela (30 px ≈ 1 m).
@export var altura_mao_em_pe: float = 31.0
@export var altura_mao_agachado: float = 17.0
@export var altura_mao_deitado: float = 5.0
@export var avanco_mao: float = 9.0           ## quanto a mão fica à frente do corpo (px de tela)

var world_vel := Vector2.ZERO            ## velocidade em unidades de mundo
var postura: Postura = Postura.EM_PE
var stamina: float = 100.0
var exausto: bool = false
var correndo: bool = false
var face: float = PI / 2.0               ## direção do olhar, em radianos, no MUNDO
var pulo_z: float = 0.0                  ## altura do pulo (px de tela)
var pulo_v: float = 0.0
var lanterna_ligada: bool = true
var _anel_ruido := Node2D.new()
var ruido: float = 110.0                 ## barulho que o jogador faz (para os inimigos, fase de combate)

## --- sobrevivência e mochila (V13) ---
var vida_max: float = 100.0
var vida: float = 100.0
var fome: float = 100.0                  ## 100 = saciado; cai por hora de jogo e, em 0, tira vida
var sede: float = 100.0                  ## 100 = hidratado; cai mais rápido que a fome, mais no calor e correndo
var _carga: float = 0.0                  ## sobrecarga da mochila (0 a 1), revista a cada quadro
var incubacao_h: float = -1.0           ## horas de jogo até a disenteria aparecer (< 0 = nada incubando)
var ruido_piso: float = 0.0              ## barulho mínimo imposto de fora neste quadro (ex.: fervendo água)
var inventario: Inventario
var ataque_cd: float = 0.0               ## recarga do golpe (V13: player.attackCd)
var golpe_t: float = 0.0                 ## tempo restante da animação de golpe
var passos: Dictionary = {}               ## progresso dos PrimeirosPassos (contagem por evento, "_ativo", "noite")
var local_inicio: String = ""            ## onde estava quando tudo começou (Inicio)
var origem: String = ""                  ## policial, mecanico, enfermeiro ou mestre_obras (Origens)
var genero: String = "m"                 ## "m" ou "f": as falas dos NPCs se ajustam (Conversas.texto)
var _tiro_t: float = 0.0                 ## tempo restante do estampido do último tiro (barulho)
var morto: bool = false
var descanso: float = 100.0              ## 100 = descansado; cai acordado e limita o teto do fôlego
var descansando: Node2D = null           ## cama onde está deitado descansando (null = não está)
var dormindo: bool = false
var dirigindo: Node2D = null             ## veículo que está dirigindo (o jogador fica escondido)
var territorio: Territorio
var raca: String = "human"               ## human, rat, vampire ou zombie (V13: player.race)
var forma: String = "human"              ## só o rato alterna: "human" ou "rat" (V13: player.form)
var doenca: Dictionary = {}              ## vazio = saudável; {tipo, horas, total, estagio, origem}
var sol: float = 0.0                     ## exposição solar do vampiro, em segundos ao sol direto (acima de 60 queima)

var _passo: float = 0.0
var _inclinacao: float = 0.0
var _ciclo: Node = null
var _saltando: bool = false               ## no meio de um salto guiado (ex.: pulando uma janela)
var _altura_luz: float = 31.0
var _brilho_mao := Sprite2D.new()           ## brilho da lente da lanterna, na mão (aditivo, não depende da luz)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lanterna_chao: PointLight2D = $LanternaChao
@onready var lanterna_objetos: PointLight2D = $LanternaObjetos


func _ready() -> void:
	add_to_group("jogador")
	stamina = stamina_max
	var sombra := SombraSol.Personagem.new()          # sombra do sol (V13: sombraChar)
	sombra.fonte = sprite
	add_child(sombra)
	add_child(SombraSol.contato(34.0))                # sombra de contato no pé
	inventario = Inventario.new()
	inventario.name = "Inventario"
	inventario.jogador = self
	add_child(inventario)
	inventario.aviso.connect(aviso)
	territorio = Territorio.new()
	territorio.name = "Territorio"
	territorio.jogador = self
	add_child(territorio)
	var agua := Agua.new()                            # beber e encher garrafas em poças, rios e lagos
	agua.name = "Agua"
	add_child(agua)
	inventario.inicial()
	# anel de barulho no chão (V13 l.1650): raio = distância em que os inimigos ouvem
	_anel_ruido.z_index = -1
	_anel_ruido.draw.connect(_desenhar_anel_ruido)
	add_child(_anel_ruido)
	aplicar_sombras_lanterna(Controles.ler_cfg().get_value("video", "sombras_lanterna", true))
	_montar_brilho_mao()


func _process(_delta: float) -> void:
	_anel_ruido.queue_redraw()


func _desenhar_anel_ruido() -> void:
	if dirigindo != null:
		return
	var pts := PackedVector2Array()
	for k in 40:
		pts.append(IsoMath.mundo_para_tela(Vector2.from_angle(TAU * k / 40.0) * ruido_efetivo()))
	_anel_ruido.draw_colored_polygon(pts, Color(1, 1, 1, 0.03))
	pts.append(pts[0])
	_anel_ruido.draw_polyline(pts, Color(1, 1, 1, 0.15), 2.0)


## Brilho pequeno e quente na mão, onde fica a lanterna: mostra de onde sai o facho.
func _montar_brilho_mao() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.85, 1.0))
	g.set_color(1, Color(1.0, 0.9, 0.6, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	_brilho_mao.texture = t
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_brilho_mao.material = mat
	_brilho_mao.z_index = 1
	_brilho_mao.visible = false
	add_child(_brilho_mao)


## Sombras da luz da lanterna (opção de vídeo: desligar alivia PCs mais fracos).
func aplicar_sombras_lanterna(ligar: bool) -> void:
	lanterna_chao.shadow_enabled = ligar


## Até onde (u de mundo) o barulho chega agora: na noite fria e parada o som vai mais longe.
func ruido_efetivo() -> float:
	if Dev.invisivel:
		return 0.0
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	var k: float = _ciclo.propagacao_som() if _ciclo != null and _ciclo.has_method("propagacao_som") else 1.0
	return ruido * k


## De quantos u de mundo um inimigo acordado te enxerga: luz do dia, neblina, postura e lanterna.
func alcance_ser_visto() -> float:
	if Dev.invisivel:
		return 0.0
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	var m: float = _ciclo.alcance_visao_m() if _ciclo != null and _ciclo.has_method("alcance_visao_m") else 8.0
	if postura == Postura.AGACHADO:
		m *= 0.65
	elif postura == Postura.DEITADO:
		m *= 0.4
	if lanterna_chao.enabled:
		m = maxf(m, 16.0)                        # no escuro a lanterna te denuncia de longe
	if _ciclo != null and _ciclo.has_method("escuridao") and float(_ciclo.escuridao()) > 0.3 and Fogueira.acesa_perto(self):
		m = maxf(m, 14.0)                        # ao lado de uma fogueira no escuro, você aparece de longe
	return m * IsoMath.METRO


## Furtividade pelo barulho (V13: hudStealth).
func texto_furtividade() -> String:
	var r := ruido_efetivo()
	if r < 70.0:
		return "Quase invisível"
	if r < 130.0:
		return "Discreto"
	if r < 230.0:
		return "Visível"
	return "Barulhento"


func _unhandled_input(event: InputEvent) -> void:
	if dirigindo != null:
		return                                   # dirigindo: o veículo trata as teclas
	if descansando != null and (event.is_action_pressed("prone") or event.is_action_pressed("crouch")
			or event.is_action_pressed("jump") or event.is_action_pressed("interact")):
		levantar()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("crouch"):
		postura = Postura.EM_PE if postura == Postura.AGACHADO else Postura.AGACHADO
	elif event.is_action_pressed("prone"):
		postura = Postura.EM_PE if postura == Postura.DEITADO else Postura.DEITADO
	elif event.is_action_pressed("jump"):
		if postura != Postura.EM_PE:
			postura = Postura.EM_PE          # o pulo primeiro levanta o personagem
		elif pulo_z <= 0.0 and stamina >= gasto_pulo and not _saltando:
			pulo_v = impulso_pulo
			stamina -= gasto_pulo * (1.0 + _carga)
	elif event.is_action_pressed("attack"):
		atacar()
	elif event.is_action_pressed("transform"):
		transformar()
	elif event.is_action_pressed("flashlight"):
		lanterna_ligada = not lanterna_ligada


## Salto guiado até 'destino' (px globais), ignorando colisões no caminho.
## Usado pelas janelas abertas: o jogador não anda através delas, ele pula.
func saltar_para(destino: Vector2, tempo: float = 0.42) -> void:
	if _saltando:
		return
	_saltando = true
	postura = Postura.EM_PE
	world_vel = Vector2.ZERO
	velocity = Vector2.ZERO
	pulo_v = gravidade * tempo * 0.5          # sobe e desce exatamente durante o salto
	pulo_z = 0.01
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "global_position", destino, tempo)
	await t.finished
	_saltando = false


func _physics_process(delta: float) -> void:
	if dirigindo != null:
		global_position = dirigindo.global_position
		lanterna_chao.enabled = false
		lanterna_objetos.enabled = false
		_atualizar_vitais(delta)
		return
	# --- pulo (só visual, como no protótipo) ---
	if pulo_v != 0.0 or pulo_z > 0.0:
		pulo_z += pulo_v * delta
		pulo_v -= gravidade * delta
		if pulo_z <= 0.0:
			pulo_z = 0.0
			pulo_v = 0.0

	if _saltando:                             # o Tween move o corpo; aqui só a animação do pulo
		sprite.position.y = -pulo_z
		return

	# --- direção pedida pelas teclas (na tela) convertida para o mundo ---
	var tecla := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := IsoMath.tela_para_mundo(tecla)
	var movendo := dir.length_squared() > 0.0001
	if movendo:
		dir = dir.normalized()
	if descansando != null:
		if movendo:
			levantar()
		else:
			postura = Postura.DEITADO

	# --- mira: o corpo vira para o cursor ---
	var alvo_face := face
	var tem_mira := false
	if mirar_com_mouse:
		var ate_cursor := IsoMath.tela_para_mundo(get_global_mouse_position() - global_position)
		if ate_cursor.length() > 14.0:
			alvo_face = ate_cursor.angle()
			tem_mira = true
	elif movendo:
		alvo_face = dir.angle()
		tem_mira = true

	var olhar := Vector2.from_angle(face)
	var cos_a := dir.dot(olhar) if movendo else 0.0

	# --- correr: só para a frente da mira, em pé e com fôlego ---
	var quer_correr := Input.is_action_pressed("run") and movendo and cos_a > 0.05
	if quer_correr and not exausto and stamina > 8.0 and postura != Postura.EM_PE:
		postura = Postura.EM_PE
	correndo = quer_correr and not exausto and stamina > 0.0 and postura == Postura.EM_PE

	if tem_mira:
		var taxa := 14.0
		if postura == Postura.DEITADO:
			taxa = 5.0
		elif postura == Postura.AGACHADO:
			taxa = 9.0
		elif correndo:
			taxa = 7.0
		face += wrapf(alvo_face - face, -PI, PI) * minf(1.0, delta * taxa)
		face = wrapf(face, -PI, PI)
		olhar = Vector2.from_angle(face)

	# --- velocidade: andar de ré ou de lado é um pouco mais lento ---
	var fator := 0.88 + (0.12 if cos_a >= 0.0 else 0.16) * cos_a
	var alvo := Vector2.ZERO
	if movendo:
		alvo = dir * velocidade_atual() * fator
	world_vel = world_vel.move_toward(alvo, (aceleracao if movendo else frenagem) * delta)

	velocity = IsoMath.mundo_para_tela(world_vel)
	if Dev.voar:                                # modo desenvolvedor: atravessa tudo
		global_position += velocity * delta
	else:
		move_and_slide()
	# se bateu em algo, a velocidade real mudou: mantém a de mundo em sincronia
	world_vel = IsoMath.tela_para_mundo(velocity)
	var rapidez := world_vel.length()
	_passo += rapidez * delta * 0.09

	_atualizar_folego(delta, rapidez)
	_atualizar_ruido(delta, rapidez)
	_inclinacao += (clampf(world_vel.x / 128.0 * 0.12, -0.14, 0.14) - _inclinacao) * minf(1.0, delta * 8.0)
	_animar(olhar, rapidez)
	_atualizar_lanterna(olhar, delta)
	_atualizar_vitais(delta)


## Velocidade máxima do estado atual (u/s).
func velocidade_atual() -> float:
	var v := run_speed if correndo else walk_speed
	if Dev.voar:
		return run_speed * Dev.voar_vezes
	v *= sintoma(1)
	if postura == Postura.AGACHADO:
		v = crouch_speed
	elif postura == Postura.DEITADO:
		v = prone_speed
	if exausto:
		v *= 0.85
	v *= 1.0 - 0.5 * _carga                 # sobrecarga: até metade da velocidade com o dobro da capacidade
	var mundo := get_tree().get_first_node_in_group("mundo")
	if mundo != null:
		v *= float(mundo.call("fator_terreno", global_position))     # água rasa do rio atrapalha
	if raca == "zombie":
		v *= 0.85
	if forma_rato():
		v *= 1.25
	return v


func nome_postura() -> String:
	match postura:
		Postura.AGACHADO:
			return "Agachado"
		Postura.DEITADO:
			return "Deitado"
	return "Correndo" if correndo else "Em pé"


## Faixas de cansaço: [descanso mínimo, teto do fôlego, nome]. Abaixo de 15, esgotado: o fôlego só chega a 15%.
const TETOS_FOLEGO := [[70.0, 1.0, "Descansado"], [50.0, 0.8, "Cansado"], [30.0, 0.6, "Muito cansado"],
	[15.0, 0.4, "Exausto"], [0.0, 0.15, "Esgotado"]]


func _faixa_cansaco() -> Array:
	for f in TETOS_FOLEGO:
		if descanso >= float(f[0]):
			return f
	return TETOS_FOLEGO[-1]


## Até quanto o fôlego recarrega agora (fração do máximo), pelo cansaço.
func teto_folego() -> float:
	return float(_faixa_cansaco()[1])


func nome_cansaco() -> String:
	return str(_faixa_cansaco()[2])


func _atualizar_folego(delta: float, rapidez: float) -> void:
	if correndo:
		stamina = maxf(0.0, stamina - gasto_correr * (1.0 + folego_no_calor * _calor()) * (1.0 + _carga) * delta)
		if stamina <= 0.0:
			exausto = true
		return
	var regen := 8.0 if rapidez > 12.0 else 13.0     # andando / parado
	if postura == Postura.DEITADO:
		regen = 24.0
	elif postura == Postura.AGACHADO:
		regen = 18.0
	if exausto:
		regen *= 0.8
	regen *= sintoma(0)
	if sede < 20.0:
		regen *= 0.6                           # desidratado, o fôlego volta mais devagar
	var teto := stamina_max * teto_folego()
	if stamina > teto:
		stamina = maxf(teto, stamina - 6.0 * delta)   # mudou de faixa: o fôlego extra se esvai aos poucos
	else:
		stamina = minf(teto, stamina + regen * delta)
	if exausto and stamina >= minf(limite_exaustao, teto * 0.9):
		exausto = false


func _atualizar_ruido(delta: float, rapidez: float) -> void:
	var andando := rapidez > 12.0
	var alvo := 210.0 if andando else 110.0
	if postura == Postura.DEITADO:
		alvo = 50.0 if andando else 28.0
	elif postura == Postura.AGACHADO:
		alvo = 100.0 if andando else 55.0
	elif correndo and rapidez > 90.0:
		alvo = 340.0
	if pulo_z > 0.0:
		alvo = maxf(alvo, 260.0)
	if andando:
		alvo += 80.0 * _carga                  # a mochila pesada chacoalha
	alvo = maxf(alvo, ruido_piso)
	ruido_piso = 0.0
	ruido += (alvo - ruido) * minf(1.0, delta * 5.0)
	if _tiro_t > 0.0:
		ruido = maxf(ruido, RUIDO_TIRO)


func _animar(olhar: Vector2, rapidez: float) -> void:
	# direção do olhar na tela -> linha da folha (0 frente, 1 lado, 2 costas)
	var tela := Vector2(olhar.x - olhar.y, olhar.x + olhar.y)
	var linha_olhar := 1
	var flip_olhar := tela.x < 0.0
	if absf(tela.x) <= absf(tela.y):
		linha_olhar = 0 if tela.y > 0.0 else 2
		flip_olhar = false
	var linha := linha_olhar
	var flip := flip_olhar
	var reverso := false
	if rapidez > 10.0:
		var alinhamento := world_vel.dot(olhar) / rapidez
		if alinhamento < -0.35:
			reverso = true                     # andando de ré
		if absf(alinhamento) < 0.55:           # andando de lado em relação à mira
			var vel_tela := Vector2(world_vel.x - world_vel.y, world_vel.x + world_vel.y)
			if linha != 1:
				linha = 1
				flip = vel_tela.x < 0.0
			else:
				linha = 0 if vel_tela.y > 0.0 else 2
				flip = false

	var quadros := sprite.sprite_frames
	var anim := "andar_" + DIRECOES[linha]
	var quadro := 0
	if golpe_t > 0.0 and postura == Postura.EM_PE and quadros.has_animation("atacar_" + DIRECOES[linha_olhar]):
		anim = "atacar_" + DIRECOES[linha_olhar]
		flip = flip_olhar
	elif postura == Postura.DEITADO:
		anim = "deitado"
		flip = tela.x < 0.0
	elif postura == Postura.AGACHADO:
		anim = "agachar_" + DIRECOES[linha_olhar]
		flip = flip_olhar
	elif correndo and linha == 1 and not reverso and rapidez > walk_speed * 1.1 \
			and quadros.has_animation("correr"):
		anim = "correr"
		quadro = int(_passo * 1.2) % quadros.get_frame_count("correr")
	elif rapidez > 10.0:
		var total := quadros.get_frame_count(anim)
		quadro = int(_passo * 0.7) % total
		if reverso:
			quadro = total - 1 - quadro
	if not quadros.has_animation(anim):
		anim = "andar_frente"
		quadro = 0
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.frame = quadro
	sprite.flip_h = flip
	sprite.position.y = -pulo_z
	sprite.rotation = _inclinacao if postura == Postura.EM_PE else 0.0


func _atualizar_lanterna(olhar: Vector2, delta: float) -> void:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	var escuro := 1.0
	if _ciclo != null and _ciclo.has_method("escuridao"):
		escuro = _ciclo.escuridao()
	var ligada := lanterna_ligada and escuro > 0.03
	var energia := energia_lanterna * clampf(escuro * 1.8, 0.0, 1.0)

	# altura da mão conforme a postura (transição suave ao agachar/deitar)
	var altura_alvo := altura_mao_em_pe
	if postura == Postura.AGACHADO:
		altura_alvo = altura_mao_agachado
	elif postura == Postura.DEITADO:
		altura_alvo = altura_mao_deitado
	_altura_luz = lerpf(_altura_luz, altura_alvo, minf(1.0, delta * 10.0))
	var fator_altura := clampf(_altura_luz / altura_mao_em_pe, 0.0, 1.0)

	# o cone é definido no chão do mundo e projetado em isométrico:
	# o eixo X da textura aponta para onde o jogador olha
	var frente := IsoMath.mundo_para_tela(olhar)
	var lado := IsoMath.mundo_para_tela(Vector2(-olhar.y, olhar.x))
	var mao := frente.normalized() * avanco_mao

	# LUZ DO CHÃO (com sombras): parte do ponto do chão embaixo da mão. Quanto mais
	# baixa a lanterna, mais rasante o feixe: alcança menos e chega mais fraco ao chão.
	var k_chao := alcance_lanterna * lerpf(0.55, 1.0, fator_altura) / 256.0
	lanterna_chao.enabled = ligada
	lanterna_chao.energy = energia * lerpf(0.75, 1.0, fator_altura)
	lanterna_chao.height = _altura_luz
	# o facho só toca o chão um pouco à frente do corpo (não nasce no pé): ~0,5 m em pé, menos agachado
	var toque := IsoMath.mundo_para_tela(olhar * IsoMath.METRO * lerpf(0.15, 0.5, fator_altura))
	lanterna_chao.transform = Transform2D(frente * k_chao, lado * k_chao, mao + toque)

	# LUZ DOS OBJETOS EM PÉ (paredes, carros, árvores, personagens): sai da altura
	# da mão, então ilumina mais baixo quando o jogador agacha ou deita.
	var k_obj := alcance_lanterna / 256.0
	lanterna_objetos.enabled = ligada
	lanterna_objetos.energy = energia
	lanterna_objetos.height = _altura_luz
	lanterna_objetos.transform = Transform2D(frente * k_obj, lado * k_obj, mao + Vector2(0.0, -_altura_luz - pulo_z))
	# brilho da própria lanterna, na mão
	_brilho_mao.visible = ligada
	_brilho_mao.position = mao + Vector2(0.0, -_altura_luz - pulo_z)
	_brilho_mao.modulate.a = clampf(escuro * 1.6, 0.25, 1.0)


# =====================================================================
# SOBREVIVÊNCIA, XP E ITENS (portado da V13: eat, useMed, xpGain, step)
# =====================================================================
const INCUBACAO_MIN_H := 2.0             ## a água contaminada dá sintomas entre 2 e 5 horas de jogo depois
const INCUBACAO_MAX_H := 5.0


func _atualizar_incubacao(horas: float) -> void:
	if incubacao_h < 0.0:
		return
	incubacao_h -= horas
	if incubacao_h > 0.0:
		return
	incubacao_h = -1.0
	if doenca.is_empty():
		doenca = nova_disenteria()
		aviso("Cólicas fortes de repente. A água que você bebeu estava contaminada: disenteria.")


func _atualizar_vitais(delta: float) -> void:
	if Dev.sem_necessidades:
		fome = 100.0
		sede = 100.0
		descanso = 100.0
	if Dev.invencivel:
		vida = vida_max
	if Dev.folego_infinito:
		stamina = stamina_max
		exausto = false
	_carga = inventario.sobrecarga()
	ataque_cd = maxf(0.0, ataque_cd - delta)
	golpe_t = maxf(0.0, golpe_t - delta)
	_tiro_t = maxf(0.0, _tiro_t - delta)
	var horas := delta * _min_por_s() / 60.0
	_atualizar_incubacao(horas)
	if descansando != null:
		descanso = minf(100.0, descanso + horas * descanso_na_cama)
	else:
		descanso = maxf(0.0, descanso - horas * cansaco_por_hora * (1.0 + (cansaco_correndo if correndo else 0.0)))
	fome = maxf(0.0, fome - horas * fome_por_hora * sintoma(2))
	if fome <= 0.0:
		vida = maxf(0.0, vida - delta * 0.7)
	if raca != "vampire":                      # o vampiro vai trocar fome e sede por sangue (marco 4)
		var k := (1.0 + sede_no_calor * _calor()) * (1.0 + (sede_correndo if correndo else 0.0))
		sede = maxf(0.0, sede - horas * sede_por_hora * k * sintoma(4))
		if sede <= 0.0:
			vida = maxf(0.0, vida - delta * 1.0)
	_atualizar_sol(delta)
	_atualizar_doenca(delta)
	if vida <= 0.0 and not morto:
		_morrer()


## Mensagem curta na tela (toast do HUD).
func aviso(texto: String) -> void:
	get_tree().call_group("hud", "aviso", texto)


## Come uma comida: +35 de fome e +8 de vida. Devolve false se não pôde (nada a consumir é feito aqui).
func comer() -> bool:
	if inventario.contar("comida") <= 0:
		aviso("Você não tem comida.")
		return false
	fome = minf(100.0, fome + 35.0)
	vida = minf(vida_max, vida + 8.0)
	aviso("Você comeu e recuperou energia.")
	return true


## Calor de 0 a 1 (DiaNoite.calor): acelera a sede e o gasto de fôlego correndo.
func _calor() -> float:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	return float(_ciclo.calor()) if _ciclo != null and _ciclo.has_method("calor") else 0.0


## Bebe: +'qtd' de sede. 'chance_doenca' é a chance de pegar disenteria (água suja ou parada).
## 'extra' vai no fim do aviso. Devolve false se não estava com sede (nada é consumido).
func beber(qtd: float, chance_doenca: float, de_onde: String, extra: String = "") -> bool:
	if raca == "vampire":
		aviso("A água não mata mais a sua sede.")
		return false
	if sede >= 98.0:
		aviso("Você não está com sede.")
		return false
	sede = minf(100.0, sede + qtd)
	# contaminada: ninguém percebe na hora; a disenteria aparece horas depois (incubação), e o aviso é o sintoma
	if chance_doenca > 0.0 and doenca.is_empty() and incubacao_h < 0.0 and randf() < chance_doenca:
		incubacao_h = randf_range(INCUBACAO_MIN_H, INCUBACAO_MAX_H)
	aviso("Você bebeu %s.%s" % [de_onde, extra])
	get_tree().call_group("primeiros_passos", "evento", "bebeu")
	return true


## Bebe uma garrafa da mochila ("agua_limpa" ou "agua_suja") e guarda a garrafa vazia.
func beber_garrafa(id: String) -> void:
	var suja := id == "agua_suja"
	if not beber(60.0, Agua.CHANCE_GARRAFA_SUJA if suja else 0.0, "água suja" if suja else "água limpa"):
		return
	inventario.remover(id, 1)
	if inventario.adicionar_parcial("garrafa", 1) > 0:
		largar_item("garrafa", 1)


## Larga 'qtd' de 'id' no chão à frente do jogador (quando não cabe na mochila).
func largar_item(id: String, qtd: int) -> void:
	var frente := Vector2.from_angle(face) * (0.9 * IsoMath.METRO)
	ItemNoChao.largar(get_parent(), global_position + IsoMath.mundo_para_tela(frente), id, qtd)


## Acende uma fogueira à frente do jogador (receita "fogueira"). Ela apaga sozinha depois de algumas horas.
func acender_fogueira() -> void:
	if dirigindo != null:
		return
	inventario.remover("fogueira", 1)
	var f := Fogueira.new()
	f.duracao_s = Fogueira.DURACAO_ACESA
	var frente := Vector2.from_angle(face) * (0.8 * IsoMath.METRO)
	f.position = global_position + IsoMath.mundo_para_tela(frente)
	get_parent().add_child(f)
	aviso("Você acendeu uma fogueira. Ela faz luz e chama atenção.")
	get_tree().call_group("primeiros_passos", "evento", "acendeu")


## Larga 'qtd' (0 = tudo) do slot no chão, à frente do jogador.
func largar_slot(i: int, qtd: int = 0) -> void:
	var r := inventario.retirar(i, qtd)
	if r.is_empty():
		return
	var frente := Vector2.from_angle(face) * (0.9 * IsoMath.METRO)
	var pos := global_position + IsoMath.mundo_para_tela(frente)
	ItemNoChao.largar(get_parent(), pos, r.id, r.quantidade, r.extra)
	aviso("Você largou %d %s." % [r.quantidade, Itens.nome(r.id).to_lower()])


# =====================================================================
# COMBATE E COLETA (portado da V13: attack, harvestHit, nearestEnemy)
# =====================================================================
## Multiplicador de dano da mão/ferramenta equipada. A V13 não distingue (todos 1,0);
## aqui o machado e a picareta batem um pouco mais forte.
const BONUS_ARMA := {"machado": 1.35, "picareta": 1.2}


func _inimigo_perto() -> Inimigo:
	var melhor: Inimigo = null
	var dist := 55.0
	var olhar := Vector2.from_angle(face)
	for e in get_tree().get_nodes_in_group("inimigo"):
		var v: Vector2 = IsoMath.tela_para_mundo(e.global_position - global_position)
		var d := v.length()
		if d < dist and v.dot(olhar) > -8.0:
			dist = d
			melhor = e
	return melhor


## Morador ao alcance do golpe, à frente (só quando não há inimigo).
func _npc_perto() -> Npc:
	var melhor: Npc = null
	var dist := 55.0
	var olhar := Vector2.from_angle(face)
	for n in get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.morto or npc.dormindo:
			continue
		var v: Vector2 = IsoMath.tela_para_mundo(npc.global_position - global_position)
		if v.length() < dist and v.dot(olhar) > -8.0:
			dist = v.length()
			melhor = npc
	return melhor


var _confirma_npc: Npc = null              ## morador que o próximo clique (em 2 s) vai mesmo atacar
var _confirma_t := 0.0


## Atacar um morador pede um segundo clique: o primeiro só avisa (evita golpe sem querer numa conversa).
func _confirmar_ataque(npc: Npc) -> bool:
	var agora := Time.get_ticks_msec() / 1000.0
	if _confirma_npc == npc and agora - _confirma_t < 2.0:
		return true
	_confirma_npc = npc
	_confirma_t = agora
	aviso("Atacar %s? Clique de novo para confirmar." % npc.nome())
	ataque_cd = 0.25
	return false


func _golpear_npc(npc: Npc) -> void:
	if not _confirmar_ataque(npc):
		return
	var dano: float = 16.0 * 1.1 * BONUS_ARMA.get(inventario.id_equipado(), 1.0)
	ataque_cd = 0.6
	golpe_t = 0.2
	aviso("Você acertou %s." % npc.nome())
	npc.receber_dano(dano)


func atacar() -> void:
	if ataque_cd > 0.0 or morto or _saltando:
		return
	if inventario.id_equipado() == "pistola":
		_atirar()
		return
	postura = Postura.EM_PE if postura == Postura.AGACHADO else postura
	var alvo := _inimigo_perto()
	if alvo == null:
		var npc := _npc_perto()
		if npc != null:
			_golpear_npc(npc)
			return
		var melhor: Coletavel = null
		var dist := INF
		for c in get_tree().get_nodes_in_group("coletavel"):
			if c.esta_ao_alcance(global_position) and c.distancia(global_position) < dist:
				dist = c.distancia(global_position)
				melhor = c
		if melhor != null:
			ataque_cd = 0.5
			if melhor.golpear(self):
				golpe_t = 0.2
			else:
				ataque_cd = 0.35
			return
		aviso("Nada ao alcance.")
		ataque_cd = 0.35
		return
	var dano: float = 16.0 if raca == "human" else (23.0 if raca == "zombie" else (19.0 if forma_rato() else 18.0))
	if raca == "human":
		dano *= 1.1
	if raca == "vampire" and _eh_noite():
		dano *= 1.3
	if forma_rato():
		dano *= 1.3
	dano *= BONUS_ARMA.get(inventario.id_equipado(), 1.0)
	ataque_cd = 0.42 if forma_rato() else 0.6
	golpe_t = 0.2
	aviso("Você acertou um %s (%d de dano)." % [Inimigo.NOMES[alvo.raca], roundi(dano)])
	alvo.receber_dano(dano)
	if not alvo.morto and alvo.raca != "zombie" and randf() < 0.18:
		infectar(alvo.raca)


# =====================================================================
# PISTOLA MÍNIMA (provisória, marco 1: testar o custo do barulho; docs/DECISOES_DESIGN.md)
# =====================================================================
const ALCANCE_TIRO_M := 12.0
const DANO_TIRO := 30.0                  ## de perto; cai até 60% disso no alcance máximo
const ANGULO_TIRO := 7.0                 ## graus de tolerância da mira
const RUIDO_TIRO := 900.0                ## u de mundo (~18 m de dia, mais à noite)


func _atirar() -> void:
	if inventario.contar("municao") <= 0:
		aviso("Clique. Sem munição.")
		ataque_cd = 0.4
		return
	inventario.remover("municao", 1)
	ataque_cd = 0.55
	golpe_t = 0.15
	_tiro_t = 0.35
	var alcance := ALCANCE_TIRO_M * IsoMath.METRO
	var alvo := _alvo_da_mira(alcance)
	var npc_mira := _npc_na_mira(alcance) if alvo == null else null
	if npc_mira != null and not _confirmar_ataque(npc_mira):
		inventario.adicionar_parcial("municao", 1)   # não atirou: devolve a bala
		return
	var olhar := Vector2.from_angle(face)
	var dist := alcance
	var mirado: Node2D = alvo if alvo != null else npc_mira
	if mirado != null:
		var v: Vector2 = IsoMath.tela_para_mundo(mirado.global_position - global_position)
		dist = v.length()
		olhar = v / maxf(dist, 0.001)
	else:
		var ate := IsoMath.tela_para_mundo(get_global_mouse_position() - global_position)
		if ate.length() > 1.0:
			olhar = ate.normalized()
	face = olhar.angle()                       # o corpo vira na hora para onde atirou
	_rastro_tiro(olhar * dist)
	var balas: int = inventario.contar("municao")
	if npc_mira != null:
		var dano_n := DANO_TIRO * lerpf(1.0, 0.6, dist / alcance)
		npc_mira.receber_dano(dano_n)
		aviso("Tiro! Acertou %s. (%d bala(s))" % [npc_mira.nome(), balas])
		return
	if alvo == null:
		aviso("Tiro! Errou. O estampido ecoa pela rua. (%d bala(s))" % balas)
		return
	var dano := DANO_TIRO * lerpf(1.0, 0.6, dist / alcance)
	alvo.receber_dano(dano)
	aviso("Tiro! Acertou um %s (%d de dano). (%d bala(s))" % [Inimigo.NOMES[alvo.raca], roundi(dano), balas])


## Morador sob o cursor, ao alcance do tiro (null se nenhum).
func _npc_na_mira(alcance: float) -> Npc:
	var mouse := get_global_mouse_position()
	for n in get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.morto or npc.dormindo:
			continue
		var d_mundo: float = IsoMath.tela_para_mundo(npc.global_position - global_position).length()
		if d_mundo < alcance and (npc.global_position + Vector2(0.0, -28.0)).distance_to(mouse) < 30.0:
			return npc
	return null


## Inimigo que o tiro acerta: primeiro o que está sob o cursor (o corpo fica ~28 px acima do pé, na tela);
## senão, o mais próximo na direção do cursor, dentro de ANGULO_TIRO. null se nenhum ao alcance.
func _alvo_da_mira(alcance: float) -> Inimigo:
	var mouse := get_global_mouse_position()
	var alvo: Inimigo = null
	var melhor := INF
	for e in get_tree().get_nodes_in_group("inimigo"):
		var d_mundo: float = IsoMath.tela_para_mundo(e.global_position - global_position).length()
		var d_tela: float = (e.global_position + Vector2(0.0, -28.0)).distance_to(mouse)
		if d_mundo < alcance and d_tela < 30.0 and d_tela < melhor:
			melhor = d_tela
			alvo = e
	if alvo != null:
		return alvo
	var ate := IsoMath.tela_para_mundo(mouse - global_position)
	var olhar := ate.normalized() if ate.length() > 1.0 else Vector2.from_angle(face)
	var dist := alcance
	for e in get_tree().get_nodes_in_group("inimigo"):
		var v: Vector2 = IsoMath.tela_para_mundo(e.global_position - global_position)
		var d := v.length()
		if d > 1.0 and d < dist and v.normalized().dot(olhar) > cos(deg_to_rad(ANGULO_TIRO)):
			dist = d
			alvo = e
	return alvo


## Risco de luz do disparo, da mão até onde a bala parou (some em 0,12 s).
func _rastro_tiro(desloc_mundo: Vector2) -> void:
	var l := Line2D.new()
	l.width = 1.5
	l.default_color = Color(1.0, 0.92, 0.6, 0.9)
	l.z_index = 5
	var mao := Vector2(0.0, -_altura_luz)
	l.points = PackedVector2Array([mao, mao + IsoMath.mundo_para_tela(desloc_mundo)])
	l.position = global_position
	get_parent().add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "modulate:a", 0.0, 0.12)
	t.tween_callback(l.queue_free)


## Bandagem: +15 de vida.
func usar_bandagem() -> void:
	if vida >= vida_max:
		aviso("Você não está ferido.")
		return
	inventario.remover("bandagem", 1)
	vida = minf(vida_max, vida + 15.0)
	aviso("Você fez um curativo (+15 de vida).")


## Bilhete do começo da partida: um rumor genérico (os rumores de verdade vêm com os NPCs, no marco 2) que aponta
## a água doce mais próxima. Aparece alguns segundos depois do aviso de boas-vindas.
func ler_bilhete_inicial() -> void:
	await get_tree().create_timer(4.5).timeout
	var a := Agua.mais_perto(IsoMath.tela_para_mundo(global_position))
	if a.is_empty():
		aviso("Bilhete no bolso: \"Não tem água por perto. Guarde a garrafa.\"")
		return
	var onde := "uma poça d'água" if a["tipo"] == "poca" else "um rio"
	aviso("Bilhete no bolso: \"Tem %s a uns %d m para o %s. Ferva antes de beber.\"" % [onde,
		roundi(float(a["m"]) / 10.0) * 10, a["rumo"]])


## Progresso dos primeiros passos vindo do save (o JSON devolve números como float).
func passo_restaurar(d: Dictionary) -> void:
	passos = {}
	for k in d:
		var v: Variant = d[k]
		passos[k] = int(v) if v is float else v


## Origem do personagem (Origens): guarda e entrega o kit. Só no começo da partida.
func definir_origem(o: String) -> void:
	origem = o
	var sobra: Array = []
	for k in Origens.kit(o):
		var resto := inventario.adicionar_parcial(k[0], k[1])
		if resto > 0:
			sobra.append([k[0], resto])
	for k in sobra:
		largar_item(k[0], k[1])


func receber_dano(n: float, quem: String = "") -> void:
	if morto or Dev.invencivel:
		return
	if raca == "zombie" and quem == "rat":
		return                                   # zumbi não sente a mordida do rato (V13)
	vida = maxf(0.0, vida - n)
	sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)


## Morte do humano (Q7, Q51): a mochila fica no corpo e, depois de alguns segundos, abre a TelaRespawn (cama ou
## lugar de início). O mundo continua como está. A morte infectada (acordar transformado) é do marco 3.
func _morrer() -> void:
	if dirigindo != null and dirigindo.has_method("sair"):
		dirigindo.sair()
	morto = true
	world_vel = Vector2.ZERO
	velocity = Vector2.ZERO
	Respawn.largar_mochila(self)
	aviso("Você morreu. O mundo continua sem você.")
	set_physics_process(false)
	sprite.animation = &"caido"
	sprite.frame = 0
	await get_tree().create_timer(3.0).timeout
	get_tree().current_scene.add_child(TelaRespawn.new())


## Volta à vida depois da TelaRespawn (quem escolhe o lugar e teleporta é o Respawn). Acorda com a vida cheia,
## com alguma fome e sede, sem doença e sem nada na mochila.
func renascer() -> void:
	morto = false
	vida_max = vida_max_atual()
	vida = vida_max
	fome = 70.0
	sede = 70.0
	descanso = 80.0
	descansando = null
	stamina = stamina_max
	exausto = false
	incubacao_h = -1.0
	sol = 0.0
	doenca = {}
	visible = true
	set_physics_process(true)


# =====================================================================
# DESCANSO E SONO NA CAMA (pedido do Victor, 18/11/2026)
# =====================================================================
const PERIGO_SONO := 14.0 * IsoMath.METRO     ## inimigo acordado mais perto que isso: não dá para dormir nem descansar


## Algum inimigo acordado (ou em alerta) por perto? Os que dormem na casa ao lado não contam.
func _perigo_perto() -> bool:
	for i in get_tree().get_nodes_in_group("inimigo"):
		var e := i as Inimigo
		if e == null or e.morto or (e.dorme and e.alerta <= 0.0):
			continue
		if IsoMath.tela_para_mundo(e.global_position - global_position).length() < PERIGO_SONO:
			return true
	return false


## Deita na cama e descansa: o tempo corre normal e o descanso volta aos poucos. Mexer-se (ou E) levanta.
func descansar_na_cama(cama: Node2D) -> void:
	if _perigo_perto():
		aviso("Não dá para relaxar com perigo por perto.")
		return
	descansando = cama
	postura = Postura.DEITADO
	world_vel = Vector2.ZERO
	global_position = cama.global_position
	aviso("Você se deita para descansar. Mexa-se para levantar.")


func levantar() -> void:
	if descansando == null:
		return
	descansando = null
	postura = Postura.EM_PE
	aviso("Você se levanta (%s)." % nome_cansaco().to_lower())


## Deita e dorme 6–7 h de jogo: a tela escurece, o relógio avança e o descanso volta a 100%. Fome e sede caem no
## ritmo do sono (60%); doenças e incubação seguem correndo, mas nada se resolve enquanto você dorme.
func dormir_na_cama(cama: Node2D) -> void:
	if dormindo:
		return
	if _perigo_perto():
		aviso("Impossível dormir com perigo por perto.")
		return
	if descanso >= 90.0:
		aviso("Você não está com sono.")
		return
	descansando = null
	dormindo = true
	postura = Postura.DEITADO
	world_vel = Vector2.ZERO
	global_position = cama.global_position
	var horas := randf_range(6.0, 7.0)
	var arvore := get_tree()
	var capa := CanvasLayer.new()
	capa.layer = 40
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	var preto := ColorRect.new()
	preto.color = Color(0, 0, 0, 0)
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(preto)
	var texto := Label.new()
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 22)
	texto.modulate = Color(1, 1, 1, 0)
	capa.add_child(texto)
	arvore.current_scene.add_child(capa)
	arvore.paused = true
	var t := capa.create_tween()
	t.tween_property(preto, "color:a", 1.0, 1.2)
	await t.finished
	_passar_horas_dormindo(horas)
	texto.text = "Você dormiu %d h %02d min." % [int(horas), int(fmod(horas, 1.0) * 60.0)]
	var t2 := capa.create_tween()
	t2.tween_property(texto, "modulate:a", 1.0, 0.5)
	t2.tween_interval(1.4)
	t2.tween_property(preto, "color:a", 0.0, 1.0)
	t2.parallel().tween_property(texto, "modulate:a", 0.0, 0.8)
	await t2.finished
	capa.queue_free()
	arvore.paused = false
	dormindo = false
	postura = Postura.EM_PE
	var ciclo := arvore.get_first_node_in_group("ciclo_dia_noite")
	aviso("Você acorda descansado. %s" % (ciclo.texto_relogio() if ciclo != null else ""))


func _passar_horas_dormindo(horas: float) -> void:
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	if ciclo != null:
		ciclo.minutos += horas * 60.0
		while ciclo.minutos >= 1440.0:
			ciclo.minutos -= 1440.0
			ciclo.dia += 1
	descanso = 100.0
	stamina = stamina_max
	exausto = false
	fome = maxf(0.0, fome - horas * fome_por_hora * 0.6)
	if raca != "vampire":
		sede = maxf(0.0, sede - horas * sede_por_hora * 0.6)
	if incubacao_h >= 0.0:
		incubacao_h = maxf(0.05, incubacao_h - horas)   # a disenteria aparece logo depois de acordar
	if not doenca.is_empty():
		doenca.horas = maxf(0.05, float(doenca.horas) - horas)
		doenca.estagio = _estagio_doenca(float(doenca.get("total", 48.0)))


# =====================================================================
# RAÇAS, SOL DO VAMPIRO E DOENÇAS (V13: start, transform, maxLife, infectPlayer, useMed, step)
# =====================================================================
const NOMES_RACA := {"human": "Humano", "rat": "Rato", "vampire": "Vampiro", "zombie": "Zumbi"}


func forma_rato() -> bool:
	return raca == "rat" and forma == "rat"


func vida_max_atual() -> float:
	return 60.0 if forma_rato() else 100.0


## Escolhe a raça. 'reiniciar' = começo de partida (zera vida, fome, doença e mochila).
func definir_raca(r: String, reiniciar: bool = true) -> void:
	raca = r
	forma = "rat" if r == "rat" else "human"
	vida_max = vida_max_atual()
	if reiniciar:
		vida = vida_max
		fome = 100.0
		sede = 100.0
		passos = {}
		incubacao_h = -1.0
		sol = 0.0
		doenca = {}
		inventario.inicial()
	else:
		vida = minf(vida, vida_max)
	_aplicar_frames()


func _aplicar_frames() -> void:
	var nome := "humano"
	match raca:
		"rat":
			nome = "rato_gigante" if forma_rato() else "homem_rato"
		"vampire":
			nome = "vampiro"
		"zombie":
			nome = "zumbi"
	sprite.sprite_frames = load("res://resources/sprite_frames/%s.tres" % nome)


func transformar() -> void:
	if raca != "rat":
		aviso("Apenas ratos alternam entre forma humana e rato.")
		return
	forma = "human" if forma == "rat" else "rat"
	vida_max = vida_max_atual()
	vida = minf(vida, vida_max)
	_aplicar_frames()
	aviso("Você assumiu a forma de %s." % ("rato" if forma_rato() else "humano"))


func _eh_noite() -> bool:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	return _ciclo != null and _ciclo.eh_noite()


## Quanto tempo de jogo passa por segundo real (minutos), para as doenças acompanharem o relógio.
func _min_por_s() -> float:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	if _ciclo == null:
		return 0.6
	return 0.0 if _ciclo.pausado else _ciclo.minutos_por_segundo


func _dentro_de_casa() -> bool:
	for e in get_tree().get_nodes_in_group("edificio"):
		if e.jogador_dentro():
			return true
	return false


## Vampiro de dia, a céu aberto. Protegem: o alcance do totem (V13) e, por decisão desta
## versão, estar dentro de uma casa.
func exposto_ao_sol() -> bool:
	return _sente_sol() and not _eh_noite() and not _dentro_de_casa() and not territorio.protege(global_position)


## Vampiro, ou humano com a mutação vampírica do estágio 2 em diante (já sente o sol, pela metade).
func _sente_sol() -> bool:
	return raca == "vampire" or (doenca.get("tipo", "") == "Mutação vampírica" and int(doenca.estagio) >= 2)


func _atualizar_sol(delta: float) -> void:
	if _sente_sol() and not _eh_noite():
		var k := 1.0 if raca == "vampire" else 0.5
		if exposto_ao_sol():
			sol += delta * k                     # em segundos reais: não depende da velocidade do relógio
			if sol > 60.0:
				vida = maxf(0.0, vida - delta * 3.0 * k)
		else:
			sol = maxf(0.0, sol - delta * 0.2)
	elif _eh_noite():
		sol = maxf(0.0, sol - delta)


## Mordida/golpe de inimigo (V13: infectPlayer). Cada origem causa uma doença diferente.
func infectar(origem: String) -> void:
	if Dev.invencivel:
		return
	if raca == "zombie" and origem == "rat":
		return
	if raca == origem and origem != "rat":
		return                                   # já é dessa raça: a mutação não faria nada
	var chance := 0.4 if origem == "rat" else (0.45 if origem == "vampire" else 0.5)
	if raca == "human":
		chance += 0.1
	if randf() >= chance:
		return
	match origem:
		"rat":
			doenca = {"tipo": "Leptospirose", "horas": 48.0, "total": 48.0, "estagio": 0.0, "origem": "rat"}
			aviso("Mordida contaminada! Leptospirose contraída. Procure antibióticos.")
		"vampire":
			doenca = {"tipo": "Mutação vampírica", "horas": 24.0, "total": 24.0, "estagio": 0.0, "origem": "vampire"}
			aviso("Você foi mordido. A mutação começou: encontre um antídoto em ninhos de morcegos.")
		_:
			doenca = {"tipo": "Infecção zumbi", "horas": 24.0, "total": 24.0, "estagio": 0.0, "origem": "zombie"}
			aviso("Infecção zumbi contraída. A transformação ou morte pode ocorrer em 24h.")


## Sintomas por estágio (RECURSO NOVO: a V13 só conta o estágio). Por doença, cinco fatores por estágio 0–3:
## [recuperação do fôlego ×, velocidade ×, fome ×, vida perdida por segundo, sede ×].
const SINTOMAS := {
	"Leptospirose": [[1.0, 1.0, 1.0, 0.0, 1.0], [0.8, 1.0, 1.0, 0.0, 1.1], [0.6, 0.92, 1.2, 0.0, 1.2],
		[0.45, 0.85, 1.3, 0.12, 1.3]],
	"Mutação vampírica": [[1.0, 1.0, 1.0, 0.0, 1.0], [1.0, 1.0, 1.3, 0.0, 1.0], [0.85, 1.0, 1.6, 0.0, 1.0],
		[0.75, 1.0, 2.0, 0.05, 1.0]],
	"Infecção zumbi": [[1.0, 1.0, 1.0, 0.0, 1.0], [0.9, 0.95, 1.2, 0.0, 1.0], [0.75, 0.9, 1.5, 0.0, 1.0],
		[0.6, 0.85, 1.8, 0.1, 1.0]],
	# disenteria: estágio 2 é o platô longo (sede ×2, fôlego −20%), sem perder vida; o 3 não é usado
	"Disenteria": [[1.0, 1.0, 1.0, 0.0, 1.0], [0.9, 1.0, 1.0, 0.0, 1.6], [0.8, 0.95, 1.1, 0.0, 2.0],
		[0.7, 0.9, 1.2, 0.05, 2.5]],
}
const AVISOS_ESTAGIO := {
	"Leptospirose": ["", "Febre e dores: o fôlego volta mais devagar.", "Febre alta: você está mais lento.",
		"Estado grave: a leptospirose está consumindo sua vida."],
	"Mutação vampírica": ["", "Fome estranha: você precisa comer mais.", "A luz do sol começa a queimar sua pele.",
		"A mutação está quase completa. Encontre um antídoto!"],
	"Infecção zumbi": ["", "Pele fria e passos pesados.", "Músculos rígidos: você está mais lento e faminto.",
		"A infecção está tomando seu corpo."],
	"Disenteria": ["", "Cólicas: você está perdendo líquido e a sede aumenta.",
		"Diarreia forte: a sede dobrou e você está mais fraco. Vai demorar a passar; um antibiótico cura.", ""],
}


## Fator do sintoma 'i' (0 fôlego, 1 velocidade, 2 fome, 3 vida/s, 4 sede) no estágio atual; 1 (ou 0) sem doença.
func sintoma(i: int) -> float:
	if doenca.is_empty() or not SINTOMAS.has(doenca.tipo):
		return 0.0 if i == 3 else 1.0
	var t: Array = SINTOMAS[doenca.tipo][clampi(int(doenca.estagio), 0, 3)]
	return t[i]


## Disenteria nova: 36 h de jogo (~1 h real). Fase aguda curta (pico em 3 h) e efeito prolongado até o fim do prazo
## ou até um antibiótico (pedido do playtest de 18/11/2026).
func nova_disenteria() -> Dictionary:
	return {"tipo": "Disenteria", "horas": 36.0, "total": 36.0, "estagio": 0.0, "origem": "agua"}


## Estágio da doença agora. As outras seguem 4 quartos do prazo (o último é o 3); a disenteria sobe rápido
## (1 h → estágio 1, 3 h → estágio 2) e fica no platô do estágio 2 até passar.
func _estagio_doenca(total: float) -> float:
	var passou: float = total - float(doenca.horas)
	if doenca.tipo == "Disenteria":
		return 0.0 if passou < 1.0 else (1.0 if passou < 3.0 else 2.0)
	return clampf(passou / total * 4.0, 0.0, 3.0)


func _atualizar_doenca(delta: float) -> void:
	if doenca.is_empty():
		return
	# a V13 tira 24 "horas" por segundo real (esgota em 2 s); aqui a doença corre com o relógio do jogo
	doenca.horas -= delta * _min_por_s() / 60.0
	var total: float = doenca.get("total", 48.0)
	var antes := int(doenca.estagio)
	doenca.estagio = _estagio_doenca(total)
	if int(doenca.estagio) > antes:
		var msg: String = (AVISOS_ESTAGIO.get(doenca.tipo, ["", "", "", ""]) as Array)[int(doenca.estagio)]
		if msg != "":
			aviso(msg)
	vida = maxf(0.0, vida - sintoma(3) * delta)
	if doenca.horas > 0.0:
		return
	if doenca.tipo == "Disenteria":
		aviso("A disenteria passou. Beba água limpa.")
	elif doenca.tipo == "Leptospirose":
		if randf() < 0.7:
			vida = 0.0
			aviso("A leptospirose foi fatal.")
		else:
			aviso("Seu organismo resistiu à leptospirose.")
	elif randf() < 0.5:
		var nova: String = doenca.origem
		doenca = {}
		definir_raca(nova, false)
		aviso("A mutação completou: você agora é %s." % NOMES_RACA[nova])
	else:
		vida = 0.0
		aviso("A infecção foi fatal.")
	doenca = {}


func texto_doenca() -> String:
	if doenca.is_empty():
		return "Saudável"
	var txt: String = doenca.tipo
	if origem == "enfermeiro":                 # diagnóstico: só a Enfermeiro(a) sabe o estágio e o prazo
		txt += " · estágio %d · %dh restantes" % [int(doenca.estagio), maxi(0, ceili(doenca.horas))]
	var sintomas: PackedStringArray = []
	if sintoma(0) < 1.0:
		sintomas.append("fôlego −%d%%" % roundi((1.0 - sintoma(0)) * 100.0))
	if sintoma(1) < 1.0:
		sintomas.append("velocidade −%d%%" % roundi((1.0 - sintoma(1)) * 100.0))
	if sintoma(2) > 1.0:
		sintomas.append("fome +%d%%" % roundi((sintoma(2) - 1.0) * 100.0))
	if sintoma(4) > 1.0:
		sintomas.append("sede +%d%%" % roundi((sintoma(4) - 1.0) * 100.0))
	if sintoma(3) > 0.0:
		sintomas.append("perdendo vida")
	if _sente_sol() and raca != "vampire":
		sintomas.append("o sol queima")
	if not sintomas.is_empty():
		txt += " · " + ", ".join(sintomas)
	return txt


## Antibiótico (V13: useMed): sem doença não é gasto. Leptospirose pede 2 para curar; 1 só alivia.
func usar_antibiotico() -> void:
	if doenca.is_empty():
		aviso("Você não possui uma doença ativa.")
		return
	if inventario.contar("antibiotico") <= 0:
		aviso("Você não tem antibióticos ou antídoto.")
		return
	inventario.remover("antibiotico", 1)
	if doenca.tipo == "Leptospirose":
		if inventario.contar("antibiotico") > 0:
			inventario.remover("antibiotico", 1)
			doenca = {}
			aviso("Dois antibióticos eliminaram a leptospirose.")
		else:
			_aliviar(12.0)
			aviso("Um antibiótico reduziu os sintomas e prolongou o prazo em 12h.")
	elif doenca.tipo == "Disenteria":
		doenca = {}
		aviso("O antibiótico curou a disenteria.")
	elif doenca.tipo == "Mutação vampírica":
		_aliviar(6.0)                          # só o antídoto dos ninhos de morcegos cura
		aviso("O antibiótico só retardou a mutação (+6h). Procure um antídoto em ninhos de morcegos.")
	else:
		doenca = {}
		aviso("O tratamento interrompeu a mutação.")


## Devolve 'h' horas ao prazo da doença (sem passar do total) e recalcula o estágio.
func _aliviar(h: float) -> void:
	var total: float = doenca.get("total", 48.0)
	doenca.horas = minf(total, doenca.horas + h)
	doenca.estagio = clampf((total - doenca.horas) / total * 4.0, 0.0, 3.0)


## Antídoto dos ninhos de morcegos: cura a mutação vampírica. Para outras doenças não é gasto.
func usar_antidoto() -> void:
	if doenca.get("tipo", "") != "Mutação vampírica":
		aviso("O antídoto só age contra a mutação vampírica.")
		return
	inventario.remover("antidoto", 1)
	doenca = {}
	sol = 0.0
	aviso("O antídoto interrompeu a mutação vampírica.")


# =====================================================================
# SAVE (SaveJogo)
# =====================================================================
func dados_para_salvar() -> Dictionary:
	var p := IsoMath.tela_para_mundo(dirigindo.global_position if dirigindo != null else global_position)
	return {"p": [p.x, p.y], "raca": raca, "forma": forma, "vida": vida, "fome": fome, "sede": sede, "origem": origem, "genero": genero, "local_inicio": local_inicio, "incubacao": incubacao_h, "passos": passos.duplicate(),
		"stamina": stamina, "descanso": descanso, "sol": sol, "doenca": doenca.duplicate(), "lanterna": lanterna_ligada,
		"slots": inventario.slots.map(func(x): return null if x == null else (x as Dictionary).duplicate()),
		"equipado": inventario.equipado}


func restaurar(d: Dictionary) -> void:
	if d.is_empty():
		return
	definir_raca(str(d.get("raca", "human")), false)
	forma = str(d.get("forma", forma))
	_aplicar_frames()
	vida_max = vida_max_atual()
	vida = clampf(float(d.get("vida", vida_max)), 1.0, vida_max)
	fome = float(d.get("fome", 100.0))
	sede = float(d.get("sede", 100.0))
	origem = str(d.get("origem", ""))
	genero = str(d.get("genero", "m"))
	local_inicio = str(d.get("local_inicio", ""))
	incubacao_h = float(d.get("incubacao", -1.0))
	passo_restaurar(d.get("passos", {}))
	stamina = float(d.get("stamina", stamina_max))
	descanso = float(d.get("descanso", 100.0))
	sol = float(d.get("sol", 0.0))
	doenca = (d.get("doenca", {}) as Dictionary).duplicate()
	lanterna_ligada = bool(d.get("lanterna", true))
	var slots := SaveJogo.slots_de(d.get("slots", []))
	for i in mini(slots.size(), inventario.slots.size()):
		inventario.slots[i] = slots[i]
	inventario.equipado = int(d.get("equipado", -1))
	inventario.mudou.emit()
