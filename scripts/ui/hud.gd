extends CanvasLayer
## HUD: relógio, barra de fôlego e estado do jogador.
## Fica em um CanvasLayer, então não é escurecido pelo ciclo de dia e noite.

@export var jogador_path: NodePath
@export var ciclo_path: NodePath

const COR_FOLEGO := Color(0.56, 0.78, 0.42)
const COR_CORRENDO := Color(0.93, 0.76, 0.33)
const COR_EXAUSTO := Color(0.84, 0.33, 0.29)

var _jogador: Node
var _ciclo: Node
var _preenchimento := StyleBoxFlat.new()
var _vida_barra := ProgressBar.new()
var _fome_barra := ProgressBar.new()
var _vida_texto := Label.new()
var _saude_texto := Label.new()
var _sol_tela := TextureRect.new()
var _toast := Label.new()
var _toast_tween: Tween
var _t_dica := 0.0                ## a dica de interação é recalculada 10× por segundo, não a cada quadro

@onready var relogio: Label = $Painel/Relogio
@onready var folego_texto: Label = $Painel/FolegoTexto
@onready var folego: ProgressBar = $Painel/Folego
@onready var estado: Label = $Painel/Estado
@onready var ajuda: Label = $Painel/Ajuda
@onready var dica: Label = $Dica


func _ready() -> void:
	add_to_group("hud")
	Controles.iniciar()                            # teclas salvas e a ação "minimapa" antes de quem as usa
	_jogador = get_node_or_null(jogador_path)
	_ciclo = get_node_or_null(ciclo_path)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	fundo.set_corner_radius_all(4)
	_preenchimento.bg_color = COR_FOLEGO
	_preenchimento.set_corner_radius_all(4)
	folego.add_theme_stylebox_override("background", fundo)
	folego.add_theme_stylebox_override("fill", _preenchimento)
	for rotulo: Label in [relogio, folego_texto, estado, ajuda, dica]:
		rotulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		rotulo.add_theme_constant_override("outline_size", 4)
		rotulo.add_theme_font_size_override("font_size", 14)
	relogio.add_theme_font_size_override("font_size", 17)
	ajuda.add_theme_font_size_override("font_size", 12)
	ajuda.modulate = Color(1.0, 1.0, 1.0, 0.7)
	# a linha de ajuda quebra dentro do painel: sem isso o painel crescia até a largura da tela e
	# esticava as barras de vida/fôlego por baixo do minimapa
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ajuda.custom_minimum_size = Vector2(300, 0)
	dica.add_theme_font_size_override("font_size", 18)
	_montar_vitais()
	_montar_toast()
	var mm := Minimapa.new()                       # V13: minimapa com bússola (M amplia)
	add_child(mm)
	var menu := MenuConfig.new()                   # V13: menu de configurações (ESC)
	menu.name = "MenuConfig"
	add_child(menu)
	menu.mudou.connect(_texto_ajuda)
	menu.mudou.connect(mm._layout)                 # a dica "M · ampliar" acompanha a tecla
	_texto_ajuda()


