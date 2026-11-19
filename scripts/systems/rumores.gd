class_name Rumores
extends RefCounted
## Rumores (marco 2, etapa 9; docs/DECISOES_DESIGN.md Q23 e Q47).
##
## Dois tipos:
## - fixos, em data/rumores.json: título, texto, a REGIÃO aproximada no mapa (nunca o ponto exato) e o canal
##   ("bilhete" ou "radio") quando vêm do loot ou do rádio; os outros saem das conversas;
## - novidades, tiradas do diário da Simulacao ("Seu Bento voltou ferido da cidade"): os NPCs contam ("Alguma
##   novidade?"), conversam entre si perto do jogador e põem no mural da comunidade.
## Canais (Q47): conversa, conversas ouvidas, mural e bilhetes, rádio. O que o jogador conhece fica em
## Conversas.rumores; as novidades ganham um id "nov_<n>" e o texto.

static var novidades: Dictionary = {}       ## id -> {titulo, texto, com, dia}
static var _regioes: Dictionary = {}        ## cache: id -> {centro, raio}


static func zerar() -> void:
	novidades = {}
	_regioes = {}


static func dados(id: String) -> Dictionary:
	if novidades.has(id):
		return novidades[id]
	return Conversas.rumor(id)


static func titulo(id: String) -> String:
	return str(dados(id).get("titulo", id))


static func conhece(id: String) -> bool:
	return Conversas.rumores.has(id)


## O jogador fica sabendo do rumor. Rumor que aponta um acampamento o descobre no mapa. Devolve o aviso ("" se já sabia).
static func conhecer(id: String) -> String:
	if conhece(id):
		return ""
	Conversas.rumores[id] = true
	var reg: Dictionary = dados(id).get("regiao", {})
	if str(reg.get("tipo", "")) == "acampamento" and not Descobertas.acampamentos.has(str(reg["ref"])):
		Descobertas.acampamentos.append(str(reg["ref"]))
	if str(reg.get("tipo", "")) == "comunidade":
		var local := str(Comunidades.dados(str(reg["ref"])).get("local", ""))
		if local.begins_with("Acampamento") and not Descobertas.acampamentos.has(local):
			Descobertas.acampamentos.append(local)
	return "Rumor anotado: %s" % titulo(id)


## Rumor fixo do canal ("bilhete", "radio") que o jogador ainda não conhece, sorteado; "" se acabaram.
static func sortear_do_canal(canal: String) -> String:
	Conversas.rumor("")                       # garante a tabela carregada
	var opcoes: Array = []
	for id in Conversas._tab_rumores:
		if str((Conversas._tab_rumores[id] as Dictionary).get("canal", "")) == canal and not conhece(str(id)):
			opcoes.append(str(id))
	return "" if opcoes.is_empty() else str(opcoes[randi() % opcoes.size()])


# ───────────────────────────── regiões ─────────────────────────────

## {centro: Vector2 (mundo), raio: float (u)} ou {} se o rumor não marca o mapa. O centro é deslocado de forma
## fixa (por id) do ponto real, para a região não entregar o lugar exato.
static func regiao(id: String) -> Dictionary:
	if _regioes.has(id):
		return _regioes[id]
	var reg: Dictionary = dados(id).get("regiao", {})
	var r := {}
	var p := _ponto(reg)
	if p != Vector2.INF:
		var g := RandomNumberGenerator.new()
		g.seed = hash(id)
		var desvio := float(reg.get("desvio_m", 0.0)) * IsoMath.METRO * g.randf()
		r = {"centro": p + Vector2.from_angle(g.randf() * TAU) * desvio, "raio": float(reg.get("raio_m", 150.0)) * IsoMath.METRO}
	_regioes[id] = r
	return r


