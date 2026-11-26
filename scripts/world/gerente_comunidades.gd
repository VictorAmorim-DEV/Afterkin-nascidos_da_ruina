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
var _murais: Dictionary = {}   ## id da comunidade -> MuralNo
var _t := 0.0
var _t_ouvir := 10.0           ## espera até a próxima conversa ouvida (s)
var _ultimo_h := -1.0          ## hora de jogo da última passada (trabalhos da VidaComunidade)
var _estruturas: Dictionary = {}   ## id da comunidade -> [nós da VidaComunidade: barril, bancada, cama de hóspede]
const RESPOSTAS := ["Deus nos ajude.", "Era só o que faltava.", "E a gente aqui, esperando a próxima.",
	"Quem sabe amanhã melhora.", "Não fala alto, que dá azar.", "É... cada dia uma."]


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t_ouvir -= 0.5
	if _t_ouvir <= 0.0:
		_conversa_ouvida()
	_t = 0.5
	DiarioPartida.passo(0.5)                   # rota, tempo por lugar e salvamento automático do diário
	Reputacao.passo()                          # boatos que chegaram à hora de correr
	Simulacao.passo()                          # turnos do ecossistema das comunidades (longe e perto)
	Portaria.passo(get_tree())                 # quem mentiu sobre a arma e aparece com ela lá dentro
	Vigilancia.passo(get_tree())               # quem contou dos seus olhos; o vampiro reconhecido
	NoiteDoAtaque.passo(get_tree())            # a noite do ataque (ato 1) e o portão arrombado
	var agora_h := Reputacao.agora_h()
	if _ultimo_h >= 0.0 and agora_h > _ultimo_h and agora_h - _ultimo_h < 1.0:
		VidaComunidade.passo(agora_h - _ultimo_h)     # trabalho em tempo real (o sono não conta)
	_ultimo_h = agora_h
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
				# sempre fechado: só abre quando o guarda abre para alguém passar (Portaria)
				pt.definir_aberto(NoiteDoAtaque.arrombado(pt.comunidade) or (Portaria.aberto(pt.comunidade) \
					and not Consequencias.portao_fechado_para(pt.comunidade, pj) \
					and not VidaComunidade.portao_fechado_para(pt.comunidade, pj)))


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
		if not Reputacao.vivo(id, str((lista[i] as Dictionary).get("id", ""))):
			continue                            # morreu de vez (Q44)
		var n := Npc.new()
		n.comunidade = id
		n.dados = lista[i]
		n.indice = i
		mundo.add_child(n)
		n.posicionar()
		nos.append(n)
	_vivos[id] = nos
	var g := Comunidades.geo(id)
	if not _murais.has(id) and not g.is_empty():
		var m := MuralNo.new()
		m.comunidade = id
		mundo.add_child(m)
		m.global_position = IsoMath.mundo_para_tela((g["fogueira"] as Vector2) + Vector2(140.0, -130.0))
		_murais[id] = m
	if not _estruturas.has(id) and not g.is_empty():
		var lista_e: Array = []
		var f: Vector2 = g["fogueira"]
		for par in [["agua", Vector2(-170.0, -150.0)], ["bancada", Vector2(230.0, 60.0)]]:
			var e := EstruturaNo.new()
			e.comunidade = id
			e.tipo = par[0]
			mundo.add_child(e)
			e.global_position = IsoMath.mundo_para_tela(f + (par[1] as Vector2))
			lista_e.append(e)
		var ch := CamaHospede.new()
		ch.comunidade = id
		mundo.add_child(ch)
		ch.global_position = IsoMath.mundo_para_tela(f + Vector2(-230.0, 90.0))
		lista_e.append(ch)
		_estruturas[id] = lista_e


func _remover(id: String) -> void:
	for n in _vivos[id]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_vivos.erase(id)
	if _murais.has(id):
		if is_instance_valid(_murais[id]):
			(_murais[id] as Node).queue_free()
		_murais.erase(id)
	for e in _estruturas.get(id, []):
		if is_instance_valid(e):
			(e as Node).queue_free()
	_estruturas.erase(id)


## Dois moradores parados conversando perto do jogador: ele ouve. Novidade do diário vira rumor; senão, uma das
## conversas fixas do arquivo da comunidade ("conversas_ouvidas"), cada uma uma vez.
func _conversa_ouvida() -> void:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j == null or j.dirigindo != null:
		_t_ouvir = 5.0
		return
	for id in _vivos:
		var nos: Array = (_vivos[id] as Array).filter(func(n): return is_instance_valid(n) and (n as Npc).parado())
		for a in nos.size():
			for b in range(a + 1, nos.size()):
				var na: Npc = nos[a]
				var nb: Npc = nos[b]
				var pa := IsoMath.tela_para_mundo(na.global_position)
				var pb := IsoMath.tela_para_mundo(nb.global_position)
				var meio := (pa + pb) * 0.5
				if pa.distance_to(pb) < 5.0 * IsoMath.METRO and meio.distance_to(IsoMath.tela_para_mundo(j.global_position)) < 8.0 * IsoMath.METRO:
					if _falar_par(str(id), na, nb, j):
						_t_ouvir = randf_range(30.0, 50.0)
						return
	_t_ouvir = 4.0


func _falar_par(id: String, na: Npc, nb: Npc, j: Node) -> bool:
	var lt := Consequencias.conversa_luto(id)
	if not lt.is_empty():
		na.falar(str(lt[0]), 4.5)
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(nb):
				nb.falar(str(lt[1]), 4.0))
		return true
	var n := Rumores.novidade_para(id)
	if not n.is_empty():
		na.falar("Ficou sabendo? %s" % str(n["texto"]), 5.0)
		get_tree().create_timer(2.6).timeout.connect(func():
			if is_instance_valid(nb):
				nb.falar(RESPOSTAS.pick_random(), 3.5))
		var av := Rumores.ouvir(n)
		if av != "":
			j.aviso(av)
		return true
	var lista: Array = Comunidades.dados(id).get("conversas_ouvidas", [])
	for i in lista.size():
		var chave := "ouvida_%s_%d" % [id, i]
		if Conversas.flags.has(chave):
			continue
		var cv: Dictionary = lista[i]
		if Consequencias.cita_morto(str(cv["a"]) + " " + str(cv["b"])):
			continue                               # fala de quem já morreu como se estivesse vivo
		Conversas.flags[chave] = true
		na.falar(str(cv["a"]), 4.5)
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(nb):
				nb.falar(str(cv["b"]), 4.0))
		if cv.has("rumor"):
			var av2 := Rumores.conhecer(str(cv["rumor"]))
			if av2 != "":
				j.aviso(av2)
		return true
	return false


## NPCs presentes agora (para testes e para o mapa).
func npcs(id: String) -> Array:
	return _vivos.get(id, [])
