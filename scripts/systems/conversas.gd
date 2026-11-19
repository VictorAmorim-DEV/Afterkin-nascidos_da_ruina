class_name Conversas
extends RefCounted
## Diálogo em árvore com os NPCs das comunidades (marco 2, etapa 5; docs/DECISOES_DESIGN.md Q37).
##
## As conversas ficam em data/dialogos/<comunidade>.json: { "<id do NPC>": árvore }. Uma árvore tem:
##   "inicio": [{"se": {condições}, "no": "<nó>"}, ...]   → o primeiro que valer abre a conversa
##   "nos": {"<nó>": {"fala": "...", "efeitos": [...], "opcoes": [{"texto", "se", "efeitos", "vai"}]}}
## "vai": "<nó>" ou "fim". Toda fala ganha no fim a opção de ir embora ("sem_sair": true tira).
##
## Condições ("se"): rep_min, rep_max (reputação na comunidade), fase (lista: madrugada, amanhecer, manha, tarde,
## tardezinha, noite), origem (texto ou lista), genero ("m"/"f"), flag, sem_flag, rumor, sem_rumor, visto (já
## conversou com este NPC), tem ({"item": qtd} na mochila).
## Efeitos: {"rep": n} (n na comunidade; "com" para outra), {"flag": "x"}, {"tira_flag": "x"}, {"rumor": "id"}
## (data/rumores.json), {"dar": "item", "qtd": n}, {"pedir": "item", "qtd": n}, {"escambo": true}.
## Texto: "{filho/filha}" usa a primeira forma para personagem masculino e a segunda para feminino.
##
## A reputação é a da Reputacao (testemunhas e boatos); o efeito "rep" de uma conversa muda a da comunidade na hora.
## Condição "lembra": o NPC lembra de um evento (furto, agressao, assassinato, defesa) que viu ou ouviu.

const PASTA := "res://data/dialogos"
const RUMORES := "res://data/rumores.json"

static var flags: Dictionary = {}           ## nome -> true
static var rumores: Dictionary = {}         ## id -> true (rumores que o jogador conhece)
static var vistos: Dictionary = {}          ## "comunidade/npc" -> true

static var _arvores: Dictionary = {}        ## comunidade -> {npc: árvore}
static var _tab_rumores: Dictionary = {}


static func zerar() -> void:
	flags = {}
	rumores = {}
	vistos = {}


static func arvore(com: String, npc: String) -> Dictionary:
	if not _arvores.has(com):
		var arq := "%s/%s.json" % [PASTA, com]
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(arq)) if FileAccess.file_exists(arq) else {}
		if not d is Dictionary:
			push_error("Conversas: %s não é um JSON válido." % arq)
			d = {}
		_arvores[com] = d
	return ((_arvores[com] as Dictionary).get(npc, {}) as Dictionary)


static func rumor(id: String) -> Dictionary:
	if _tab_rumores.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUMORES)) if FileAccess.file_exists(RUMORES) else {}
		_tab_rumores = d if d is Dictionary else {}
	return (_tab_rumores.get(id, {}) as Dictionary)


static func reputacao(com: String) -> int:
	return Reputacao.valor(com)


# ───────────────────────────── condições ─────────────────────────────

## ctx = {"com": id, "npc": id, "jogador": Node}
static func vale(se: Dictionary, ctx: Dictionary) -> bool:
	var com: String = ctx["com"]
	var j: Node = ctx["jogador"]
	for k in se:
		var v: Variant = se[k]
		match k:
			"rep_min":
				if reputacao(com) < int(v): return false
			"rep_max":
				if reputacao(com) > int(v): return false
			"fase":
				if not (v as Array).has(_fase()): return false
			"origem":
				var o: String = str(j.origem) if j != null else ""
				if v is Array:
					if not (v as Array).has(o): return false
				elif o != str(v): return false
			"genero":
				if (str(j.genero) if j != null else "m") != str(v): return false
			"flag":
				if not flags.has(str(v)): return false
			"sem_flag":
				if flags.has(str(v)): return false
			"rumor":
				if not rumores.has(str(v)): return false
			"sem_rumor":
				if rumores.has(str(v)): return false
			"visto":
				if vistos.has("%s/%s" % [com, ctx["npc"]]) != bool(v): return false
			"lembra":
				var achou := false
				for m in Reputacao.memoria(com, str(ctx["npc"])):
					if str((m as Dictionary)["ev"]) == str(v):
						achou = true
				if not achou: return false
			"tem":
				for item in (v as Dictionary):
					if j == null or j.inventario.contar(str(item)) < int((v as Dictionary)[item]): return false
	return true


