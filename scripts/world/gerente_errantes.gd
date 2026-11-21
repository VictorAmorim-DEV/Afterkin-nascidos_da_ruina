class_name GerenteErrantes
extends Node
## Põe sobreviventes errantes (Errante) nas ruas das cidades perto do jogador, de vez em quando, e os tira quando
## ele se afasta (marco 2, etapa 10; Q42). No máximo MAX ao mesmo tempo; à noite, mais saqueadores.

const MAX := 2
const LONGE := 95.0 * IsoMath.METRO
const PESOS_DIA := {"assustado": 25, "ferido": 20, "andarilho": 15, "saqueador": 18, "em_combate": 22}
const PESOS_NOITE := {"assustado": 10, "ferido": 15, "andarilho": 5, "saqueador": 50, "em_combate": 20}

var _vivos: Array = []
var _t := 5.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 3.0
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null or j.morto:
		return
	var pj := IsoMath.tela_para_mundo((j.dirigindo if j.dirigindo != null else j).global_position)
	for e in _vivos.duplicate():
		if not is_instance_valid(e):
			_vivos.erase(e)
		elif IsoMath.tela_para_mundo((e as Node2D).global_position).distance_to(pj) > LONGE:
			for z in (e as Errante).zumbis:
				if is_instance_valid(z):
					(z as Node).queue_free()
			(e as Node).queue_free()
			_vivos.erase(e)
	if _vivos.size() >= MAX or MundoGen.zona(pj) != "urbano" or Comunidades.perto(pj, 60.0 * IsoMath.METRO) != "":
		return
	if _rng.randf() < 0.2:
		criar(_sortear_tipo(), pj)


func _sortear_tipo() -> String:
	var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
	var pesos: Dictionary = PESOS_NOITE if ciclo != null and ciclo.eh_noite() else PESOS_DIA
	var total := 0
	for k in pesos:
		total += int(pesos[k])
	var r := _rng.randi_range(1, total)
	for k in pesos:
		r -= int(pesos[k])
		if r <= 0:
			return str(k)
	return "assustado"


## Um ponto de rua a 25–40 m do jogador (INF se não achar).
func _ponto_de_rua(pj: Vector2) -> Vector2:
	var area := Rect2(pj - Vector2.ONE * 45.0 * IsoMath.METRO, Vector2.ONE * 90.0 * IsoMath.METRO)
	var faixas := MundoGen.ruas(area)
	for tent in 20:
		if faixas.is_empty():
			break
		var fd: Dictionary = faixas[_rng.randi() % faixas.size()]
		var r: Rect2 = (fd["r"] as Rect2).intersection(area)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var p := Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))
		var d := p.distance_to(pj)
		if d > 25.0 * IsoMath.METRO and d < 40.0 * IsoMath.METRO:
			return p
	return Vector2.INF


func criar(tipo: String, pj: Vector2) -> Errante:
	var p := _ponto_de_rua(pj)
	if p == Vector2.INF:
		return null
	var e := Errante.criar(tipo, p, _rng)
	var mundo := get_parent()
	mundo.add_child(e)
	_vivos.append(e)
	if tipo == "em_combate":
		var cena := load("res://scenes/enemies/inimigo.tscn") as PackedScene
		for k in _rng.randi_range(1, 2):
			var z := cena.instantiate() as Inimigo
			z.raca = "zombie"
			z.dorme = false
			z.position = IsoMath.mundo_para_tela(p + Vector2.from_angle(_rng.randf() * TAU) * 1.6 * IsoMath.METRO)
			mundo.add_child(z)
			e.zumbis.append(z)
	return e


func errantes() -> Array:
	return _vivos.filter(func(e): return is_instance_valid(e))
