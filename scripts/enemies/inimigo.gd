class_name Inimigo
extends CharacterBody2D
## Zumbi ou rato gigante (V13: atualizarInimigos). Dorme até ouvir o jogador, persegue,
## abre ou arromba portas e ataca de perto. Trabalha em "mundo" (u) como o jogador.
## Etapa 10b: a presa pode ser o jogador ou um humano por perto (errante, morador) que ele ouça ou veja.

const FRAMES := {
	"zombie": "res://resources/sprite_frames/zumbi.tres",
	"rat": "res://resources/sprite_frames/rato_gigante.tres",
	"vampire": "res://resources/sprite_frames/vampiro.tres",
}
const NOMES := {"zombie": "Zumbi", "rat": "Rato gigante", "vampire": "Vampiro"}
## Raça de cada espécie (docs/DECISOES_DESIGN.md, "Vocabulário"): a guerra é entre raças.
const RACAS := {"zombie": "Necrótico", "rat": "Bestial", "vampire": "Profano"}
const M := IsoMath.METRO
const DIRECOES: Array[String] = ["frente", "lado", "costas"]

@export_enum("zombie", "rat", "vampire") var raca: String = "zombie"
@export var dorme: bool = true
var casa: Edificio = null          ## casa onde mora; o vampiro volta para ela de dia e dorme
var chefe: String = ""             ## "mae" = Mãe da Colônia (MaeColonia), mini boss do ninho de morcegos
var ninho_p := Vector2.ZERO        ## ninho da Mãe da Colônia (mundo)
var invasao := Vector2.INF         ## invasor (NoiteDoAtaque): ponto da Vila para onde ele vai, caçando quem achar
var _fuga_p := Vector2.INF         ## fugindo da Vila ao amanhecer: some quando chega longe
var _fuga_t := 0.0
var _revoada_cd: float = 0.0

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
var _golpe_jogador := false            ## o último dano veio do jogador (recompensa e "defesa" só nesse caso)
const OUVE_HUMANO := 9.0 * M           ## de quantos u um monstro acordado percebe um humano andando
## Mordida do vampiro (habilidade; docs/DECISOES_DESIGN.md, marco 3): aviso visível, depois o bote.
const AVISO_MORDIDA := 0.6             ## s de aviso (o vampiro se encolhe e os olhos brilham): dá para fugir
const RECARGA_MORDIDA := 20.0          ## s entre uma mordida e outra
const INICIA_MORDIDA := 1.0 * M        ## distância em que ele prepara o bote
const ALCANCE_MORDIDA := 0.75 * M      ## no fim do aviso, se o jogador ainda estiver aqui, a mordida pega
var _mordida_t: float = 0.0            ## > 0: preparando o bote
var _mordida_cd: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("inimigo")
	sprite.sprite_frames = load(FRAMES[raca])
	hp_max = 25.0 if raca == "rat" else 45.0
	if chefe == "mae":
		hp_max = MaeColonia.VIDA
		sprite.scale *= 1.45
		sprite.self_modulate = Color(0.78, 0.62, 0.86)
	hp = hp_max
	_flip_dorme = randf() < 0.5
	_animar(Vector2.DOWN, false)
	var sombra := SombraSol.Personagem.new()          # sombra do sol (V13: sombraChar)
	sombra.fonte = sprite
	add_child(sombra)
	add_child(SombraSol.contato(34.0))                # sombra de contato no pé


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
	var jog := get_tree().get_first_node_in_group("jogador")
	if jog == null:
		return
	ataque_t -= delta
	golpe_t -= delta
	var em := _mundo()
	var eb := _edif_em(em)
	var j: Node = jog
	var pm: Vector2 = IsoMath.tela_para_mundo(jog.global_position)
	var d := em.distance_to(pm)
	var pb := _edif_em(pm)
	var ouve: float = jog.ruido_efetivo() * (1.0 if eb == pb else 0.55) if jog.vida > 0.0 else 0.0
	# acordado, também enxerga: só no mesmo ambiente (mesmo prédio, ou os dois na rua), conforme luz, neblina,
	# postura e lanterna do jogador
	var ve: bool = jog.vida > 0.0 and eb == pb and d < float(jog.alcance_ser_visto())
	if _fuga_p != Vector2.INF:
		ouve = 0.0                                   # fugindo da Vila ao amanhecer: não caça ninguém
		ve = false
		alerta = 0.0
	elif not dorme or alerta > 0.0:
		var h := _humano_perto(em, eb, d if (d < ouve or ve) else INF)
		if h != null:
			j = h                                # a presa agora é um humano: errante ou morador
			pm = IsoMath.tela_para_mundo(h.global_position)
			d = em.distance_to(pm)
			pb = _edif_em(pm)
			ouve = OUVE_HUMANO
			ve = true
	elif jog.vida <= 0.0:
		return

	if dorme:
		if d < ouve:
			dorme = false
			alerta = 4.0
		elif _noite() and (raca == "rat" or raca == "vampire") and not saiu and chefe == "":   # a Mãe não sai do ninho
			dorme = false
			passeio = true
			saiu = true
		else:
			_animar(Vector2.DOWN, false)
			return
	alerta = maxf(0.0, alerta - delta)
	if d < ouve or ve:
		alerta = 4.0

	if raca == "vampire" and _fuga_p == Vector2.INF and _mordida(delta, j, jog, d, eb == pb):
		return
	var vel := 62.0 if raca == "rat" else 46.0
	var noite := _noite()
	if raca == "vampire" and noite:
		vel *= 1.35
	var alvo := Vector2.ZERO
	var tem_alvo := false
	if alerta > 0.0 and d < 28.0 * M:
		alvo = pm
		tem_alvo = true
	elif _fuga_p != Vector2.INF:
		alvo = _fuga_p
		tem_alvo = true
		_fuga_t -= delta
		if _fuga_t <= 0.0 or em.distance_to(_fuga_p) < 1.5 * M:
			queue_free()
			return
	elif invasao != Vector2.INF:
		# invasor: anda pela Vila de um ponto a outro, caçando quem estiver acordado
		if em.distance_to(invasao) < 2.0 * M:
			invasao = invasao + Vector2(randf_range(-14, 14), randf_range(-5, 5)) * M
		alvo = invasao
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
				if r[3].bater_porta(porta, delta) and em.distance_to(IsoMath.tela_para_mundo(jog.global_position)) < 16.0 * M:
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

	if d < 24.0 and ataque_t <= 0.0 and eb == pb and _fuga_p == Vector2.INF:
		ataque_t = 1.3
		golpe_t = 0.25
		if j == jog:
			j.receber_dano(8.0 if raca == "zombie" else 6.0, raca)
			if raca != "vampire" and randf() < 0.12:   # o vampiro só infecta pela mordida (habilidade)
				j.infectar(raca)
		else:
			j.receber_dano(8.0 if raca == "zombie" else 6.0, false)   # humano atacado pelo monstro
	_animar(dir if dir != Vector2.ZERO else (pm - em), dir != Vector2.ZERO)


