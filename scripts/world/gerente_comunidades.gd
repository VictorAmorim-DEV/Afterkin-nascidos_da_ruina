class_name GerenteComunidades
extends Node
## Põe os moradores das comunidades no mundo quando o jogador chega perto e os tira quando ele se afasta
## ("abstrata longe, real perto", Q43: a simulação de longe é a etapa 8). Também abre e fecha os portões das
## comunidades pelo horário de cada uma.

const PERTO := 5200.0          ## u de mundo da borda da comunidade para os NPCs aparecerem (~105 m)
const LONGE := 7200.0          ## ... e para sumirem
const FIGURANTES_ROTINA := {"madrugada": "casa", "amanhecer": "casa", "manha": "trabalho", "tarde": "praca",
	"tardezinha": "fogueira", "noite": "casa"}

var _vivos: Dictionary = {}    ## id da comunidade -> [Npc]
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	if j == null:
		return
	var pj := IsoMath.tela_para_mundo((j.dirigindo if j.dirigindo != null else j).global_position)
	for id in Comunidades.ids():
		var g := Comunidades.geo(str(id))
		if g.is_empty():
			continue
		var d := _dist_rect(pj, g["area"])
		if d < PERTO and not _vivos.has(id):
			_criar(str(id))
		elif d > LONGE and _vivos.has(id):
			_remover(str(id))
	if ciclo != null:
		for p in get_tree().get_nodes_in_group("portao"):
			var pt := p as PortaoNo
			if pt != null and pt.comunidade != "":
				pt.definir_aberto(Comunidades.portao_aberto(pt.comunidade, float(ciclo.minutos)))


static func _dist_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _criar(id: String) -> void:
	var cd := Comunidades.dados(id)
	var lista: Array = (cd.get("npcs", []) as Array).duplicate()
	for k in int(cd.get("figurantes", 0)):
		lista.append({"id": "figurante_%d" % k, "nome": "Morador" if k % 2 == 0 else "Moradora", "papel": "figurante",
			"casa": lista.size(), "rotina": FIGURANTES_ROTINA})
	var mundo := get_parent()
	var nos: Array = []
	for i in lista.size():
		var n := Npc.new()
		n.comunidade = id
		n.dados = lista[i]
		n.indice = i
		mundo.add_child(n)
		n.posicionar()
		nos.append(n)
	_vivos[id] = nos


func _remover(id: String) -> void:
	for n in _vivos[id]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_vivos.erase(id)


## NPCs presentes agora (para testes e para o mapa).
func npcs(id: String) -> Array:
	return _vivos.get(id, [])
