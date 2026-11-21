class_name Errantes
extends RefCounted
## Ecossistema vivo de sobreviventes errantes (marco 2, etapa 10b; pedido de 20/11/2026).
##
## Uma população persistente vive no mapa sem depender do jogador: anda, vasculha a cidade, caça, procura água,
## pede abrigo nas comunidades, luta com monstros, foge, embosca e se junta em grupos. Cada errante tem nome, índole
## (pacifico, desconfiado, oportunista, hostil), necessidades (fome, sede, vida), munição, o que carrega, um
## objetivo, a posição no mundo e a opinião que tem do jogador. Morre de vez; chegam outros com o tempo.
##
## - LONGE do jogador (abstrato): a cada hora de jogo cada um anda rumo ao objetivo e os encontros são sorteados
##   pelo perigo da zona e pela hora (monstros, outros errantes, chegada a uma comunidade).
## - PERTO do jogador (real): o GerenteErrantes cria o nó Errante, que continua o que o agente fazia; ao se afastar,
##   o estado volta para cá.
## - Bandos de saqueadores têm uma toca numa cidade e emboscam quem passa; a reputação do jogador com eles
##   (Reputacao "saqueadores") decide se o deixam passar ou se o convidam.
## - As expedições das comunidades também são agentes daqui (papel "expedicao"): saem, vasculham e voltam.
## Tudo que importa vai para o diário da Simulacao (com = comunidade mais perto ou ""), de onde saem os rumores.

const POP_INICIAL := 30
const POP_MIN := 24
## ~200 m por hora de jogo: a mesma velocidade de um corpo andando (1,7 m/s × 100 s reais por hora de jogo),
## com paradas. A ilha tem ~5 km: atravessá-la leva mais de um dia de jogo.
const VEL_H := 200.0 * IsoMath.METRO
const PERTO_JOGADOR := 160.0 * IsoMath.METRO       ## mais perto que isso, o GerenteErrantes anda com ele em tempo real
const INDOLES := {"pacifico": 30, "desconfiado": 30, "oportunista": 25, "hostil": 15}
const NOMES_M := ["Seu Josué", "Kléber", "Wellington", "Diego", "Juarez", "Mané", "Rogério", "Seu Ari", "Edson", "Baiano",
	"Fábio", "Seu Nonato", "Rafael", "Tião", "Gilmar", "Cleiton"]
const NOMES_F := ["Dona Lurdes", "Patrícia", "Rita", "Sandra", "Cida", "Tainá", "Jussara", "Dona Zefa", "Bruna", "Neusa",
	"Kátia", "Dona Socorro", "Luana", "Marta", "Vânia", "Débora"]
## Monstros: força no combate (1 = um zumbi) e se só saem de noite. Bárbaros, feiticeiras e outros entram aqui.
const MONSTROS := {"zombie": {"por": "por zumbis", "forca": 1.0, "noite": false},
	"rat": {"por": "por ratos gigantes", "forca": 0.7, "noite": false},
	"vampire": {"por": "pelos da noite", "forca": 2.2, "noite": true}}
## Chance de topar com monstros por hora, por zona (à noite ×1,8).
const PERIGO_ZONA := {"urbano": 0.035, "aldeia": 0.02, "mata": 0.02, "semiarido": 0.015, "deserto": 0.012, "acampamento": 0.01}

static var agentes: Dictionary = {}          ## id -> agente
static var grupos: Dictionary = {}           ## gid -> {membros: [id], faccao, toca: Vector2}
static var _ultimo_h := -1.0
static var _seq := 0
static var _rng := RandomNumberGenerator.new()


static func zerar() -> void:
	agentes = {}
	grupos = {}
	_ultimo_h = -1.0
	_seq = 0


