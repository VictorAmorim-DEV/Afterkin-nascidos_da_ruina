class_name Inicio
extends RefCounted
## Onde o personagem estava quando tudo começou (docs/DECISOES_DESIGN.md, ajustes do playtest 1 e 2).
## Escolhe-se o LUGAR (cidade, vilarejo ou acampamento); o prédio é SORTEADO a cada partida: uma casa ou um prédio de
## apartamentos qualquer dentro dele. Nunca um ponto de loot especial (hospital, mercado, delegacia...), para o loot
## bom continuar exigindo uma incursão pela cidade.
## O começo é seguro: o prédio (ou o acampamento) nasce sem inimigos, às 08:00. O perigo fica do lado de fora.

const IDS: Array[String] = ["porto_atlantico", "baia_dourada", "sao_jorge", "vila_nova_serra", "vila_rocas",
	"acampamento"]

## "area" = nome em MundoGen.AREAS; "vilarejo" = nome em MundoGen.VILAREJOS; "acampamento" = nome do acampamento.
const DADOS := {
	"porto_atlantico": {"nome": "Porto Atlântico", "tipo": "cidade grande", "area": "Porto Atlântico"},
	"baia_dourada": {"nome": "Baía Dourada", "tipo": "cidade grande", "area": "Baía Dourada"},
	"sao_jorge": {"nome": "São Jorge", "tipo": "cidade", "area": "São Jorge"},
	"vila_nova_serra": {"nome": "Vila Nova da Serra", "tipo": "vilarejo", "vilarejo": "Vila Nova da Serra"},
	"vila_rocas": {"nome": "Vila das Roças", "tipo": "vilarejo", "vilarejo": "Vila das Roças"},
	"acampamento": {"nome": "Santuário do Sol", "tipo": "acampamento", "acampamento": "Acampamento Santuário do Sol"},
}

## Local padrão sugerido por origem (o resto começa em Porto Atlântico).
const PADRAO := {"mestre_obras": "acampamento"}

## Usos de prédio onde se pode nascer: casa (sem uso) e apartamentos.
const USOS_DE_MORAR := ["", "casa", "apartamentos"]

## Zona sem inimigos do começo da partida (mundo). O Mundo não cria moradores nem inimigos soltos dentro dela.
static var zona_segura := Rect2()


static func nome(id: String) -> String:
	return str((DADOS.get(id, {}) as Dictionary).get("nome", id))


static func tipo(id: String) -> String:
	return str((DADOS.get(id, {}) as Dictionary).get("tipo", ""))


## Frase "onde você estava" antes do sorteio (tela inicial).
static func onde(id: String) -> String:
	var d: Dictionary = DADOS.get(id, {})
	if d.has("acampamento"):
		return "no %s" % d["acampamento"]
	return "numa casa de %s" % d.get("nome", id)


## O ponto 'p' (mundo) está dentro da zona segura do começo?
static func seguro(p: Vector2) -> bool:
	return zona_segura.has_area() and zona_segura.has_point(p)


## Sorteia o ponto de nascimento no local 'id': {"p": Vector2 (mundo), "zona": Rect2, "onde": frase} ou {}.
static func achar(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = DADOS.get(id, {})
	if d.has("area"):
		for a in MundoGen.AREAS.size():
			if MundoGen.AREAS[a]["nome"] == d["area"]:
				return _predio_da_area(a, str(d["area"]), rng)
	if d.has("acampamento"):
		for c in MundoGen.acampamentos():
			var cd: Dictionary = c
			if cd["nome"] == d["acampamento"]:
				var cc: Vector2 = cd["c"]
				var meia := Vector2(float(cd["hw"]), float(cd["hh"])) + Vector2(400.0, 400.0)
				return {"p": cc + Vector2(0.0, 160.0), "zona": Rect2(cc - meia, meia * 2.0), "onde": "no %s" % cd["nome"]}
	if d.has("vilarejo"):
		for v in MundoGen.aldeias():
			var vd: Dictionary = v
			var casas: Array = vd["casas"]
			if vd["nome"] == d["vilarejo"] and not casas.is_empty():
				var casa: Dictionary = casas[rng.randi() % casas.size()]
				var r := _dentro_do_lote(casa["p"], int(casa["w"]), int(casa["h"]))
				r["onde"] = "numa casa da %s" % vd["nome"]
				return r
	return {}


## Casa ou prédio de apartamentos sorteado entre os da área urbana 'a'.
static func _predio_da_area(a: int, nome_area: String, rng: RandomNumberGenerator) -> Dictionary:
	var opcoes: Array = []
	for b in Quadras.blocos():
		var bv: Vector3i = b
		if bv.z != a:
			continue
		for s in Quadras._bloco(bv.x, bv.y, bv.z)["specs"]:
			var sd: Dictionary = s
			if sd["k"] != "edificio":
				continue
			var uso: String = str((sd.get("o", {}) as Dictionary).get("uso", ""))
			if uso in USOS_DE_MORAR:
				opcoes.append(sd)
	if opcoes.is_empty():
		return {}
	var sd: Dictionary = opcoes[rng.randi() % opcoes.size()]
	var r := _dentro_do_lote(sd["p"], int(sd["w"]), int(sd["h"]))
	var uso2: String = str((sd.get("o", {}) as Dictionary).get("uso", ""))
	r["onde"] = ("num prédio de apartamentos de %s" if uso2 == "apartamentos" else "numa casa de %s") % nome_area
	return r


## Meio do prédio (posição do canto 'p' em mundo, 'w' × 'h' tiles) e a zona segura: o prédio com 6 m de folga.
static func _dentro_do_lote(p: Vector2, w: int, h: int) -> Dictionary:
	var tam := Vector2(w, h) * Edificio.TILE
	var folga := Vector2.ONE * 6.0 * IsoMath.METRO
	return {"p": p + tam * 0.5, "zona": Rect2(p - folga, tam + folga * 2.0)}
