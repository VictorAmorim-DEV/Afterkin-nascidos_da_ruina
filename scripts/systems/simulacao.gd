class_name Simulacao
extends RefCounted
## Ecossistema das comunidades (marco 2, etapa 8; docs/DECISOES_DESIGN.md Q39, Q43 e Q44).
##
## Longe do jogador tudo é abstrato: cada comunidade tem reservas (comida em dias, remédio, munição), população,
## feridos, habilidades e a relação com as outras. A cada TURNO_H horas de jogo ela produz, consome, cuida dos
## feridos e decide UMA ação pelas necessidades: expedição à cidade, levar o ferido a quem sabe Medicina, trocar com
## a vizinha, aprender uma habilidade ou ficar quieta. O resultado é sorteado com risco (ferido, morte, nada achado).
## Perto do jogador, os efeitos aparecem: quem saiu em expedição some da comunidade, quem se feriu fica em casa,
## quem morreu não volta (Reputacao.mortos). Tudo vai para o diário, de onde a etapa 9 tira os rumores.
## A expedição é um agente do ecossistema de errantes (Errantes, etapa 10b): sai, anda até a cidade, vasculha, corre
## os riscos do caminho e volta (ou não); a comunidade espera e recebe o que ele trouxe.
## Os valores iniciais ficam em "simulacao" no arquivo da comunidade.

const TURNO_H := 6.0
const CONSUMO_DIA := 1.0               ## a comunidade come 1 dia de comida por dia
const DIARIO_MAX := 60

## id -> {comida, remedio, municao, pop, feridos: [{quem, nome, grav, tratado, hosp}], hab: [..], rel: {id: n},
##        acao: {tipo, ate, quem, destino}, ultimo_h}
static var com: Dictionary = {}
static var diario: Array = []          ## [{dia, hora, com, texto}]
static var _ultimo_h: float = -1.0


static func zerar() -> void:
	com = {}
	diario = []
	_ultimo_h = -1.0


static func _iniciar() -> void:
	if not com.is_empty():
		return
	for id in Comunidades.ids():
		var d := Comunidades.dados(str(id))
		var s: Dictionary = d.get("simulacao", {})
		var hab: Array = []
		for n in d.get("npcs", []):
			for h in (n as Dictionary).get("habilidades", []):
				if not hab.has(h):
					hab.append(h)
		var rel: Dictionary = {}
		var tipos := {"aliada": 40, "neutra": 0, "rival": -40}
		var rd: Dictionary = d.get("relacoes", {})
		for outra in rd:
			rel[str(outra)] = int(tipos.get(str(rd[outra]), 0))
		var feridos: Array = []
		for f in s.get("feridos", []):
			var fd: Dictionary = f
			feridos.append({"quem": str(fd["quem"]), "nome": _nome_npc(str(id), str(fd["quem"])), "grav": float(fd["grav"]),
				"tratado": false, "hosp": ""})
		com[str(id)] = {"comida": float(s.get("comida", 5.0)), "remedio": int(s.get("remedio", 0)),
			"municao": int(s.get("municao", 0)), "pop": int(s.get("pop", 10)),
			"producao": float(s.get("producao", 1.0)), "feridos": feridos, "hab": hab, "rel": rel, "acao": {}}
	_ultimo_h = Reputacao.agora_h()


## Palavra no masculino ou feminino conforme o NPC ("ferido"/"ferida"); figurante = masculino.
static func _g(id: String, npc: String, m: String, f: String) -> String:
	for n in Comunidades.dados(id).get("npcs", []):
		if str((n as Dictionary)["id"]) == npc:
			return f if str((n as Dictionary).get("genero", "m")) == "f" else m
	return m


static func _nome_npc(id: String, npc: String) -> String:
	for n in Comunidades.dados(id).get("npcs", []):
		if str((n as Dictionary)["id"]) == npc:
			return str((n as Dictionary)["nome"])
	return "um morador"


static func estado(id: String) -> Dictionary:
	_iniciar()
	return com.get(id, {})


# ───────────────────────────── relógio ─────────────────────────────

## Chamado pelo GerenteComunidades: roda os turnos que couberam no tempo que passou (inclusive o sono).
static func passo() -> void:
	_iniciar()
	var h := Reputacao.agora_h()
	if _ultimo_h < 0.0:
		_ultimo_h = h
	var turnos := 0
	while h - _ultimo_h >= TURNO_H and turnos < 12:
		_ultimo_h += TURNO_H
		turnos += 1
		for id in com:
			_turno(str(id), _ultimo_h)


