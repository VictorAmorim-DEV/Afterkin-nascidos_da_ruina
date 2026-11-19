class_name Escambo
extends RefCounted
## Escambo sem moeda (marco 2, etapa 7; docs/DECISOES_DESIGN.md Q22, Q30, Q41 e Q52).
##
## - Valor base inverso à escassez (VALORES): sucata vale pouco, munição e antibiótico valem muito.
## - Cada comerciante tem a "loja" no arquivo da comunidade (data/comunidades/*.json, dentro do NPC):
##   "estoque" inicial, "repoe" (quanto volta por dia, até o estoque inicial), "demanda" (multiplica o que ele paga
##   pelo seu item) e "rep_min" (item que ele só troca com quem tem essa reputação).
## - Saturação: cada unidade de um item que ele recebe baixa o que ele paga pelo próximo; some 1/3 por dia.
## - Reputação: boa, ele cobra menos e paga mais; ruim, o contrário (até −40, quando ninguém conversa).
## - A balança compara o que você oferece com o que pede e só diz "aceita", "quer mais" ou "nem pensar".

const VALORES := {
	"sucata": 1.0, "madeira": 1.5, "pedra": 1.5, "garrafa": 2.0, "pano": 2.0, "agua_suja": 2.0, "comida": 4.0,
	"municao": 6.0, "fogueira": 8.0, "agua_limpa": 8.0, "bandagem": 10.0, "machado": 15.0, "picareta": 15.0,
	"cama": 20.0, "antibiotico": 25.0, "pistola": 60.0, "antidoto": 60.0,
}
const NAO_TROCA := ["totem"]
const MARGEM := 1.25                 ## o comerciante cobra 25% acima do que paga
const SATURACAO := 0.12              ## cada unidade recebida baixa 12% o que paga pela próxima (do mesmo item)

## "comunidade/npc" -> {"estoque": {item: qtd}, "sat": {item: unidades}, "dia": int (última reposição)}
static var estado: Dictionary = {}


static func zerar() -> void:
	estado = {}


static func tem_loja(npc: Npc) -> bool:
	return npc != null and npc.dados.has("loja")


static func _chave(npc: Npc) -> String:
	return "%s/%s" % [npc.comunidade, str(npc.dados.get("id", ""))]


static func _dia() -> int:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	return int(c.dia) if c != null else 1


## Estado da loja, com a reposição e o fim da saturação dos dias que passaram.
static func loja(npc: Npc) -> Dictionary:
	var k := _chave(npc)
	var def: Dictionary = npc.dados.get("loja", {})
	if not estado.has(k):
		estado[k] = {"estoque": (def.get("estoque", {}) as Dictionary).duplicate(), "sat": {}, "dia": _dia()}
	var e: Dictionary = estado[k]
	var dias := _dia() - int(e["dia"])
	if dias > 0:
		e["dia"] = _dia()
		var ini: Dictionary = def.get("estoque", {})
		var rep: Dictionary = def.get("repoe", {})
		var est: Dictionary = e["estoque"]
		for item in rep:
			var teto := maxi(int(ini.get(item, 0)), int(est.get(item, 0)))
			est[item] = mini(teto, int(est.get(item, 0)) + int(rep[item]) * dias)
		var sat: Dictionary = e["sat"]
		for item in sat.keys():
			sat[item] = float(sat[item]) * pow(2.0 / 3.0, dias)
			if float(sat[item]) < 0.2:
				sat.erase(item)
	return e


static func _fator_rep(npc: Npc) -> float:
	return clampf(1.0 - Reputacao.valor(npc.comunidade) / 150.0, 0.8, 1.4)


## Quanto o comerciante dá pela PRÓXIMA unidade do seu item (com demanda, saturação e reputação). 0 = não quer.
static func paga(npc: Npc, item: String, ja_na_oferta: int = 0) -> float:
	if NAO_TROCA.has(item) or not VALORES.has(item):
		return 0.0
	var def: Dictionary = npc.dados.get("loja", {})
	var dem: float = float((def.get("demanda", {}) as Dictionary).get(item, 1.0)) * Simulacao.demanda(npc.comunidade, item)
	var sat: float = float((loja(npc)["sat"] as Dictionary).get(item, 0.0)) + ja_na_oferta
	return float(VALORES[item]) * dem / (1.0 + SATURACAO * sat) / _fator_rep(npc)


