class_name Npc
extends CharacterBody2D
## Morador de uma comunidade (Comunidades, marco 2). Segue a rotina do arquivo da comunidade: a cada fase do dia vai
## para casa, portão, fogueira, praça ou trabalho. Na madrugada e à noite, quem está "em casa" entra e dorme (some
## do mapa até a rotina mudar). E perto dele abre a conversa (DialogoUI, árvore em data/dialogos); sem árvore,
## só uma fala curta pelo papel.
## Pode ser ferido e morto pelo jogador (Reputacao: agressão e assassinato, com testemunhas); atacado, foge.
## Sprite provisório: o humano do jogador, com uma cor por NPC, até chegarem as folhas de sprite dos NPCs.

const M := IsoMath.METRO
const DIRECOES: Array[String] = ["frente", "lado", "costas"]
const VEL := 1.7 * IsoMath.METRO              ## caminhada tranquila (u/s)
const ALCANCE_FALA := 2.2 * IsoMath.METRO
const CORES := [Color(1.0, 0.86, 0.76), Color(0.82, 0.92, 1.0), Color(0.9, 1.0, 0.84), Color(1.0, 0.92, 0.7),
	Color(0.88, 0.8, 1.0), Color(1.0, 0.8, 0.84), Color(0.8, 0.95, 0.95)]

var comunidade: String = ""
var dados: Dictionary = {}                    ## entrada do NPC no JSON (id, nome, papel, rotina, casa...)
var indice: int = 0                           ## posição na lista (espalha quem tem a mesma tarefa)
var tarefa: String = ""
var dormindo := false
var conversando := false                      ## parado, olhando para o jogador, enquanto a DialogoUI está aberta
var morto := false
var vida: float = 40.0
var _fuga_t := 0.0                            ## segundos fugindo do jogador depois de apanhar
var _t_agressao := -99.0                      ## quando foi a última agressão registrada (s, para não repetir a cada golpe)

var _alvo := Vector2.INF                      ## mundo
var _passo := 0.0
var _lado := 0.0
var _desvio_t := 0.0
var _t_pensar := 0.0
var _parado_t := 0.0
var _olhar := Vector2.DOWN
var _sprite := AnimatedSprite2D.new()
var _col := CollisionShape2D.new()


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interativo")
	y_sort_enabled = true
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var forma := CircleShape2D.new()
	forma.radius = 6.0
	_col.shape = forma
	add_child(_col)
	_sprite.sprite_frames = load("res://resources/sprite_frames/humano.tres")
	_sprite.scale = Vector2.ONE * 0.368
	_sprite.offset = Vector2(0, -76)
	_sprite.light_mask = 2
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.self_modulate = CORES[absi(hash(comunidade + str(dados.get("id", "")))) % CORES.size()]
	add_child(_sprite)
	var sombra := SombraSol.Personagem.new()
	sombra.fonte = _sprite
	add_child(sombra)
	add_child(SombraSol.contato(34.0))
	_animar(false)


func nome() -> String:
	return str(dados.get("nome", "Morador"))


func _mundo() -> Vector2:
	return IsoMath.tela_para_mundo(global_position)


## Fase atual do dia (DiaNoite.Fase) e a tarefa da rotina para ela.
func _tarefa_agora() -> String:
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	var fase: int = int(ciclo.fase()) if ciclo != null else 2
	var rotina: Dictionary = dados.get("rotina", {})
	return str(rotina.get(Comunidades.CHAVES_FASE[fase], "praca"))


## Ponto (mundo) da tarefa na geometria da comunidade.
func ponto_da_tarefa(t: String) -> Vector2:
	var g := Comunidades.geo(comunidade)
	if g.is_empty():
		return _mundo()
	match t:
		"casa":
			var casas: Array = g["casas"]
			return casas[int(dados.get("casa", indice)) % casas.size()]
		"portao":
			var ps: Array = g["portoes"]
			return (ps[indice % ps.size()] as Dictionary)["dentro"]
		"fogueira", "praca", "trabalho":
			var lista: Array = g["praca" if t == "fogueira" else t]
			return lista[indice % lista.size()]
	return g["centro"]