static func _turno(id: String, h: float) -> void:
	var c: Dictionary = com[id]
	var f := TURNO_H / 24.0
	# produção e consumo (o forte da comunidade, com sorte e azar)
	c["comida"] = maxf(0.0, float(c["comida"]) + (float(c["producao"]) * randf_range(0.7, 1.3) - CONSUMO_DIA) * f)
	if float(c["comida"]) <= 0.0 and randf() < 0.1:
		_registrar(id, "A fome aperta %s: as porções foram cortadas pela metade." % Comunidades.em_nome(id))
	_cuidar_feridos(id, f)
	# ação em andamento
	var a: Dictionary = c["acao"]
	if not a.is_empty():
		if str(a["tipo"]) == "expedicao":
			var ag: Dictionary = Errantes.agentes.get(str(a.get("agente", "")), {})
			if ag.is_empty() or not bool(ag["vivo"]) or h >= float(a["ate"]):
				_concluir(id, a)
				c["acao"] = {}
		elif h >= float(a["ate"]):
			_concluir(id, a)
			c["acao"] = {}
		return
	_decidir(id, h)


# ───────────────────────────── feridos ─────────────────────────────

static func _cuidar_feridos(id: String, f: float) -> void:
	var c: Dictionary = com[id]
	var restam: Array = []
	for fr in c["feridos"]:
		var fd: Dictionary = fr
		var onde: String = fd["hosp"] if str(fd["hosp"]) != "" else id
		var medico: bool = (com[onde]["hab"] as Array).has("medicina")
		if bool(fd["tratado"]) or (medico and int(com[onde]["remedio"]) > 0):
			if not bool(fd["tratado"]) and medico:
				com[onde]["remedio"] = int(com[onde]["remedio"]) - 1     # o tratamento gasta um remédio
				fd["tratado"] = true
			fd["grav"] = float(fd["grav"]) - 0.25 * f
		else:
			fd["grav"] = float(fd["grav"]) + 0.08 * f
		if float(fd["grav"]) >= 1.0:
			_morreu(id, fd, "não resistiu aos ferimentos")
			continue
		if float(fd["grav"]) <= 0.0:
			_registrar(id, "%s, %s, se recuperou%s." % [fd["nome"], Comunidades.de(id),
				" na casa do médico" if str(fd["hosp"]) != "" else ""])
			if str(fd["quem"]) != "":
				Conversas.flags["%s_curado" % fd["quem"]] = true
				Conversas.flags["%s_%s_curado" % [id, fd["quem"]]] = true
			continue
		restam.append(fd)
	c["feridos"] = restam


static func _morreu(id: String, fd: Dictionary, como: String) -> void:
	var c: Dictionary = com[id]
	c["pop"] = maxi(0, int(c["pop"]) - 1)
	if str(fd.get("quem", "")) != "":
		Reputacao.npc_morreu(id, str(fd["quem"]))
	_registrar(id, "%s, %s, %s." % [fd["nome"], Comunidades.de(id), como])


## Um sobrevivente encaminhado pelo jogador chegou: a comunidade cresce e registra no diário.
static func receber_sobrevivente(id: String, quem: String, fem: bool = false, pelo_jogador: bool = true) -> void:
	var c := estado(id)
	if c.is_empty():
		return
	c["pop"] = int(c["pop"]) + 1
	if pelo_jogador:
		_registrar(id, "%s chegou %s dizendo que foi %s por alguém de fora." % [quem, Comunidades.em_nome(id),
			"mandada" if fem else "mandado"])
	else:
		_registrar(id, "%s chegou %s pedindo abrigo e foi %s." % [quem, Comunidades.em_nome(id), "aceita" if fem else "aceito"])


## Notícia do mundo lá fora (errantes): vai para o diário com a comunidade mais perto (ou "").
static func registrar_noticia(id: String, texto: String) -> void:
	_registrar(id, texto)


