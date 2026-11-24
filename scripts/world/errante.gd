class_name Errante
extends Npc
## Corpo de um agente do ecossistema de errantes (Errantes) quando ele está perto do jogador (etapa 10b).
## Continua o que o agente fazia: anda até o destino, vasculha, embosca, procura água ou abrigo; ferido, cai e pede
## ajuda. Luta com os monstros por perto (ou foge, conforme a índole, a vida e a munição); os monstros também o
## atacam (Inimigo escolhe a presa entre o jogador e os humanos). O que acontece aqui volta para o agente.
## Saqueador de bando: com reputação "saqueadores" abaixo de 30, embosca o jogador; acima, deixa passar, conversa e
## pode convidar para o bando. A conversa muda com o estado e com a opinião que o errante tem do jogador.

const PRESENTES := [["comida", 2], ["agua_limpa", 1], ["bandagem", 1], ["municao", 3], ["pano", 2], ["sucata", 4]]
const ALCANCE_LUTA := 9.0 * IsoMath.METRO
const REP_BANDO := 30                          ## reputação com os saqueadores para o bando te deixar passar

var agente: Dictionary = {}
var _t_ataque := 0.0
var _t_balao := 0.0
var _t_pensar_e := 0.0
var _parado_e := 0.0
var _recompensou := false
var _alvo_monstro: Node2D = null


static func de_agente(a: Dictionary) -> Errante:
	var e := Errante.new()
	e.agente = a
	var titulos := {"andarilho": "andarilho", "catador": "catador", "cacador": "caçador", "saqueador": "saqueador",
		"expedicao": "de uma comunidade", "vingador": "de uma comunidade"}
	var t: String = titulos.get(str(a["papel"]), "sobrevivente")
	if str(a["genero"]) == "f" and t in ["andarilho", "catador", "caçador", "saqueador"]:
		t = {"andarilho": "andarilha", "catador": "catadora", "caçador": "caçadora", "saqueador": "saqueadora"}[t]
	e.dados = {"id": str(a["id"]), "nome": str(a["nome"]), "titulo": t, "genero": str(a["genero"]), "papel": str(a["papel"])}
	if str(a["papel"]) == "andarilho":
		e.dados["loja"] = {"estoque": a["itens"], "demanda": {"comida": 1.3, "agua_limpa": 1.2}}
	e.vida = float(a["vida"]) * 0.45                 # 100 do agente = 45 de vida no corpo
	return e


func _ready() -> void:
	super._ready()
	add_to_group("errante")
	tarefa = "andar"
	global_position = IsoMath.mundo_para_tela(agente["p"])
	_alvo = agente["destino"]
	if str(agente["papel"]) == "saqueador":
		_sprite.self_modulate = Color(0.85, 0.7, 0.65)
	agente["real"] = true


func hostil() -> bool:
	if morto:
		return false
	if str(agente.get("papel", "")) == "vingador":
		return true
	if str(agente.get("papel", "")) == "saqueador":
		return Reputacao.valor("saqueadores") < REP_BANDO or int(agente["opiniao"]) < -20 \
			or Errantes.contratado(str(agente.get("grupo", "")))
	return (str(agente.get("indole", "")) == "hostil" and int(agente["opiniao"]) <= 0) or int(agente["opiniao"]) < -40


func caido() -> bool:
	return desacordado() or (bool(agente.get("ferido", false)) and float(agente["vida"]) < 45.0)


## Errante: foge e lembra. Se viu o rosto, o boato chega à comunidade mais perto.
func _ao_acordar(viu: bool, j: Node2D) -> void:
	agente["opiniao"] = int(agente["opiniao"]) - 60
	if not (agente["lembra"] as Array).has("rapto"):
		(agente["lembra"] as Array).append("rapto")
	if viu:
		falar("Foi você! Eu vi a sua cara!", 3.0)
		Reputacao.boato_errante(-25 if bebido else -15, "sangue" if bebido else "rapto")
		j.aviso("%s acordou e viu o seu rosto. Vai contar para alguém." % nome())
	else:
		falar("Onde... o que fizeram comigo?" if bebido else "Onde... onde eu tô?", 3.0)


## Devolve o estado do corpo para o agente (ao sumir de perto, ao morrer).
func devolver() -> void:
	agente["p"] = _mundo()
	agente["vida"] = clampf(vida / 0.45, 0.0, 100.0)
	agente["real"] = false


