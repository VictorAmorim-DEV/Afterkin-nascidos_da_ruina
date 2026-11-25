class_name Territorio
extends Node
## Totem de território e abrigo (V13: placeTotem, removeTotem, build, player.totem/shelter).
## O totem demarca um raio; dentro dele o vampiro não leva sol. O código da V13 não afasta inimigos.

const NIVEIS := [1, 5, 10, 15, 20]
const VIDAS := [100, 160, 230, 320, 500]
const ALCANCES := [170.0, 220.0, 280.0, 350.0, 450.0]     ## u de mundo
const CUSTO_ABRIGO := [["madeira", 8], ["sucata", 4]]
const M := IsoMath.METRO

var jogador: Node = null
var totem: Dictionary = {}        ## {no, tier, nivel, hp, max, alcance} — vazio = sem totem
var abrigo: bool = false
var _no_abrigo: Node2D = null


func tem_totem() -> bool:
	return not totem.is_empty()


## Põe o totem do slot 'slot' da mochila no chão, onde o jogador está.
func colocar_totem(slot: int) -> void:
	var inv: Inventario = jogador.inventario
	var x = inv.slots[slot]
	if x == null or x.id != "totem":
		return
	if tem_totem():
		jogador.aviso("Você já possui um totem ativo. Remova-o antes.")
		return
	var t: int = clampi(int(x.get("tier", 0)), 0, 4)
	inv.retirar(slot, 1)
	var no: Node2D = TotemNo.new()
	jogador.get_parent().add_child(no)
	no.global_position = jogador.global_position
	no.alcance = ALCANCES[t]
	var vida: float = VIDAS[t] * (1.5 if jogador.origem == "mestre_obras" else 1.0)   # Mestre de Obras: +50%
	totem = {"no": no, "tier": t, "nivel": NIVEIS[t], "hp": vida, "max": vida, "alcance": ALCANCES[t]}
	jogador.aviso("Totem de nível %d colocado. Proteção em raio de %.1f m." % [NIVEIS[t], ALCANCES[t] / M])


func _dist_ao_totem(pos_tela: Vector2) -> float:
	return IsoMath.tela_para_mundo(totem.no.global_position - pos_tela).length()


func remover_totem() -> void:
	if not tem_totem():
		jogador.aviso("Nenhum totem colocado.")
		return
	if _dist_ao_totem(jogador.global_position) > 4.0 * M:
		jogador.aviso("Aproxime-se do totem para recolhê-lo.")
		return
	if jogador.inventario.adicionar_parcial("totem", 1, {"tier": totem.tier}) > 0:
		jogador.aviso("Inventário cheio! Libere um slot.")
		return
	totem.no.queue_free()
	if _no_abrigo != null:
		_no_abrigo.queue_free()
		_no_abrigo = null
	totem = {}
	abrigo = false
	jogador.aviso("Totem recolhido para o inventário.")


## Abrigo básico: ao lado do totem, 3 m para o sul-leste do mundo (V13: build).
## Custo do abrigo; o Mestre de Obras paga 25% menos.
func custo_abrigo() -> Array:
	var out: Array = []
	for c in CUSTO_ABRIGO:
		out.append([c[0], Origens.desconto(c[1]) if jogador.origem == "mestre_obras" else int(c[1])])
	return out


func construir_abrigo() -> void:
	if not tem_totem():
		jogador.aviso("É necessário colocar um totem antes de estabelecer um esconderijo.")
		return
	if abrigo:
		jogador.aviso("Você já possui um abrigo vinculado ao totem.")
		return
	var inv: Inventario = jogador.inventario
	var custo := custo_abrigo()
	for c in custo:
		if inv.contar(c[0]) < c[1]:
			jogador.aviso("Para construir: %s." % Itens.texto_lista(custo))
			return
	for c in custo:
		inv.remover(c[0], c[1])
	abrigo = true
	_no_abrigo = AbrigoNo.new()
	jogador.get_parent().add_child(_no_abrigo)
	_no_abrigo.global_position = totem.no.global_position + IsoMath.mundo_para_tela(Vector2(3.0 * M, 3.0 * M))
	jogador.aviso("Abrigo construído. O totem marca esta área como seu território.")


## O ponto (px globais) está dentro do território do totem?
func protege(pos_tela: Vector2) -> bool:
	return tem_totem() and _dist_ao_totem(pos_tela) < totem.alcance


func resumo() -> String:
	if not tem_totem():
		return "Nenhum totem colocado."
	return "Nível %d • %d/%d HP • raio %.1f m%s" % [totem.nivel, ceili(totem.hp), totem.max, totem.alcance / M,
		" • abrigo construído" if abrigo else ""]


## Totem e abrigo para o SaveJogo (posição do totem em u de mundo).
func dados_para_salvar() -> Dictionary:
	if not tem_totem():
		return {}
	var p := IsoMath.tela_para_mundo(totem.no.global_position)
	return {"totem": {"p": [p.x, p.y], "tier": totem.tier, "hp": totem.hp}, "abrigo": abrigo}


func restaurar(d: Dictionary) -> void:
	if not d.has("totem"):
		return
	var td: Dictionary = d["totem"]
	var t: int = clampi(int(td.get("tier", 0)), 0, 4)
	var no: Node2D = TotemNo.new()
	jogador.get_parent().add_child(no)
	var pl: Array = td["p"]
	no.global_position = IsoMath.mundo_para_tela(Vector2(float(pl[0]), float(pl[1])))
	no.alcance = ALCANCES[t]
	totem = {"no": no, "tier": t, "nivel": NIVEIS[t], "hp": float(td.get("hp", VIDAS[t])), "max": VIDAS[t], "alcance": ALCANCES[t]}
	if bool(d.get("abrigo", false)):
		abrigo = true
		_no_abrigo = AbrigoNo.new()
		jogador.get_parent().add_child(_no_abrigo)
		_no_abrigo.global_position = no.global_position + IsoMath.mundo_para_tela(Vector2(3.0 * M, 3.0 * M))