## O jogador tratou um ferido (antibiótico + instruções do médico, ou a Medicina dele): passa a melhorar.
## 'reducao' é quanto a gravidade cai na hora (o kit cirúrgico tira da beira da morte).
static func tratar(id: String, npc: String, reducao: float = 0.15) -> bool:
	for fr in estado(id).get("feridos", []):
		var fd: Dictionary = fr
		if str(fd["quem"]) == npc:
			fd["tratado"] = true
			fd["grav"] = maxf(0.05, float(fd["grav"]) - reducao)
			_registrar(id, "Alguém de fora tratou %s, %s." % [fd["nome"], Comunidades.de(id)])
			Medicina.tratou(id, npc)
			return true
	return false


static func ferido(id: String, npc: String) -> Dictionary:
	for fr in estado(id).get("feridos", []):
		if str((fr as Dictionary)["quem"]) == npc:
			return fr
	return {}


## O NPC saiu (expedição, viagem com o ferido) ou está hospedado em outra comunidade?
static func ausente(id: String, npc: String) -> bool:
	var a: Dictionary = estado(id).get("acao", {})
	if not a.is_empty() and (a.get("quem", []) as Array).has(npc):
		return true
	var fd := ferido(id, npc)
	return not fd.is_empty() and str(fd["hosp"]) != ""


# ───────────────────────────── decisões ─────────────────────────────

static func _decidir(id: String, h: float) -> void:
	var c: Dictionary = com[id]
	var grave := 0.0
	var mais_grave: Dictionary = {}
	for fr in c["feridos"]:
		if str((fr as Dictionary)["hosp"]) == "" and not bool((fr as Dictionary)["tratado"]):
			if float((fr as Dictionary)["grav"]) > grave:
				grave = float((fr as Dictionary)["grav"])
				mais_grave = fr
	var tem_med: bool = (c["hab"] as Array).has("medicina")
	# 0) o jogador sabe Medicina: quem não tem médico manda pedir ajuda (sem deixar de decidir o resto)
	if grave > 0.0 and not tem_med:
		Medicina.pedir_ajuda(id, mais_grave)
	# 1) ferido e ninguém que saiba tratar: levar a quem sabe (o orgulho só cede com o recado ou no desespero)
	if grave > 0.0 and not tem_med:
		var destino := _quem_tem("medicina", id)
		var orgulho_cedeu: bool = Conversas.flags.has("caio_aceita_ajuda") or id != "santuario_do_sol" \
			or (grave > 0.75 and randf() < 0.08)
		if destino != "" and orgulho_cedeu and int(c["rel"].get(destino, 0)) > -30:
			_levar_ferido(id, destino, h)
			return
		if int(c["remedio"]) <= 0 and randf() < 0.6:
			_expedicao(id, "remedio", h)
			return
	# 2) comida acabando: trocar com a vizinha que tem sobra, senão expedição
	if float(c["comida"]) < 2.5:
		var vizinha := _quem_tem_sobra("comida", id)
		if vizinha != "" and int(c["municao"]) >= 2 and int(c["rel"].get(vizinha, 0)) >= -10:
			_trocar(id, vizinha, "comida", "municao")
			return
		_expedicao(id, "comida", h)
		return
	# 3) sem aperto: aprender com a vizinha amiga, ou uma expedição de vez em quando
	if not tem_med and randf() < 0.15:
		var mestre := _quem_tem("medicina", id)
		if mestre != "" and int(c["rel"].get(mestre, 0)) >= 30:
			_registrar(id, "%s mandou alguém aprender Medicina %s." % [_Cap(Comunidades.com_artigo(id)), Comunidades.em_nome(mestre)])
			c["acao"] = {"tipo": "aprender", "ate": h + 72.0, "quem": [], "destino": mestre, "hab": "medicina"}
			return
	if randf() < 0.12:
		_expedicao(id, "sucata", h)
	elif randf() < 0.04:
		_incidente(id)


static func _quem_tem(hab: String, exceto: String) -> String:
	for outra in com:
		if str(outra) != exceto and (com[outra]["hab"] as Array).has(hab):
			return str(outra)
	return ""


static func _quem_tem_sobra(rec: String, exceto: String) -> String:
	for outra in com:
		if str(outra) != exceto and float(com[outra][rec]) > 6.0:
			return str(outra)
	return ""