## Começa já no lugar da tarefa atual (aparece pronto quando o jogador chega perto).
func posicionar() -> void:
	tarefa = _tarefa_agora()
	_alvo = ponto_da_tarefa(tarefa)
	global_position = IsoMath.mundo_para_tela(_alvo)
	_dormir(_deve_dormir())


func _deve_dormir() -> bool:
	if tarefa != "casa":
		return false
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	return ciclo == null or ciclo.eh_noite() or int(ciclo.fase()) == 0


func _dormir(v: bool) -> void:
	dormindo = v
	visible = not v
	_col.set_deferred("disabled", v)


func _physics_process(delta: float) -> void:
	_t_pensar -= delta
	if _t_pensar <= 0.0:
		_t_pensar = 1.0
		var t := _tarefa_agora()
		if t != tarefa:
			tarefa = t
			_alvo = ponto_da_tarefa(t)
			if dormindo:
				_dormir(false)                # acordou: sai de casa
	if dormindo or morto:
		return
	if _fuga_t > 0.0:
		_fugir(delta)
		return
	if conversando:
		velocity = Vector2.ZERO
		_olhar_para_jogador()
		_animar(false)
		return
	var em := _mundo()
	var v := _alvo - em
	if v.length() < 26.0:
		velocity = Vector2.ZERO
		if _deve_dormir():
			_dormir(true)
			return
		_parado_t += delta
		if _parado_t > 6.0 and tarefa != "portao":
			_parado_t = 0.0                    # dá uns passos à toa perto do lugar
			_alvo = ponto_da_tarefa(tarefa) + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		_olhar_para_jogador()
		_animar(false)
		return
	var dir := v.normalized()
	if _desvio_t > 0.0:
		_desvio_t -= delta
		dir = (dir * 0.35 + Vector2(-dir.y, dir.x) * _lado).normalized()
	var antes := global_position
	velocity = IsoMath.mundo_para_tela(dir * VEL)
	move_and_slide()
	var andou := IsoMath.tela_para_mundo(global_position - antes).length()
	if andou < VEL * delta * 0.35 and _desvio_t <= 0.0:
		_lado = 1.0 if randf() < 0.5 else -1.0
		_desvio_t = 0.5
	_passo += VEL * delta * 0.09
	_olhar = dir
	_animar(true)


## Correndo para longe do jogador (atacado).
func _fugir(delta: float) -> void:
	_fuga_t -= delta
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	var dir := Vector2.from_angle(randf() * TAU)
	if j != null:
		var d := IsoMath.tela_para_mundo(global_position - j.global_position)
		if d.length() > 1.0:
			dir = d.normalized()
	if _desvio_t > 0.0:
		_desvio_t -= delta
		dir = (dir * 0.35 + Vector2(-dir.y, dir.x) * _lado).normalized()
	var antes := global_position
	velocity = IsoMath.mundo_para_tela(dir * VEL * 2.6)
	move_and_slide()
	if IsoMath.tela_para_mundo(global_position - antes).length() < VEL * delta * 0.8 and _desvio_t <= 0.0:
		_lado = 1.0 if randf() < 0.5 else -1.0
		_desvio_t = 0.5
	_passo += VEL * 2.6 * delta * 0.09
	_olhar = dir
	_animar(true)
	if _fuga_t <= 0.0:
		_alvo = ponto_da_tarefa(tarefa)


## Golpe ou tiro do jogador. A primeira agressão em alguns segundos vira um evento com testemunhas; morrer, outro.
func receber_dano(n: float) -> void:
	if morto:
		return
	vida -= n
	_sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if dormindo:
		_dormir(false)
	if vida <= 0.0:
		_morrer()
		return
	_fuga_t = 6.0
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _t_agressao > 20.0:
		_t_agressao = agora
		Reputacao.registrar("agressao", _mundo(), self)


