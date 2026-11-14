extends Node2D
## Construção em camadas, com corte por cômodo no estilo Project Zomboid.
##
## Camadas (ver tools/gerar_construcao.py), uma de cada por cômodo:
##   Interior<Cômodo>  piso, móveis e as paredes altas do fundo
##   Fachada<Cômodo>   telhado + parede frontal
## As peças foram recortadas pela mesma linha, então sempre encaixam sem emenda.
##
## Com a casa fechada só a fachada aparece: de fora não dá para ver nada dentro.
## Quando um cômodo é REVELADO — o jogador entra nele, ou abre uma porta/janela
## dele —, só a metade da fachada daquele cômodo some (telhado e parede da frente).
## As paredes altas do fundo, os móveis e o piso continuam à vista, e os outros
## cômodos seguem fechados.

@export var comodos: PackedStringArray = []
@export var duracao_transicao: float = 0.35
## Abrir uma porta ou janela já revela o cômodo, mesmo com o jogador do lado de fora.
@export var revelar_ao_abrir: bool = true

var _dentro: Dictionary = {}          ## cômodo -> nº de corpos do jogador dentro
var _aberto: Dictionary = {}          ## cômodo -> alguma abertura dele está aberta
var _transicao: Tween


func _ready() -> void:
	for c in comodos:
		_dentro[c] = 0
		_aberto[c] = false
		var area := get_node_or_null("Area" + c.capitalize()) as Area2D
		if area != null:
			area.body_entered.connect(_corpo_entrou.bind(c))
			area.body_exited.connect(_corpo_saiu.bind(c))
	for no in find_children("*", "Node2D", true, false):
		if no is Abertura:
			no.mudou.connect(_abertura_mudou)
	_abertura_mudou()
	_aplicar(0.0)


## Um cômodo está revelado quando o jogador está nele ou quando uma porta
## ou janela dele foi aberta.
func revelado(comodo: String) -> bool:
	return _dentro.get(comodo, 0) > 0 or (revelar_ao_abrir and _aberto.get(comodo, false))


func jogador_dentro() -> bool:
	for c in comodos:
		if _dentro.get(c, 0) > 0:
			return true
	return false


func _corpo_entrou(corpo: Node2D, comodo: String) -> void:
	if corpo.is_in_group("jogador"):
		_dentro[comodo] = _dentro.get(comodo, 0) + 1
		_aplicar(duracao_transicao)


func _corpo_saiu(corpo: Node2D, comodo: String) -> void:
	if corpo.is_in_group("jogador"):
		_dentro[comodo] = maxi(0, _dentro.get(comodo, 0) - 1)
		_aplicar(duracao_transicao)


func _abertura_mudou() -> void:
	for c in comodos:
		_aberto[c] = false
	for no in find_children("*", "Node2D", true, false):
		if no is Abertura and no.aberta:
			for c in no.comodos:
				_aberto[c] = true
	_aplicar(duracao_transicao)


func _aplicar(duracao: float) -> void:
	var alvos: Dictionary = {}                      # nó -> alfa de destino
	for c in comodos:
		var mostrar := revelado(c)
		var dentro := get_node_or_null("Interior" + c.capitalize())
		if dentro != null:
			alvos[dentro] = 1.0 if mostrar else 0.0
		var fora := get_node_or_null("Fachada" + c.capitalize())
		if fora != null:
			alvos[fora] = 0.0 if mostrar else 1.0
		# os sprites das portas e janelas acompanham a camada em que são desenhados
		for sp in get_children():
			if sp is Sprite2D:
				if String(sp.name).ends_with("_fachada_" + c):
					sp.visible = not mostrar
				elif String(sp.name).ends_with("_interior_" + c):
					sp.visible = mostrar

	if _transicao != null and _transicao.is_valid():
		_transicao.kill()
	if duracao <= 0.0:
		for alvo in alvos:
			alvo.modulate.a = alvos[alvo]
		return
	_transicao = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for alvo in alvos:
		_transicao.tween_property(alvo, "modulate:a", alvos[alvo], duracao)
