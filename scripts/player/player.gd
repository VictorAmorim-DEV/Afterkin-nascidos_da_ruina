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
var fome: float = 100.0                  ## 100 = saciado; cai 0,13/s e, em 0, tira vida
var xp: int = 0
var nivel: int = 1
var inventario: Inventario
var ataque_cd: float = 0.0               ## recarga do golpe (V13: player.attackCd)
var golpe_t: float = 0.0                 ## tempo restante da animação de golpe
var morto: bool = false
var dirigindo: Node2D = null             ## veículo que está dirigindo (o jogador fica escondido)
var territorio: Territorio
var raca: String = "human"               ## human, rat, vampire ou zombie (V13: player.race)
var forma: String = "human"              ## só o rato alterna: "human" ou "rat" (V13: player.form)
var doenca: Dictionary = {}              ## vazio = saudável; {tipo, horas, estagio, origem}
var sol: float = 0.0                     ## exposição solar do vampiro (0 a 60; acima disso queima)

var _passo: float = 0.0
var _inclinacao: float = 0.0
var _ciclo: Node = null
var _saltando: bool = false               ## no meio de um salto guiado (ex.: pulando uma janela)
var _altura_luz: float = 31.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lanterna_chao: PointLight2D = $LanternaChao
@onready var lanterna_objetos: PointLight2D = $LanternaObjetos


func _ready() -> void:
	add_to_group("jogador")
	stamina = stamina_max
	var sombra := SombraSol.Personagem.new()          # sombra do sol (V13: sombraChar)
	sombra.fonte = sprite
	add_child(sombra)
	inventario = Inventario.new()
	inventario.name = "Inventario"
	inventario.jogador = self
	add_child(inventario)
	inventario.aviso.connect(aviso)
	territorio = Territorio.new()
	territorio.name = "Territorio"
	territorio.jogador = self
	add_child(territorio)
	inventario.inicial()
	# anel de barulho no chão (V13 l.1650): raio = distância em que os inimigos ouvem
	_anel_ruido.z_index = -1
	_anel_ruido.draw.connect(_desenhar_anel_ruido)
	add_child(_anel_ruido)
	aplicar_sombras_lanterna(Controles.ler_cfg().get_value("video", "sombras_lanterna", true))


func _process(_delta: float) -> void:
	_anel_ruido.queue_redraw()


func _desenhar_anel_ruido() -> void:
	if dirigindo != null:
		return
	var pts := PackedVector2Array()
	for k in 40:
		pts.append(IsoMath.mundo_para_tela(Vector2.from_angle(TAU * k / 40.0) * ruido))
	_anel_ruido.draw_colored_polygon(pts, Color(1, 1, 1, 0.03))
	pts.append(pts[0])
	_anel_ruido.draw_polyline(pts, Color(1, 1, 1, 0.15), 2.0)


## Sombras da luz da lanterna (opção de vídeo: desligar alivia PCs mais fracos).
func aplicar_sombras_lanterna(ligar: bool) -> void:
	lanterna_chao.shadow_enabled = ligar


## Furtividade pelo barulho (V13: hudStealth).
func texto_furtividade() -> String:
	if ruido < 70.0:
		return "Quase invisível"
	if ruido < 130.0:
		return "Discreto"
	if ruido < 230.0:
		return "Visível"
	return "Barulhento"


func _unhandled_input(event: InputEvent) -> void:
	if dirigindo != null:
		return                                   # dirigindo: o veículo trata as teclas
	if event.is_action_pressed("crouch"):
		postura = Postura.EM_PE if postura == Postura.AGACHADO else Postura.AGACHADO
	elif event.is_action_pressed("prone"):
		postura = Postura.EM_PE if postura == Postura.DEITADO else Postura.DEITADO
	elif event.is_action_pressed("jump"):
		if postura != Postura.EM_PE:
			postura = Postura.EM_PE          # o pulo primeiro levanta o personagem
		elif pulo_z <= 0.0 and stamina >= gasto_pulo and not _saltando:
			pulo_v = impulso_pulo
			stamina -= gasto_pulo
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
	if postura == Postura.AGACHADO:
		v = crouch_speed
	elif postura == Postura.DEITADO:
		v = prone_speed
	if exausto:
		v *= 0.85
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


func _atualizar_folego(delta: float, rapidez: float) -> void:
	if correndo:
		stamina = maxf(0.0, stamina - gasto_correr * delta)
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
	stamina = minf(stamina_max, stamina + regen * delta)
	if exausto and stamina >= limite_exaustao:
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
	ruido += (alvo - ruido) * minf(1.0, delta * 5.0)


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
	lanterna_chao.transform = Transform2D(frente * k_chao, lado * k_chao, mao)

	# LUZ DOS OBJETOS EM PÉ (paredes, carros, árvores, personagens): sai da altura
	# da mão, então ilumina mais baixo quando o jogador agacha ou deita.
	var k_obj := alcance_lanterna / 256.0
	lanterna_objetos.enabled = ligada
	lanterna_objetos.energy = energia
	lanterna_objetos.height = _altura_luz
	lanterna_objetos.transform = Transform2D(frente * k_obj, lado * k_obj, mao + Vector2(0.0, -_altura_luz - pulo_z))