## Quem vai para fora: um NPC com o papel certo que esteja vivo e em casa, senão um morador qualquer.
static func _escolher_quem(id: String, papeis: Array) -> String:
	for n in Comunidades.dados(id).get("npcs", []):
		var nd: Dictionary = n
		var nid := str(nd["id"])
		if papeis.has(str(nd.get("papel", ""))) and Reputacao.vivo(id, nid) and ferido(id, nid).is_empty() and not ausente(id, nid):
			return nid
	return ""


static func _expedicao(id: String, alvo: String, h: float) -> void:
	var c: Dictionary = com[id]
	var quem := _escolher_quem(id, ["cacador", "pescador", "guarda", "comerciante"]) if randf() < 0.5 else ""
	var nome := _nome_npc(id, quem) if quem != "" else "um grupo de moradores"
	var agente := Errantes.expedicao(id, alvo, quem, _Cap(nome) if quem == "" else nome, _g(id, quem, "m", "f") == "f")
	c["acao"] = {"tipo": "expedicao", "alvo": alvo, "ate": h + 60.0, "quem": [quem] if quem != "" else [], "agente": agente}
	_registrar(id, "%s saiu %s atrás de %s na cidade." % [_Cap(nome), Comunidades.de(id),
		{"remedio": "remédio", "comida": "comida", "sucata": "material"}[alvo]])


static func _levar_ferido(id: String, destino: String, h: float) -> void:
	var c: Dictionary = com[id]
	for fr in c["feridos"]:
		var fd: Dictionary = fr
		if str(fd["hosp"]) == "":
			fd["hosp"] = destino
			c["rel"][destino] = int(c["rel"].get(destino, 0)) + 10
			com[destino]["rel"][id] = int(com[destino]["rel"].get(id, 0)) + 5
			_registrar(id, "%s levou %s até %s para ser %s." % [_Cap(Comunidades.com_artigo(id)), fd["nome"],
				Comunidades.com_artigo(destino), _g(id, str(fd["quem"]), "tratado", "tratada")])
			if randf() < 0.15:
				fd["grav"] = float(fd["grav"]) + 0.1
				_registrar(id, "A viagem com %s foi dura: os da noite seguiram o grupo por um bom trecho." % fd["nome"])
			return


static func _trocar(id: String, vizinha: String, recebe: String, paga: String) -> void:
	var c: Dictionary = com[id]
	var v: Dictionary = com[vizinha]
	c[paga] = int(c[paga]) - 2
	v[paga] = int(v[paga]) + 2
	c[recebe] = float(c[recebe]) + 3.0
	v[recebe] = float(v[recebe]) - 3.0
	c["rel"][vizinha] = int(c["rel"].get(vizinha, 0)) + 4
	v["rel"][id] = int(v["rel"].get(id, 0)) + 4
	_registrar(id, "%s trocou munição por comida com %s." % [_Cap(Comunidades.com_artigo(id)), Comunidades.com_artigo(vizinha)])


static func _concluir(id: String, a: Dictionary) -> void:
	var c: Dictionary = com[id]
	match str(a["tipo"]):
		"expedicao":
			_fim_expedicao(id, a)
		"aprender":
			if not (c["hab"] as Array).has(str(a["hab"])):
				(c["hab"] as Array).append(str(a["hab"]))
			_registrar(id, "%s agora tem alguém que sabe %s." % [_Cap(Comunidades.com_artigo(id)), "Medicina" if a["hab"] == "medicina" else a["hab"]])


