class_name Errante
extends Npc
## Sobrevivente solto na cidade (marco 2, etapa 10; docs/DECISOES_DESIGN.md Q42 e Q45). Sem comunidade.
## Tipos (GerenteErrantes sorteia):
## - "assustado": procura comida; dá para conversar, roubar ou encaminhar a uma comunidade;
## - "ferido": caído, pede bandagem, água ou comida; ajudado, agradece com o que tem e um rumor;
## - "andarilho": troca o que carrega (Escambo);
## - "saqueador": hostil, ataca quem chega perto; matar um saqueador não pesa na reputação;
## - "em_combate": luta contra zumbis; se você o salvar, fica grato (recompensa, rumor e o convite para uma
##   comunidade). Se ninguém ajudar, pode morrer.
## Ajudar e roubar viram boato: o errante escapa e conta na comunidade mais perto (Reputacao.boato_errante).
## Matar sem testemunha: ninguém sabe (Q40).

const NOMES_M := ["Seu Josué", "Kléber", "Wellington", "Diego", "Juarez", "Mané", "Rogério", "Seu Ari"]
const NOMES_F := ["Dona Lurdes", "Patrícia", "Rita", "Sandra", "Cida", "Tainá", "Jussara", "Dona Zefa"]
const PRESENTES := [["comida", 2], ["agua_limpa", 1], ["bandagem", 1], ["municao", 3], ["pano", 2], ["sucata", 4]]
const VEL_HOSTIL := 1.7 * IsoMath.METRO * 1.8

var tipo: String = "assustado"
var casa_p := Vector2.ZERO                    ## ponto (mundo) em volta do qual ele anda
var zumbis: Array = []                        ## os que o atacam (em_combate)
var _recompensou := false
var _indo_embora := false
var _t_ataque := 0.0
var _t_balao := 0.0
var _t_vaga := 0.0


static func criar(tipo_: String, p: Vector2, rng: RandomNumberGenerator) -> Errante:
	var e := Errante.new()
	e.tipo = tipo_
	e.casa_p = p
	var fem := rng.randf() < 0.5
	var nome_e: String = (NOMES_F if fem else NOMES_M)[rng.randi() % 8]
	var titulos := {"assustado": "sobrevivente", "ferido": "ferid" + ("a" if fem else "o"), "andarilho": "andarilho",
		"saqueador": "saqueador", "em_combate": "sobrevivente"}
	e.dados = {"id": "errante_%d" % rng.randi(), "nome": nome_e, "titulo": str(titulos[tipo_]), "genero": "f" if fem else "m",
		"papel": tipo_}
	if tipo_ == "andarilho":
		e.dados["loja"] = {"estoque": {"comida": rng.randi_range(1, 4), "agua_limpa": rng.randi_range(0, 2),
			"bandagem": rng.randi_range(0, 2), "municao": rng.randi_range(0, 4), "pano": rng.randi_range(1, 3),
			"garrafa": rng.randi_range(0, 2)}, "demanda": {"comida": 1.3, "agua_limpa": 1.2}}
	e.vida = 45.0 if tipo_ == "saqueador" else 35.0
	return e


func _ready() -> void:
	super._ready()
	add_to_group("errante")
	tarefa = "andar"
	_alvo = casa_p
	global_position = IsoMath.mundo_para_tela(casa_p)
	if tipo == "saqueador":
		_sprite.self_modulate = Color(0.85, 0.7, 0.65)
	if tipo == "ferido":
		_sprite.animation = &"deitado"


func hostil() -> bool:
	return tipo == "saqueador" and not morto


func _physics_process(delta: float) -> void:
	if morto:
		return
	_t_balao -= delta
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if _fuga_t > 0.0:
		_fugir(delta)
		return
	if conversando:
		velocity = Vector2.ZERO
		_olhar_para_jogador()
		_animar(false)
		return
	match tipo:
		"ferido":
			velocity = Vector2.ZERO
			_sprite.animation = &"deitado"
			_sprite.frame = 0
		"saqueador":
			_hostil(delta, j)
		"em_combate":
			_combate(delta)
		_:
			_vagar(delta)


