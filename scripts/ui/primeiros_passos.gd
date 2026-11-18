class_name PrimeirosPassos
extends Control
## "Primeiros passos" (docs/DECISOES_DESIGN.md, ajustes do playtest, item 5): lista discreta, à direita, embaixo do
## minimapa, na voz do personagem. Ensina o loop em ordem — água, juntar coisas, fogo, ferver, lugar seguro,
## sobreviver à noite — sem travar o jogo. Só o passo atual mostra a dica de tecla.
## Os passos avançam por eventos que o jogo manda ao grupo "primeiros_passos" (evento("bebeu") etc.); a noite é
## vigiada pelo relógio. O progresso fica no jogador (Player.passos) e vai no save. Vira o diário no marco 3.

## [id, texto na voz do personagem, dica (com %s = teclas), evento que conta, quantas vezes]
const PASSOS := [
	["agua", "Preciso de água.", "Beba a garrafa (mochila: %s) ou aperte %s na beira de uma poça ou rio.", "bebeu", 1],
	["vasculhar", "Juntar o que der.", "Aperte %s perto de armários, geladeiras e caixas. Cuidado com o peso da mochila.", "vasculhou", 3],
	["fogo", "Fazer fogo.", "Na mochila (%s), aba de fabricação: fogueira (5 madeira, 3 pedra). Depois, use-a.", "acendeu", 1],
	["ferver", "Água limpa.", "Com água suja na mochila, aperte %s ao lado da fogueira. O fogo faz barulho.", "ferveu", 1],
	["abrigo", "Um lugar seguro antes de escurecer.", "Fabrique um totem e use-o onde quer ficar; o abrigo sai da aba Território.", "totem", 1],
	["noite", "Sobreviver à primeira noite.", "No escuro eles enxergam pouco, mas ouvem longe. Agache (%s) e cuidado com a lanterna (%s).", "", 1],
]

var _jogador: Node = null
var _texto := RichTextLabel.new()
var _t := 0.0
var _concluido_em := -1.0


func _ready() -> void:
	add_to_group("primeiros_passos")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -330.0
	offset_right = -16.0
	offset_top = 250.0
	offset_bottom = 520.0
	var fundo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	fundo.add_theme_stylebox_override("panel", sb)
	fundo.custom_minimum_size = Vector2(314, 0)    # a altura acompanha o texto
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_texto.custom_minimum_size = Vector2(294, 0)
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("normal_font_size", 13)
	_texto.add_theme_font_size_override("bold_font_size", 13)
	fundo.add_child(_texto)
	visible = false


## Liga os primeiros passos para o jogador (começo de partida, ou partida carregada que ainda não terminou).
func iniciar(j: Node) -> void:
	_jogador = j
	if not j.passos.has("_ativo"):
		j.passos["_ativo"] = true
	_atualizar()


## Recebe um evento do jogo ("bebeu", "vasculhou", "acendeu", "ferveu", "totem").
func evento(nome: String) -> void:
	if _jogador == null or not bool(_jogador.passos.get("_ativo", false)):
		return
	_jogador.passos[nome] = int(_jogador.passos.get(nome, 0)) + 1
	_atualizar()


func _feito(p: Array) -> bool:
	if p[0] == "noite":
		return bool(_jogador.passos.get("noite", false))
	return int(_jogador.passos.get(p[3], 0)) >= int(p[4])


func _dica(p: Array) -> String:
	var t: String = p[2]
	match p[0]:
		"agua":
			return t % [Controles.nome("inventory"), Controles.nome("interact")]
		"vasculhar", "ferver":
			return t % Controles.nome("interact")
		"fogo":
			return t % Controles.nome("inventory")
		"noite":
			return t % [Controles.nome("crouch"), Controles.nome("flashlight")]
	return t


func _atualizar() -> void:
	if _jogador == null or not bool(_jogador.passos.get("_ativo", false)):
		visible = false
		return
	var linhas: PackedStringArray = ["[b]PRIMEIROS PASSOS[/b]"]
	var atual := -1
	for i in PASSOS.size():
		var p: Array = PASSOS[i]
		if _feito(p):
			linhas.append("[color=#7fbf7f]✓ %s[/color]" % p[1])
		elif atual < 0:
			atual = i
			linhas.append("[color=#ffe08a]▸ %s[/color]" % p[1])
			linhas.append("[color=#b8b8b8][i]   %s[/i][/color]" % _dica(p))
		else:
			linhas.append("[color=#8a8a8a]· %s[/color]" % p[1])
	if atual < 0:
		linhas.append("")
		linhas.append("[color=#ffe08a]Você passou pelo primeiro dia. Daqui em diante, é com você.[/color]")
		if _concluido_em < 0.0:
			_concluido_em = Time.get_ticks_msec() / 1000.0
	_texto.text = "\n".join(linhas)
	visible = true


func _process(delta: float) -> void:
	if _jogador == null or not visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	# a noite: conta quando o dia 2 amanhece (6h) com o jogador vivo
	if not bool(_jogador.passos.get("noite", false)):
		var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
		if ciclo != null and int(ciclo.dia) >= 2 and float(ciclo.minutos) >= 360.0 and not _jogador.morto:
			_jogador.passos["noite"] = true
			_jogador.aviso("O sol nasceu. Você sobreviveu à primeira noite.")
			_atualizar()
	# tudo feito: a lista some depois de 12 s
	if _concluido_em >= 0.0 and Time.get_ticks_msec() / 1000.0 - _concluido_em > 12.0:
		_jogador.passos["_ativo"] = false
		visible = false