func _physics_process(delta: float) -> void:
	if morto:
		return
	_t_balao -= delta
	_t_ataque -= delta
	agente["p"] = _mundo()
	agente["vida"] = clampf(vida / 0.45, 0.0, 100.0)
	if desacordado():
		_desacordado()
		return
	if _fuga_t > 0.0:
		_fugir(delta)
		return
	if conversando:
		velocity = Vector2.ZERO
		_olhar_para_jogador()
		_animar(false)
		return
	if caido():
		velocity = Vector2.ZERO
		_sprite.animation = &"deitado"
		_sprite.frame = 0
		if _t_balao <= 0.0 and _dist_jogador() < 10.0 * IsoMath.METRO:
			_t_balao = 12.0
			falar("Ei... me ajuda...", 3.0)
		return
	if _lutar_com_monstros(delta):
		return
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if hostil() and j != null and not j.morto and _dist_jogador() < 11.0 * IsoMath.METRO:
		_atacar_jogador(delta, j)
		return
	_seguir_objetivo(delta)


## Anda rumo ao destino do agente; chegando, faz o que o objetivo pede e o Errantes escolhe o próximo.
func _seguir_objetivo(delta: float) -> void:
	_t_pensar_e -= delta
	if _t_pensar_e <= 0.0:
		_t_pensar_e = 2.0
		Errantes._objetivo(agente)
		_alvo = agente["destino"]
	var obj := str(agente["objetivo"])
	if obj == "emboscar" and _mundo().distance_to(_alvo) < 30.0:
		velocity = Vector2.ZERO                     # agachado, esperando quem passa
		_sprite.animation = &"agachar_frente"
		_sprite.frame = 0
		return
	if _andar_para(_alvo, VEL * (0.7 if bool(agente["ferido"]) else 1.0), delta):
		_parado_e += delta
		if obj == "vasculhar":
			_sprite.animation = &"agachar_frente"
			_sprite.frame = 0
			if _parado_e > 6.0:
				_parado_e = 0.0
				if randf() < 0.4:
					Errantes._achar(agente)
				agente["destino"] = _mundo() + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 300.0)
				_alvo = agente["destino"]
		elif _parado_e > 4.0:
			_parado_e = 0.0
			_olhar_para_jogador()


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


# ───────────────────────────── combate ─────────────────────────────

## Monstro acordado por perto: luta (índole, vida e munição) ou foge. Devolve true se está ocupado com isso.
func _lutar_com_monstros(delta: float) -> bool:
	if _alvo_monstro == null or not is_instance_valid(_alvo_monstro) or (_alvo_monstro as Inimigo).morto:
		_alvo_monstro = null
		var melhor := ALCANCE_LUTA
		for m in get_tree().get_nodes_in_group("inimigo"):
			var im := m as Inimigo
			if im == null or im.morto or im.dorme:
				continue
			var d := IsoMath.tela_para_mundo(im.global_position - global_position).length()
			if d < melhor:
				melhor = d
				_alvo_monstro = im
	if _alvo_monstro == null:
		return false
	var corajoso: bool = str(agente["indole"]) in ["hostil", "desconfiado", "oportunista"] or int(agente["municao"]) > 0
	if not corajoso or vida < 12.0:
		_fuga_t = 4.0                               # foge do bicho
		if _t_balao <= 0.0:
			_t_balao = 6.0
			falar(["Corre!", "Sai, sai!", "Socorro!"].pick_random(), 2.0)
		return true
	var pm := IsoMath.tela_para_mundo(_alvo_monstro.global_position)
	var d2 := _mundo().distance_to(pm)
	if int(agente["municao"]) > 0 and d2 < 8.0 * IsoMath.METRO and d2 > 1.5 * IsoMath.METRO:
		velocity = Vector2.ZERO
		_olhar = (pm - _mundo()).normalized()
		_animar(false)
		if _t_ataque <= 0.0:
			_t_ataque = 1.4
			agente["municao"] = int(agente["municao"]) - 1
			(_alvo_monstro as Inimigo).receber_dano(22.0, false)
			falar("*BANG*", 0.8)
		return true
	if d2 > 1.1 * IsoMath.METRO:
		_andar_para(pm, VEL * 1.5, delta)
		return true
	velocity = Vector2.ZERO
	_olhar = (pm - _mundo()).normalized()
	_sprite.animation = &"atacar_frente"
	if _t_ataque <= 0.0:
		_t_ataque = 1.0
		(_alvo_monstro as Inimigo).receber_dano(9.0 if str(agente["indole"]) != "hostil" else 12.0, false)
	return true