func _andar_para(p: Vector2, vel: float, delta: float) -> bool:
	var v := p - _mundo()
	if v.length() < 24.0:
		velocity = Vector2.ZERO
		_animar(false)
		return true
	var dir := v.normalized()
	if _desvio_t > 0.0:
		_desvio_t -= delta
		dir = (dir * 0.35 + Vector2(-dir.y, dir.x) * _lado).normalized()
	var antes := global_position
	velocity = IsoMath.mundo_para_tela(dir * vel)
	move_and_slide()
	if IsoMath.tela_para_mundo(global_position - antes).length() < vel * delta * 0.35 and _desvio_t <= 0.0:
		_lado = 1.0 if randf() < 0.5 else -1.0
		_desvio_t = 0.5
	_passo += vel * delta * 0.09
	_olhar = dir
	_animar(true)
	return false


## Anda à toa perto do ponto dele (ou vai embora, depois de encaminhado).
func _vagar(delta: float) -> void:
	if _indo_embora:
		_andar_para(_alvo, VEL * 1.4, delta)
		return
	if _andar_para(_alvo, VEL, delta):
		_t_vaga -= delta
		_olhar_para_jogador()
		if _t_vaga <= 0.0:
			_t_vaga = randf_range(3.0, 7.0)
			_alvo = casa_p + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 260.0)


## Saqueador: vem para cima de quem chega perto e bate; ferido, foge.
func _hostil(delta: float, j: Node2D) -> void:
	_t_ataque -= delta
	if j == null or j.morto:
		_vagar(delta)
		return
	var d := IsoMath.tela_para_mundo(j.global_position - global_position).length()
	if d > 11.0 * IsoMath.METRO:
		_vagar(delta)
		return
	if _t_balao <= 0.0:
		_t_balao = 9.0
		falar(["Passa a mochila!", "Perdeu, perdeu!", "Isso aqui é nosso!"].pick_random(), 2.5)
	if d > 1.1 * IsoMath.METRO:
		_andar_para(IsoMath.tela_para_mundo(j.global_position), VEL_HOSTIL, delta)
	elif _t_ataque <= 0.0:
		_t_ataque = 1.2
		velocity = Vector2.ZERO
		j.receber_dano(7.0, "humano")
		_olhar = IsoMath.tela_para_mundo(j.global_position - global_position).normalized()
		_animar(false)


## Em combate: perde vida enquanto houver zumbi colado nele; sem zumbi por perto, acabou (grato, se vivo).
func _combate(delta: float) -> void:
	zumbis = zumbis.filter(func(z): return is_instance_valid(z) and not z.morto)
	var perto := false
	for z in zumbis:
		if IsoMath.tela_para_mundo((z as Node2D).global_position - global_position).length() < 5.0 * IsoMath.METRO:
			perto = true
	if zumbis.is_empty():
		tipo = "grato"
		falar("Valeu! Você salvou a minha vida!", 4.0)
		return
	velocity = Vector2.ZERO
	_sprite.animation = &"atacar_frente"
	_sprite.frame = int(Time.get_ticks_msec() / 150) % maxi(1, _sprite.sprite_frames.get_frame_count(&"atacar_frente"))
	if perto:
		vida -= 1.6 * delta
		if _t_balao <= 0.0:
			_t_balao = 7.0
			falar(["Socorro!", "Me ajuda aqui!", "Sai! Sai daqui!"].pick_random(), 2.5)
		if vida <= 0.0:
			_morrer()


# ───────────────────────────── dano e morte ─────────────────────────────