static func _ponto(reg: Dictionary) -> Vector2:
	var ref := str(reg.get("ref", ""))
	match str(reg.get("tipo", "")):
		"comunidade":
			var g := Comunidades.geo(ref)
			return g["centro"] if not g.is_empty() else Vector2.INF
		"acampamento":
			for c in MundoGen.acampamentos():
				if str((c as Dictionary)["nome"]) == ref:
					return (c as Dictionary)["c"]
		"area":
			for a in MundoGen.AREAS.size():
				if str(MundoGen.AREAS[a]["nome"]) == ref:
					return MundoGen.area_rect(a).get_center()
		"poi":
			var area := Rect2()
			for a in MundoGen.AREAS.size():
				if str(MundoGen.AREAS[a]["nome"]) == str(reg.get("area", "")):
					area = MundoGen.area_rect(a)
			for poi in Descobertas.pois():
				if str((poi as Dictionary)["uso"]) == ref and (not area.has_area() or area.has_point((poi as Dictionary)["p"])):
					return (poi as Dictionary)["p"]
		"ninho_perto":
			var g2 := Comunidades.geo(ref)
			if g2.is_empty():
				return Vector2.INF
			var melhor := Vector2.INF
			for n in MundoGen.ninhos():
				if melhor == Vector2.INF or (n as Vector2).distance_to(g2["centro"]) < melhor.distance_to(g2["centro"]):
					melhor = n
			return melhor
	return Vector2.INF


## Rumores conhecidos que marcam o mapa: [id].
static func no_mapa() -> Array:
	var out: Array = []
	for id in Conversas.rumores:
		if not regiao(str(id)).is_empty():
			out.append(str(id))
	return out


# ───────────────────────────── novidades (diário da Simulacao) ─────────────────────────────

## Novidade que um NPC da comunidade 'com' pode contar e o jogador ainda não ouviu: as da própria comunidade nos
## últimos 3 dias, e as das outras com mais de meio dia (o tempo de a notícia viajar). {} se nada.
static func novidade_para(com: String) -> Dictionary:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	var agora_h := float(c.dia) * 24.0 + float(c.minutos) / 60.0 if c != null else 0.0
	for i in range(Simulacao.diario.size() - 1, -1, -1):
		var e: Dictionary = Simulacao.diario[i]
		var h := float(e["dia"]) * 24.0 + float(e["hora"])
		if agora_h - h > 72.0:
			break
		if str(e["com"]) != com and agora_h - h < 12.0:
			continue
		var id := "nov_%d_%d_%d" % [int(e["dia"]), int(e["hora"]), absi(hash(str(e["texto"]))) % 100000]
		if not conhece(id):
			return {"id": id, "texto": str(e["texto"]), "com": str(e["com"]), "dia": int(e["dia"])}
	return {}


## O jogador ouviu a novidade 'n' (de novidade_para).
static func ouvir(n: Dictionary) -> String:
	novidades[str(n["id"])] = {"titulo": str(n["texto"]), "texto": str(n["texto"]), "com": str(n["com"]), "dia": int(n["dia"])}
	return conhecer(str(n["id"]))


# ───────────────────────────── rádio ─────────────────────────────

## Ligar o rádio de pilha: de madrugada pega uma transmissão (rumor do canal "radio") por noite.
static func usar_radio(j: Node) -> void:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	var h := float(c.minutos) / 60.0 if c != null else 12.0
	if h >= 5.0:
		j.aviso("Só chiado. Dizem que de madrugada pega alguma coisa.")
		return
	var noite := "radio_noite_%d" % (int(c.dia) if c != null else 0)
	if Conversas.flags.has(noite):
		j.aviso("Chiado. Ninguém mais falou esta noite.")
		return
	var id := sortear_do_canal("radio")
	Conversas.flags[noite] = true
	if id == "":
		j.aviso("Chiado... uma voz distante, cortada. Nada que dê para entender.")
		return
	conhecer(id)
	j.aviso("O rádio pega uma voz: %s (Rumor anotado: %s)" % [str(dados(id).get("texto", "")), titulo(id)])


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"novidades": novidades.duplicate(true)}


static func restaurar(d: Dictionary) -> void:
	zerar()
	novidades = (d.get("novidades", {}) as Dictionary).duplicate(true)