## Habilidade de mordida do vampiro. Devolve true enquanto ele está parado preparando o bote.
func _mordida(delta: float, presa: Node, jog: Node, d: float, mesmo_lugar: bool) -> bool:
	_mordida_cd -= delta
	if _mordida_t > 0.0:
		_mordida_t -= delta
		var pulso := 0.5 + 0.5 * sin(_mordida_t * 40.0)
		sprite.modulate = Color(1.0, 0.45 + 0.3 * pulso, 0.45 + 0.3 * pulso)
		velocity = Vector2.ZERO
		if _mordida_t <= 0.0:
			sprite.modulate = Color.WHITE
			golpe_t = 0.3
			var pj := IsoMath.tela_para_mundo(jog.global_position)
			if not jog.morto and _mundo().distance_to(pj) < ALCANCE_MORDIDA:
				jog.receber_mordida(_mundo())
			elif not jog.morto:
				get_tree().call_group("hud", "aviso", "Você escapou do bote do vampiro.")
		return true
	if chefe == "mae":
		_revoada_cd -= delta
		if presa == jog and alerta > 0.0 and _revoada_cd <= 0.0 and d < MaeColonia.REVOADA_ALCANCE and not jog.morto:
			_revoada_cd = MaeColonia.RECARGA_REVOADA
			Revoada.soltar(jog)
	if presa == jog and alerta > 0.0 and _mordida_cd <= 0.0 and d < INICIA_MORDIDA and mesmo_lugar and not jog.morto:
		_mordida_t = AVISO_MORDIDA
		_mordida_cd = MaeColonia.RECARGA_MORDIDA if chefe == "mae" else RECARGA_MORDIDA
		get_tree().call_group("hud", "aviso", "O vampiro se encolhe para dar o bote!")
		return true
	return false


