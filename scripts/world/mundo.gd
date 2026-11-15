class_name Mundo
extends Node2D
## Mundo aberto contínuo: carrega e descarrega CHUNKS de 1024 × 1024 u em volta da câmera (a pé ou de carro),
## sem tela de carregamento. O conteúdo vem de MundoGen (determinístico), então um chunk descartado volta igual.
##
## Dois anéis, em chunks (distância de xadrez até o chunk do foco):
##   anel 3  → chão + colisão da água funda (barato, aparece antes de entrar na tela)
##   anel 2  → objetos: árvores, cercas, casas (Edificio), carros, inimigos...
##   anel 4+ → descarrega.
## A criação é fatiada: no máximo ORCAMENTO_US microssegundos por quadro, o chunk mais perto primeiro.
##
## Biomas: cinco Area2D em faixas (tropical | transição | semiárido | transição | deserto) detectam o
## jogador (também dentro do carro) e um Tween troca a tinta da luz ambiente do CanvasModulate (DiaNoite).

const CH := MundoGen.CH
const R_CHAO := 3
const R_OBJ := 2
const R_DESCARGA := 4
const ORCAMENTO_US := 5000
const PREFIXOS_SEM_FISICA := ["arvore", "palmeira", "mato", "capim", "arbusto", "entulho"]

## Tinta da luz ambiente por bioma (multiplica a cor do dia/noite).
const TINTAS: Array = [Color(0.93, 1.0, 0.94), Color(1.0, 0.90, 0.72), Color(1.0, 0.80, 0.58)]

@export var grama: Texture2D

var jogador: Node2D = null

class Chunk:
	var c := Vector2i.ZERO
	var chao: Node2D = null
	var corpo: StaticBody2D = null
	var nos: Array = []
	var tarefas: Array = []
	var inimigos: Array = []
	var obj_planejado := false

var _chunks: Dictionary = {}          ## Vector2i -> Chunk
var _estado: Dictionary = {}          ## Vector2i -> inimigos que restavam ao descarregar
var _coletados: Dictionary = {}       ## Vector2i (posição de mundo arredondada) -> galho/pedra já pego
var _portoes: Dictionary = {}         ## Vector2i (meio do vão) -> aberto, depois que o jogador mexeu
var _saqueados: Dictionary = {}       ## Vector2i -> recipiente fixo já vasculhado (ninhos de morcegos)
var _fila_chao: Array[Vector2i] = []
var _fila_obj: Array[Vector2i] = []
var _obra: Chunk = null
var _cc := Vector2i(-9999, -9999)
var _cenas: Dictionary = {}
var _ciclo: Node = null
var _tween: Tween = null
var _bioma_anunciado: int = -1          ## bioma (0 tropical, 1 semiárido, 2 deserto) já anunciado no HUD
var _t_retintar: float = 0.0
var _focando := true
## objetos (árvores, carros...) translúcidos porque estão na frente do jogador: nó -> true enquanto encobrem
var _desbotados: Dictionary = {}
var _t_transp := 0.0
const ALFA_PROP := 0.35


func _ready() -> void:
	add_to_group("mundo")
	y_sort_enabled = true
	if grama == null:
		grama = load("res://assets/sprites_hd_recortados/chao/grama.png")
	jogador = get_node_or_null("Player") as Node2D
	if jogador != null:
		jogador.position = IsoMath.mundo_para_tela(MundoGen.INICIO)
	SaveJogo.aplicar_mundo(self)                 # partida carregada: posição e memória do mundo antes da carga
	add_child(Atmosfera.new())                   # poeira e folhas caindo em volta da câmera
	TerrenoTexturas.preparar_todas()
	TexturasParede.atlas_relevo()                # gera o atlas (e o relevo dele) na carga, não no primeiro edifício
	# carga inicial síncrona (limitada): o jogador já nasce com chão e a vizinhança de volta
	var foco := _foco_mundo()
	_cc = Vector2i(floori(foco.x / CH), floori(foco.y / CH))
	_reagendar(foco)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and _passo():
		pass
	call_deferred("_tinta_inicial")


func _tinta_inicial() -> void:
	var ciclo := _achar_ciclo()
	var foco := _foco_mundo()
	if ciclo != null:
		ciclo.set("tinta_bioma", _tinta_para(MundoGen.bioma_valor(foco.x, foco.y)))


func _achar_ciclo() -> Node:
	if _ciclo == null or not is_instance_valid(_ciclo):
		_ciclo = get_tree().get_first_node_in_group("ciclo_dia_noite")
	return _ciclo


