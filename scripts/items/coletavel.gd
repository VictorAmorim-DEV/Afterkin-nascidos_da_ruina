class_name Coletavel
extends Node2D
## Árvore ou pedra grande que se colhe com ferramenta equipada (V13: NODE, harvestHit).
## Fica como filho do objeto do cenário; ao esgotar, o objeto inteiro some (V13: toco/pedra usada).

const DADOS := {
	"arvore": {"ferramenta": "machado", "nome": "a árvore", "hp": 5, "item": "madeira", "dica": "Cortar árvore (machado)"},
	"rocha": {"ferramenta": "picareta", "nome": "a pedra", "hp": 6, "item": "pedra", "dica": "Quebrar pedra (picareta)"},
}
const ALCANCE := 95.0       ## unidades de mundo (V13: 75 a partir da borda da base)

@export_enum("arvore", "rocha") var tipo: String = "arvore"
var hp: int = 0
var usado: bool = false


func _ready() -> void:
	hp = DADOS[tipo].hp
	add_to_group("coletavel")
	add_to_group("interativo")


func distancia(p_tela: Vector2) -> float:
	return IsoMath.tela_para_mundo(global_position - p_tela).length()


func _alvo() -> bool:
	var j := get_tree().get_first_node_in_group("jogador")
	if usado or j == null or distancia(j.global_position) > ALCANCE:
		return false
	var d := distancia(j.global_position)
	for o in get_tree().get_nodes_in_group("coletavel"):
		if o != self and not o.usado and o.distancia(j.global_position) < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 2


func texto_interacao() -> String:
	return "Botão esquerdo — " + DADOS[tipo].dica if _alvo() else ""


func esta_ao_alcance(p_tela: Vector2) -> bool:
	return not usado and distancia(p_tela) <= ALCANCE


## Um golpe do jogador. Devolve true se houve golpe (gasta o tempo de recarga).
func golpear(j: Node) -> bool:
	var d: Dictionary = DADOS[tipo]
	if j.inventario.id_equipado() != d.ferramenta:
		j.aviso("Equipe %s no inventário para atacar %s." % ["um machado" if d.ferramenta == "machado" else "uma picareta", d.nome])
		return false
	if hp == 1 and not j.inventario.pode_adicionar([[d.item, 5]]):
		j.aviso("Inventário cheio! Libere espaço antes do golpe final.")
		return false
	hp -= 1
	_chacoalhar()
	if hp > 0:
		j.aviso("Golpe em %s (%d/%d)." % [d.nome, d.hp - hp, d.hp])
		return true
	var n := randi_range(3, 5)
	j.inventario.adicionar_itens([[d.item, n]])
	usado = true
	j.ganhar_xp(8)
	j.aviso("+%d %s coletada(s)." % [n, Itens.nome(d.item).to_lower()])
	var alvo := get_parent() as CanvasItem
	remove_from_group("interativo")
	var t := create_tween()
	t.tween_interval(0.2)
	t.tween_property(alvo, "modulate:a", 0.0, 0.5)
	t.tween_callback(alvo.queue_free)
	return true


func _chacoalhar() -> void:
	var pai := get_parent() as Node2D
	if pai == null:
		return
	var base := pai.position
	var t := create_tween()
	t.tween_property(pai, "position", base + Vector2(2.5, 0), 0.04)
	t.tween_property(pai, "position", base + Vector2(-2.5, 0), 0.08)
	t.tween_property(pai, "position", base, 0.04)
