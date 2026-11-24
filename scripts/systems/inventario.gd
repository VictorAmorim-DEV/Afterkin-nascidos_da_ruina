class_name Inventario
extends Node
## Mochila do jogador (V13: inventory, addToSlots, canAdd, removeItem, moveSlot, craft).
## 20 slots, cada um nulo ou {id, quantidade, maximo, ...extras}. Empilha até o limite de cada item.

signal mudou
signal aviso(texto: String)

const TAMANHO := 20
const CAPACIDADE_KG := 35.0  ## acima disso o jogador fica lento, cansa mais e faz mais barulho

var slots: Array = []
var equipado: int = -1       ## índice do slot da ferramenta equipada (-1 = mãos livres)
var jogador: Node = null     ## quem usa os itens (comer, remédio...)


func _init() -> void:
	slots.resize(TAMANHO)
	slots.fill(null)


## Peso total da mochila, em kg.
func peso_total() -> float:
	var t := 0.0
	for x in slots:
		if x != null:
			t += Itens.peso(x.id) * int(x.quantidade)
	return t


## Excesso de carga de 0 (dentro da capacidade) a 1 (o dobro da capacidade ou mais).
func sobrecarga() -> float:
	return clampf((peso_total() - CAPACIDADE_KG) / CAPACIDADE_KG, 0.0, 1.0)


## Coloca 'qtd' de 'id' em 'alvo' (a lista de slots). Devolve o que NÃO coube.
static func empilhar(alvo: Array, id: String, qtd: int, extra: Dictionary = {}) -> int:
	for x in alvo:
		if qtd <= 0:
			break
		if x != null and x.id == id and x.quantidade < x.maximo:
			var n := mini(qtd, x.maximo - x.quantidade)
			x.quantidade += n
			qtd -= n
	for i in alvo.size():
		if qtd <= 0:
			break
		if alvo[i] == null:
			var m := Itens.stack_max(id)
			var n := mini(qtd, m)
			var novo := {"id": id, "quantidade": n, "maximo": m}
			novo.merge(extra)
			alvo[i] = novo
			qtd -= n
	return qtd


func _copia() -> Array:
	return slots.map(func(x): return null if x == null else x.duplicate())


func pode_adicionar(lista: Array) -> bool:
	var c := _copia()
	for x in lista:
		if empilhar(c, x[0], x[1]) > 0:
			return false
	return true


## Tudo ou nada, como na V13 (addItems).
func adicionar_itens(lista: Array) -> bool:
	lista = lista.filter(func(x): return x[1] > 0)
	if not pode_adicionar(lista):
		return false
	for x in lista:
		empilhar(slots, x[0], x[1])
	mudou.emit()
	return true


## Adiciona o que couber e devolve o que sobrou (usado ao pegar do chão).
func adicionar_parcial(id: String, qtd: int, extra: Dictionary = {}) -> int:
	var resto := empilhar(slots, id, qtd, extra)
	if resto != qtd:
		mudou.emit()
	return resto


func contar(id: String) -> int:
	var t := 0
	for x in slots:
		if x != null and x.id == id:
			t += x.quantidade
	return t


func remover(id: String, qtd: int, alvo: Array = []) -> void:
	var real := alvo.is_empty()
	var lista: Array = slots if real else alvo
	var i := lista.size() - 1
	while i >= 0 and qtd > 0:
		var x = lista[i]
		if x != null and x.id == id:
			var n := mini(qtd, x.quantidade)
			x.quantidade -= n
			qtd -= n
			if x.quantidade <= 0:
				lista[i] = null
		i -= 1
	if real:
		_conferir_equipado()
		mudou.emit()


func vazios() -> int:
	return slots.count(null)


func _conferir_equipado() -> void:
	if equipado >= 0:
		var x = slots[equipado]
		if x == null or not Itens.DB[x.id].get("ferramenta", false):
			equipado = -1


func id_equipado() -> String:
	_conferir_equipado()
	return "" if equipado < 0 else slots[equipado].id


