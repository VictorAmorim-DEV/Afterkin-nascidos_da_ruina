extends CanvasModulate
## Relógio e ciclo de dia e noite do protótipo V13.
## A cor do CanvasModulate escurece o mundo à noite e clareia ao amanhecer.
## No protótipo um dia inteiro dura 60 s (24 minutos de jogo por segundo).

## Luz ambiente por hora: [minuto do dia, r, g, b] (tabela do protótipo, js/lighting.js).
const AMBIENTE: Array = [
	[0, 26, 32, 60], [270, 30, 36, 66], [330, 92, 80, 110], [375, 190, 150, 140],
	[420, 236, 222, 205], [480, 255, 255, 255], [1050, 255, 250, 240], [1110, 245, 190, 150],
	[1160, 150, 105, 120], [1210, 58, 54, 92], [1270, 30, 36, 66], [1440, 26, 32, 60],
]

@export_range(0.0, 1439.0, 1.0) var minutos: float = 480.0   ## hora atual em minutos (480 = 08:00)
@export var dia: int = 1
@export var minutos_por_segundo: float = 24.0                 ## velocidade do relógio
@export var pausado: bool = false

## Tinta do bioma (multiplica a luz do dia/noite). O Mundo muda isto com um Tween ao cruzar faixas de bioma.
var tinta_bioma := Color.WHITE
var _cor_base := Color.WHITE


func _ready() -> void:
	add_to_group("ciclo_dia_noite")
	_aplicar()


func _process(delta: float) -> void:
	if not pausado:
		minutos += delta * minutos_por_segundo
		while minutos >= 1440.0:
			minutos -= 1440.0
			dia += 1
	_aplicar()
	SombraSol.atualizar(minutos)


func _aplicar() -> void:
	_cor_base = cor_ambiente(minutos)
	color = Color(_cor_base.r * tinta_bioma.r, _cor_base.g * tinta_bioma.g, _cor_base.b * tinta_bioma.b)


## Cor da luz ambiente no minuto dado (0 a 1440).
func cor_ambiente(m: float) -> Color:
	for i in range(AMBIENTE.size() - 1):
		var a: Array = AMBIENTE[i]
		var b: Array = AMBIENTE[i + 1]
		if m >= a[0] and m <= b[0]:
			var t: float = (m - a[0]) / float(b[0] - a[0])
			var s := t * t * (3.0 - 2.0 * t)
			return Color(
				lerpf(a[1], b[1], s) / 255.0,
				lerpf(a[2], b[2], s) / 255.0,
				lerpf(a[3], b[3], s) / 255.0)
	return Color.WHITE


## 0 = dia claro, perto de 0,85 = noite fechada.
func escuridao() -> float:
	return 1.0 - (_cor_base.r + _cor_base.g + _cor_base.b) / 3.0


func eh_noite() -> bool:
	return minutos < 6.0 * 60.0 or minutos >= 19.0 * 60.0


func texto_relogio() -> String:
	return "DIA %d • %02d:%02d • %s" % [dia, int(minutos / 60.0), int(minutos) % 60, "NOITE" if eh_noite() else "DIA"]
