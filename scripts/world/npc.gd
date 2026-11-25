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
var fora := false                             ## saiu em expedição ou viagem (Simulacao): some até voltar
var furioso := false                          ## ataca o jogador (Consequencias: vingança, guarda expulsando o assassino)
var _t_golpe := 0.0
var _t_grito_n := 0.0
## Sono e rapto (marco 3, Sangue): dorme deitado na cama da casa (ou na entrada da barraca); barulho deixa inquieto
## e depois acorda. Nocauteado, fica desacordado até 'acorda_h' (hora do jogo) e pode ser arrastado.
const NOCAUTE_H := 1.5
const VE_AO_ACORDAR := 8.0 * IsoMath.METRO      ## acordando, reconhece quem estiver até aqui (sem capuz)
var acorda_h: float = -1.0
var arrastado_por: Node2D = null
var bebido := false                              ## beberam o sangue dele
var suspeita := 0.0                              ## dormindo: 0 = sono pesado, 0,5 = inquieto, 1 = acorda
var _na_cama := false
var _cama_no: Node2D = null                      ## desenho da cama (para sumir junto quando o cômodo não está à vista)
var _t_sono := 0.0
var _revide_t := 0.0                             ## s partindo para cima de quem tentou pegá-lo dormindo

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


## Fase atual do dia (DiaNoite.Fase) e a tarefa da rotina para ela. Ferido (Simulacao) fica em casa.
func _tarefa_agora() -> String:
	if not Simulacao.ferido(comunidade, str(dados.get("id", ""))).is_empty():
		return "casa"
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	var fase: int = int(ciclo.fase()) if ciclo != null else 2
	var rotina: Dictionary = dados.get("rotina", {})
	var chave: String = Comunidades.CHAVES_FASE[fase]
	return Consequencias.rotina(comunidade, str(dados.get("id", "")), chave, str(rotina.get(chave, "praca")))


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
	_conferir_fora()


## Saiu ou voltou de uma expedição/viagem da Simulacao: some ou reaparece em casa.
func _conferir_fora() -> void:
	var f := Simulacao.ausente(comunidade, str(dados.get("id", ""))) or Consequencias.ausente(comunidade, str(dados.get("id", "")))
	if f == fora:
		return
	fora = f
	if fora:
		visible = false
		_col.set_deferred("disabled", true)
	else:
		global_position = IsoMath.mundo_para_tela(ponto_da_tarefa("casa"))
		_dormir(_deve_dormir())


func _deve_dormir() -> bool:
	if tarefa != "casa":
		return false
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	return ciclo == null or ciclo.eh_noite() or int(ciclo.fase()) == 0


func _dormir(v: bool) -> void:
	var antes := dormindo
	dormindo = v
	visible = true
	_col.set_deferred("disabled", v)
	if v and not antes:
		suspeita = 0.0
		_ir_para_cama()
	elif not v and _na_cama:
		_na_cama = false                         # levanta da cama e sai pela porta da casa
		_cama_no = null
		modulate.a = 1.0
		global_position = IsoMath.mundo_para_tela(ponto_da_tarefa("casa"))


## Deita na cama da casa dele (Vila: a cama do quarto do prédio; acampamento: na entrada da barraca).
## O prédio só tem móveis quando está montado perto do jogador; até lá, deita na porta e tenta de novo.
func _ir_para_cama() -> void:
	var g := Comunidades.geo(comunidade)
	_sprite.animation = &"deitado"
	_sprite.frame = 0
	if g.is_empty():
		return
	var lotes: Array = g.get("lotes", [])
	if lotes.is_empty():
		return
	var lote: Vector2 = lotes[int(dados.get("casa", indice)) % lotes.size()]
	for e in get_tree().get_nodes_in_group("edificio"):
		var ed := e as Edificio
		if ed == null or not ed.pronto:
			continue
		var origem := IsoMath.tela_para_mundo(ed.global_position)
		if origem.distance_to(lote) > 3.0 * M:
			continue
		var camas: Array = ed.moveis.filter(func(m): return m.tipo == "cama")
		if camas.is_empty():
			return
		var m: Dictionary = camas[indice % camas.size()]
		global_position = IsoMath.mundo_para_tela(origem + Vector2((m.x0 + m.x1) / 2.0, (m.y0 + m.y1) / 2.0 + 6.0))
		_cama_no = m.no
		_na_cama = true
		return


