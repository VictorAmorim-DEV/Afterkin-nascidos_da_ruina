extends StaticBody2D
class_name ParedeModular
## Um trecho de parede do kit modular (1 célula).
##
## Tem duas peças no mesmo lugar: Alta (parede inteira) e Baixa (parede cortada,
## estilo Project Zomboid). A construção chama definir_baixa() para trocar uma pela
## outra. A colisão e o oclusor de luz são deste nó e não mudam com a troca.

## Cômodos que, quando revelados, fazem esta parede abaixar (calculado pelo gerador).
@export var baixa_para: PackedStringArray = []
@export var duracao: float = 0.3

var baixa: bool = false
var _transicao: Tween

@onready var peca_alta: Node2D = $Alta
@onready var peca_baixa: Node2D = $Baixa


func definir_baixa(valor: bool, imediato: bool = false) -> void:
	if valor == baixa and not imediato:
		return
	baixa = valor
	if _transicao != null and _transicao.is_valid():
		_transicao.kill()
	var alfa_alta := 0.0 if baixa else 1.0
	if imediato:
		peca_alta.modulate.a = alfa_alta
		peca_baixa.modulate.a = 1.0 - alfa_alta
		return
	_transicao = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_transicao.tween_property(peca_alta, "modulate:a", alfa_alta, duracao)
	_transicao.tween_property(peca_baixa, "modulate:a", 1.0 - alfa_alta, duracao)
