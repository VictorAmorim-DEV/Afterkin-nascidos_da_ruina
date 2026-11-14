class_name ItemNoChao
extends Node2D
## Item solto no mundo. Pegue com E; largue pelo inventário (botões "Largar").
## A origem do nó fica no chão (pé do objeto), por isso o Y-Sort funciona.

const RAIO := 1.0 * IsoMath.METRO       ## alcance da coleta, em unidades de mundo
const CENA := preload("res://scenes/items/item_no_chao.tscn")

var id: String = "madeira"
var quantidade: int = 1
var extra: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
var _t: float = 0.0


## Cria o item em 'pos_tela' (px globais) dentro de 'pai'.
static func largar(pai: Node, pos_tela: Vector2, id_: String, qtd: int, extra_: Dictionary = {}) -> ItemNoChao:
	var n: ItemNoChao = CENA.instantiate()
	n.id = id_
	n.quantidade = qtd
	n.extra = extra_
	pai.add_child(n)
	n.global_position = pos_tela
	return n


func _ready() -> void:
	add_to_group("item_chao")
	add_to_group("interativo")
	_sprite.texture = Itens.icone(id)
	_sprite.scale = Vector2.ONE * (22.0 / maxf(1.0, _sprite.texture.get_width())) if _sprite.texture else Vector2.ONE
	_sprite.position = Vector2(0, -9)
	_t = randf() * TAU
	queue_redraw()


func _draw() -> void:
	# sombra no chão (elipse achatada, como o chão isométrico)
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(Vector2(cos(a) * 10.0, sin(a) * 5.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))


func _process(delta: float) -> void:
	_t += delta * 2.5
	_sprite.position.y = -9.0 + sin(_t) * 1.5


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func distancia_ao_jogador() -> float:
	var j := _jogador()
	if j == null:
		return INF
	return IsoMath.tela_para_mundo(global_position - j.global_position).length()


## Este é o item mais próximo do jogador e está ao alcance?
func _e_o_alvo() -> bool:
	var d := distancia_ao_jogador()
	if d > RAIO:
		return false
	for o in get_tree().get_nodes_in_group("item_chao"):
		if o != self and o.distancia_ao_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 10


func texto_interacao() -> String:
	if not _e_o_alvo():
		return ""
	return "E — pegar %s%s" % [Itens.nome(id).to_lower(), " ×%d" % quantidade if quantidade > 1 else ""]


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	var j := _jogador()
	if j == null or not "inventario" in j or j.dirigindo != null:
		return
	get_viewport().set_input_as_handled()
	var resto: int = j.inventario.adicionar_parcial(id, quantidade, extra)
	if resto >= quantidade:
		j.aviso("Inventário cheio! Libere espaço para pegar.")
		return
	j.aviso("Você pegou %d %s." % [quantidade - resto, Itens.nome(id).to_lower()])
	quantidade = resto
	if quantidade <= 0:
		queue_free()