## Ponto do mundo (u) que a câmera está olhando.
func _foco_mundo() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return IsoMath.tela_para_mundo(cam.get_screen_center_position())
	if jogador != null:
		return IsoMath.tela_para_mundo(jogador.global_position)
	return MundoGen.INICIO


## Lentidão em água rasa etc., para o ponto de tela dado (usado pelo jogador).
func fator_terreno(p_tela: Vector2) -> float:
	return MundoGen.fator_terreno(IsoMath.tela_para_mundo(p_tela))


func _process(delta: float) -> void:
	var foco := _foco_mundo()
	var cc := Vector2i(floori(foco.x / CH), floori(foco.y / CH))
	if cc != _cc:
		_cc = cc
		_reagendar(foco)
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < ORCAMENTO_US:
		if not _passo():
			break
	_t_transp -= delta
	if _t_transp <= 0.0:
		_t_transp = 0.1
		_marcar_props_na_frente()
	_animar_props(delta)
	# tinta do bioma: a cada meio segundo a luz ambiente vai (Tween no CanvasModulate) para a cor do bioma sob a
	# câmera; a transição do mapa é contínua, então a cor também muda aos poucos
	_t_retintar -= delta
	if _t_retintar <= 0.0:
		_t_retintar = 0.5
		var v := MundoGen.bioma_valor(foco.x, foco.y)
		_tintar(_tinta_para(v), 1.6)
		var b := MundoGen.bioma_id(v)
		if b != _bioma_anunciado:
			if _bioma_anunciado >= 0 and jogador != null and jogador.has_method("aviso"):
				jogador.call("aviso", "Entrando: " + MundoGen.nome_bioma(b))
			_bioma_anunciado = b


# ───────────────────────────── objetos na frente do jogador ─────────────────────────────

## Árvores e outros objetos que encobrem a cabeça/tronco do jogador ficam translúcidos (só os dos chunks vizinhos).
func _marcar_props_na_frente() -> void:
	var novos: Dictionary = {}
	if jogador != null and not ("dirigindo" in jogador and jogador.dirigindo != null):
		var pj := jogador.global_position
		var corpo := Rect2(pj.x - 22.0, pj.y - 72.0, 44.0, 48.0)          # cabeça e tronco; pernas atrás de arbusto não contam
		var pm := IsoMath.tela_para_mundo(pj)
		var cj := Vector2i(floori(pm.x / CH), floori(pm.y / CH))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var ch: Chunk = _chunks.get(cj + Vector2i(dx, dy))
				if ch == null:
					continue
				for no in ch.nos:
					if not is_instance_valid(no) or not (no is IsoProp):
						continue
					var d: Vector2 = (no as Node2D).global_position - pj
					if absf(d.x) > 420.0 or d.y < 0.0 or d.y > 650.0:
						continue
					if (no as IsoProp).cobre(corpo, pj.y):
						novos[no] = true
	for no in _desbotados.keys():
		if not novos.has(no):
			_desbotados[no] = false                  # volta a ficar opaco (o _animar_props tira da lista)
	for no in novos:
		_desbotados[no] = true


func _animar_props(delta: float) -> void:
	if _desbotados.is_empty():
		return
	var k := minf(1.0, delta * 8.0)
	for no in _desbotados.keys():
		if not is_instance_valid(no):
			_desbotados.erase(no)
			continue
		var alvo := ALFA_PROP if _desbotados[no] else 1.0
		var n2 := no as Node2D
		var a := lerpf(n2.modulate.a, alvo, k)
		if absf(a - alvo) < 0.01:
			a = alvo
		n2.modulate.a = a
		if a == 1.0 and not _desbotados[no]:
			_desbotados.erase(no)


# ───────────────────────────── fila de chunks ─────────────────────────────

func _valido(k: Vector2i) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < MundoGen.NX and k.y < MundoGen.NY


