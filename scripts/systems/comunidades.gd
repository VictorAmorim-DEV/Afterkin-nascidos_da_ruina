class_name Comunidades
extends RefCounted
## Comunidades humanas do marco 2 (docs/DECISOES_DESIGN.md, Q35–Q56).
##
## Cada comunidade é um arquivo em data/comunidades/*.json (nome, local no mapa, forte, horário do portão e os NPCs
## com papel e rotina). Acrescentar uma comunidade = escrever um arquivo; o "local" é o nome de um vilarejo ou
## acampamento de MundoGen. O MundoGen pergunta aqui quais lugares são comunidade para murar o vilarejo e marcar
## os portões; o GerenteComunidades põe os NPCs no mundo quando o jogador chega perto.
##
## Geometria (u de mundo) por comunidade: área protegida (sem inimigos), portões (ponto de dentro e de fora),
## casas (onde cada NPC dorme), fogueira, praça e pontos de trabalho.

## Ao criar o preset de exportação, incluir "data/*.json" nos filtros de recursos (não são recursos do Godot).
const PASTA := "res://data/comunidades"

static var _dados: Dictionary = {}          ## id -> Dictionary do JSON
static var _por_local: Dictionary = {}      ## nome do vilarejo/acampamento -> id
static var _geo: Dictionary = {}            ## id -> geometria (calculada sob demanda)
static var _carregado := false


static func carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var dir := DirAccess.open(PASTA)
	if dir == null:
		push_warning("Comunidades: pasta %s não encontrada." % PASTA)
		return
	for arq in dir.get_files():
		if not arq.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [PASTA, arq]))
		if not d is Dictionary:
			push_error("Comunidades: %s não é um JSON válido." % arq)
			continue
		var cd: Dictionary = d
		_dados[str(cd["id"])] = cd
		_por_local[str(cd["local"])] = str(cd["id"])


static func ids() -> Array:
	carregar()
	return _dados.keys()


static func dados(id: String) -> Dictionary:
	carregar()
	return _dados.get(id, {})


static func nome(id: String) -> String:
	return str(dados(id).get("nome", id))


## "da Vila dos Pescadores" / "do Santuário do Sol" (artigo no arquivo da comunidade).
static func de(id: String) -> String:
	return "d%s %s" % [str(dados(id).get("artigo", "o")), nome(id)]


## "na Vila dos Pescadores" / "no Santuário do Sol".
static func em_nome(id: String) -> String:
	return "n%s %s" % [str(dados(id).get("artigo", "o")), nome(id)]


## "a Vila dos Pescadores" / "o Santuário do Sol".
static func com_artigo(id: String) -> String:
	return "%s %s" % [str(dados(id).get("artigo", "o")), nome(id)]


## Id da comunidade que mora no vilarejo/acampamento 'local' ("" se nenhuma).
static func do_local(local: String) -> String:
	carregar()
	return str(_por_local.get(local, ""))


# ───────────────────────────── geometria ─────────────────────────────

## {area: Rect2, portoes: [{dentro, fora}], casas: [Vector2], fogueira, praca: [Vector2], trabalho: [Vector2], centro}
static func geo(id: String) -> Dictionary:
	if _geo.has(id):
		return _geo[id]
	var g := {}
	var local := str(dados(id).get("local", ""))
	for a in MundoGen.aldeias():
		var ad: Dictionary = a
		if ad["nome"] == local and ad.has("muro"):
			g = _geo_vilarejo(ad)
	for c in MundoGen.acampamentos():
		var cd: Dictionary = c
		if cd["nome"] == local:
			g = _geo_acampamento(cd)
	_geo[id] = g
	return g


