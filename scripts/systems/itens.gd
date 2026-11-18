class_name Itens
extends RefCounted
## Tabelas de itens, receitas e loot — portadas da V13 (ITEMS, RECIPES, CONTEM, SAQUE).

const ICONE := "res://assets/ui/icons/icon_%s.png"

const DB := {
	"madeira": {"nome": "Madeira", "stack": 64, "peso": 0.6, "desc": "Material básico de construção e fabricação."},
	"pedra": {"nome": "Pedra", "stack": 64, "peso": 0.9, "desc": "Usada em ferramentas."},
	"sucata": {"nome": "Sucata", "stack": 32, "peso": 0.5, "desc": "Peças para totens e abrigos."},
	"comida": {"nome": "Comida", "stack": 16, "peso": 0.3, "uso": true, "desc": "Recupera fome e um pouco de vida."},
	"antibiotico": {"nome": "Antibiótico", "stack": 8, "peso": 0.05, "uso": true, "desc": "Trata doenças."},
	"antidoto": {"nome": "Antídoto", "stack": 4, "peso": 0.1, "uso": true, "desc": "Tirado de ninhos de morcegos. Interrompe a mutação vampírica."},
	"machado": {"nome": "Machado", "stack": 1, "peso": 1.5, "ferramenta": true, "desc": "Equipado, corta árvores com o botão esquerdo."},
	"picareta": {"nome": "Picareta", "stack": 1, "peso": 1.8, "ferramenta": true, "desc": "Equipada, quebra pedras grandes com o botão esquerdo."},
	"totem": {"nome": "Totem de território", "stack": 1, "peso": 3.0, "uso": true, "desc": "Use para posicionar seu totem aqui."},
	"garrafa": {"nome": "Garrafa vazia", "stack": 4, "peso": 0.05, "desc": "Encha numa poça, rio ou lago (E na beira da água)."},
	"agua_suja": {"nome": "Água suja", "stack": 4, "peso": 0.6, "uso": true,
		"desc": "Mata a sede, mas pode causar disenteria. Ferva numa fogueira para ficar limpa."},
	"agua_limpa": {"nome": "Água limpa", "stack": 4, "peso": 0.6, "uso": true, "desc": "Mata a sede sem risco."},
	"bandagem": {"nome": "Bandagem", "stack": 8, "peso": 0.05, "uso": true, "desc": "Recupera 15 de vida."},
	"pistola": {"nome": "Pistola", "stack": 1, "peso": 0.7, "ferramenta": true,
		"desc": "Equipada, atira com o botão esquerdo (alcance 12 m). O estampido acorda e atrai tudo por perto."},
	"municao": {"nome": "Munição", "stack": 30, "peso": 0.012, "desc": "Bala de pistola. Rara."},
	"fogueira": {"nome": "Fogueira", "stack": 2, "peso": 2.0, "uso": true,
		"desc": "Use para acender à sua frente. Ferve água suja, mas faz luz e barulho. Apaga em ~3 h de jogo."},
	"pano": {"nome": "Pano", "stack": 16, "peso": 0.15, "desc": "Lençol, cortina ou roupa velha. Serve para fazer uma cama."},
	"cama": {"nome": "Cama", "stack": 1, "peso": 4.0, "uso": true,
		"desc": "Use dentro de uma casa ou do seu abrigo para montá-la. Quando morrer, você pode renascer nela."},
}

## Receitas de fabricação (V13: RECIPES).
const RECEITAS := [
	{"id": "totem", "desc": "Um por jogador. Fica no inventário até ser usado.", "custo": []},
	{"id": "machado", "desc": "Madeira só se obtém de árvores com machado.", "custo": [["madeira", 4], ["pedra", 3]]},
	{"id": "picareta", "desc": "Necessária para pedras grandes.", "custo": [["madeira", 4], ["pedra", 4]]},
	{"id": "fogueira", "desc": "Ferve água suja. Faz luz e barulho.", "custo": [["madeira", 5], ["pedra", 3]]},
	{"id": "cama", "desc": "Monte num lugar coberto: vira ponto de renascimento.", "custo": [["madeira", 6], ["pano", 3]]},
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


## Peso de uma unidade, em kg.
static func peso(id: String) -> float:
	return float((DB[id] as Dictionary).get("peso", 0.5))


## Custo da receita. Não depende de nível nem de raça (docs/DECISOES_DESIGN.md, Q4 e Q28); os descontos vêm da
## origem: o Mecânico gasta 25% menos sucata e o Mestre de Obras paga 25% menos pelo totem e pela cama.
static func custo_receita(id: String, origem: String = "") -> Array:
	var base: Array = []
	if id == "totem":
		base = [["madeira", 10], ["sucata", 5]]   # na lista RECEITAS o totem aparece com custo vazio
	else:
		for r in RECEITAS:
			if r.id == id:
				base = (r.custo as Array).duplicate(true)
	var out: Array = []
	for c in base:
		var qtd: int = c[1]
		if (origem == "mecanico" and c[0] == "sucata") or (origem == "mestre_obras" and id in ["totem", "cama"]):
			qtd = Origens.desconto(qtd)
		out.append([c[0], qtd])
	return out


## Tabela de saque (V13: SAQUE). Devolve [[id, qtd], ...] já sorteado, sem as quantidades 0.
static func saque(tipo: String, rng: RandomNumberGenerator) -> Array:
	var l: Array = []
	match tipo:
		"geladeira":
			l = [["comida", rng.randi_range(0, 2)], ["agua_limpa", 1 if rng.randf() < 0.2 else 0]]
		"armario":
			l = [["sucata", rng.randi_range(0, 2)], ["antibiotico", 1 if rng.randf() < 0.06 else 0],
				["agua_limpa", 1 if rng.randf() < 0.06 else 0], ["pano", rng.randi_range(0, 2)]]
		"comoda":
			l = [["antibiotico", 1 if rng.randf() < 0.12 else 0], ["sucata", rng.randi_range(0, 1)],
				["municao", rng.randi_range(1, 3) if rng.randf() < 0.05 else 0], ["pano", rng.randi_range(0, 1)]]
		"estante":
			l = [["madeira", rng.randi_range(0, 2)], ["sucata", rng.randi_range(0, 1)]]
		"balcao":
			l = [["comida", rng.randi_range(0, 1)], ["sucata", rng.randi_range(0, 1)],
				["agua_limpa", 1 if rng.randf() < 0.1 else 0], ["garrafa", 1 if rng.randf() < 0.25 else 0]]
		"armario_med":
			l = [["antibiotico", rng.randi_range(1, 2) if rng.randf() < 0.4 else 0],
				["bandagem", rng.randi_range(1, 2) if rng.randf() < 0.5 else 0]]
		"prateleira":
			l = [["comida", rng.randi_range(0, 2)], ["sucata", rng.randi_range(0, 1)]]
		"arquivo":
			l = [["sucata", rng.randi_range(0, 2)]]
		"caixa":
			l = [["madeira", rng.randi_range(1, 3)], ["sucata", rng.randi_range(0, 2)],
				["garrafa", 1 if rng.randf() < 0.2 else 0]]
		"mesa_esc":
			l = [["sucata", rng.randi_range(0, 1)], ["antibiotico", 1 if rng.randf() < 0.04 else 0]]
		"scrap":
			l = [["sucata", rng.randi_range(1, 3)], ["garrafa", 1 if rng.randf() < 0.15 else 0]]
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