## Dormindo: deitado; o barulho do jogador por perto deixa inquieto e, passando do ponto, acorda.
## Com a comunidade em alerta (Simulacao), o sono é mais leve.
func _sono(delta: float) -> void:
	velocity = Vector2.ZERO
	_sprite.animation = &"deitado"
	_sprite.frame = 0
	if _na_cama and _cama_no != null and is_instance_valid(_cama_no):
		modulate.a = _cama_no.modulate.a        # dentro de casa: só aparece quando o cômodo está à vista
	_t_sono -= delta
	if _t_sono > 0.0:
		return
	_t_sono = 0.5
	if not _na_cama:
		_ir_para_cama()
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null or bool(j.morto):
		return
	var d := _dist_jogador()
	var leve := 2.0 if Simulacao.alerta(comunidade) else 1.0
	var mesmo := Reputacao._predio_em(get_tree(), _mundo()) == Reputacao._predio_em(get_tree(), IsoMath.tela_para_mundo(j.global_position))
	var ouve: float = float(j.ruido_efetivo()) * (0.6 if mesmo else 0.25) * leve
	if d < ouve:
		var antes := suspeita
		suspeita = minf(1.0, suspeita + 0.2 * leve)
		if antes < 0.5 and suspeita >= 0.5:
			falar("Hm...?", 2.0)
		if suspeita >= 1.0:
			falar("Quem tá aí?!", 2.5)
			acordar_assustado()
	else:
		suspeita = maxf(0.0, suspeita - 0.04)


## Tentativa de pegá-lo dormindo (Sangue). Sem perceber nada, pega sempre; inquieto, a chance cai.
## Falhando, ele acorda: foge gritando ou parte para cima (o guarda sempre parte). Devolve true se pegou.
func tentar_captura(j: Node2D) -> bool:
	var chance := 1.0 if suspeita < 0.5 else clampf(1.0 - suspeita, 0.1, 0.5)
	_na_cama = false                             # fica onde está (na cama), em vez de sair pela porta
	_cama_no = null
	modulate.a = 1.0
	if randf() < chance:
		_dormir(false)
		nocautear()
		return true
	_dormir(false)
	_sprite.animation = &"andar_frente"
	if str(dados.get("papel", "")).begins_with("guarda") or randf() < 0.5:
		_revide_t = 20.0
		furioso = true
		falar("Sai de cima de mim!", 2.5)
	else:
		_fuga_t = 8.0
		falar("Socorro! Socorro!", 3.0)
	Reputacao.registrar("agressao", _mundo(), self)
	j.aviso("%s acordou antes da hora." % nome())
	return false


func desacordado() -> bool:
	return acorda_h >= 0.0


## Golpe na nuca (Sangue): cai desacordado por NOCAUTE_H horas de jogo.
func nocautear() -> void:
	acorda_h = Reputacao.agora_h() + NOCAUTE_H
	_fuga_t = 0.0
	conversando = false
	velocity = Vector2.ZERO
	_col.set_deferred("disabled", true)
	falar("Ugh—", 1.5)


func _desacordado() -> void:
	velocity = Vector2.ZERO
	_sprite.animation = &"deitado"
	_sprite.frame = 0
	if Reputacao.agora_h() >= acorda_h:
		_acordar()


## Acorda do nocaute: foge e conta. Se quem fez isso estiver perto e de rosto descoberto, ele viu.
func _acordar() -> void:
	acorda_h = -1.0
	_col.set_deferred("disabled", false)
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j != null and j.get("carregando") == self:
		j.set("carregando", null)
	arrastado_por = null
	_fuga_t = 8.0
	var viu: bool = j != null and not bool(j.morto) and _dist_jogador() < VE_AO_ACORDAR and not Sangue.rosto_coberto(j)
	_ao_acordar(viu, j)