static func _geo_vilarejo(ad: Dictionary) -> Dictionary:
	var muro: Rect2 = ad["muro"]
	var yc: float = ad["rua_y"]
	var portoes: Array = []
	for pt in ad["portoes"]:
		var par: Array = pt
		var meio: Vector2 = ((par[0] as Vector2) + (par[1] as Vector2)) * 0.5
		var para_dentro := (muro.get_center() - meio).normalized()
		para_dentro = Vector2(signf(para_dentro.x), 0.0)          # portões nas pontas da rua (oeste e leste)
		portoes.append({"dentro": meio + para_dentro * 160.0, "fora": meio - para_dentro * 200.0, "meio": meio})
	var casas: Array = []
	for cs in ad["casas"]:
		var cdd: Dictionary = cs
		var hp: Vector2 = cdd["p"]
		var norte: bool = cdd["f"] == "s"
		casas.append(Vector2(hp.x + 224.0, yc + (-110.0 if norte else 110.0)))   # na rua, em frente ao portão do lote
	var centro := Vector2(muro.get_center().x, yc)
	var fogueira: Vector2 = ad["fogueira"]
	var praca: Array = [fogueira + Vector2(-150, -70), fogueira + Vector2(160, -60), fogueira + Vector2(-120, 80),
		fogueira + Vector2(140, 90)]
	var trabalho: Array = [Vector2(muro.position.x + 260.0, yc - 60.0), Vector2(muro.end.x - 260.0, yc + 60.0),
		Vector2(muro.position.x + 420.0, yc + 70.0), Vector2(muro.end.x - 420.0, yc - 70.0)]
	return {"area": muro, "portoes": portoes, "casas": casas, "fogueira": fogueira, "praca": praca,
		"trabalho": trabalho, "centro": centro}


static func _geo_acampamento(cd: Dictionary) -> Dictionary:
	var cc: Vector2 = cd["c"]
	var hw: float = cd["hw"]
	var hh: float = cd["hh"]
	var sul: bool = cd["gate"] == "s"
	var gy: float = cc.y + (hh if sul else -hh)
	var dentro_y: float = -150.0 if sul else 150.0
	var portoes: Array = [{"dentro": Vector2(cc.x, gy + dentro_y), "fora": Vector2(cc.x, gy - dentro_y * 1.4),
		"meio": Vector2(cc.x, gy)}]
	var casas: Array = []
	for t in [Vector2(-400, -330), Vector2(-130, -340), Vector2(150, -330), Vector2(410, -310), Vector2(-440, 40),
			Vector2(440, 60)]:
		casas.append(cc + (t as Vector2) + Vector2(0.0, 120.0))   # na frente da tenda
	var fogueira := cc + Vector2(0, 40)
	var praca: Array = [fogueira + Vector2(-130, -40), fogueira + Vector2(130, -30), fogueira + Vector2(-90, 90),
		fogueira + Vector2(100, 100)]
	var trabalho: Array = [cc + Vector2(-300, 170), cc + Vector2(300, 180), cc + Vector2(-330, -40),
		cc + Vector2(330, -20)]
	return {"area": Rect2(cc.x - hw, cc.y - hh, hw * 2.0, hh * 2.0), "portoes": portoes, "casas": casas,
		"fogueira": fogueira, "praca": praca, "trabalho": trabalho, "centro": cc}


## O ponto (mundo) está dentro de alguma comunidade? (sem inimigos nem moradores-monstro)
static func protege(p: Vector2) -> bool:
	for id in ids():
		var g := geo(str(id))
		if not g.is_empty() and (g["area"] as Rect2).grow(80.0).has_point(p):
			return true
	return false


## Comunidade a menos de 'margem' (u) da área ("" se nenhuma).
static func perto(p: Vector2, margem: float) -> String:
	for id in ids():
		var g := geo(str(id))
		if not g.is_empty() and (g["area"] as Rect2).grow(margem).has_point(p):
			return str(id)
	return ""


## Comunidade cuja área contém o ponto ("" se nenhuma).
static func em(p: Vector2) -> String:
	for id in ids():
		var g := geo(str(id))
		if not g.is_empty() and (g["area"] as Rect2).has_point(p):
			return str(id)
	return ""


# ───────────────────────────── horário ─────────────────────────────

## O portão da comunidade fica aberto nesta hora (minutos do dia)? Padrão: abre às 6h, fecha às 18h.
static func portao_aberto(id: String, minutos: float) -> bool:
	var pd: Dictionary = dados(id).get("portao", {})
	var abre: float = float(pd.get("abre", 6)) * 60.0
	var fecha: float = float(pd.get("fecha", 18)) * 60.0
	return minutos >= abre and minutos < fecha


## Chave da rotina para a fase do dia (DiaNoite.Fase).
const CHAVES_FASE := ["madrugada", "amanhecer", "manha", "tarde", "tardezinha", "noite"]