## Arrastar o slot 'a' para o 'b': junta pilhas iguais ou troca de lugar.
func mover(a: int, b: int) -> void:
	var A = slots[a]
	var B = slots[b]
	if A == null or a == b:
		return
	if B != null and A.id == B.id and B.quantidade < B.maximo:
		var n := mini(A.quantidade, B.maximo - B.quantidade)
		B.quantidade += n
		A.quantidade -= n
		if A.quantidade <= 0:
			slots[a] = null
	else:
		slots[a] = B
		slots[b] = A
		if equipado == a:
			equipado = b
		elif equipado == b:
			equipado = a
	mudou.emit()


func alternar_equipado(i: int) -> void:
	var x = slots[i]
	if x == null or not Itens.DB[x.id].get("ferramenta", false):
		return
	equipado = -1 if equipado == i else i
	mudou.emit()


## Tira 'qtd' do slot (0 = tudo) e devolve {id, quantidade, extra} para quem for largar no chão.
func retirar(i: int, qtd: int = 0) -> Dictionary:
	var x = slots[i]
	if x == null:
		return {}
	var n: int = x.quantidade if qtd <= 0 else mini(qtd, x.quantidade)
	var extra := {}
	for k in x:
		if k != "id" and k != "quantidade" and k != "maximo":
			extra[k] = x[k]
	var out := {"id": x.id, "quantidade": n, "extra": extra}
	x.quantidade -= n
	if x.quantidade <= 0:
		slots[i] = null
	_conferir_equipado()
	mudou.emit()
	return out


func usar(i: int) -> void:
	var x = slots[i]
	if x == null or jogador == null:
		return
	match x.id:
		"comida":
			if jogador.comer():
				remover("comida", 1)
		"antibiotico":
			jogador.usar_antibiotico()
		"antidoto":
			jogador.usar_antidoto()
		"totem":
			jogador.territorio.colocar_totem(i)
		"agua_suja", "agua_limpa":
			jogador.beber_garrafa(x.id)
		"fogueira":
			jogador.acender_fogueira()
		"bandagem":
			jogador.usar_bandagem()
		"soro":
			jogador.beber_soro()
		"soro_contencao":
			jogador.usar_soro_contencao()
		"kit_cirurgico":
			jogador.usar_kit_cirurgico()
		"cama":
			Respawn.colocar_cama(jogador, i)
		"radio":
			Rumores.usar_radio(jogador)


func fabricar(id: String) -> void:
	if id == "totem" and (jogador.territorio.tem_totem() or contar("totem") > 0):
		aviso.emit("Você já possui um totem (ativo ou no inventário).")
		return
	for r in Itens.RECEITAS:
		if r.id == id and not Itens.receita_disponivel(r):
			aviso.emit("Você ainda não sabe fazer isso.")
			return
	var custo := Itens.custo_receita(id, jogador.origem)
	for c in custo:
		if contar(c[0]) < c[1]:
			aviso.emit("Materiais insuficientes.")
			return
	var sim := _copia()
	for c in custo:
		remover(c[0], c[1], sim)
	if empilhar(sim, id, 1) > 0:
		aviso.emit("Inventário cheio! Libere um slot para fabricar.")
		return
	for c in custo:
		remover(c[0], c[1])
	empilhar(slots, id, 1, {"tier": 0} if id == "totem" else {})   # melhorar o totem fica para o marco 6
	for c in custo:
		if c[0] == "agua_limpa" and adicionar_parcial("garrafa", int(c[1])) > 0:   # a garrafa volta vazia
			jogador.largar_item("garrafa", 1)
	mudou.emit()
	aviso.emit("%s fabricado e guardado no inventário. Equipe manualmente." % Itens.nome(id))


## Itens iniciais da V13 (resetInventory).
func inicial() -> void:
	slots.fill(null)
	empilhar(slots, "madeira", 5)
	empilhar(slots, "sucata", 3)
	empilhar(slots, "comida", 2)
	empilhar(slots, "agua_limpa", 1)
	empilhar(slots, "garrafa", 1)
	equipado = -1
	mudou.emit()