## Morador: viu, a comunidade fica sabendo (ele é a testemunha); não viu, mas beberam o sangue dele, a comunidade
## entra em alerta. O Errante faz a sua versão.
func _ao_acordar(viu: bool, j: Node2D) -> void:
	if comunidade == "":
		return
	if viu:
		falar("Foi você! Eu vi a sua cara!", 3.0)
		Reputacao.registrar("sangue" if bebido else "rapto", _mundo(), self)
		j.aviso("%s acordou e viu o seu rosto." % nome())
	else:
		falar("O que... o que fizeram comigo?", 3.0)
		if bebido:
			Simulacao.alertar(comunidade, "%s acordou fora de casa, fraco, com marcas de dentes no pescoço." % nome())


func _physics_process(delta: float) -> void:
	_t_pensar -= delta
	if _t_pensar <= 0.0:
		_t_pensar = 1.0
		_conferir_fora()
		if not Reputacao.vivo(comunidade, str(dados.get("id", ""))) and not morto and comunidade != "":
			queue_free()                      # consta como morto: não pode estar andando por aí
			return
		var jh := get_tree().get_first_node_in_group("jogador") as Node2D
		furioso = (comunidade != "" and not morto and Consequencias.hostil(comunidade, str(dados.get("id", "")), jh, self)) \
			or _revide_t > 0.0 or Vigilancia.ataca(self)
		if not furioso and comunidade != "" and Vigilancia.monstro.has(comunidade) and _dist_jogador() < 12.0 * M \
				and not dormindo and not desacordado():
			_fuga_t = 4.0                         # um deles aqui dentro: quem não luta, foge
		var t := _tarefa_agora()
		if t != tarefa:
			tarefa = t
			_alvo = ponto_da_tarefa(t)
			if dormindo:
				_dormir(false)                # acordou: sai de casa
	_revide_t -= delta
	if morto or fora:
		return
	if desacordado():
		_desacordado()
		return
	if dormindo:
		_sono(delta)
		return
	if furioso and vida >= 12.0:
		var j := get_tree().get_first_node_in_group("jogador") as Node2D
		if j != null and not j.morto and j.dirigindo == null and _dist_jogador() < 16.0 * M:
			conversando = false
			_atacar(delta, j)
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


## Partindo para cima do jogador: corre até ele e golpeia; guarda às vezes atira.
func _atacar(delta: float, j: Node2D) -> void:
	_t_golpe -= delta
	_t_grito_n -= delta
	if _t_grito_n <= 0.0:
		_t_grito_n = 8.0
		falar(Consequencias.grito(comunidade, str(dados.get("id", ""))), 2.5)
	var d := _dist_jogador()
	var guarda := str(dados.get("papel", "")).begins_with("guarda")
	if guarda and d < 9.0 * M and d > 2.0 * M and randf() < 0.008:
		j.receber_dano(14.0, "humano")
		falar("*BANG*", 0.8)
		return
	if d > 1.1 * M:
		var dir := IsoMath.tela_para_mundo(j.global_position - global_position).normalized()
		velocity = IsoMath.mundo_para_tela(dir * VEL * 1.9)
		move_and_slide()
		_passo += VEL * 1.9 * delta * 0.09
		_olhar = dir
		_animar(true)
	elif _t_golpe <= 0.0:
		_t_golpe = 1.2
		velocity = Vector2.ZERO
		j.receber_dano(8.0, "humano")
		_olhar = IsoMath.tela_para_mundo(j.global_position - global_position).normalized()
		_animar(false)


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


## Golpe ou tiro do jogador (ou ataque de monstro: por_jogador = false). A primeira agressão do jogador em alguns
## segundos vira um evento com testemunhas; morrer, outro.
func receber_dano(n: float, por_jogador: bool = true) -> void:
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
	_fuga_t = 6.0 if not furioso or vida < 12.0 else 0.0     # quem quer briga não foge (só muito ferido)
	var agora := Time.get_ticks_msec() / 1000.0
	if por_jogador and comunidade != "" and agora - _t_agressao > 20.0:
		_t_agressao = agora
		Reputacao.registrar("agressao", _mundo(), self)