## Saqueador (ou hostil) para cima do jogador.
func _atacar_jogador(delta: float, j: Node2D) -> void:
	if _t_balao <= 0.0:
		_t_balao = 9.0
		falar(str(agente["frase"]) if agente.has("frase") else ["Passa a mochila!", "Perdeu, perdeu!", "Isso aqui é nosso!"].pick_random(), 2.5)
	var d := _dist_jogador()
	if int(agente["municao"]) > 0 and d < 8.0 * IsoMath.METRO and d > 2.0 * IsoMath.METRO and randf() < 0.01:
		agente["municao"] = int(agente["municao"]) - 1
		j.receber_dano(14.0, "humano")
		falar("*BANG*", 0.8)
		return
	if d > 1.1 * IsoMath.METRO:
		_andar_para(IsoMath.tela_para_mundo(j.global_position), VEL * 1.8, delta)
	elif _t_ataque <= 0.0:
		_t_ataque = 1.2
		velocity = Vector2.ZERO
		j.receber_dano(7.0, "humano")
		_olhar = IsoMath.tela_para_mundo(j.global_position - global_position).normalized()
		_animar(false)


## Golpe do jogador (por_jogador) ou de um monstro.
func receber_dano(n: float, por_jogador: bool = true) -> void:
	if morto:
		return
	vida -= n
	_sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if por_jogador:
		agente["opiniao"] = int(agente["opiniao"]) - 40
		if not (agente["lembra"] as Array).has("atacado"):
			(agente["lembra"] as Array).append("atacado")
	if vida <= 0.0:
		_morrer_por(por_jogador)
		return
	if vida < 15.0:
		_fuga_t = 8.0
		agente["ferido"] = true
	elif por_jogador and not hostil():
		_fuga_t = 6.0
		falar("Tá louco?!", 2.0)


func _morrer() -> void:
	_morrer_por(true)


func _morrer_por(por_jogador: bool) -> void:
	morto = true
	conversando = false
	remove_from_group("interativo")
	acorda_h = -1.0
	Corpo.anexar(self, nome(), true)
	if bebido:
		set_meta("mordido", true)
	_col.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_sprite.animation = &"caido"
	_sprite.frame = 0
	var era_hostil := str(agente.get("papel", "")) == "saqueador" or str(agente.get("indole", "")) == "hostil"
	devolver()
	agente["morto_por_jogador"] = por_jogador
	var lugar := Respawn.nome_do_lugar(_mundo())
	Errantes.morrer(agente, "mort%s %s" % ["a" if agente["genero"] == "f" else "o", lugar])
	var j := get_tree().get_first_node_in_group("jogador")
	if por_jogador:
		if not era_hostil:
			Reputacao.registrar("assassinato", _mundo())       # na cidade quase nunca há quem veja
		if str(agente.get("grupo", "")) != "" and str(agente.get("papel", "")) == "saqueador":
			for id in (Errantes.grupos.get(agente["grupo"], {}) as Dictionary).get("membros", []):
				var b: Dictionary = Errantes.agentes.get(id, {})
				if not b.is_empty() and bool(b["vivo"]) and (b["p"] as Vector2).distance_to(_mundo()) < 30.0 * IsoMath.METRO:
					Reputacao.mudar("saqueadores", -10)       # o bando viu: um dos seus caiu
					b["opiniao"] = int(b["opiniao"]) - 60
					break
	var it: Dictionary = agente.get("itens", {})
	var deixou: Array = []
	for k in it:
		if int(it[k]) > 0:
			deixou.append([str(k), int(it[k])])
	if not deixou.is_empty():
		var pick: Array = deixou.pick_random()
		ItemNoChao.largar(get_parent(), global_position + Vector2(6, 2), str(pick[0]), int(pick[1]))
	if j != null and por_jogador:
		j.aviso("%s está mort%s." % [nome(), "a" if agente["genero"] == "f" else "o"])


# ───────────────────────────── conversa ─────────────────────────────