## Quanto ele cobra por uma unidade do item dele. INF = não troca isso com você (reputação baixa para o item).
static func cobra(npc: Npc, item: String) -> float:
	var minimo: Dictionary = (npc.dados.get("loja", {}) as Dictionary).get("rep_min", {})
	if minimo.has(item) and Reputacao.valor(npc.comunidade) < int(minimo[item]):
		return INF
	return float(VALORES.get(item, 5.0)) * MARGEM * _fator_rep(npc)


## Valor da oferta: soma unidade a unidade (a saturação cresce dentro da própria oferta).
static func valor_oferta(npc: Npc, oferta: Dictionary) -> float:
	var t := 0.0
	for item in oferta:
		for i in int(oferta[item]):
			t += paga(npc, str(item), i)
	return t


static func valor_pedido(npc: Npc, pedido: Dictionary) -> float:
	var t := 0.0
	for item in pedido:
		t += cobra(npc, str(item)) * int(pedido[item])
	return t


## Julgamento da balança: [texto, aceita?, inclinação de -1 (recusa) a 1 (sobra do seu lado)].
static func julgar(npc: Npc, oferta: Dictionary, pedido: Dictionary) -> Array:
	var vo := valor_oferta(npc, oferta)
	var vp := valor_pedido(npc, pedido)
	if vp == INF:
		return ["Isso eu não troco com você. Ainda não.", false, -1.0]
	if vo <= 0.0 and vp <= 0.0:
		return ["Escolha o que oferecer e o que quer levar.", false, 0.0]
	if vp <= 0.0:
		return ["Aceita de presente, claro. Escolha o que quer levar.", false, 1.0]
	var r := vo / vp
	var incl := clampf((r - 1.0) * 1.5, -1.0, 1.0)
	if r >= 1.5:
		return ["Aceita na hora. Você está dando mais do que precisa.", true, incl]
	if r >= 1.0:
		return ["Aceita.", true, incl]
	if r >= 0.8:
		return ["Quer um pouco mais.", false, incl]
	if r >= 0.5:
		return ["Quer bem mais do que isso.", false, incl]
	return ["Nem pensar.", false, incl]


## Faz a troca (já julgada como aceita): tira e dá itens, mexe no estoque e na saturação. Devolve a mensagem.
static func trocar(npc: Npc, j: Node, oferta: Dictionary, pedido: Dictionary) -> String:
	var inv: Inventario = j.inventario
	for item in oferta:
		if inv.contar(str(item)) < int(oferta[item]):
			return "Você não tem mais tudo isso."
	var e := loja(npc)
	var est: Dictionary = e["estoque"]
	for item in pedido:
		if int(est.get(item, 0)) < int(pedido[item]):
			return "Ele não tem mais tudo isso."
	var sim := inv._copia()
	for item in oferta:
		inv.remover(str(item), int(oferta[item]), sim)
	for item in pedido:
		if Inventario.empilhar(sim, str(item), int(pedido[item])) > 0:
			return "Sua mochila não tem espaço para isso."
	for item in oferta:
		inv.remover(str(item), int(oferta[item]))
		est[item] = int(est.get(item, 0)) + int(oferta[item])
		Simulacao.ajustar(npc.comunidade, str(item), int(oferta[item]))   # entra na reserva da comunidade
		var sat: Dictionary = e["sat"]
		sat[item] = float(sat.get(item, 0.0)) + int(oferta[item])
	var lista: Array = []
	for item in pedido:
		lista.append([str(item), int(pedido[item])])
		est[item] = int(est[item]) - int(pedido[item])
		Simulacao.ajustar(npc.comunidade, str(item), -int(pedido[item]))
	inv.adicionar_itens(lista)
	return "Troca feita com %s." % npc.nome()


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return estado.duplicate(true)


static func restaurar(d: Dictionary) -> void:
	zerar()
	for k in d:
		var e: Dictionary = (d[k] as Dictionary).duplicate(true)
		var est: Dictionary = {}
		for item in (e.get("estoque", {}) as Dictionary):
			est[str(item)] = int(e["estoque"][item])
		e["estoque"] = est
		e["dia"] = int(e.get("dia", 1))
		estado[str(k)] = e
