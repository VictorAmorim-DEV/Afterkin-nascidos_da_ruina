class_name Origens
extends RefCounted
## Origens: o que o personagem era antes da queda (docs/DECISOES_DESIGN.md Q5, Q18, Q28).
## Dão um kit e um perk pequenos. Tudo aqui é PROVISÓRIO no marco 1: kits não podem dar vantagem grande, e armas
## e equipamentos bons se conseguem no mundo ou se fabricam. A pistola do Policial existe só para testar o tiro.

const IDS: Array[String] = ["policial", "mecanico", "enfermeiro", "mestre_obras"]

const DADOS := {
	"policial": {
		"nome": "Policial",
		"resumo": "Pistola com poucas balas.",
		"descricao": "Começa com uma pistola e 6 balas (provisório, para testar o tiro). O disparo é alto: acorda e "
			+ "atrai tudo por perto. Mais tarde, a comunidade humana confia um pouco mais em você.",
		"kit": [["pistola", 1], ["municao", 6]],
	},
	"mecanico": {
		"nome": "Mecânico",
		"resumo": "Fabrica gastando menos sucata.",
		"descricao": "As receitas gastam 25% menos sucata. Começa com 4 sucatas a mais.",
		"kit": [["sucata", 4]],
	},
	"enfermeiro": {
		"nome": "Enfermeiro(a)",
		"resumo": "Bandagens, antibiótico e diagnóstico.",
		"descricao": "Começa com 3 bandagens e 1 antibiótico. Vê o estágio e o tempo restante das doenças; as "
			+ "outras origens só percebem os sintomas.",
		"kit": [["bandagem", 3], ["antibiotico", 1]],
	},
	"mestre_obras": {
		"nome": "Mestre de Obras",
		"resumo": "Abrigo e totem mais baratos e resistentes.",
		"descricao": "Totem e abrigo custam 25% menos, e o totem resiste 50% mais. Começa com 6 madeiras a mais.",
		"kit": [["madeira", 6]],
	},
}


static func nome(id: String) -> String:
	return str((DADOS.get(id, {}) as Dictionary).get("nome", "Sobrevivente"))


static func kit(id: String) -> Array:
	return (DADOS.get(id, {}) as Dictionary).get("kit", []) as Array


## Desconto de 25% num material (arredondado, nunca abaixo de 1).
static func desconto(qtd: int) -> int:
	return maxi(1, roundi(qtd * 0.75))
