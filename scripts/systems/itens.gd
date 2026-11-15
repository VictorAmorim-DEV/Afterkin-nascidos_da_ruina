class_name Itens
extends RefCounted
## Tabelas de itens, receitas e loot — portadas da V13 (ITEMS, RECIPES, CONTEM, SAQUE).

const ICONE := "res://assets/ui/icons/icon_%s.png"

const DB := {
	"madeira": {"nome": "Madeira", "stack": 64, "desc": "Material básico de construção e fabricação."},
	"pedra": {"nome": "Pedra", "stack": 64, "desc": "Usada em ferramentas."},
	"sucata": {"nome": "Sucata", "stack": 32, "desc": "Peças para totens e abrigos."},
	"comida": {"nome": "Comida", "stack": 16, "uso": true, "desc": "Recupera fome e um pouco de vida."},
	"antibiotico": {"nome": "Antibiótico", "stack": 8, "uso": true, "desc": "Trata doenças."},
	"antidoto": {"nome": "Antídoto", "stack": 4, "uso": true, "desc": "Tirado de ninhos de morcegos. Interrompe a mutação vampírica."},
	"machado": {"nome": "Machado", "stack": 1, "ferramenta": true, "desc": "Equipado, corta árvores com o botão esquerdo."},
	"picareta": {"nome": "Picareta", "stack": 1, "ferramenta": true, "desc": "Equipada, quebra pedras grandes com o botão esquerdo."},
	"totem": {"nome": "Totem de território", "stack": 1, "uso": true, "desc": "Use para posicionar seu totem aqui."},
}

## Receitas de fabricação (V13: RECIPES).
const RECEITAS := [
	{"id": "totem", "desc": "Um por jogador. Fica no inventário até ser usado.", "custo": []},
	{"id": "machado", "desc": "Madeira só se obtém de árvores com machado.", "custo": [["madeira", 4], ["pedra", 3]]},
	{"id": "picareta", "desc": "Necessária para pedras grandes.", "custo": [["madeira", 4], ["pedra", 4]]},
]

## Nome do recipiente que o jogador vasculha (V13: CONTEM).
const CONTEM := {
	"estante": "estante", "armario": "guarda-roupa", "comoda": "cômoda", "geladeira": "geladeira",
	"balcao": "armário da cozinha", "armario_med": "armário de remédios", "prateleira": "prateleira",
	"arquivo": "arquivo", "caixa": "caixa", "mesa_esc": "gaveta da mesa", "scrap": "sucata",
	"esgoto": "acesso ao esgoto", "ninho": "ninho de morcegos",
}

static var _cache: Dictionary = {}


static func existe(id: String) -> bool:
	return DB.has(id)


static func nome(id: String) -> String:
	return DB[id].nome


static func icone(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load(ICONE % id) if ResourceLoader.exists(ICONE % id) else null
	return _cache[id]


static func stack_max(id: String) -> int:
	return DB[id].stack


static func custo_receita(id: String, nivel: int = 1, raca: String = "human") -> Array:
	## Humano: ferramentas custam 80% (arredondado ao inteiro mais próximo; a V13 arredonda para cima e o desconto some)
	if id == "totem":
		var t := int((nivel - 1) / 5.0)
		if raca == "human":
			return [["madeira", 8 + t * 4], ["sucata", 4 + t * 3]]
		return [["madeira", 10 + t * 5], ["sucata", 5 + t * 3]]
	for r in RECEITAS:
		if r.id == id:
			var out: Array = []
			for c in r.custo:
				out.append([c[0], roundi(c[1] * 0.8) if raca == "human" else c[1]])
			return out
	return []


## Tabela de saque (V13: SAQUE). Devolve [[id, qtd], ...] já sorteado, sem as quantidades 0.
static func saque(tipo: String, rng: RandomNumberGenerator) -> Array:
	var l: Array = []
	match tipo:
		"geladeira":
			l = [["comida", rng.randi_range(0, 2)]]
		"armario":
			l = [["sucata", rng.randi_range(0, 2)], ["antibiotico", 1 if rng.randf() < 0.06 else 0]]
		"comoda":
			l = [["antibiotico", 1 if rng.randf() < 0.12 else 0], ["sucata", rng.randi_range(0, 1)]]
		"estante":
			l = [["madeira", rng.randi_range(0, 2)], ["sucata", rng.randi_range(0, 1)]]
		"balcao":
			l = [["comida", rng.randi_range(0, 1)], ["sucata", rng.randi_range(0, 1)]]
		"armario_med":
			l = [["antibiotico", rng.randi_range(1, 2) if rng.randf() < 0.4 else 0]]
		"prateleira":
			l = [["comida", rng.randi_range(0, 2)], ["sucata", rng.randi_range(0, 1)]]
		"arquivo":
			l = [["sucata", rng.randi_range(0, 2)]]
		"caixa":
			l = [["madeira", rng.randi_range(1, 3)], ["sucata", rng.randi_range(0, 2)]]
		"mesa_esc":
			l = [["sucata", rng.randi_range(0, 1)], ["antibiotico", 1 if rng.randf() < 0.04 else 0]]
		"scrap":
			l = [["sucata", rng.randi_range(1, 3)]]
		"esgoto":
			l = [["sucata", 2]]
		"ninho":
			l = [["antidoto", 2 if rng.randf() < 0.25 else 1]]
	return l.filter(func(x): return x[1] > 0)


static func texto_lista(lista: Array) -> String:
	var partes: PackedStringArray = []
	for x in lista:
		partes.append("%d %s" % [x[1], nome(x[0]).to_lower()])
	return ", ".join(partes)