static func iniciar() -> void:
	if not agentes.is_empty() or _ultimo_h >= 0.0:
		return
	_rng.randomize()
	_ultimo_h = Reputacao.agora_h()
	# três bandos de saqueadores, cada um com a toca numa cidade
	for b in 3:
		var toca := _ponto_urbano()
		var gid := "bando_%d" % b
		grupos[gid] = {"membros": [], "faccao": "saqueadores", "toca": toca}
		for k in _rng.randi_range(3, 4):
			var a := novo("saqueador", toca + _desvio(40.0), "hostil")
			a["grupo"] = gid
			(grupos[gid]["membros"] as Array).append(a["id"])
	while agentes.size() < POP_INICIAL:
		var p := _ponto_urbano() if _rng.randf() < 0.7 else _ponto_estrada()
		var papel: String = ["andarilho", "catador", "cacador"][_rng.randi() % 3]
		var a := novo(papel, p, _sortear_indole())
		if _rng.randf() < 0.25:                    # família ou dupla andando junto
			var gid := "grupo_%d" % _seq
			grupos[gid] = {"membros": [a["id"]], "faccao": "", "toca": Vector2.INF}
			a["grupo"] = gid
			for k in _rng.randi_range(1, 2):
				var b := novo(papel, p + _desvio(4.0), a["indole"])
				b["grupo"] = gid
				(grupos[gid]["membros"] as Array).append(b["id"])


## Cria um agente e o põe na população.
static func novo(papel: String, p: Vector2, indole: String) -> Dictionary:
	_seq += 1
	var fem := _rng.randf() < 0.5
	var nomes: Array = NOMES_F if fem else NOMES_M
	var a := {"id": "e%d" % _seq, "nome": str(nomes[_rng.randi() % nomes.size()]), "genero": "f" if fem else "m",
		"papel": papel, "indole": indole, "grupo": "", "com": "", "p": p, "destino": p, "objetivo": "",
		"fome": _rng.randf_range(50.0, 100.0), "sede": _rng.randf_range(50.0, 100.0), "vida": 100.0,
		"municao": _rng.randi_range(0, 3) if papel != "saqueador" else _rng.randi_range(2, 6),
		"itens": {}, "opiniao": 0, "real": false, "ferido": false, "lembra": [], "vivo": true}
	if papel == "andarilho":
		a["itens"] = {"comida": _rng.randi_range(1, 4), "agua_limpa": _rng.randi_range(0, 2), "pano": _rng.randi_range(1, 3),
			"bandagem": _rng.randi_range(0, 2), "garrafa": _rng.randi_range(0, 2)}
	else:
		a["itens"] = {"comida": _rng.randi_range(0, 2), "sucata": _rng.randi_range(0, 3)}
	agentes[a["id"]] = a
	return a


static func _sortear_indole() -> String:
	var r := _rng.randi_range(1, 100)
	for k in INDOLES:
		r -= int(INDOLES[k])
		if r <= 0:
			return str(k)
	return "desconfiado"


static func _desvio(m: float) -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, m) * IsoMath.METRO


## Um ponto de rua numa cidade qualquer (fora das áreas especiais).
static func _ponto_urbano() -> Vector2:
	for tent in 30:
		var a := _rng.randi() % MundoGen.AREAS.size()
		if str(MundoGen.AREAS[a].get("cat", "")) == "especial" and _rng.randf() < 0.7:
			continue
		var r := MundoGen.area_rect(a)
		var faixas := MundoGen.ruas(r)
		if faixas.is_empty():
			continue
		var fd: Dictionary = faixas[_rng.randi() % faixas.size()]
		var fr: Rect2 = fd["r"]
		var p := Vector2(_rng.randf_range(fr.position.x, fr.end.x), _rng.randf_range(fr.position.y, fr.end.y))
		if Comunidades.perto(p, 80.0 * IsoMath.METRO) == "":
			return p
	return MundoGen.area_rect(0).get_center()


static func _ponto_estrada() -> Vector2:
	var est := MundoGen.estradas()
	for tent in 20:
		var e: Dictionary = est[_rng.randi() % est.size()]
		var pts: PackedVector2Array = e["pts"]
		var p := pts[_rng.randi() % pts.size()]
		if Comunidades.perto(p, 80.0 * IsoMath.METRO) == "" and MapaMundi.sd(p.x, p.y) < -0.5:
			return p
	return _ponto_urbano()


static func vivos() -> Array:
	return agentes.values().filter(func(a): return bool(a["vivo"]))


static func nome_com_artigo(a: Dictionary) -> String:
	return str(a["nome"])


# ───────────────────────────── relógio ─────────────────────────────