func receber_dano(n: float) -> void:
	if morto:
		return
	vida -= n
	_sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if vida <= 0.0:
		_morrer()
		return
	if tipo == "saqueador" and vida < 15.0:
		_fuga_t = 8.0                          # ferido, o saqueador foge
	elif tipo != "saqueador":
		_fuga_t = 6.0
		if tipo != "em_combate":
			tipo = "assustado"
		falar("Tá louco?!", 2.0)


func _morrer() -> void:
	morto = true
	conversando = false
	remove_from_group("interativo")
	_col.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_sprite.animation = &"caido"
	_sprite.frame = 0
	var j := get_tree().get_first_node_in_group("jogador")
	if tipo != "saqueador" and tipo != "em_combate" and tipo != "grato":
		Reputacao.registrar("assassinato", _mundo())     # na cidade quase nunca há quem veja
	if j != null and tipo == "saqueador":
		var item: Array = PRESENTES.pick_random()
		ItemNoChao.largar(get_parent(), global_position + Vector2(6, 2), str(item[0]), int(item[1]))
		j.aviso("O saqueador caiu. Deixou %d %s no chão." % [int(item[1]), Itens.nome(str(item[0])).to_lower()])
	elif j != null:
		j.aviso("%s está morto." % nome())
	var t := create_tween()
	t.tween_interval(20.0)
	t.tween_property(self, "modulate:a", 0.0, 2.0)
	t.tween_callback(queue_free)


# ───────────────────────────── conversa ─────────────────────────────

func texto_interacao() -> String:
	if tipo == "saqueador" or not _e_o_alvo() or conversando:
		return ""
	return "E — falar com %s" % nome()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo() or tipo == "saqueador" or conversando:
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	if tipo == "em_combate":
		j.aviso("%s: “Agora não! Me ajuda com eles!”" % nome())
		return
	var ui := DialogoUI.new()
	ui.npc = self
	ui.arvore_pronta = arvore()
	get_tree().current_scene.add_child(ui)


## Árvore de conversa gerada pelo tipo (mesmo formato de data/dialogos).
func arvore() -> Dictionary:
	var encaminhar := [
		{"texto": "Tem gente boa na Vila dos Pescadores. Vai pra lá.", "vai": "vai", "efeitos": [{"acao": "encaminhar:vila_dos_pescadores"}]},
		{"texto": "O Santuário do Sol, perto do lago, aceita gente.", "vai": "vai", "efeitos": [{"acao": "encaminhar:santuario_do_sol"}]},
	]
	var roubar := {"texto": "Passa o que você tem. Agora.", "vai": "roubado", "se": {"tem_arma": true}, "efeitos": [{"acao": "roubar"}]}
	var nos := {
		"vai": {"fala": "Sério? Então eu vou. Vou dizer que foi você que mandou.", "sem_sair": true,
			"opcoes": [{"texto": "Vai com cuidado.", "vai": "fim"}]},
		"roubado": {"fala": "Tá, tá! Leva! Só não me machuca...", "sem_sair": true, "opcoes": [{"texto": "...", "vai": "fim"}]},
	}
	match tipo:
		"ferido":
			nos["oi"] = {"fala": "Ei... me ajuda. Cortei num vidro, não para de sangrar.", "opcoes": [
				{"texto": "Toma uma bandagem.", "vai": "ajudado", "se": {"tem": {"bandagem": 1}}, "efeitos": [{"acao": "ajudar:bandagem"}]},
				{"texto": "Bebe um pouco de água.", "vai": "ajudado", "se": {"tem": {"agua_limpa": 1}}, "efeitos": [{"acao": "ajudar:agua_limpa"}]},
				{"texto": "Come alguma coisa.", "vai": "ajudado", "se": {"tem": {"comida": 1}}, "efeitos": [{"acao": "ajudar:comida"}]},
				roubar]}
			nos["ajudado"] = {"fala": "Deus te pague. Não tenho muito, mas toma isso. E escuta o que eu ouvi por aí...",
				"efeitos": [{"acao": "recompensa"}], "opcoes": encaminhar}
		"andarilho":
			nos["oi"] = {"fala": "Andarilho, sim. Troco o que carrego nas costas. Quer ver?", "opcoes": [
				{"texto": "Quero ver.", "vai": "loja"}, roubar]}
			nos["loja"] = {"fala": "Vamos lá.", "efeitos": [{"escambo": true}]}
		"grato":
			nos["oi"] = {"fala": "Você apareceu na hora certa. Eu não ia aguentar mais um. Toma, é seu.",
				"efeitos": [{"acao": "recompensa"}], "opcoes": [{"texto": "Pra onde você ia?", "vai": "convite"}] + encaminhar}
			nos["convite"] = {"fala": "Pro Santuário do Sol. Eles precisam de gente que sabe lutar... vem comigo, se quiser. Lá tem um rapaz ferido, inclusive.",
				"efeitos": [{"rumor": "guga_ferido"}], "opcoes": encaminhar}
		_:
			nos["oi"] = {"fala": ["Calma! Não atira. Eu só tô procurando comida.", "Você é de algum grupo? Faz dias que eu não vejo gente viva."].pick_random(),
				"opcoes": encaminhar + [roubar]}
	return {"inicio": [{"no": "oi"}], "nos": nos}