func _reagendar(foco: Vector2) -> void:
	_fila_chao.clear()
	_fila_obj.clear()
	var cand: Array = []
	for dy in range(-R_CHAO, R_CHAO + 1):
		for dx in range(-R_CHAO, R_CHAO + 1):
			var k := _cc + Vector2i(dx, dy)
			if _valido(k):
				cand.append(k)
	cand.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _centro(a).distance_squared_to(foco) < _centro(b).distance_squared_to(foco))
	for kk in cand:
		var k2: Vector2i = kk
		var d: int = maxi(absi(k2.x - _cc.x), absi(k2.y - _cc.y))
		if not _chunks.has(k2):
			_fila_chao.append(k2)
		if d <= R_OBJ:
			var ch: Chunk = _chunks.get(k2)
			if ch == null or not ch.obj_planejado:
				_fila_obj.append(k2)
	for key in _chunks.keys():
		var kd: Vector2i = key
		if maxi(absi(kd.x - _cc.x), absi(kd.y - _cc.y)) > R_DESCARGA:
			_descarregar(kd)


func _centro(k: Vector2i) -> Vector2:
	return Vector2((k.x + 0.5) * CH, (k.y + 0.5) * CH)


## Um passo de trabalho; false = nada a fazer.
func _passo() -> bool:
	if _obra != null:
		if _obra.tarefas.is_empty():
			_obra = null
			return true
		var spec: Dictionary = _obra.tarefas.pop_front()
		_instanciar(_obra, spec)
		return true
	if not _fila_obj.is_empty():
		var k: Vector2i = _fila_obj[0]
		if not _chunks.has(k):
			_criar_chao(k)
			return true
		_fila_obj.pop_front()
		var ch: Chunk = _chunks[k]
		if not ch.obj_planejado:
			ch.obj_planejado = true
			var specs := MundoGen.planejar(k, int(_estado.get(k, -1)))
			specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["k"] == "edificio") < int(b["k"] == "edificio"))
			ch.tarefas = specs
			_obra = ch
		return true
	if not _fila_chao.is_empty():
		var k2: Vector2i = _fila_chao.pop_front()
		if not _chunks.has(k2):
			_criar_chao(k2)
		return true
	return false


func _criar_chao(k: Vector2i) -> void:
	var ch := Chunk.new()
	ch.c = k
	var cg := ChaoChunk.new()
	cg.c = k
	cg.grama = grama
	add_child(cg)
	ch.chao = cg
	ch.corpo = _corpo_agua(k)
	_chunks[k] = ch


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


## Colisão da água funda do chunk (o raso, as pontes e os vaus ficam livres): polígonos do marching squares.
func _corpo_agua(k: Vector2i) -> StaticBody2D:
	var r := Rect2(k.x * CH, k.y * CH, CH, CH)
	var maior := -99.0
	for j in 5:
		for i in 5:
			maior = maxf(maior, MapaMundi.sd(r.position.x + i * 256.0, r.position.y + j * 256.0))
	if maior < MapaMundi.FUNDO - 1.5:
		return null
	var corpo: StaticBody2D = null
	for poli in MapaMundi.poligonos(r, MapaMundi.FUNDO, 64.0):
		var qp: PackedVector2Array = poli
		if qp.size() < 3 or _area(qp) < 300.0:
			continue
		if corpo == null:
			corpo = StaticBody2D.new()
			corpo.name = "AguaFunda"
			corpo.position = IsoMath.mundo_para_tela(r.position)     # polígonos locais: precisão longe da origem
			add_child(corpo)
		var tela := PackedVector2Array()
		for p in qp:
			tela.append(IsoMath.mundo_para_tela(p - r.position))
		var cp := CollisionPolygon2D.new()
		cp.polygon = tela
		corpo.add_child(cp)
	return corpo


func _descarregar(k: Vector2i) -> void:
	var ch: Chunk = _chunks.get(k)
	if ch == null:
		return
	if ch == _obra:
		_obra = null
	if ch.obj_planejado and ch.tarefas.is_empty():
		var vivos := 0
		for i in ch.inimigos:
			if is_instance_valid(i) and not (i as Inimigo).morto:
				vivos += 1
		_estado[k] = vivos
	var casas: Array = []
	for no in ch.nos:
		if is_instance_valid(no) and no is Edificio:
			casas.append(no)
	if not casas.is_empty():                    # moradores nascem fora do edifício: saem junto
		for i in get_tree().get_nodes_in_group("inimigo"):
			if is_instance_valid((i as Inimigo).casa) and (i as Inimigo).casa in casas:
				i.queue_free()
	for no in ch.nos:
		if not is_instance_valid(no):
			continue
		if no is Veiculo:                       # carro dirigido ou levado para outro lugar fica onde está
			var v := no as Veiculo
			var origem: Vector2 = v.get_meta("origem", v.position)
			if v.motorista != null or v.position.distance_to(origem) > 30.0:
				continue
		no.queue_free()
	if ch.chao != null:
		ch.chao.queue_free()
	if ch.corpo != null:
		ch.corpo.queue_free()
	_chunks.erase(k)