## Chamado pelo GerenteErrantes: roda as horas que passaram (inclusive o sono), no máximo 24 por vez.
static func passo() -> void:
	iniciar()
	var h := Reputacao.agora_h()
	var horas := 0
	while h - _ultimo_h >= 1.0 and horas < 24:
		_ultimo_h += 1.0
		horas += 1
		_hora()


static func _hora() -> void:
	var lista := vivos()
	for a in lista:
		if not bool(a["vivo"]):
			continue
		_necessidades(a)
		if not bool(a["vivo"]) or bool(a["real"]):
			continue                                # o nó real cuida de andar e lutar
		_objetivo(a)
		if not bool(a.get("perto", false)):
			_andar(a)                               # perto do jogador quem anda é o GerenteErrantes, segundo a segundo
		_encontro_monstro(a)
	_encontros_entre(lista)
	_chegadas()
	if vivos().size() < POP_MIN and _rng.randf() < 0.15:
		novo(["andarilho", "catador", "cacador"][_rng.randi() % 3], _ponto_estrada(), _sortear_indole())


# ───────────────────────────── vida de cada um ─────────────────────────────

static func _necessidades(a: Dictionary) -> void:
	a["fome"] = maxf(0.0, float(a["fome"]) - 2.2)
	a["sede"] = maxf(0.0, float(a["sede"]) - 3.5)
	var z := MundoGen.zona(a["p"])
	if z != "urbano" and float(a["sede"]) < 60.0 and _rng.randf() < 0.45:
		a["sede"] = 100.0                         # achou rio, poça ou cacimba
	elif z == "urbano" and float(a["sede"]) < 55.0 and _rng.randf() < 0.25:
		a["sede"] = minf(100.0, float(a["sede"]) + 50.0)   # poça na rua, caixa d'água, garrafa achada
	if z == "urbano" and str(a["objetivo"]) in ["vasculhar", "emboscar", "seguir"] and _rng.randf() < 0.22:
		_achar(a)                                  # na cidade, sempre se acha alguma coisa pelo caminho
	if str(a["objetivo"]) == "cacar" and z != "urbano" and _rng.randf() < 0.25:
		a["fome"] = minf(100.0, float(a["fome"]) + 45.0)
	if float(a["fome"]) < 40.0 and int((a["itens"] as Dictionary).get("comida", 0)) > 0:
		a["itens"]["comida"] = int(a["itens"]["comida"]) - 1
		a["fome"] = minf(100.0, float(a["fome"]) + 35.0)
	if float(a["sede"]) < 40.0 and int((a["itens"] as Dictionary).get("agua_limpa", 0)) > 0:
		a["itens"]["agua_limpa"] = int(a["itens"]["agua_limpa"]) - 1
		a["sede"] = minf(100.0, float(a["sede"]) + 50.0)
	if float(a["fome"]) <= 0.0 or float(a["sede"]) <= 0.0:
		a["vida"] = float(a["vida"]) - 3.0
	elif float(a["vida"]) < 100.0:
		a["vida"] = minf(100.0, float(a["vida"]) + (1.0 if bool(a["ferido"]) else 3.0))
	if float(a["vida"]) >= 70.0:
		a["ferido"] = false
	# a índole muda com a vida: a fome empurra para o saque, a fartura acalma
	if float(a["fome"]) < 10.0 and _rng.randf() < 0.05:
		a["indole"] = {"pacifico": "desconfiado", "desconfiado": "oportunista", "oportunista": "hostil"}.get(a["indole"], a["indole"])
	if float(a["vida"]) <= 0.0:
		var o := _o(a)
		morrer(a, ("mort%s de fome e sede" % o) if float(a["fome"]) <= 0.0 or float(a["sede"]) <= 0.0 else ("mort%s pelos ferimentos" % o))