static func _fase() -> String:
	var arvore_cena := Engine.get_main_loop() as SceneTree
	var ciclo: Node = arvore_cena.get_first_node_in_group("ciclo_dia_noite") if arvore_cena != null else null
	return Comunidades.CHAVES_FASE[int(ciclo.fase()) if ciclo != null else 2]


# ───────────────────────────── efeitos ─────────────────────────────

## Aplica os efeitos; devolve as mensagens curtas para o jogador (rumor anotado, item recebido...).
static func aplicar(efeitos: Array, ctx: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var j: Node = ctx["jogador"]
	for e in efeitos:
		var ed: Dictionary = e
		if ed.has("rep"):
			Reputacao.mudar(str(ed.get("com", ctx["com"])), int(ed["rep"]))
		if ed.has("flag"):
			flags[str(ed["flag"])] = true
		if ed.has("tira_flag"):
			flags.erase(str(ed["tira_flag"]))
		if ed.has("rumor") and not rumores.has(str(ed["rumor"])):
			rumores[str(ed["rumor"])] = true
			var r := rumor(str(ed["rumor"]))
			msgs.append("Rumor anotado: %s" % str(r.get("titulo", ed["rumor"])))
		if ed.has("dar") and j != null:
			var qtd := int(ed.get("qtd", 1))
			var resto: int = j.inventario.adicionar_parcial(str(ed["dar"]), qtd)
			if resto > 0:
				j.largar_item(str(ed["dar"]), resto)
			msgs.append("Você recebeu %d %s." % [qtd, Itens.nome(str(ed["dar"])).to_lower()])
		if ed.has("pedir") and j != null:
			var qtd2 := int(ed.get("qtd", 1))
			j.inventario.remover(str(ed["pedir"]), qtd2)
			msgs.append("Você entregou %d %s." % [qtd2, Itens.nome(str(ed["pedir"])).to_lower()])
		if ed.has("escambo"):
			ctx["abrir_escambo"] = true            # a DialogoUI fecha a conversa e abre a TelaEscambo
	return msgs


# ───────────────────────────── texto ─────────────────────────────

## "{filho/filha}" → a forma do gênero do personagem; "{comunidade}" → o nome da comunidade.
static func texto(s: String, ctx: Dictionary) -> String:
	var j: Node = ctx["jogador"]
	var fem: bool = j != null and str(j.genero) == "f"
	var out := s.replace("{comunidade}", Comunidades.nome(str(ctx["com"])))
	var re := RegEx.create_from_string("\\{([^{}/]*)/([^{}/]*)\\}")
	for m in re.search_all(out):
		out = out.replace(m.get_string(0), m.get_string(2) if fem else m.get_string(1))
	return out


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"flags": flags.keys(), "rumores": rumores.keys(), "vistos": vistos.keys()}


static func restaurar(d: Dictionary) -> void:
	zerar()
	for f in d.get("flags", []):
		flags[str(f)] = true
	for r in d.get("rumores", []):
		rumores[str(r)] = true
	var rd: Dictionary = d.get("rep", {})          # saves da etapa 5: a reputação morava aqui
	for k in rd:
		Reputacao.rep[str(k)] = int(rd[k])
	for v in d.get("vistos", []):
		vistos[str(v)] = true