## A expedição (agente do Errantes) voltou, morreu ou sumiu: a comunidade recebe o que veio.
static func _fim_expedicao(id: String, a: Dictionary) -> void:
	var c: Dictionary = com[id]
	var aid := str(a.get("agente", ""))
	var ag: Dictionary = Errantes.agentes.get(aid, {})
	var quem: Array = a.get("quem", [])
	var npc_id := str(quem[0]) if not quem.is_empty() else ""
	if ag.is_empty() or not bool(ag.get("voltou", false)):
		if not ag.is_empty() and bool(ag["vivo"]):
			Errantes.morrer(ag, "perdido na cidade")          # passou do tempo: não volta mais
		c["pop"] = maxi(0, int(c["pop"]) - 1)
		Errantes.agentes.erase(aid)
		return
	var trouxe: Dictionary = ag.get("itens", {})
	var partes: PackedStringArray = []
	for item in trouxe:
		var n := int(trouxe[item])
		if n <= 0:
			continue
		match str(item):
			"comida":
				c["comida"] = float(c["comida"]) + n * 1.0
			"antibiotico", "bandagem":
				c["remedio"] = int(c["remedio"]) + n
			"municao":
				c["municao"] = int(c["municao"]) + n
		partes.append("%d %s" % [n, Itens.nome(str(item)).to_lower()])
	var nome := str(ag["nome"])
	if float(ag["vida"]) < 70.0:
		(c["feridos"] as Array).append({"quem": npc_id, "nome": nome, "grav": clampf((100.0 - float(ag["vida"])) / 100.0, 0.2, 0.7),
			"tratado": false, "hosp": ""})
		_registrar(id, "%s voltou %s da cidade (%s)." % [nome, _g(id, npc_id, "ferido", "ferida"), Comunidades.nome(id)])
	if partes.is_empty():
		_registrar(id, "%s voltou da cidade de mãos vazias (%s)." % [nome, Comunidades.nome(id)])
	else:
		_registrar(id, "%s voltou da cidade com %s (%s)." % [nome, ", ".join(partes), Comunidades.nome(id)])
	Errantes.agentes.erase(aid)


static func _incidente(id: String) -> void:
	var c: Dictionary = com[id]
	if randf() < 0.5:
		c["comida"] = maxf(0.0, float(c["comida"]) - 1.5)
		_registrar(id, "Ratos entraram no depósito %s e estragaram parte da comida." % Comunidades.de(id))
	else:
		c["municao"] = maxi(0, int(c["municao"]) - 1)
		_registrar(id, "Os da noite rondaram o muro %s; gastaram munição para espantar." % Comunidades.de(id))


# ───────────────────────────── jogador e trocas ─────────────────────────────

## O jogador trocou com um comerciante: o que entra e sai muda as reservas da comunidade.
const RECURSO_DO_ITEM := {"comida": "comida", "antibiotico": "remedio", "bandagem": "remedio", "municao": "municao"}


static func ajustar(id: String, item: String, delta: int) -> void:
	if not RECURSO_DO_ITEM.has(item) or estado(id).is_empty():
		return
	var rec: String = RECURSO_DO_ITEM[item]
	var c: Dictionary = com[id]
	if rec == "comida":
		c["comida"] = maxf(0.0, float(c["comida"]) + delta * 0.1)       # 10 comidas ≈ 1 dia da comunidade
	else:
		c[rec] = maxi(0, int(c[rec]) + delta)


## A comunidade precisa muito disto? Multiplica o que o comerciante dela paga (demanda vinda da simulação).
static func demanda(id: String, item: String) -> float:
	var c := estado(id)
	if c.is_empty():
		return 1.0
	match str(RECURSO_DO_ITEM.get(item, "")):
		"comida":
			return 1.6 if float(c["comida"]) < 2.5 else 1.0
		"remedio":
			return 1.5 if not (c["feridos"] as Array).is_empty() and int(c["remedio"]) <= 0 else 1.0
		"municao":
			return 1.3 if int(c["municao"]) <= 1 else 1.0
	return 1.0


# ───────────────────────────── diário ─────────────────────────────

static func _Cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s



static func _registrar(id: String, texto: String) -> void:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	diario.append({"dia": int(c.dia) if c != null else 1, "hora": int(float(c.minutos) / 60.0) if c != null else 0,
		"com": id, "texto": texto})
	if diario.size() > DIARIO_MAX:
		diario = diario.slice(diario.size() - DIARIO_MAX)


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"com": com.duplicate(true), "diario": diario.duplicate(true), "ultimo_h": _ultimo_h}


static func restaurar(d: Dictionary) -> void:
	zerar()
	var cd: Dictionary = d.get("com", {})
	for id in cd:
		var c: Dictionary = (cd[id] as Dictionary).duplicate(true)
		for k in ["remedio", "municao", "pop"]:
			c[k] = int(c.get(k, 0))
		for k in ["comida", "producao"]:
			c[k] = float(c.get(k, 0.0))
		var rel: Dictionary = {}
		for o in (c.get("rel", {}) as Dictionary):
			rel[str(o)] = int(c["rel"][o])
		c["rel"] = rel
		com[str(id)] = c
	diario = (d.get("diario", []) as Array).duplicate(true)
	_ultimo_h = float(d.get("ultimo_h", -1.0))
