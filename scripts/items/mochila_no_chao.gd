class_name MochilaNoChao
extends Node2D
## Mochila que ficou no corpo quando o jogador morreu (Respawn, Q7/Q51): guarda todos os slots. E pega tudo o que
## couber; o que não couber continua aqui. Vai para o save e aparece no mapa do mundo.

const RAIO := 1.3 * IsoMath.METRO

var slots: Array = []


## Cria a mochila em 'p' (u de mundo) dentro de 'pai'.
static func largar(pai: Node, p: Vector2, slots_: Array) -> MochilaNoChao:
	var n := MochilaNoChao.new()
	n.slots = slots_
	pai.add_child(n)
	n.global_position = IsoMath.mundo_para_tela(p)
	return n


func _ready() -> void:
	y_sort_enabled = true
	light_mask = 2
	add_to_group("interativo")
	add_to_group("mochila_chao")
	queue_redraw()


func itens() -> int:
	return slots.filter(func(x): return x != null).size()


func _draw() -> void:
	# mancha escura no chão e a mochila tombada
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(Vector2(cos(a) * 22.0, sin(a) * 10.0) + Vector2(4, 2))
	draw_colored_polygon(pts, Color(0.18, 0.05, 0.04, 0.55))
	var lona := Color8(78, 92, 62)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(9, -6), Vector2(13, 3), Vector2(-7, 8)]), lona.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(9, -6), Vector2(8, -15), Vector2(-11, -12)]), lona)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -11), Vector2(6, -14), Vector2(5, -18), Vector2(-8, -16)]), lona.lightened(0.15))
	draw_line(Vector2(-6, -12), Vector2(-5, -1), Color8(40, 44, 34), 2.0)
	draw_line(Vector2(4, -14), Vector2(5, -3), Color8(40, 44, 34), 2.0)


func _jogador() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func _dist() -> float:
	var j := _jogador()
	if j == null:
		return INF
	return IsoMath.tela_para_mundo(global_position - j.global_position).length()


func _e_o_alvo() -> bool:
	var d := _dist()
	if d > RAIO:
		return false
	for o in get_tree().get_nodes_in_group("mochila_chao"):
		if o != self and o._dist() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 9


func texto_interacao() -> String:
	if not _e_o_alvo():
		return ""
	var n := itens()
	return "E — pegar sua mochila (%d %s)" % [n, "item" if n == 1 else "itens"]


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	var j := _jogador()
	if j == null or not "inventario" in j or j.dirigindo != null or j.morto:
		return
	get_viewport().set_input_as_handled()
	var pegou := 0
	for i in slots.size():
		var x = slots[i]
		if x == null:
			continue
		var extra: Dictionary = {}
		for k in (x as Dictionary).keys():
			if not k in ["id", "quantidade", "maximo"]:
				extra[k] = x[k]
		var qtd: int = int(x["quantidade"])
		var resto: int = j.inventario.adicionar_parcial(str(x["id"]), qtd, extra)
		pegou += qtd - resto
		if resto <= 0:
			slots[i] = null
		else:
			x["quantidade"] = resto
	if itens() == 0:
		j.aviso("Você recuperou sua mochila.")
		queue_free()
	elif pegou > 0:
		j.aviso("Você pegou o que coube. O resto continua na mochila.")
	else:
		j.aviso("Mochila cheia! Libere espaço para pegar suas coisas.")
