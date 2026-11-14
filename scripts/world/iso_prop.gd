@tool
class_name IsoProp
extends StaticBody2D
## Objeto de cenário isométrico com profundidade pela BASE INTEIRA.
##
## A base é o paralelogramo que o objeto ocupa no chão, definido por 3 pontos da
## imagem (em px): canto esquerdo, pivô (vértice de baixo) e canto direito.
## A origem do nó fica no pivô.
##
## O Y-Sort da Godot ordena cada nó por um único ponto, o que erra em objetos
## compridos (carros, Kombi, muros). Aqui o sprite é dividido em fatias verticais
## e cada fatia é ordenada pela altura da borda da frente da base naquela coluna.
## Assim o personagem fica na frente ou atrás de acordo com a base inteira.

@export var textura: Texture2D:
	set(v):
		textura = v
		_agendar()
@export var escala: float = 1.0:
	set(v):
		escala = v
		_agendar()
@export_group("Base (px da imagem)")
@export var base_esq := Vector2.ZERO:
	set(v):
		base_esq = v
		_agendar()
@export var pivo := Vector2.ZERO:
	set(v):
		pivo = v
		_agendar()
@export var base_dir := Vector2.ZERO:
	set(v):
		base_dir = v
		_agendar()
@export_group("Profundidade")
## Largura de cada fatia, em px de tela. Menor = mais preciso, mais nós.
@export_range(4.0, 64.0, 1.0) var largura_fatia: float = 12.0:
	set(v):
		largura_fatia = v
		_agendar()
## Folga lateral (px de tela) para o corpo do personagem não ser cortado pela fatia vizinha.
@export var folga: float = 10.0:
	set(v):
		folga = v
		_agendar()

@export_group("Luz da lanterna")
## Objeto largo só recebe a luz quando a lanterna está do lado da frente da base
## (as faces que a câmera vê). Árvores e postes ignoram isto.
@export var luz_por_lado: bool = true
## Não recebe a luz quando há uma parede ou outro objeto entre a lanterna e ele.
@export var luz_checar_obstaculos: bool = true

## Camada de luz dos objetos em pé (o chão usa a camada 1, com sombras).
const MASCARA_LUZ_OBJETOS := 2
const ALCANCE_LUZ := 520.0            ## px de tela; além disso não vale a pena checar

var _fatias: Array[Sprite2D] = []
var _largo: bool = false
var _iluminado: bool = true
var _espera_luz: float = 0.0


func _ready() -> void:
	_espera_luz = randf() * 0.12
	_montar()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_espera_luz -= delta
	if _espera_luz > 0.0:
		return
	_espera_luz = 0.12
	var iluminado := _recebe_luz()
	if iluminado != _iluminado:
		_iluminado = iluminado
		for f in _fatias:
			if is_instance_valid(f):
				f.light_mask = MASCARA_LUZ_OBJETOS if _iluminado else 0


## Decide se a lanterna do jogador alcança as faces visíveis deste objeto.
func _recebe_luz() -> bool:
	var jogador := get_tree().get_first_node_in_group("jogador") as Node2D
	if jogador == null:
		return true
	var p := to_local(jogador.global_position)
	if p.length() > ALCANCE_LUZ:
		return true
	if luz_por_lado and _largo and p.y < frente_em(p.x) - 2.0:
		return false					   # lanterna atrás do objeto: a face visível fica no escuro
	if luz_checar_obstaculos:
		var centro := to_global((canto_esq() + canto_dir()) * 0.5)
		var consulta := PhysicsRayQueryParameters2D.create(jogador.global_position, centro, 1, [get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(consulta).is_empty():
			return false				   # tem parede ou outro objeto no caminho
	return true


func _agendar() -> void:
	if is_node_ready():
		_montar()


## Cantos da base em relação ao pivô, em px de tela.
func canto_esq() -> Vector2:
	return (base_esq - pivo) * escala


func canto_dir() -> Vector2:
	return (base_dir - pivo) * escala


## Altura (y de tela, relativo ao pivô) da borda da frente da base na coluna x.
func frente_em(x: float) -> float:
	var e := canto_esq()
	var d := canto_dir()
	if x <= 0.0:
		if e.x >= -0.01:
			return 0.0
		return e.y * clampf(x / e.x, 0.0, 1.0)
	if d.x <= 0.01:
		return 0.0
	return d.y * clampf(x / d.x, 0.0, 1.0)


func _montar() -> void:
	for f in _fatias:
		if is_instance_valid(f):
			f.queue_free()
	_fatias.clear()
	y_sort_enabled = true
	_atualizar_colisao()
	if textura == null or escala <= 0.0:
		return
	var tam := textura.get_size()
	var x_esq := clampf(base_esq.x, 0.0, tam.x)
	var x_dir := clampf(base_dir.x, x_esq, tam.x)
	var largura_base := (x_dir - x_esq) * escala
	_largo = largura_base >= largura_fatia * 2.5
	if not _largo:
		# base pequena (árvore, poste): um sprite só, ordenado pelo centro da base
		_criar_fatia(0.0, tam.x, ((canto_esq() + canto_dir()) * 0.5).y, tam.y)
		return
	var cortes: Array[float] = [0.0]
	var n := int(ceil(largura_base / largura_fatia))
	for i in range(n + 1):
		var c := roundf(lerpf(x_esq, x_dir, float(i) / float(n)))
		if c > cortes[-1]:
			cortes.append(c)
	if tam.x > cortes[-1]:
		cortes.append(tam.x)
	for i in range(cortes.size() - 1):
		var xa := (cortes[i] - pivo.x) * escala
		var xb := (cortes[i + 1] - pivo.x) * escala
		var y := minf(frente_em(xa - folga), frente_em(xb + folga))
		_criar_fatia(cortes[i], cortes[i + 1], y, tam.y)


func _criar_fatia(c0: float, c1: float, y_ordem: float, altura: float) -> void:
	var s := Sprite2D.new()
	s.texture = textura
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(c0, 0.0, c1 - c0, altura)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.light_mask = MASCARA_LUZ_OBJETOS if _iluminado else 0
	s.scale = Vector2(escala, escala)
	# a posição da fatia é o ponto de ordenação; o offset devolve a arte ao lugar
	s.position = Vector2((c0 - pivo.x) * escala, y_ordem)
	s.offset = Vector2(0.0, -pivo.y - y_ordem / escala)
	add_child(s, false, Node.INTERNAL_MODE_BACK)
	_fatias.append(s)


func _atualizar_colisao() -> void:
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null:
		return
	var poligono := forma.shape as ConvexPolygonShape2D
	if poligono == null:
		return
	var e := canto_esq()
	var d := canto_dir()
	var pontos := PackedVector2Array([Vector2.ZERO, e, e + d, d])
	if poligono.points != pontos:
		poligono.points = pontos
