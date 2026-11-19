class_name PainelDev
extends CanvasLayer
## Modo desenvolvedor (F1): ferramentas para testar sem esperar o jogo acontecer. Só abre em build de debug.
## Itens, teleporte, chaves (Dev), tempo, cura/doenças e limpar inimigos. Não pausa o jogo.

const TECLA := KEY_F1

var _raiz := PanelContainer.new()
var _itens := OptionButton.new()
var _qtd := SpinBox.new()
var _lugares := OptionButton.new()
var _destinos: Array = []                 ## Vector2 (mundo) de cada entrada de _lugares
var _vel := OptionButton.new()
var _rep := Label.new()
var _t_rep := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Dev.disponivel():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.08, 0.94)
	sb.border_color = Color(0.85, 0.35, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_raiz.add_theme_stylebox_override("panel", sb)
	_raiz.position = Vector2(16, 70)
	_raiz.visible = false
	add_child(_raiz)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(330, 0)
	_raiz.add_child(col)
	_titulo(col, "MODO DESENVOLVEDOR  (F1 fecha)")

	_titulo(col, "Itens")
	var li := HBoxContainer.new()
	for id in Itens.DB:
		_itens.add_item(Itens.nome(id))
		_itens.set_item_metadata(_itens.item_count - 1, id)
	_itens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	li.add_child(_itens)
	_qtd.min_value = 1
	_qtd.max_value = 64
	_qtd.value = 5
	li.add_child(_qtd)
	li.add_child(_botao("Dar", _dar_item))
	col.add_child(li)

	_titulo(col, "Teleporte")
	var lt := HBoxContainer.new()
	_montar_lugares()
	_lugares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.add_child(_lugares)
	lt.add_child(_botao("Ir", _ir_lugar))
	col.add_child(lt)
	col.add_child(_botao("Ir para o marcador do mapa (botão direito no mapa)", _ir_marcador))

	_titulo(col, "Chaves")
	for par in [["Fôlego infinito", "folego_infinito"], ["Invencível (sem dano nem infecção)", "invencivel"],
			["Sem fome e sede", "sem_necessidades"], ["Invisível para inimigos", "invisivel"],
			["Voar (atravessa tudo)", "voar"]]:
		var c := CheckBox.new()
		c.text = par[0]
		c.focus_mode = Control.FOCUS_NONE
		c.button_pressed = Dev.valor(par[1])
		c.toggled.connect(func(v: bool): Dev.ligar(par[1], v))
		col.add_child(c)
	var lvoo := HBoxContainer.new()
	var rvoo := Label.new()
	rvoo.text = "Velocidade do voo:"
	lvoo.add_child(rvoo)
	var voo := OptionButton.new()
	for n in [4, 8, 10, 16]:
		voo.add_item("%d× correndo" % n)
	voo.focus_mode = Control.FOCUS_NONE
	voo.item_selected.connect(func(i: int): Dev.voar_vezes = [4.0, 8.0, 10.0, 16.0][i])
	lvoo.add_child(voo)
	col.add_child(lvoo)
	col.add_child(_botao("Revelar o mapa inteiro", func():
		Descobertas.revelar_retangulo(Rect2(0, 0, MinimapaBase.W * MinimapaBase.PX, MinimapaBase.H * MinimapaBase.PX))
		for c in MundoGen.acampamentos():
			if not Descobertas.acampamentos.has(c["nome"]):
				Descobertas.acampamentos.append(c["nome"])
		_aviso("Mapa revelado.")))

	_titulo(col, "Tempo")
	var lh := HBoxContainer.new()
	for par in [["06h", 360.0], ["12h", 720.0], ["19h", 1140.0], ["00h", 0.0]]:
		lh.add_child(_botao(par[0], _ir_hora.bind(par[1])))
	lh.add_child(_botao("+1 h", func(): _ir_hora(-1.0)))
	col.add_child(lh)
	var lv := HBoxContainer.new()
	var rv := Label.new()
	rv.text = "Velocidade do relógio:"
	lv.add_child(rv)
	for n in ["×1 (40 min/dia)", "×10", "×60 (40 s/dia)"]:
		_vel.add_item(n)
	_vel.item_selected.connect(_mudar_velocidade)
	lv.add_child(_vel)
	col.add_child(lv)

	_titulo(col, "Jogador e mundo")
	var lj := HBoxContainer.new()
	lj.add_child(_botao("Curar tudo", _curar))
	lj.add_child(_botao("Disenteria", _doenca.bind("Disenteria")))
	lj.add_child(_botao("Mutação", _doenca.bind("Mutação vampírica")))
	col.add_child(lj)
	col.add_child(_botao("Matar inimigos num raio de 30 m", _matar_perto))

	_titulo(col, "Reputação")
	_rep.add_theme_font_size_override("font_size", 12)
	col.add_child(_rep)
	var lr := HBoxContainer.new()
	lr.add_child(_botao("+20 aqui", _mexer_rep.bind(20)))
	lr.add_child(_botao("−20 aqui", _mexer_rep.bind(-20)))
	lr.add_child(_botao("Espalhar boatos já", func():
		for b in Reputacao.pendentes:
			b["hora"] = 0.0
		Reputacao.passo()
		_aviso("Boatos espalhados.")))
	col.add_child(lr)


func _process(delta: float) -> void:
	if not _raiz.visible:
		return
	_t_rep -= delta
	if _t_rep > 0.0:
		return
	_t_rep = 0.5
	var linhas: PackedStringArray = []
	for id in Comunidades.ids():
		linhas.append("%s: %d" % [Comunidades.nome(str(id)), Reputacao.valor(str(id))])
	linhas.append("Humana geral: %d · boatos a caminho: %d · mortos: %d" % [roundi(Reputacao.humana),
		Reputacao.pendentes.size(), Reputacao.mortos.size()])
	_rep.text = "\n".join(linhas)


## Reputação da comunidade mais perto (até 300 m).
func _mexer_rep(n: int) -> void:
	var j := _j()
	var com := Comunidades.perto(IsoMath.tela_para_mundo(j.global_position), 300.0 * IsoMath.METRO)
	if com == "":
		_aviso("Nenhuma comunidade por perto.")
		return
	Reputacao.mudar(com, n)
	_aviso("%s: %d" % [Comunidades.nome(com), Reputacao.valor(com)])


func _titulo(col: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.95, 0.6, 1.0))
	l.add_theme_font_size_override("font_size", 13)
	col.add_child(l)