## Galho/pedra pego: não volta quando o chunk for gerado de novo.
func marcar_coletado(p_mundo: Vector2) -> void:
	_coletados[Vector2i(p_mundo)] = true


## Recipiente fixo vasculhado (Lootavel.chave): não enche de novo ao recarregar o chunk.
func lembrar_saque(chave: Vector2i) -> void:
	_saqueados[chave] = true


## Portão aberto/fechado pelo jogador: o estado sobrevive ao descarregar o chunk.
func lembrar_portao(meio_mundo: Vector2, aberto: bool) -> void:
	_portoes[Vector2i(meio_mundo)] = aberto


func chunks_carregados() -> int:
	return _chunks.size()


# ───────────────────────────── instanciar objetos ─────────────────────────────

func _cena(caminho: String) -> PackedScene:
	if not _cenas.has(caminho):
		_cenas[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cenas[caminho] as PackedScene


func _instanciar(ch: Chunk, spec: Dictionary) -> void:
	var tipo: String = spec["k"]
	var no: Node2D = null
	match tipo:
		"prop":
			no = _prop(spec)
		"carro":
			var cena := _cena("res://scenes/world/veiculos/%s.tscn" % spec["n"])
			if cena != null:
				var v := cena.instantiate() as Veiculo
				v.proa = spec["proa"]
				v.queimado = spec.get("queimado", false)
				v.position = IsoMath.mundo_para_tela(spec["p"])
				v.set_meta("origem", v.position)
				add_child(v)
				no = v
		"edificio":
			var e := Edificio.new()
			e.largura_tiles = spec["w"]
			e.altura_tiles = spec["h"]
			e.frente = spec["f"]
			e.semente = spec["sem"]
			e.moradores = spec["mor"]
			if spec.has("o"):
				e.configurar(spec["o"])          # prédio: uso, andares, cobertura, placa...
			e.position = IsoMath.mundo_para_tela(spec["p"])
			add_child(e)
			no = e
		"cerca":
			var f := CercaNo.new()
			f.a = spec["a"]
			f.b = spec["b"]
			f.estilo = spec["e"]
			add_child(f)
			no = f
		"cacto":
			var c := Cacto.new()
			c.variante = spec["v"]
			c.position = IsoMath.mundo_para_tela(spec["p"])
			add_child(c)
			no = c
		"tenda":
			var t := Tenda.new()
			t.cor = spec["cor"]
			t.position = IsoMath.mundo_para_tela(spec["p"])
			add_child(t)
			no = t
		"fogueira":
			var fo := Fogueira.new()
			fo.position = IsoMath.mundo_para_tela(spec["p"])
			add_child(fo)
			no = fo
		"ninho":
			var ni := NinhoMorcegos.new()
			var p_ni: Vector2 = spec["p"]
			ni.semente = p_ni.x * 0.001 + p_ni.y * 0.0007
			ni.position = IsoMath.mundo_para_tela(p_ni)
			var lt := Lootavel.new()
			lt.name = "Loot"
			lt.tipo = "ninho"
			lt.alcance_m = 2.6
			lt.chave = Vector2i(p_ni)
			lt.usado = _saqueados.has(lt.chave)
			lt.position = IsoMath.mundo_para_tela(Vector2(0.0, NinhoMorcegos.RAIO * 0.75))
			ni.add_child(lt)
			add_child(ni)
			no = ni
		"plantacao":
			var pl := Plantacao.new()
			pl.r = spec["r"]
			pl.seco = spec["seco"]
			pl.semente = int(pl.r.position.x * 7.0 + pl.r.position.y * 13.0)
			add_child(pl)
			no = pl
		"cachoeira":
			var ca := Cachoeira.new()
			ca.position = IsoMath.mundo_para_tela(spec["p"])
			add_child(ca)
			no = ca
		"urbano":
			var ou := ObjetoUrbano.new()
			ou.tipo = spec["t"]
			ou.fp = spec["r"]
			ou.h = spec["h"]
			ou.solido = spec.get("s", true)
			ou.extra = spec.get("x", {})
			add_child(ou)
			var loot_u: String = spec.get("loot", "")
			if loot_u != "":                       # bueiro: acesso ao esgoto vasculhável
				var lu := Lootavel.new()
				lu.name = "Loot"
				lu.tipo = loot_u
				lu.position = IsoMath.mundo_para_tela(ou.fp.get_center()) - ou.position
				ou.add_child(lu)
			no = ou
		"portao":
			var pt := PortaoNo.new()
			pt.a = spec["a"]
			pt.b = spec["b"]
			pt.estilo = spec["e"]
			pt.aberto = _portoes.get(Vector2i((pt.a + pt.b) * 0.5), spec["aberto"])
			add_child(pt)
			no = pt
		"coleta":
			if not _coletados.has(Vector2i(spec["p"])):
				var cs := ColetaSolta.new()
				cs.tipo = spec["t"]
				cs.variante = spec["v"]
				cs.origem = spec["p"]
				cs.position = IsoMath.mundo_para_tela(spec["p"])
				add_child(cs)
				no = cs
		"inimigo":
			var cena_i := _cena("res://scenes/enemies/inimigo.tscn")
			if cena_i != null:
				var ini := cena_i.instantiate() as Inimigo
				ini.raca = spec["raca"]
				ini.dorme = randf() < 0.7
				ini.position = IsoMath.mundo_para_tela(spec["p"])
				add_child(ini)
				ch.inimigos.append(ini)
				no = ini
	if no != null:
		ch.nos.append(no)


func _prop(spec: Dictionary) -> Node2D:
	var nome: String = spec["n"]
	var cena := _cena("res://scenes/world/props_hd/%s.tscn" % nome)
	if cena == null:
		return null
	var no := cena.instantiate() as Node2D
	no.position = IsoMath.mundo_para_tela(spec["p"])
	add_child(no)
	Vento.aplicar(no, nome)                      # árvores, arbustos e mato balançam
	var col: String = spec.get("col", "")
	if col != "":
		var co := Coletavel.new()
		co.name = "Colher"
		co.tipo = col
		no.add_child(co)
	var loot: String = spec.get("loot", "")
	if loot != "":
		var l := Lootavel.new()
		l.name = "Loot"
		l.tipo = loot
		l.position = Vector2(0, -8)
		no.add_child(l)
	for pre in PREFIXOS_SEM_FISICA:
		if nome.begins_with(pre):
			no.set_physics_process(false)         # vegetação e entulho não precisam checar a lanterna
			break
	return no


# ───────────────────────────── biomas ─────────────────────────────

func _tinta_para(v: float) -> Color:
	if v <= 1.0:
		return (TINTAS[0] as Color).lerp(TINTAS[1], clampf(v, 0.0, 1.0))
	return (TINTAS[1] as Color).lerp(TINTAS[2], clampf(v - 1.0, 0.0, 1.0))


func _tintar(alvo: Color, dur: float) -> void:
	var ciclo := _achar_ciclo()
	if ciclo == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(ciclo, "tinta_bioma", alvo, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ───────────────────────────── save ─────────────────────────────

static func _lista_v(d: Dictionary) -> Array:
	var out: Array = []
	for k in d:
		var v: Vector2i = k
		out.append([v.x, v.y])
	return out


## O que o mundo lembra, para o SaveJogo. Os chunks carregados entram com os inimigos vivos agora.
func dados_para_salvar() -> Dictionary:
	var estado := _estado.duplicate()
	for k in _chunks:
		var ch: Chunk = _chunks[k]
		if ch.obj_planejado and ch.tarefas.is_empty():
			var vivos := 0
			for i in ch.inimigos:
				if is_instance_valid(i) and not (i as Inimigo).morto:
					vivos += 1
			estado[k] = vivos
	var est: Array = []
	for k in estado:
		var kv: Vector2i = k
		est.append([kv.x, kv.y, int(estado[k])])
	var port: Array = []
	for k in _portoes:
		var kp: Vector2i = k
		port.append([kp.x, kp.y, bool(_portoes[k])])
	return {"coletados": _lista_v(_coletados), "saqueados": _lista_v(_saqueados), "portoes": port, "estado": est}


func restaurar(d: Dictionary) -> void:
	for p in d.get("coletados", []):
		_coletados[Vector2i(int(p[0]), int(p[1]))] = true
	for p in d.get("saqueados", []):
		_saqueados[Vector2i(int(p[0]), int(p[1]))] = true
	for p in d.get("portoes", []):
		_portoes[Vector2i(int(p[0]), int(p[1]))] = bool(p[2])
	for p in d.get("estado", []):
		_estado[Vector2i(int(p[0]), int(p[1]))] = int(p[2])