## Ações dos efeitos {"acao": ...} das falas (Conversas.aplicar).
func acao(a: String, ctx: Dictionary) -> PackedStringArray:
	var j: Node = ctx["jogador"]
	var msgs: PackedStringArray = []
	var partes := a.split(":")
	match partes[0]:
		"ajudar":
			j.inventario.remover(partes[1], 1)
			msgs.append("Você deu 1 %s a %s." % [Itens.nome(partes[1]).to_lower(), nome()])
			tipo = "assustado"
			_sprite.animation = &"andar_frente"
			Reputacao.boato_errante(5, "ajuda_errante")
		"recompensa":
			if not _recompensou:
				_recompensou = true
				var item: Array = PRESENTES.pick_random()
				var resto: int = j.inventario.adicionar_parcial(str(item[0]), int(item[1]))
				if resto > 0:
					j.largar_item(str(item[0]), resto)
				msgs.append("%s te deu %d %s." % [nome(), int(item[1]), Itens.nome(str(item[0])).to_lower()])
				if tipo == "grato":
					Reputacao.boato_errante(5, "ajuda_errante")
				if randf() < 0.6:
					var rid := Rumores.sortear_do_canal("bilhete")
					if rid != "":
						msgs.append(Rumores.conhecer(rid))
		"roubar":
			var lista: Array = []
			if dados.has("loja"):
				var est: Dictionary = Escambo.loja(self)["estoque"]
				for k in est:
					if int(est[k]) > 0:
						lista.append([str(k), int(est[k])])
						est[k] = 0
			else:
				lista.append(PRESENTES.pick_random())
			for it in lista:
				var resto2: int = j.inventario.adicionar_parcial(str(it[0]), int(it[1]))
				if resto2 > 0:
					j.largar_item(str(it[0]), resto2)
			msgs.append("Você tomou: %s." % Itens.texto_lista(lista))
			Reputacao.boato_errante(-8, "roubo_errante")
			_fuga_t = 8.0
			tipo = "assustado"
			_indo_embora = true
		"encaminhar":
			Simulacao.receber_sobrevivente(partes[1], nome(), str(dados.get("genero", "m")) == "f")
			Reputacao.mudar(partes[1], 4)
			msgs.append("%s vai para %s." % [nome(), Comunidades.com_artigo(partes[1])])
			_indo_embora = true
			_alvo = _mundo() + Vector2.from_angle(randf() * TAU) * 60.0 * IsoMath.METRO
			var t := create_tween()
			t.tween_interval(25.0)
			t.tween_callback(queue_free)
	return msgs
