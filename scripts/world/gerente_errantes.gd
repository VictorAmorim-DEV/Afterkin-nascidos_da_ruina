class_name GerenteErrantes
extends Node
## Ponte entre o ecossistema abstrato de errantes (Errantes) e o mundo (etapa 10b): roda as horas da simulação e,
## a cada segundo, dá corpo (Errante) aos agentes que estão perto do jogador — onde quer que a vida deles os tenha
## levado — e devolve ao abstrato os que ficaram longe. Ninguém nasce "para o jogador": se você chega a uma cidade,
## quem já estava lá aparece; se alguém chega à cidade onde você está, ele aparece chegando.
## Agentes dentro das comunidades não ganham corpo (estão lá dentro).

const PERTO := 60.0 * IsoMath.METRO
const LONGE := 80.0 * IsoMath.METRO

var _corpos: Dictionary = {}       ## id do agente -> Errante
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	Errantes.passo()
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null:
		return
	var pj := IsoMath.tela_para_mundo((j.dirigindo if j.dirigindo != null else j).global_position)
	for id in _corpos.keys():
		var e: Errante = _corpos[id]
		if not is_instance_valid(e):
			_corpos.erase(id)
			continue
		if e.morto:
			continue
		if not bool(e.agente["vivo"]) or e._mundo().distance_to(pj) > LONGE or Comunidades.em(e._mundo()) != "":
			e.devolver()
			e.queue_free()
			_corpos.erase(id)
	for a in Errantes.vivos():
		var aid := str(a["id"])
		var dist := (a["p"] as Vector2).distance_to(pj)
		a["perto"] = dist < Errantes.PERTO_JOGADOR
		if not _corpos.has(aid) and bool(a["perto"]):
			_andar_um_segundo(a)                    # chega andando, em tempo real, até ganhar corpo
		if _corpos.has(aid) or dist > PERTO:
			continue
		if Comunidades.em(a["p"]) != "":
			continue
		var e2 := Errante.de_agente(a)
		get_parent().add_child(e2)
		_corpos[aid] = e2


## Agente sem corpo, mas perto do jogador: anda 1 s na velocidade de um corpo rumo ao destino.
func _andar_um_segundo(a: Dictionary) -> void:
	Errantes._objetivo(a)
	var v: Vector2 = (a["destino"] as Vector2) - (a["p"] as Vector2)
	var passo := Npc.VEL * (0.7 if bool(a["ferido"]) else 1.0)
	a["p"] = a["destino"] if v.length() <= passo else (a["p"] as Vector2) + v.normalized() * passo


func corpos() -> Array:
	return _corpos.values().filter(func(e): return is_instance_valid(e))


## Compatibilidade com o teste antigo (lista dos errantes com corpo).
func errantes() -> Array:
	return corpos()