func _process(delta: float) -> void:
	_t_dica -= delta
	if _t_dica <= 0.0:
		_t_dica = 0.1
		_atualizar_dica()
	if _ciclo != null:
		relogio.text = _ciclo.texto_relogio()
	if _jogador == null:
		return
	# V13: hudArea
	relogio.text += " · " + ("SEU ESCONDERIJO" if _jogador.territorio.abrigo else "TERRAS ABANDONADAS")
	folego.max_value = _jogador.stamina_max
	folego.value = _jogador.stamina
	folego_texto.text = "FÔLEGO %d%%%s" % [int(_jogador.stamina), " · EXAUSTO" if _jogador.exausto else ""]
	if _jogador.exausto:
		_preenchimento.bg_color = COR_EXAUSTO
	elif _jogador.correndo:
		_preenchimento.bg_color = COR_CORRENDO
	else:
		_preenchimento.bg_color = COR_FOLEGO
	var eq: String = _jogador.inventario.id_equipado()
	estado.text = "%s • %s · Lanterna %s · %s" % [_jogador.nome_postura(), _jogador.texto_furtividade(),
		"ligada" if _jogador.lanterna_ligada else "desligada", Itens.nome(eq) if eq != "" else "mãos livres"]
	_vida_barra.max_value = _jogador.vida_max
	_vida_barra.value = _jogador.vida
	_fome_barra.value = _jogador.fome
	var forma: String = " · FORMA RATO" if _jogador.forma_rato() else ""
	_vida_texto.text = "%s%s · NÍVEL %d (XP %d/%d)\nVIDA %d/%d · FOME %d%%" % [_jogador.NOMES_RACA[_jogador.raca].to_upper(), forma,
		_jogador.nivel, _jogador.xp, _jogador.nivel * 100, ceili(_jogador.vida), int(_jogador.vida_max), int(_jogador.fome)]
	var doente: bool = not _jogador.doenca.is_empty()
	_saude_texto.text = "SAÚDE: " + _jogador.texto_doenca()
	if _jogador.raca == "vampire":
		_saude_texto.text += "\nSOL %d/60%s" % [int(_jogador.sol), " · QUEIMANDO" if _jogador.sol > 60.0 else ""]
	if _jogador.territorio.tem_totem():
		_saude_texto.text += "\nTOTEM: " + _jogador.territorio.resumo()
	if _jogador.dirigindo != null:
		_saude_texto.text += "\n%s: %d km/h%s" % [_jogador.dirigindo.nome.to_upper(), _jogador.dirigindo.velocidade_kmh(),
			"" if _jogador.dirigindo.farol_ligado else " · faróis apagados"]
	_saude_texto.modulate = Color(1.0, 0.45, 0.4) if doente else Color(0.7, 1.0, 0.7)
	_sol_tela.visible = _jogador.exposto_ao_sol()
	_sol_tela.modulate.a = clampf(_jogador.sol / 30.0 + 0.35, 0.35, 1.0)


## Dica de interação: o objeto do grupo "interativo" de maior prioridade que tiver algo a dizer.
## Com ~80 interativos na cidade (alguns comparando-se com o próprio grupo), fazer isso todo quadro custava ~1 ms.
func _atualizar_dica() -> void:
	var texto := ""
	var melhor := -1
	for no in get_tree().get_nodes_in_group("interativo"):
		if no.has_method("texto_interacao"):
			var t: String = no.texto_interacao()
			var pr: int = no.prioridade_interacao() if no.has_method("prioridade_interacao") else 0
			if t != "" and pr > melhor:
				texto = t
				melhor = pr
	dica.text = texto
	dica.visible = texto != ""


func _barra(b: ProgressBar, cor: Color) -> void:
	b.custom_minimum_size = Vector2(240, 8)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0, 0, 0, 0.5)
	fundo.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = cor
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", fill)


func _montar_vitais() -> void:
	var painel: Node = $Painel
	_vida_texto.add_theme_font_size_override("font_size", 13)
	_vida_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_vida_texto.add_theme_constant_override("outline_size", 4)
	_barra(_vida_barra, Color(0.78, 0.25, 0.22))
	_barra(_fome_barra, Color(0.85, 0.62, 0.25))
	_fome_barra.max_value = 100.0
	_saude_texto.add_theme_font_size_override("font_size", 13)
	_saude_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_saude_texto.add_theme_constant_override("outline_size", 4)
	# vinheta escura do sol (V13: gradiente radial quando o vampiro está exposto)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.35, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_sol_tela.texture = tex
	_sol_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sol_tela.stretch_mode = TextureRect.STRETCH_SCALE
	_sol_tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sol_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sol_tela.visible = false
	add_child(_sol_tela)
	move_child(_sol_tela, 0)
	for n in [_vida_texto, _vida_barra, _fome_barra, _saude_texto]:
		painel.add_child(n)
		painel.move_child(n, painel.get_child_count() - 2)     # antes da linha de ajuda
	pass


## Linha de ajuda montada com as teclas atuais (muda quando o jogador remapeia no menu).
func _texto_ajuda() -> void:
	var n := func(a: String) -> String: return Controles.nome(a)
	ajuda.text = "%s %s %s %s mover · %s correr · %s agachar · %s deitar · %s pular · %s lanterna · %s interagir / entrar no veículo · %s mochila · %s atacar/colher · %s forma (rato) · %s minimapa · %s menu · F9 trocar raça" % [
		n.call("move_up"), n.call("move_left"), n.call("move_down"), n.call("move_right"), n.call("run"), n.call("crouch"),
		n.call("prone"), n.call("jump"), n.call("flashlight"), n.call("interact"), n.call("inventory"), n.call("attack"),
		n.call("transform"), n.call("minimapa"), n.call("menu")]


func _montar_toast() -> void:
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)


## Mensagem passageira no topo da tela (V13: toast/log).
func aviso(texto: String) -> void:
	_toast.text = texto
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)
