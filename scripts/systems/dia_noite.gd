extends CanvasModulate
## Relógio e ciclo de dia e noite.
## A cor do CanvasModulate escurece o mundo à noite e clareia ao amanhecer.
## Na V13 um dia durava 60 s; aqui dura 40 min reais (0,6 minuto de jogo por segundo, docs/DECISOES_DESIGN.md Q17).
##
## Seis fases (Q27), cada uma muda o que é sensato fazer. Os efeitos físicos são contínuos (sem saltos na troca
## de fase): temperatura por uma curva diária, alcance de visão pela luz ambiente, neblina no amanhecer e o som
## que vai mais longe no ar frio e parado da noite.

## Luz ambiente por hora: [minuto do dia, r, g, b] (tabela do protótipo, js/lighting.js).
const AMBIENTE: Array = [
	[0, 26, 32, 60], [270, 30, 36, 66], [330, 92, 80, 110], [375, 190, 150, 140],
	[420, 236, 222, 205], [480, 255, 255, 255], [1050, 255, 250, 240], [1110, 245, 190, 150],
	[1160, 150, 105, 120], [1210, 58, 54, 92], [1270, 30, 36, 66], [1440, 26, 32, 60],
]

@export_range(0.0, 1439.0, 1.0) var minutos: float = 480.0   ## hora atual em minutos (480 = 08:00)
@export var dia: int = 1
@export var minutos_por_segundo: float = 0.6                  ## velocidade do relógio: 1440 / 0,6 = 2400 s = dia de 40 min
@export var pausado: bool = false

@export_group("Clima")
@export var temp_media: float = 23.0                          ## °C
@export var temp_amplitude: float = 10.0                      ## mínima ~13 °C às 2h, máxima ~33 °C às 14h
@export var visao_dia_m: float = 12.0                         ## de quantos metros um inimigo acordado te vê de dia
@export var visao_noite_m: float = 3.5                        ## ... e na noite fechada (sem lanterna)
@export var som_noite: float = 1.25                           ## o som vai 25% mais longe na noite fechada
@export var neblina_max: float = 0.6                          ## quanto a neblina do amanhecer corta a visão (0 a 1)

enum Fase { MADRUGADA, AMANHECER, MANHA, TARDE, TARDEZINHA, NOITE }
const NOMES_FASE := ["MADRUGADA", "AMANHECER", "MANHÃ", "TARDE", "TARDEZINHA", "NOITE"]
## Hora em que cada fase começa (a madrugada começa à 0h).
const INICIO_FASE := [0.0, 5.0, 7.0, 12.0, 16.0, 19.0]

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
	return "DIA %d • %02d:%02d • %s • %d °C" % [dia, int(minutos / 60.0), int(minutos) % 60, NOMES_FASE[fase()],
		roundi(temperatura())]


## Fase do dia agora.
func fase() -> Fase:
	var h := minutos / 60.0
	for i in range(INICIO_FASE.size() - 1, -1, -1):
		if h >= INICIO_FASE[i]:
			return i as Fase
	return Fase.MADRUGADA


## Temperatura do ar em °C: curva diária, mínima às 2h e máxima às 14h.
func temperatura() -> float:
	var h := minutos / 60.0
	return temp_media + temp_amplitude * cos(TAU * (h - 14.0) / 24.0)


## Calor de 0 (até 26 °C) a 1 (33 °C ou mais). A sede e o fôlego usam isto (etapa 3).
func calor() -> float:
	return clampf((temperatura() - 26.0) / 7.0, 0.0, 1.0)


## Neblina do amanhecer, de 0 a 1: sobe a partir das 4h30, é mais densa às 5h45 e some até as 7h30.
func neblina() -> float:
	var h := minutos / 60.0
	if h < 4.5 or h > 7.5:
		return 0.0
	var t := (h - 4.5) / 1.25 if h < 5.75 else (7.5 - h) / 1.75
	return t * t * (3.0 - 2.0 * t)


## Até quantos metros um inimigo acordado enxerga alguém em pé, sem lanterna: segue a luz ambiente e a neblina.
func alcance_visao_m() -> float:
	var luz := 1.0 - clampf(escuridao() / 0.8, 0.0, 1.0)
	return lerpf(visao_noite_m, visao_dia_m, luz) * (1.0 - neblina_max * neblina())


## Quanto mais longe o som vai em relação ao dia (1 de dia, 'som_noite' na noite fechada).
func propagacao_som() -> float:
	return lerpf(1.0, som_noite, clampf(escuridao() / 0.8, 0.0, 1.0))