func _morrer() -> void:
	morto = true
	conversando = false
	remove_from_group("interativo")
	acorda_h = -1.0
	Corpo.anexar(self, nome(), true)           # o corpo fica no chão (Corpo: some longe do jogador)
	if bebido:
		set_meta("mordido", true)
	_col.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_sprite.animation = &"caido" if _sprite.sprite_frames.has_animation(&"caido") else _sprite.animation
	_sprite.frame = 0
	var id := str(dados.get("id", ""))
	var com_nome := not id.begins_with("figurante") and comunidade != ""
	if com_nome:
		Reputacao.npc_morreu(comunidade, id)
	Reputacao.registrar("assassinato", _mundo(), null, id if com_nome else "")
	if com_nome:
		Consequencias.morte(comunidade, id, "jogador")
	var j := get_tree().get_first_node_in_group("jogador")
	if j != null:
		j.aviso("%s está %s." % [nome(), "morta" if str(dados.get("genero", "m")) == "f" else "morto"])


## Acordou com alguém mexendo na casa dele de noite (Reputacao: furto). Sai para a rua, assustado.
func acordar_assustado() -> void:
	_dormir(false)
	_fuga_t = 3.0


## Balão de fala sobre a cabeça por alguns segundos (conversas ouvidas, Rumores).
func falar(texto: String, dur: float = 4.0) -> void:
	var antigo := get_node_or_null("Balao")
	if antigo != null:
		antigo.name = "BalaoVelho"                # o queue_free só vale no fim do quadro: tira o nome já
		antigo.queue_free()
	var p := PanelContainer.new()
	p.name = "Balao"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.82)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_font_size_override("font_size", 11)
	p.add_child(l)
	p.z_index = 50
	p.position = Vector2(-101, -150)
	add_child(p)
	var t := p.create_tween()
	t.tween_interval(dur)
	t.tween_property(p, "modulate:a", 0.0, 0.6)
	t.tween_callback(p.queue_free)


func parado() -> bool:
	return not dormindo and not desacordado() and not morto and not fora and not conversando and _fuga_t <= 0.0 and velocity.length() < 1.0


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
	if dormindo or morto or fora or desacordado():
		return false
	var d := _dist_jogador()
	if d > ALCANCE_FALA * (2.4 if tarefa == "portao" else 1.0):     # o guarda conversa pela grade do portão
		return false
	for o in get_tree().get_nodes_in_group("npc"):
		if o != self and not o.dormindo and o._dist_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 8


func texto_interacao() -> String:
	if desacordado() and _dist_jogador() < 2.0 * M:
		return "E — %s %s" % ["soltar" if arrastado_por != null else "arrastar", nome()]
	return "E — falar com %s" % nome() if _e_o_alvo() and not conversando and not furioso else ""


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
	if event.is_action_pressed("interact") and desacordado() and _dist_jogador() < 2.0 * M:
		var jd := get_tree().get_first_node_in_group("jogador") as Node2D
		if jd != null and not bool(jd.morto):
			get_viewport().set_input_as_handled()
			Sangue.arrastar(jd, self)
		return
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	if conversando:
		return
	var arv := {}
	if Conversas.arvore(comunidade, str(dados.get("id", ""))).is_empty():
		var ctx := {"com": comunidade, "npc": str(dados.get("id", "")), "jogador": j}
		var teste := {"nos": {}}
		if Medicina.opcoes(teste, ctx, [], true).is_empty():
			j.aviso("%s: “%s”" % [nome(), fala()])     # figurante (ou NPC sem conversa escrita): fala curta
			return
		arv = {"inicio": [{"no": "oi"}], "nos": {"oi": {"fala": fala()}}}   # ferido sem conversa escrita: dá para tratar
	var ui := DialogoUI.new()
	ui.npc = self
	ui.arvore_pronta = arv
	get_tree().current_scene.add_child(ui)
