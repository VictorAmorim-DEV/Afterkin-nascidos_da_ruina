extends Node2D
## Construção modular com visibilidade por cômodo (estilo Project Zomboid).
##
## A cena é montada por tools/gerar_construcao.py a partir do kit de peças: cada
## parede, piso, telhado, porta e janela é um nó próprio. Este script só decide,
## a cada instante, quais cômodos estão REVELADOS e aplica isso às peças:
##
##   - Telhado<Cômodo> some quando algum cômodo da lista "some_para" dele é revelado
##   - cada parede abaixa quando algum cômodo da lista "baixa_para" dela é revelado
##   - Escuro<Cômodo> cobre o cômodo que ficou sem telhado mas ainda não foi revelado
##
## Um cômodo é revelado quando o jogador está DENTRO dele (Area<Cômodo>), ou quando
## uma porta/janela dele está aberta e o jogador está junto dela — ou do outro lado
## dela, no cômodo vizinho. Saindo da casa e se afastando, nada mais está revelado:
## telhados e paredes altas voltam sozinhos.

@export var comodos: PackedStringArray = []
@export var duracao_transicao: float = 0.3
## Distância (px) até uma porta/janela aberta para ela revelar o cômodo pelo lado de fora.
@export var raio_espiar: float = 46.0

var _dentro: Dictionary = {}          ## cômodo -> nº de corpos do jogador dentro
var _revelado: Dictionary = {}        ## cômodo -> bool (estado aplicado)
var _aberturas: Array[Abertura] = []
var _paredes: Array[ParedeModular] = []
var _transicoes: Dictionary = {}      ## nó -> Tween
var _espera: float = 0.0


func _ready() -> void:
	for c in comodos:
		_dentro[c] = 0
		_revelado[c] = false
		var area := get_node_or_null("Area" + c.capitalize()) as Area2D
		if area != null:
			area.body_entered.connect(_corpo_entrou.bind(c))
			area.body_exited.connect(_corpo_saiu.bind(c))
	for no in find_children("*", "Node2D", true, false):
		if no is Abertura:
			_aberturas.append(no)
			no.mudou.connect(_atualizar)
		elif no is ParedeModular:
			_paredes.append(no)
	_atualizar(true)


func _physics_process(delta: float) -> void:
	_espera -= delta
	if _espera <= 0.0:
		_espera = 0.1                 # o jogador se aproximando/afastando de uma abertura
		_atualizar()


func jogador_dentro() -> bool:
	for c in comodos:
		if _dentro.get(c, 0) > 0:
			return true
	return false


func revelado(comodo: String) -> bool:
	return _revelado.get(comodo, false)


func _corpo_entrou(corpo: Node2D, comodo: String) -> void:
	if corpo.is_in_group("jogador"):
		_dentro[comodo] = _dentro.get(comodo, 0) + 1
		_atualizar()


func _corpo_saiu(corpo: Node2D, comodo: String) -> void:
	if corpo.is_in_group("jogador"):
		_dentro[comodo] = maxi(0, _dentro.get(comodo, 0) - 1)
		_atualizar()


func _calcular() -> Dictionary:
	var novo: Dictionary = {}
	for c in comodos:
		novo[c] = _dentro.get(c, 0) > 0
	for ab in _aberturas:
		if not ab.aberta:
			continue
		var ve := ab.perto(raio_espiar)           # espiando de fora, junto da abertura
		for c in ab.comodos:
			if _dentro.get(c, 0) > 0:
				ve = true                         # ou dentro de um dos cômodos que ela liga
		if ve:
			for c in ab.comodos:
				novo[c] = true
	return novo


func _atualizar(imediato: bool = false) -> void:
	var novo := _calcular()
	if novo == _revelado and not imediato:
		return
	_revelado = novo
	var tempo := 0.0 if imediato else duracao_transicao
	for parede in _paredes:
		var abaixa := false
		for c in parede.baixa_para:
			abaixa = abaixa or _revelado.get(c, false)
		parede.definir_baixa(abaixa, imediato)
	for c in comodos:
		var nome := c.capitalize()
		var telhado := get_node_or_null("Telhado" + nome) as CanvasItem
		var sem_telhado := false
		if telhado != null:
			for outro in telhado.get_meta("some_para", PackedStringArray()):
				sem_telhado = sem_telhado or _revelado.get(outro, false)
			_fundir(telhado, 0.0 if sem_telhado else 1.0, tempo)
		var escuro := get_node_or_null("Escuro" + nome) as CanvasItem
		if escuro != null:
			_fundir(escuro, 1.0 if (sem_telhado and not _revelado[c]) else 0.0, tempo)
		var conteudo := get_node_or_null("Conteudo" + nome) as CanvasItem
		if conteudo != null:
			_fundir(conteudo, 1.0 if _revelado[c] else 0.0, tempo)


## Leva a opacidade de um nó até 'alfa' (some de vez quando chega a zero).
func _fundir(no: CanvasItem, alfa: float, tempo: float) -> void:
	if _transicoes.has(no) and _transicoes[no] != null and _transicoes[no].is_valid():
		_transicoes[no].kill()
	if tempo <= 0.0:
		no.modulate.a = alfa
		no.visible = alfa > 0.0
		return
	no.visible = true
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(no, "modulate:a", alfa, tempo)
	if alfa <= 0.0:
		t.tween_callback(no.hide)
	_transicoes[no] = t