## Escolhe o que fazer quando chegou ao destino (ou não tem objetivo).
static func _objetivo(a: Dictionary) -> void:
	var p: Vector2 = a["p"]
	if str(a["objetivo"]) != "" and p.distance_to(a["destino"]) > 30.0 * IsoMath.METRO:
		return
	if str(a["papel"]) == "expedicao":
		_objetivo_expedicao(a)
		return
	if str(a["grupo"]) != "" and not _lider(a):
		var l := _lider_de(a)
		if not l.is_empty():
			a["objetivo"] = "seguir"
			a["destino"] = (l["destino"] as Vector2) + _desvio(5.0)
			return
	if str(a["papel"]) == "saqueador":
		var toca: Vector2 = (grupos.get(a["grupo"], {}) as Dictionary).get("toca", p)
		if float(a["fome"]) < 50.0 or float(a["sede"]) < 50.0:
			a["objetivo"] = "vasculhar"              # bando com fome sai para saquear
			a["destino"] = toca + _desvio(300.0)
		elif _rng.randf() < 0.5:
			a["objetivo"] = "emboscar"
			a["destino"] = toca + _desvio(120.0)
		else:
			a["objetivo"] = "vasculhar"
			a["destino"] = _ponto_urbano() if _rng.randf() < 0.3 else toca + _desvio(60.0)
		return
	if bool(a["ferido"]) and float(a["vida"]) < 50.0:
		var com := _comunidade_mais_perto(p)
		if com != "" and str(a["indole"]) != "hostil":
			a["objetivo"] = "abrigo"
			a["destino"] = Comunidades.geo(com)["centro"]
			return
	if float(a["sede"]) < 35.0:
		a["objetivo"] = "agua"
		a["destino"] = p + _desvio(400.0) if MundoGen.zona(p) == "urbano" else p
	elif float(a["fome"]) < 45.0:
		if str(a["papel"]) == "cacador" or _rng.randf() < 0.3:
			a["objetivo"] = "cacar"
			a["destino"] = _ponto_estrada()
		else:
			a["objetivo"] = "vasculhar"                # com fome, a cidade mais perto
			a["destino"] = p + _desvio(150.0) if MundoGen.zona(p) == "urbano" else _cidade_mais_perto(p)
	elif str(a["papel"]) == "andarilho" and _rng.randf() < 0.4:
		var com2 := _comunidade_mais_perto(p)
		a["objetivo"] = "trocar"
		a["destino"] = Comunidades.geo(com2)["centro"] if com2 != "" else _ponto_urbano()
	else:
		a["objetivo"] = "vasculhar" if _rng.randf() < 0.6 else "vagar"
		a["destino"] = _ponto_urbano() if a["objetivo"] == "vasculhar" else p + _desvio(600.0)


static func _lider(a: Dictionary) -> bool:
	var g: Dictionary = grupos.get(a["grupo"], {})
	var m: Array = g.get("membros", [])
	for id in m:
		if agentes.has(id) and bool(agentes[id]["vivo"]):
			return id == a["id"]
	return true


static func _lider_de(a: Dictionary) -> Dictionary:
	for id in (grupos.get(a["grupo"], {}) as Dictionary).get("membros", []):
		if agentes.has(id) and bool(agentes[id]["vivo"]):
			return agentes[id]
	return {}


static func _andar(a: Dictionary) -> void:
	var p: Vector2 = a["p"]
	var dest: Vector2 = a["destino"]
	var v := dest - p
	if v.length() < 1.0:
		if str(a["objetivo"]) == "vasculhar" and _rng.randf() < 0.35:
			_achar(a)
		return
	var passo := VEL_H * (0.6 if bool(a["ferido"]) else 1.0)
	a["p"] = dest if v.length() <= passo else p + v.normalized() * passo


## Vasculhando a cidade: às vezes acha alguma coisa.
static func _achar(a: Dictionary) -> void:
	var it: Dictionary = a["itens"]
	var r := _rng.randf()
	var achou: String = "comida" if r < 0.5 else ("agua_limpa" if r < 0.62 else ("sucata" if r < 0.8 else ("bandagem" if r < 0.88 else ("municao" if r < 0.95 else "antibiotico"))))
	it[achou] = int(it.get(achou, 0)) + 1


## Encontro com monstros, sorteado pelo perigo da zona e pela noite.
static func _encontro_monstro(a: Dictionary) -> void:
	var p: Vector2 = a["p"]
	var z := MundoGen.zona(p)
	if Comunidades.perto(p, 20.0 * IsoMath.METRO) != "":
		return
	var noite := _noite()
	var chance: float = float(PERIGO_ZONA.get(z, 0.02)) * (1.8 if noite else 1.0)
	if _rng.randf() > chance:
		return
	var opcoes: Array = []
	for k in MONSTROS:
		if not bool(MONSTROS[k]["noite"]) or noite:
			opcoes.append(k)
	var m: String = opcoes[_rng.randi() % opcoes.size()]
	var qtd := _rng.randi_range(1, 3)
	lutar(a, m, qtd)


