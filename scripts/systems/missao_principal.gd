class_name MissaoPrincipal
extends RefCounted
## Missão principal do ato 1 (marco 3, etapa 3.7; docs/DECISOES_DESIGN.md, "O começo" e "Ato 1").
## É do mundo (do grupo, regra do co-op): o passo vale para todos e vai no save do mundo.
## 3.7a: o começo — todos acordam na enfermaria da Vila dos Pescadores (a casa do Dr. Heitor), resgatados pelo Toné.

const COM := "vila_dos_pescadores"
const MEDICO := "medico"
const PRIMEIRA_FALA := "O que aconteceu? Onde estou?"

static var passo := 0                       ## 0 = ainda não acordou (os passos entram na 3.7b)


static func zerar() -> void:
	passo = 0


## Índice da casa do médico na geometria da Vila (a enfermaria).
static func _casa_medico() -> int:
	for n in Comunidades.dados(COM).get("npcs", []):
		var nd: Dictionary = n
		if str(nd.get("id", "")) == MEDICO:
			return int(nd.get("casa", 0))
	return 0


## Ponto (mundo) na rua, em frente à enfermaria; INF se a Vila não existe.
static func ponto_enfermaria() -> Vector2:
	var g := Comunidades.geo(COM)
	if g.is_empty() or (g["casas"] as Array).is_empty():
		return Vector2.INF
	var casas: Array = g["casas"]
	return casas[_casa_medico() % casas.size()]


## Leva o jogador à porta da enfermaria, revela a Vila no mapa e, quando a casa terminar de ser construída,
## põe ele ao lado da cama (Edificio constrói fatiado; o prédio só fica 'pronto' depois de alguns quadros).
static func levar_a_enfermaria(j: Node) -> void:
	var p := ponto_enfermaria()
	if p == Vector2.INF:
		return
	var g := Comunidades.geo(COM)
	var area: Rect2 = g["area"]
	Descobertas.revelar_retangulo(area.grow(20.0 * IsoMath.METRO))
	var mundo := j.get_tree().get_first_node_in_group("mundo")
	if mundo != null and mundo.has_method("teleportar"):
		mundo.teleportar(p)
	_ir_para_a_cama(j)


static func _ir_para_a_cama(j: Node) -> void:
	var g := Comunidades.geo(COM)
	var lotes: Array = g.get("lotes", [])
	if lotes.is_empty():
		return
	var lote: Vector2 = lotes[_casa_medico() % lotes.size()]
	var arvore := j.get_tree()
	for k in 120:                                       # até ~60 s reais (a cutscene pausa a construção)
		var cama := _cama_da_casa(arvore, lote)
		if cama != Vector2.INF:
			if is_instance_valid(j):
				j.global_position = IsoMath.mundo_para_tela(cama)
			return
		await arvore.create_timer(0.5, true).timeout
		if not is_instance_valid(j):
			return


## Ponto (mundo) ao lado da cama do prédio do lote, ou INF se a casa ainda não está pronta.
static func _cama_da_casa(arvore: SceneTree, lote: Vector2) -> Vector2:
	for e in arvore.get_nodes_in_group("edificio"):
		var ed := e as Edificio
		if ed == null or not ed.pronto:
			continue
		var origem := IsoMath.tela_para_mundo(ed.global_position)
		if origem.distance_to(lote) > 3.0 * IsoMath.METRO:
			continue
		var camas: Array = ed.moveis.filter(func(m): return m.tipo == "cama")
		if camas.is_empty():
			return origem
		var m: Dictionary = camas[0]
		return origem + Vector2(m.x1 + 18.0, (m.y0 + m.y1) / 2.0)   # em pé, ao lado da cama
	return Vector2.INF


## Fim da cutscene: o personagem abre os olhos na enfermaria.
static func acordar(j: Node) -> void:
	if passo < 1:
		passo = 1
	j.aviso(PRIMEIRA_FALA)


static func dados_para_salvar() -> Dictionary:
	return {"passo": passo}


static func restaurar(d: Dictionary) -> void:
	passo = int(d.get("passo", 0))