func _botao(t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(acao)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not Dev.disponivel():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == TECLA:
		_raiz.visible = not _raiz.visible
		get_viewport().set_input_as_handled()


func _j() -> Node2D:
	return get_tree().get_first_node_in_group("jogador") as Node2D


func _aviso(t: String) -> void:
	var j := _j()
	if j != null:
		j.aviso("[DEV] " + t)


func _dar_item() -> void:
	var j := _j()
	var id: String = _itens.get_item_metadata(_itens.selected)
	var n := int(_qtd.value)
	var sobra: int = j.inventario.adicionar_parcial(id, n)
	if sobra > 0:
		j.largar_item(id, sobra)
	_aviso("+%d %s%s" % [n, Itens.nome(id).to_lower(), " (parte no chão)" if sobra > 0 else ""])


func _montar_lugares() -> void:
	for a in MundoGen.AREAS.size():
		var r := MundoGen.area_rect(a)
		_lugares.add_item(str(MundoGen.AREAS[a]["nome"]))
		_destinos.append(r.position + Vector2(MundoGen.RUA, MundoGen.RUA) * 0.5)   # um cruzamento, na rua
	for v in MundoGen.aldeias():
		_lugares.add_item(str((v as Dictionary)["nome"]))
		_destinos.append(((v as Dictionary)["area"] as Rect2).get_center())
	for c in MundoGen.acampamentos():
		_lugares.add_item(str((c as Dictionary)["nome"]))
		_destinos.append((c as Dictionary)["c"] + Vector2(0, 160))


func _teleportar(p: Vector2, nome: String) -> void:
	var j := _j()
	if j == null or j.dirigindo != null:
		_aviso("Saia do veículo para teleportar.")
		return
	get_tree().get_first_node_in_group("mundo").teleportar(p)
	_aviso("Teleportado: " + nome)


func _ir_lugar() -> void:
	_teleportar(_destinos[_lugares.selected], _lugares.get_item_text(_lugares.selected))


func _ir_marcador() -> void:
	if Descobertas.marcador == Vector2.INF:
		_aviso("Ponha um marcador no mapa (M, botão direito) antes.")
		return
	_teleportar(Descobertas.marcador, "marcador")


func _ir_hora(minutos: float) -> void:
	var c := get_tree().get_first_node_in_group("ciclo_dia_noite")
	if minutos < 0.0:
		c.minutos += 60.0
		if c.minutos >= 1440.0:
			c.minutos -= 1440.0
			c.dia += 1
	else:
		if minutos <= c.minutos:
			c.dia += 1                            # ir para uma hora que já passou = a do dia seguinte
		c.minutos = minutos
	_aviso("Agora: " + c.texto_relogio())


func _mudar_velocidade(i: int) -> void:
	get_tree().get_first_node_in_group("ciclo_dia_noite").minutos_por_segundo = [0.6, 6.0, 36.0][i]


func _curar() -> void:
	var j := _j()
	j.vida = j.vida_max
	j.descanso = 100.0
	j.fome = 100.0
	j.sede = 100.0
	j.doenca = {}
	j.incubacao_h = -1.0
	j.sol = 0.0
	_aviso("Vida, fome, sede e saúde restauradas.")


func _doenca(tipo: String) -> void:
	var j := _j()
	j.doenca = j.nova_disenteria() if tipo == "Disenteria" else \
		{"tipo": tipo, "horas": 24.0, "total": 24.0, "estagio": 0.0, "origem": "vampire"}
	_aviso("Doença: " + tipo)


func _matar_perto() -> void:
	var j := _j()
	var n := 0
	for e in get_tree().get_nodes_in_group("inimigo"):
		if IsoMath.tela_para_mundo(e.global_position - j.global_position).length() < 30.0 * IsoMath.METRO:
			e.receber_dano(9999.0)
			n += 1
	_aviso("%d inimigo(s) eliminados." % n)