## Combate abstrato: força do grupo (vida, munição, índole) contra a dos monstros. Devolve "venceu", "ferido",
## "fugiu" ou "morreu".
static func lutar(a: Dictionary, monstro: String, qtd: int) -> String:
	var membros := _membros_juntos(a)
	var forca := 0.0
	for b in membros:
		forca += float(b["vida"]) / 100.0 * (1.4 if str(b["indole"]) == "hostil" else 1.0) + 0.3 * minf(3.0, float(b["municao"]))
	var contra := float(MONSTROS[monstro]["forca"]) * qtd
	var com := _comunidade_mais_perto(a["p"])
	var lugar := _lugar(a["p"])
	var por: String = MONSTROS[monstro]["por"]
	var o := _o(a)
	if _rng.randf() < forca / (forca + contra) + 0.15:
		for b in membros:
			if int(b["municao"]) > 0 and _rng.randf() < 0.5:
				b["municao"] = int(b["municao"]) - 1
		return "venceu"
	if _rng.randf() < 0.6:
		a["vida"] = float(a["vida"]) - _rng.randf_range(20.0, 40.0)
		a["ferido"] = true
		if float(a["vida"]) <= 0.0:
			morrer(a, "mort%s %s %s" % [o, por, lugar])
			return "morreu"
		Simulacao.registrar_noticia(com, "%s foi atacad%s %s %s e escapou ferid%s." % [a["nome"], o, por, lugar, o])
		return "ferido"
	if _rng.randf() < 0.7:
		a["vida"] = float(a["vida"]) - _rng.randf_range(10.0, 25.0)
		a["p"] = (a["p"] as Vector2) + _desvio(150.0)
		return "fugiu"
	morrer(a, "mort%s %s %s" % [o, por, lugar])
	return "morreu"


## "o"/"a" para o gênero do agente.
static func _o(a: Dictionary) -> String:
	return "a" if str(a["genero"]) == "f" else "o"


static func _membros_juntos(a: Dictionary) -> Array:
	var out: Array = [a]
	if str(a["grupo"]) == "":
		return out
	for id in (grupos.get(a["grupo"], {}) as Dictionary).get("membros", []):
		var b: Dictionary = agentes.get(id, {})
		if not b.is_empty() and b != a and bool(b["vivo"]) and (b["p"] as Vector2).distance_to(a["p"]) < 40.0 * IsoMath.METRO:
			out.append(b)
	return out


## Errantes que se cruzam: troca, ajuda, briga, emboscada, se juntar.
static func _encontros_entre(lista: Array) -> void:
	for i in lista.size():
		var a: Dictionary = lista[i]
		if not bool(a["vivo"]) or bool(a["real"]):
			continue
		for k in range(i + 1, lista.size()):
			var b: Dictionary = lista[k]
			if not bool(b["vivo"]) or bool(b["real"]) or (a["grupo"] != "" and a["grupo"] == b["grupo"]):
				continue
			if (a["p"] as Vector2).distance_to(b["p"]) > 60.0 * IsoMath.METRO or _rng.randf() > 0.35:
				continue
			_cruzar(a, b)


