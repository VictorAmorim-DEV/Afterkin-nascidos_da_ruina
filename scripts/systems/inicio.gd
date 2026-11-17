class_name Inicio
extends RefCounted
## Onde o personagem estava quando tudo começou (docs/DECISOES_DESIGN.md, ajustes do playtest 1 e 2).
## Cada local é um lugar real do mundo: um prédio de Porto Atlântico pelo uso, um acampamento ou uma casa de vilarejo.
## O começo é seguro: o prédio (ou o acampamento) nasce sem inimigos, às 08:00. O perigo fica do lado de fora.
## A origem só sugere o local padrão; qualquer combinação vale.

const IDS: Array[String] = ["delegacia", "hospital", "mercado", "oficina", "acampamento", "casa"]

const DADOS := {
	"delegacia": {"nome": "Delegacia", "onde": "na delegacia de Porto Atlântico", "uso": "delegacia"},
	"hospital": {"nome": "Hospital", "onde": "no hospital de Porto Atlântico", "uso": "hospital"},
	"mercado": {"nome": "Supermercado", "onde": "no supermercado de Porto Atlântico", "uso": "mercado"},
	"oficina": {"nome": "Oficina", "onde": "na oficina de Porto Atlântico", "uso": "oficina"},
	"acampamento": {"nome": "Acampamento", "onde": "no Acampamento Santuário do Sol",
		"acampamento": "Acampamento Santuário do Sol"},
	"casa": {"nome": "Em casa", "onde": "em casa, na Vila das Roças", "vilarejo": "Vila das Roças"},
}

## Local padrão sugerido por origem.
const PADRAO := {"policial": "delegacia", "enfermeiro": "hospital", "mecanico": "oficina",
	"mestre_obras": "acampamento"}

## Zona sem inimigos do começo da partida (mundo). O Mundo não cria moradores nem inimigos soltos dentro dela.
static var zona_segura := Rect2()


static func nome(id: String) -> String:
	return str((DADOS.get(id, {}) as Dictionary).get("nome", id))


static func onde(id: String) -> String:
	return str((DADOS.get(id, {}) as Dictionary).get("onde", ""))


## O ponto 'p' (mundo) está dentro da zona segura do começo?
static func seguro(p: Vector2) -> bool:
	return zona_segura.has_area() and zona_segura.has_point(p)


## Ponto de nascimento (mundo) do local 'id' e a zona segura em volta: {"p": Vector2, "zona": Rect2}.
## {} se o local não foi achado (o jogo então mantém o ponto atual).
static func achar(id: String) -> Dictionary:
	var d: Dictionary = DADOS.get(id, {})
	if d.has("uso"):
		return _predio_da_cidade(str(d["uso"]))
	if d.has("acampamento"):
		for c in MundoGen.acampamentos():
			var cd: Dictionary = c
			if cd["nome"] == d["acampamento"]:
				var cc: Vector2 = cd["c"]
				var meia := Vector2(float(cd["hw"]), float(cd["hh"])) + Vector2(400.0, 400.0)
				return {"p": cc + Vector2(0.0, 160.0), "zona": Rect2(cc - meia, meia * 2.0)}
	if d.has("vilarejo"):
		for v in MundoGen.aldeias():
			var vd: Dictionary = v
			if vd["nome"] == d["vilarejo"] and not (vd["casas"] as Array).is_empty():
				var casa: Dictionary = (vd["casas"] as Array)[0]
				return _dentro_do_lote(casa["p"], int(casa["w"]), int(casa["h"]))
	return {}


## Primeiro prédio de Porto Atlântico (área 0) com esse uso.
static func _predio_da_cidade(uso: String) -> Dictionary:
	for b in Quadras.blocos():
		var bv: Vector3i = b
		if bv.z != 0:
			continue
		for s in Quadras._bloco(bv.x, bv.y, bv.z)["specs"]:
			var sd: Dictionary = s
			if sd["k"] == "edificio" and sd.has("o") and (sd["o"] as Dictionary).get("uso", "") == uso:
				return _dentro_do_lote(sd["p"], int(sd["w"]), int(sd["h"]))
	return {}


## Meio do prédio (posição do canto 'p' em mundo, 'w' × 'h' tiles) e a zona segura: o prédio com 6 m de folga.
static func _dentro_do_lote(p: Vector2, w: int, h: int) -> Dictionary:
	var tam := Vector2(w, h) * Edificio.TILE
	var folga := Vector2.ONE * 6.0 * IsoMath.METRO
	return {"p": p + tam * 0.5, "zona": Rect2(p - folga, tam + folga * 2.0)}