func _morrer() -> void:
	morto = true
	conversando = false
	remove_from_group("interativo")
	_col.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_sprite.animation = &"caido" if _sprite.sprite_frames.has_animation(&"caido") else _sprite.animation
	_sprite.frame = 0
	var id := str(dados.get("id", ""))
	if not id.begins_with("figurante"):
		Reputacao.npc_morreu(comunidade, id)
	Reputacao.registrar("assassinato", _mundo())
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.aviso("%s está morto." % nome())
	var t := create_tween()
	t.tween_interval(20.0)
	t.tween_property(self, "modulate:a", 0.0, 2.0)
	t.tween_callback(queue_free)


## Acordou com alguém mexendo na casa dele de noite (Reputacao: furto). Sai para a rua, assustado.
func acordar_assustado() -> void:
	_dormir(false)
	_fuga_t = 3.0


func _olhar_para_jogador() -> void:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null:
		return
	var d := IsoMath.tela_para_mundo(j.global_position - global_position)
	if d.length() < ALCANCE_FALA * 2.0:
		_olhar = d.normalized()


func _animar(andando: bool) -> void:
	var tela := Vector2(_olhar.x - _olhar.y, _olhar.x + _olhar.y)
	var linha := 1
	var flip := tela.x < 0.0
	if absf(tela.x) <= absf(tela.y):
		linha = 0 if tela.y > 0.0 else 2
		flip = false
	var anim := "andar_" + DIRECOES[linha]
	var quadros := _sprite.sprite_frames
	if not quadros.has_animation(anim):
		anim = "andar_frente"
	var q := int(_passo * 0.7) % quadros.get_frame_count(anim) if andando else 0
	if _sprite.animation != anim:
		_sprite.animation = anim
	_sprite.frame = mini(q, quadros.get_frame_count(anim) - 1)
	_sprite.flip_h = flip


# ───────────────────────────── conversa (provisória) ─────────────────────────────

func _dist_jogador() -> float:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	return INF if j == null else IsoMath.tela_para_mundo(j.global_position - global_position).length()


func _e_o_alvo() -> bool:
	if dormindo or morto:
		return false
	var d := _dist_jogador()
	if d > ALCANCE_FALA:
		return false
	for o in get_tree().get_nodes_in_group("npc"):
		if o != self and not o.dormindo and o._dist_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 8


func texto_interacao() -> String:
	return "E — falar com %s" % nome() if _e_o_alvo() and not conversando else ""


## Fala curta pelo papel e pela hora (provisório até o diálogo em árvore, etapa 5).
func fala() -> String:
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	var tarde: bool = ciclo != null and int(ciclo.fase()) >= 4
	match str(dados.get("papel", "")):
		"guarda":
			return "O portão fecha às %dh. Depois disso, ninguém entra." % int((Comunidades.dados(comunidade).get("portao", {}) as Dictionary).get("fecha", 18))
		"lider":
			return "Bem-vindo a %s. Aqui todo mundo trabalha." % Comunidades.nome(comunidade)
		"comerciante":
			return "Tenho umas coisas para trocar. Volte quando eu tiver a mercadoria arrumada."
		"mestre_medicina":
			return "Se alguém estiver ferido, traga até mim. Remédio é que anda em falta."
		"pescador":
			return "O mar ainda dá peixe. A cidade é que não dá mais nada."
		"cacador":
			return "Tem bicho estranho na mata. E não é só bicho."
	return "Já está escurecendo. Melhor ficar do lado de dentro." if tarde else "Bom dia."


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	if conversando:
		return
	if Conversas.arvore(comunidade, str(dados.get("id", ""))).is_empty():
		j.aviso("%s: “%s”" % [nome(), fala()])     # figurante (ou NPC sem conversa escrita): fala curta
		return
	var ui := DialogoUI.new()
	ui.npc = self
	get_tree().current_scene.add_child(ui)