static func _cruzar(a: Dictionary, b: Dictionary) -> void:
	var lugar := _lugar(a["p"])
	var com := _comunidade_mais_perto(a["p"])
	var ha: bool = a["indole"] == "hostil" or (a["indole"] == "oportunista" and float(a["fome"]) < 25.0)
	var hb: bool = b["indole"] == "hostil" or (b["indole"] == "oportunista" and float(b["fome"]) < 25.0)
	if ha != hb:
		var agressor: Dictionary = a if ha else b
		var vitima: Dictionary = b if ha else a
		var it: Dictionary = vitima["itens"]
		if it.is_empty():
			return                                  # já não tem nada: o agressor deixa para lá
		for k in it.keys():
			agressor["itens"][k] = int((agressor["itens"] as Dictionary).get(k, 0)) + int(it[k])
		vitima["itens"] = {}
		if _rng.randf() < 0.25:
			morrer(vitima, "mort%s numa emboscada %s" % [_o(vitima), lugar])
		else:
			vitima["vida"] = float(vitima["vida"]) - 25.0
			vitima["ferido"] = true
			vitima["lembra"].append("assaltado")
			Simulacao.registrar_noticia(com, "%s foi assaltad%s %s; levaram tudo." % [vitima["nome"],
				"a" if vitima["genero"] == "f" else "o", lugar])
		return
	if ha and hb:
		return                                  # dois lobos se evitam
	# dois em paz: trocam comida por água, ou um ferido ganha ajuda; às vezes viram um grupo
	if bool(a["ferido"]) != bool(b["ferido"]) and _rng.randf() < 0.5:
		var f: Dictionary = a if bool(a["ferido"]) else b
		f["vida"] = minf(100.0, float(f["vida"]) + 20.0)
	if a["grupo"] == "" and b["grupo"] == "" and _rng.randf() < 0.2:
		var gid := "grupo_%d" % (_seq + 1000)
		grupos[gid] = {"membros": [a["id"], b["id"]], "faccao": "", "toca": Vector2.INF}
		a["grupo"] = gid
		b["grupo"] = gid


## Quem chegou a uma comunidade: pede abrigo (fica, se ela aceitar), troca ou vai embora.
static func _chegadas() -> void:
	for a in vivos():
		if bool(a["real"]) or str(a["papel"]) in ["saqueador", "expedicao"]:
			continue
		var com := Comunidades.perto(a["p"], 15.0 * IsoMath.METRO)
		if com == "":
			continue
		if str(a["objetivo"]) == "abrigo":
			var c := Simulacao.estado(com)
			var enviado: bool = str(a.get("enviado", "")) == com
			if not c.is_empty() and (float(c["comida"]) > 2.0 or enviado) and a["indole"] != "hostil":
				Simulacao.receber_sobrevivente(com, str(a["nome"]), a["genero"] == "f", enviado)
				if enviado:
					Reputacao.mudar(com, 4)        # chegou dizendo que foi você que mandou (Q45)
				a["vivo"] = false
				a["entrou"] = com
			else:
				a["objetivo"] = "vagar"
				a["destino"] = (a["p"] as Vector2) + _desvio(800.0)
				Simulacao.registrar_noticia(com, "%s pediu abrigo %s e não foi aceit%s." % [a["nome"], Comunidades.em_nome(com),
					"a" if a["genero"] == "f" else "o"])
		elif str(a["objetivo"]) == "trocar":
			a["objetivo"] = ""                  # trocou e segue viagem


static func morrer(a: Dictionary, como: String) -> void:
	if not bool(a["vivo"]):
		return
	a["vivo"] = false
	a["morte"] = como
	var quem := "um andarilho" if a["genero"] == "m" else "uma andarilha"
	if str(a["papel"]) == "saqueador":
		quem = "do bando de saqueadores"
	Simulacao.registrar_noticia(_comunidade_mais_perto(a["p"]), "%s, %s, foi %s." % [a["nome"], quem, como] \
		if str(a["papel"]) != "expedicao" else "%s não voltou da cidade: foi %s." % [a["nome"], como])
	if str(a["papel"]) == "expedicao" and str(a.get("npc", "")) != "":
		Reputacao.npc_morreu(str(a["com"]), str(a["npc"]))


# ───────────────────────────── expedições das comunidades ─────────────────────────────

## A comunidade 'com' manda uma expedição atrás de 'alvo' (remedio, comida, sucata). 'npc' = id do personagem
## com nome que vai ("" = um grupo de moradores). Devolve o id do agente.
static func expedicao(com: String, alvo: String, npc: String, nome: String, fem: bool) -> String:
	iniciar()
	var g := Comunidades.geo(com)
	var a := novo("expedicao", (g["centro"] as Vector2) if not g.is_empty() else _ponto_urbano(), "desconfiado")
	a["com"] = com
	a["npc"] = npc
	a["nome"] = nome
	a["genero"] = "f" if fem else "m"
	a["alvo"] = alvo
	a["itens"] = {}
	a["fome"] = 100.0
	a["sede"] = 100.0
	a["municao"] = 2
	a["objetivo"] = "ir"
	a["destino"] = _cidade_mais_perto(a["p"])
	a["saiu_h"] = Reputacao.agora_h()
	return a["id"]


