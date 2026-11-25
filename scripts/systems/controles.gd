class_name Controles
extends RefCounted
## Controles remapeáveis e configurações salvas (V13: defaultBindings, bindingLabels, setBinding, resetBindings
## e o localStorage — aqui um ConfigFile em user://). Trabalha direto no InputMap da Godot: quem lê
## is_action_pressed("jump") passa a ouvir a tecla nova sem mudar nada.

const ARQUIVO := "user://configuracoes.cfg"

## [ação, rótulo] na ordem do menu (V13: bindingLabels). "guard" fica de fora: a Godot ainda não tem guarda.
const ACOES := [
	["move_up", "Mover para cima"], ["move_down", "Mover para baixo"], ["move_left", "Mover para a esquerda"],
	["move_right", "Mover para a direita"], ["run", "Correr (segurar)"], ["crouch", "Agachar (alterna)"],
	["prone", "Deitar (alterna)"], ["jump", "Pular"], ["interact", "Interagir / vasculhar / pegar"],
	["attack", "Atacar / colher"], ["morder", "Beber sangue (infectado)"], ["transform", "Alternar forma (ratos)"], ["flashlight", "Lanterna"],
	["inventory", "Inventário"], ["diario", "Diário"], ["minimapa", "Mapa do mundo"], ["salvar_rapido", "Salvar a partida"],
	["carregar_rapido", "Carregar a partida salva"], ["menu", "Menu / configurações"]]

static var _padroes: Dictionary = {}        ## ação -> Array[InputEvent] do project.godot
static var _carregado := false


## Guarda os padrões, cria ações que só existem em código e aplica o que estiver salvo. Idempotente.
static func iniciar() -> void:
	if _carregado:
		return
	_carregado = true
	for par in [["minimapa", KEY_M], ["salvar_rapido", KEY_F5], ["carregar_rapido", KEY_F8], ["morder", KEY_B], ["diario", KEY_J]]:
		var nome_acao: String = par[0]
		if not InputMap.has_action(nome_acao):
			InputMap.add_action(nome_acao)
			var m := InputEventKey.new()
			m.physical_keycode = par[1]
			InputMap.action_add_event(nome_acao, m)
	for a in ACOES:
		var acao: String = a[0]
		_padroes[acao] = InputMap.action_get_events(acao).duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	for a in ACOES:
		var acao2: String = a[0]
		var ev := _de_dict(cfg.get_value("controles", acao2, {}))
		if ev != null:
			_definir(acao2, ev)
	aplicar_video_audio(cfg)


## Evento principal de uma ação (o que o menu mostra e troca).
static func evento(acao: String) -> InputEvent:
	var evs := InputMap.action_get_events(acao)
	return evs[0] if not evs.is_empty() else null


static func nome(acao: String) -> String:
	return nome_evento(evento(acao))


static func nome_evento(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Botão esquerdo"
			MOUSE_BUTTON_RIGHT: return "Botão direito"
			MOUSE_BUTTON_MIDDLE: return "Botão do meio"
			_: return "Mouse %d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)   # nome no layout do teclado
		match code:
			KEY_SPACE: return "Espaço"
			KEY_ESCAPE: return "ESC"
			KEY_CTRL: return "Ctrl"
			KEY_SHIFT: return "Shift"
			KEY_ALT: return "Alt"
			KEY_TAB: return "Tab"
			KEY_ENTER: return "Enter"
		return OS.get_keycode_string(code).to_upper()
	return ev.as_text()


## Troca a tecla da ação. Se outra ação usava a mesma tecla, ela perde a tecla; devolve o rótulo dela ("" = nenhuma).
static func trocar(acao: String, ev: InputEvent) -> String:
	var limpo := _limpar(ev)
	var tirada := ""
	for a in ACOES:
		var outra: String = a[0]
		if outra != acao and _igual(evento(outra), limpo):
			InputMap.action_erase_events(outra)
			tirada = a[1]
	_definir(acao, limpo)
	salvar()
	return tirada


static func restaurar() -> void:
	for a in ACOES:
		var acao: String = a[0]
		InputMap.action_erase_events(acao)
		for ev in _padroes.get(acao, []):
			InputMap.action_add_event(acao, ev)
	salvar()


static func salvar(cfg: ConfigFile = null) -> void:
	if cfg == null:
		cfg = ConfigFile.new()
		cfg.load(ARQUIVO)                          # mantém vídeo e áudio
	for a in ACOES:
		var acao: String = a[0]
		cfg.set_value("controles", acao, _para_dict(evento(acao)))
	cfg.save(ARQUIVO)


## Forma simples e estável no arquivo: {"tecla": código físico} ou {"mouse": botão}.
static func _para_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventMouseButton:
		return {"mouse": (ev as InputEventMouseButton).button_index}
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"tecla": k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode}
	return {}


static func _de_dict(d: Variant) -> InputEvent:
	if not (d is Dictionary):
		return null
	var dd: Dictionary = d
	if dd.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(dd["mouse"])
		return m
	if dd.has("tecla"):
		var k := InputEventKey.new()
		k.physical_keycode = int(dd["tecla"])
		return k
	return null


static func ler_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO)
	return cfg


## Vídeo e áudio salvos (tela cheia, V-Sync, volume). As sombras da lanterna o jogador lê sozinho.
static func aplicar_video_audio(cfg: ConfigFile) -> void:
	var cheia: bool = cfg.get_value("video", "tela_cheia", false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if cheia else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cfg.get_value("video", "vsync", true) else DisplayServer.VSYNC_DISABLED)
	var vol: float = cfg.get_value("audio", "volume", 0.7)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.0001)))
	AudioServer.set_bus_mute(0, vol <= 0.001)


## Só a tecla/botão, sem estado de "pressionado" nem modificadores (é isso que vai para o InputMap e o arquivo).
static func _limpar(ev: InputEvent) -> InputEvent:
	if ev is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (ev as InputEventMouseButton).button_index
		return m
	var k := InputEventKey.new()
	var ek := ev as InputEventKey
	k.physical_keycode = ek.physical_keycode if ek.physical_keycode != KEY_NONE else ek.keycode
	return k


static func _igual(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var ca := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var cb := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return ca == cb
	return false


static func _definir(acao: String, ev: InputEvent) -> void:
	InputMap.action_erase_events(acao)
	InputMap.action_add_event(acao, ev)