## Humano (errante ou morador acordado) mais perto que o jogador e ao alcance de percepção; null se nenhum.
func _humano_perto(em: Vector2, eb: Edificio, d_jogador: float) -> Node2D:
	var melhor: Node2D = null
	var dist := minf(d_jogador, OUVE_HUMANO)
	for n in get_tree().get_nodes_in_group("npc"):
		var h := n as Npc
		if h == null or h.morto or h.dormindo or h.fora:
			continue
		var ph := IsoMath.tela_para_mundo(h.global_position)
		var dh := em.distance_to(ph)
		if dh < dist and _edif_em(ph) == eb:
			dist = dh
			melhor = h
	return melhor


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


## Amanheceu na noite do ataque: sai da Vila pelo portão e some.
func fugir_da_vila() -> void:
	var g := Comunidades.geo(NoiteDoAtaque.COM)
	invasao = Vector2.INF
	alerta = 0.0
	_fuga_t = 25.0
	var portoes: Array = g.get("portoes", [])
	if portoes.is_empty():
		_fuga_p = _mundo() + Vector2(40, 0) * M
		return
	var fora: Vector2 = (portoes[0] as Dictionary)["fora"]
	var centro: Vector2 = g["centro"]
	_fuga_p = fora + (fora - centro).normalized() * 30.0 * M


func receber_dano(n: float, por_jogador: bool = true) -> void:
	if morto:
		return
	_golpe_jogador = por_jogador
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
	Corpo.anexar(self, nome_exibido(), false)   # o corpo fica no chão até o jogador ir para longe
	if chefe == "mae":
		MaeColonia.morreu(ninho_p)
		MaeColonia.dar_sangue(get_tree(), global_position)
	if _golpe_jogador and Comunidades.perto(_mundo(), 15.0 * M) != "":
		Reputacao.registrar("defesa", _mundo())   # quem viu, conta: você enfrentou um monstro perto do muro
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.animation = &"caido"
	sprite.frame = 0
	sprite.flip_h = _flip_dorme
	var j := get_tree().get_first_node_in_group("jogador")
	if _golpe_jogador:
		DiarioPartida.abate(nome_exibido())
		Diario.abate(j, nome_exibido())
		if chefe == "mae":
			Diario.marcar(j, "mae")
	if j != null and _golpe_jogador and chefe == "":   # a Mãe da Colônia só dá o sangue antigo (MaeColonia)
		if j.inventario.adicionar_itens([["comida", 1]]):
			j.aviso("Inimigo derrotado. +1 comida.")
		else:
			ItemNoChao.largar(get_parent(), global_position + Vector2(0, 2), "comida", 1)
			j.aviso("Inimigo derrotado; a comida ficou no chão (mochila cheia).")
	queue_redraw()


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


func nome_exibido() -> String:
	return "Mãe da Colônia" if chefe == "mae" else str(NOMES.get(raca, raca))


## "Zumbi (Necrótico)": a espécie com a raça, para o diário e os textos que apresentam o monstro.
static func rotulo(especie: String) -> String:
	return "%s (%s)" % [str(NOMES.get(especie, especie)), str(RACAS.get(especie, "?"))]