# =====================================================================
# SOBREVIVÊNCIA, XP E ITENS (portado da V13: eat, useMed, xpGain, step)
# =====================================================================
func _atualizar_vitais(delta: float) -> void:
	ataque_cd = maxf(0.0, ataque_cd - delta)
	golpe_t = maxf(0.0, golpe_t - delta)
	fome = maxf(0.0, fome - delta * 0.13)
	if fome <= 0.0:
		vida = maxf(0.0, vida - delta * 0.7)
	_atualizar_sol(delta)
	_atualizar_doenca(delta)
	if vida <= 0.0 and not morto:
		_morrer()


## Mensagem curta na tela (toast do HUD).
func aviso(texto: String) -> void:
	get_tree().call_group("hud", "aviso", texto)


func ganhar_xp(n: int) -> void:
	xp += n
	while nivel < 20 and xp >= nivel * 100:
		xp -= nivel * 100
		nivel += 1
		aviso("Você alcançou o nível %d." % nivel)


## Come uma comida: +35 de fome e +8 de vida. Devolve false se não pôde (nada a consumir é feito aqui).
func comer() -> bool:
	if inventario.contar("comida") <= 0:
		aviso("Você não tem comida.")
		return false
	fome = minf(100.0, fome + 35.0)
	vida = minf(vida_max, vida + 8.0)
	aviso("Você comeu e recuperou energia.")
	return true


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


func atacar() -> void:
	if ataque_cd > 0.0 or morto or _saltando:
		return
	postura = Postura.EM_PE if postura == Postura.AGACHADO else postura
	var alvo := _inimigo_perto()
	if alvo == null:
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


func receber_dano(n: float, quem: String = "") -> void:
	if morto:
		return
	if raca == "zombie" and quem == "rat":
		return                                   # zumbi não sente a mordida do rato (V13)
	vida = maxf(0.0, vida - n)
	sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)


func _morrer() -> void:
	morto = true
	SelecaoRaca.titulo_proximo = "Você não sobreviveu"
	aviso("Você morreu. O mundo continua sem você.")
	set_physics_process(false)
	sprite.animation = &"caido"
	sprite.frame = 0
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()


# =====================================================================
# RAÇAS, SOL DO VAMPIRO E DOENÇAS (V13: start, transform, maxLife, infectPlayer, useMed, step)
# =====================================================================
const NOMES_RACA := {"human": "Humano", "rat": "Rato", "vampire": "Vampiro", "zombie": "Zumbi"}


func forma_rato() -> bool:
	return raca == "rat" and forma == "rat"


func vida_max_atual() -> float:
	return 60.0 if forma_rato() else 100.0


## Escolhe a raça. 'reiniciar' = começo de partida (zera vida, fome, XP, nível, doença e mochila).
func definir_raca(r: String, reiniciar: bool = true) -> void:
	raca = r
	forma = "rat" if r == "rat" else "human"
	vida_max = vida_max_atual()
	if reiniciar:
		vida = vida_max
		fome = 100.0
		xp = 0
		nivel = 1
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
		return 24.0
	return 0.0 if _ciclo.pausado else _ciclo.minutos_por_segundo


func _dentro_de_casa() -> bool:
	for e in get_tree().get_nodes_in_group("edificio"):
		if e.jogador_dentro():
			return true
	return false


## Vampiro de dia, a céu aberto. Protegem: o alcance do totem (V13) e, por decisão desta
## versão, estar dentro de uma casa.
func exposto_ao_sol() -> bool:
	return raca == "vampire" and not _eh_noite() and not _dentro_de_casa() and not territorio.protege(global_position)


func _atualizar_sol(delta: float) -> void:
	if raca == "vampire" and not _eh_noite():
		if exposto_ao_sol():
			sol += delta * _min_por_s() / 60.0
			if sol > 60.0:
				vida = maxf(0.0, vida - delta * 3.0)
		else:
			sol = maxf(0.0, sol - delta * 0.2)
	elif _eh_noite():
		sol = maxf(0.0, sol - delta)


## Mordida/golpe de inimigo (V13: infectPlayer). Cada origem causa uma doença diferente.
func infectar(origem: String) -> void:
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
			doenca = {"tipo": "Leptospirose", "horas": 48.0, "estagio": 0.0, "origem": "rat"}
			aviso("Mordida contaminada! Leptospirose contraída. Procure antibióticos.")
		"vampire":
			doenca = {"tipo": "Mutação vampírica", "horas": 24.0, "estagio": 0.0, "origem": "vampire"}
			aviso("Você foi mordido. A mutação começou: encontre um antídoto em ninhos de morcegos.")
		_:
			doenca = {"tipo": "Infecção zumbi", "horas": 24.0, "estagio": 0.0, "origem": "zombie"}
			aviso("Infecção zumbi contraída. A transformação ou morte pode ocorrer em 24h.")


func _atualizar_doenca(delta: float) -> void:
	if doenca.is_empty():
		return
	# a V13 tira 24 "horas" por segundo real (esgota em 2 s); aqui a doença corre com o relógio do jogo
	doenca.horas -= delta * _min_por_s() / 60.0
	doenca.estagio = minf(3.0, (48.0 - doenca.horas) / 12.0)
	if doenca.horas > 0.0:
		return
	if doenca.tipo == "Leptospirose":
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
	return "%s · estágio %d · %dh restantes" % [doenca.tipo, int(doenca.estagio), maxi(0, ceili(doenca.horas))]


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
			doenca.horas += 12.0
			doenca.estagio = maxf(0.0, doenca.estagio - 1.0)
			aviso("Um antibiótico reduziu os sintomas e prolongou o prazo em 12h.")
	else:
		doenca = {}
		aviso("O tratamento interrompeu a mutação.")
