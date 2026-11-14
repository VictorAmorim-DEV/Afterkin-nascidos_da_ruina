class_name ColetaSolta
extends Node2D
## Galho ou pedra pequena solta no chão (V13: branch / pebble, l.1398-1404). Pega com E, sem ferramenta:
## 1 a 3 de madeira ou pedra e 2 de XP. Sem colisão: é só um recurso no chão.
## O Mundo guarda a posição do que foi pego, então o chunk recarregado não traz o objeto de volta.

const RAIO := 1.0 * IsoMath.METRO
const TIPOS := {
	"galho": {"item": "madeira", "msg": "Você pegou um galho.", "dica": "E — pegar galho",
		"sprites": ["tronco_03"], "escala": 0.45},
	"pedrinha": {"item": "pedra", "msg": "Você pegou pedras pequenas.", "dica": "E — pegar pedra pequena",
		"sprites": ["pedra_04", "pedra_06", "pedra_07", "pedra_09", "pedra_10", "pedra_11"], "escala": 0.6},
}
const PASTA := "res://assets/sprites_hd_recortados/objetos_natureza/%s.png"

var tipo: String = "galho"
var variante: int = 0            ## sorteada pelo MundoGen (determinística)
var origem := Vector2.ZERO       ## posição de MUNDO do spec (chave para o Mundo lembrar que foi pego)


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("coleta_solta")
	var t: Dictionary = TIPOS[tipo]
	var nomes: Array = t["sprites"]
	var s := Sprite2D.new()
	s.texture = load(PASTA % nomes[variante % nomes.size()])
	s.scale = Vector2.ONE * float(t["escala"])
	s.flip_h = variante % 2 == 1
	s.centered = true
	if s.texture != null:
		s.offset = Vector2(0, -s.texture.get_height() * 0.5 + 3.0)    # a base do sprite fica na origem
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.light_mask = 2
	add_child(s)


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func distancia_ao_jogador() -> float:
	var j := _jogador()
	if j == null:
		return INF
	return IsoMath.tela_para_mundo(global_position - j.global_position).length()


func _e_o_alvo() -> bool:
	var d := distancia_ao_jogador()
	if d > RAIO:
		return false
	for o in get_tree().get_nodes_in_group("coleta_solta"):
		if o != self and o.distancia_ao_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 8                                     # abaixo do item largado (10), acima dos recipientes (5)


func texto_interacao() -> String:
	return TIPOS[tipo]["dica"] if _e_o_alvo() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	if get_tree().get_nodes_in_group("item_chao").any(func(i): return i.texto_interacao() != ""):
		return                                   # item largado tem prioridade
	var j := _jogador()
	if j == null or not "inventario" in j or j.dirigindo != null:
		return
	get_viewport().set_input_as_handled()
	var t: Dictionary = TIPOS[tipo]
	var g := [[t["item"], randi_range(1, 3)]]
	if not j.inventario.pode_adicionar(g):
		j.aviso("Inventário cheio! Libere espaço para coletar.")
		return
	j.inventario.adicionar_itens(g)
	j.ganhar_xp(2)
	j.aviso(t["msg"])
	var m := get_tree().get_first_node_in_group("mundo")
	if m != null and m.has_method("marcar_coletado"):
		m.marcar_coletado(origem)
	queue_free()