func texto_interacao() -> String:
	if desacordado() and _dist_jogador() < 2.0 * IsoMath.METRO:
		return "E — %s %s" % ["soltar" if arrastado_por != null else "arrastar", nome()]
	if hostil() or not _e_o_alvo() or conversando:
		return ""
	return "E — falar com %s" % nome()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and desacordado() and _dist_jogador() < 2.0 * IsoMath.METRO:
		var jj := get_tree().get_first_node_in_group("jogador") as Node2D
		if jj != null and not bool(jj.morto):
			get_viewport().set_input_as_handled()
			Sangue.arrastar(jj, self)
		return
	if not event.is_action_pressed("interact") or not _e_o_alvo() or hostil() or conversando:
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	if _alvo_monstro != null:
		j.aviso("%s: “Agora não! Me ajuda com eles!”" % nome())
		return
	var ui := DialogoUI.new()
	ui.npc = self
	ui.arvore_pronta = arvore()
	get_tree().current_scene.add_child(ui)


## Árvore de conversa gerada pelo estado (mesmo formato de data/dialogos).
func arvore() -> Dictionary:
	var encaminhar := [
		{"texto": "Tem gente boa na Vila dos Pescadores. Vai pra lá.", "vai": "vai", "efeitos": [{"acao": "encaminhar:vila_dos_pescadores"}]},
		{"texto": "O Santuário do Sol, perto do lago, aceita gente.", "vai": "vai", "efeitos": [{"acao": "encaminhar:santuario_do_sol"}]},
	]
	var roubar := {"texto": "Passa o que você tem. Agora.", "vai": "roubado", "se": {"tem_arma": true}, "efeitos": [{"acao": "roubar"}]}
	var nos := {
		"vai": {"fala": "Sério? Então eu vou pra lá. Vou dizer que foi você que mandou.", "sem_sair": true,
			"opcoes": [{"texto": "Vai com cuidado.", "vai": "fim"}]},
		"roubado": {"fala": "Tá, tá! Leva! Só não me machuca...", "sem_sair": true, "opcoes": [{"texto": "...", "vai": "fim"}]},
	}
	var op := int(agente["opiniao"])
	if str(agente["papel"]) == "expedicao":
		nos["oi"] = {"fala": "Tô em expedição %s. Não dá pra parar muito." % Comunidades.de(str(agente["com"])), "opcoes": []}
	elif caido():
		nos["oi"] = {"fala": "Ei... me ajuda. Fui atacad%s, não para de sangrar." % ("a" if agente["genero"] == "f" else "o"), "opcoes": [
			{"texto": "Toma uma bandagem.", "vai": "ajudado", "se": {"tem": {"bandagem": 1}}, "efeitos": [{"acao": "ajudar:bandagem"}]},
			{"texto": "Bebe um pouco de água.", "vai": "ajudado", "se": {"tem": {"agua_limpa": 1}}, "efeitos": [{"acao": "ajudar:agua_limpa"}]},
			{"texto": "Come alguma coisa.", "vai": "ajudado", "se": {"tem": {"comida": 1}}, "efeitos": [{"acao": "ajudar:comida"}]},
			roubar]}
		nos["ajudado"] = {"fala": "Deus te pague. Não tenho muito, mas toma isso. E escuta o que eu ouvi por aí...",
			"efeitos": [{"acao": "recompensa"}], "opcoes": encaminhar}
	elif str(agente["papel"]) == "saqueador":
		nos["oi"] = {"fala": "Tá liberado. Os nossos falam bem de você. Por enquanto.", "opcoes": [
			{"texto": "Quero correr com vocês.", "vai": "bando", "se": {"sem_flag": "aceito_saqueadores"}},
			{"texto": "Onde vocês ficam?", "vai": "toca", "se": {"flag": "aceito_saqueadores"}}]}
		nos["bando"] = {"fala": "Você? ... Já fez o bastante pra gente ouvir falar. Tá dentro. Aparece na toca.",
			"efeitos": [{"flag": "aceito_saqueadores"}, {"acao": "toca"}]}
		nos["toca"] = {"fala": "Já te falei. A gente fica na toca. Não traz ninguém.", "efeitos": [{"acao": "toca"}]}
	elif bool(agente.get("grato", false)):
		nos["oi"] = {"fala": "Você apareceu na hora certa. Eu não ia aguentar mais um. Toma, é seu.",
			"efeitos": [{"acao": "recompensa"}], "opcoes": encaminhar}
	elif op < -20:
		nos["oi"] = {"fala": "Fica longe de mim. Eu sei o que você fez.", "opcoes": []}
	elif str(agente["papel"]) == "andarilho":
		nos["oi"] = {"fala": "Andarilh%s, sim. Troco o que carrego nas costas. Quer ver?" % ("a" if agente["genero"] == "f" else "o"),
			"opcoes": [{"texto": "Quero ver.", "vai": "loja"}, roubar] + encaminhar}
		nos["loja"] = {"fala": "Vamos lá.", "efeitos": [{"escambo": true}]}
	else:
		var falas := {"pacifico": "Oi... você é de algum grupo? Faz dias que eu não vejo gente viva.",
			"desconfiado": "Para aí. Mãos onde eu possa ver. O que você quer?",
			"oportunista": "Opa, que mochila cheia, hein? Tem comida aí pra dividir?",
			"hostil": "Some daqui antes que dê ruim."}
		nos["oi"] = {"fala": str(falas.get(str(agente["indole"]), falas["desconfiado"])), "opcoes": encaminhar + [roubar]}
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
			var medico := partes[1] == "bandagem" and Medicina.tem("tratar_ferimentos")   # curativo de quem sabe
			agente["vida"] = minf(100.0, float(agente["vida"]) + (70.0 if medico else 35.0))
			if medico:
				msgs.append("Você limpou e enfaixou direito: %s vai ficar bem." % nome())
			vida = float(agente["vida"]) * 0.45
			agente["opiniao"] = int(agente["opiniao"]) + 30
			agente["indole"] = {"hostil": "oportunista", "oportunista": "desconfiado", "desconfiado": "pacifico"}.get(agente["indole"], agente["indole"])
			Reputacao.boato_errante(5, "ajuda_errante")
		"recompensa":
			if not _recompensou and not bool(agente.get("recompensou", false)):
				_recompensou = true
				agente["recompensou"] = true
				var item: Array = PRESENTES.pick_random()
				var resto: int = j.inventario.adicionar_parcial(str(item[0]), int(item[1]))
				if resto > 0:
					j.largar_item(str(item[0]), resto)
				msgs.append("%s te deu %d %s." % [nome(), int(item[1]), Itens.nome(str(item[0])).to_lower()])
				if bool(agente.get("grato", false)):
					Reputacao.boato_errante(5, "ajuda_errante")
				if randf() < 0.6:
					var rid := Rumores.sortear_do_canal("bilhete")
					if rid != "":
						msgs.append(Rumores.conhecer(rid))
		"roubar":
			var it: Dictionary = agente["itens"]
			var lista: Array = []
			for k in it:
				if int(it[k]) > 0:
					lista.append([str(k), int(it[k])])
			if lista.is_empty():
				lista.append(PRESENTES.pick_random())
			agente["itens"] = {}
			if dados.has("loja"):
				dados["loja"]["estoque"] = agente["itens"]
			for x in lista:
				var resto2: int = j.inventario.adicionar_parcial(str(x[0]), int(x[1]))
				if resto2 > 0:
					j.largar_item(str(x[0]), resto2)
			msgs.append("Você tomou: %s." % Itens.texto_lista(lista))
			agente["opiniao"] = int(agente["opiniao"]) - 60
			(agente["lembra"] as Array).append("roubado")
			Reputacao.boato_errante(-8, "roubo_errante")
			_fuga_t = 8.0
		"encaminhar":
			agente["objetivo"] = "abrigo"
			agente["destino"] = Comunidades.geo(partes[1])["centro"]
			agente["enviado"] = partes[1]
			agente["opiniao"] = int(agente["opiniao"]) + 15
			_alvo = agente["destino"]
			msgs.append("%s vai para %s." % [nome(), Comunidades.com_artigo(partes[1])])
		"toca":
			var g: Dictionary = Errantes.grupos.get(str(agente.get("grupo", "")), {})
			if g.has("toca") and g["toca"] != Vector2.INF:
				var rid2 := "toca_%s" % str(agente["grupo"])
				var tp: Vector2 = g["toca"]
				Rumores.novidades[rid2] = {"titulo": "A toca do bando de saqueadores", "rotulo": "toca dos saqueadores",
					"texto": "O bando fica numa toca na cidade. Não leve ninguém.",
					"regiao": {"tipo": "ponto", "p": [tp.x, tp.y], "raio_m": 90, "desvio_m": 40},
					"descoberta": {"nome": "Toca dos saqueadores", "icone": "perigo"}}
				msgs.append(Rumores.conhecer(rid2))
	return msgs