static func _objetivo_expedicao(a: Dictionary) -> void:
	match str(a["objetivo"]):
		"ir":
			a["objetivo"] = "vasculhar"
			a["vasculhar_ate"] = Reputacao.agora_h() + 4.0
			a["destino"] = (a["p"] as Vector2) + _desvio(80.0)
		"vasculhar":
			if Reputacao.agora_h() < float(a.get("vasculhar_ate", 0.0)):
				a["destino"] = (a["p"] as Vector2) + _desvio(80.0)
				if _rng.randf() < 0.5:
					var alvo := str(a.get("alvo", "sucata"))
					var item: String = {"remedio": "antibiotico", "comida": "comida", "sucata": "sucata"}.get(alvo, "sucata")
					if _rng.randf() < 0.5:
						item = ["comida", "sucata", "bandagem", "municao"][_rng.randi() % 4]
					a["itens"][item] = int((a["itens"] as Dictionary).get(item, 0)) + 1
			else:
				a["objetivo"] = "voltar"
				a["destino"] = Comunidades.geo(str(a["com"]))["centro"]
		"voltar":
			a["vivo"] = false
			a["voltou"] = true                  # a Simulacao lê o que trouxe e encerra a ação


static func _cidade_mais_perto(p: Vector2) -> Vector2:
	var melhor := Vector2.INF
	for i in MundoGen.AREAS.size():
		if str(MundoGen.AREAS[i].get("cat", "")) == "especial":
			continue
		var c := MundoGen.area_rect(i).get_center()
		if melhor == Vector2.INF or c.distance_to(p) < melhor.distance_to(p):
			melhor = c
	return melhor + _desvio(60.0)


# ───────────────────────────── utilidades ─────────────────────────────

static func _noite() -> bool:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	return c != null and c.eh_noite()


static func _comunidade_mais_perto(p: Vector2) -> String:
	var melhor := ""
	var dist := INF
	for id in Comunidades.ids():
		var g := Comunidades.geo(str(id))
		if not g.is_empty() and (g["centro"] as Vector2).distance_to(p) < dist:
			dist = (g["centro"] as Vector2).distance_to(p)
			melhor = str(id)
	return melhor


## "perto de São Jorge" / "em Porto Atlântico" (para o diário).
static func _lugar(p: Vector2) -> String:
	return Respawn.nome_do_lugar(p)


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	var ag: Dictionary = {}
	for id in agentes:
		var a: Dictionary = (agentes[id] as Dictionary).duplicate(true)
		for k in ["p", "destino"]:
			a[k] = [(a[k] as Vector2).x, (a[k] as Vector2).y]
		a["real"] = false
		ag[id] = a
	var gr: Dictionary = {}
	for gid in grupos:
		var g: Dictionary = (grupos[gid] as Dictionary).duplicate(true)
		var t: Vector2 = g["toca"]
		g["toca"] = [] if t == Vector2.INF else [t.x, t.y]
		gr[gid] = g
	return {"agentes": ag, "grupos": gr, "ultimo_h": _ultimo_h, "seq": _seq}


static func restaurar(d: Dictionary) -> void:
	zerar()
	if d.is_empty():
		return
	for id in (d.get("agentes", {}) as Dictionary):
		var a: Dictionary = (d["agentes"][id] as Dictionary).duplicate(true)
		for k in ["p", "destino"]:
			var l: Array = a[k]
			a[k] = Vector2(float(l[0]), float(l[1]))
		for k in ["fome", "sede", "vida"]:
			a[k] = float(a[k])
		a["municao"] = int(a["municao"])
		a["opiniao"] = int(a.get("opiniao", 0))
		var it: Dictionary = {}
		for k in (a.get("itens", {}) as Dictionary):
			it[str(k)] = int(a["itens"][k])
		a["itens"] = it
		agentes[str(id)] = a
	for gid in (d.get("grupos", {}) as Dictionary):
		var g: Dictionary = (d["grupos"][gid] as Dictionary).duplicate(true)
		var t: Array = g.get("toca", [])
		g["toca"] = Vector2.INF if t.is_empty() else Vector2(float(t[0]), float(t[1]))
		grupos[str(gid)] = g
	_ultimo_h = float(d.get("ultimo_h", -1.0))
	_seq = int(d.get("seq", 0))
