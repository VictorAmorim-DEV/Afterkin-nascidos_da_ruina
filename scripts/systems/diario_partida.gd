class_name DiarioPartida
extends RefCounted
## Diário da partida para os testadores (marco 2, etapa 13; docs/DECISOES_DESIGN.md Q54, respostas de 21/11/2026).
##
## Registra em segundo plano o que acontece com o jogador (início, mortes, renascimentos, trocas, reputação, crimes,
## inimigos mortos, doenças, habilidades, trabalhos, rumores, sono, lugares) e as notícias do mundo, mais a rota
## (um ponto a cada AMOSTRA_S) e o tempo em cada lugar. Sem botão: exporta sozinho quando o jogador morre, quando
## fecha o jogo e a cada AUTO_S (para não perder tudo se o jogo travar), na pasta do jogo:
##   diarios/partida_<data>/diario.txt   — o diário em texto
##   diarios/partida_<data>/eventos.json — os dados crus
##   diarios/partida_<data>/resumo.html  — mapa da ilha com rotas e mortes, tempo por lugar, reputação, linha do tempo
## No editor, "pasta do jogo" é a pasta do projeto (diarios/ fica fora do Git); no jogo exportado, a do executável.

const AMOSTRA_S := 20.0
const AUTO_S := 300.0
const ROTA_MAX := 6000
const EVENTOS_MAX := 4000
const MODELO_HTML := "res://data/resumo_partida.html"

static var id: String = ""                 ## "2026-11-21_14-05-33"
static var info: Dictionary = {}           ## origem, genero, local
static var eventos: Array = []             ## [{h, dia, hora, real, tipo, texto, p: [x, y]}]
static var rota: Array = []                ## [[x, y, h, vida]]
static var tempos: Dictionary = {}         ## lugar -> segundos reais
static var abates: Dictionary = {}         ## tipo de inimigo -> quantos o jogador matou
static var real_s: float = 0.0             ## segundos reais jogados
static var _t_amostra := 0.0
static var _t_auto := 0.0
static var _lugar := ""
static var _doenca := ""
static var _mapa_b64 := ""


static func zerar() -> void:
	id = ""
	info = {}
	eventos = []
	rota = []
	tempos = {}
	abates = {}
	real_s = 0.0
	_t_amostra = 0.0
	_t_auto = 0.0
	_lugar = ""
	_doenca = ""


## Partida nova (SelecaoRaca): abre um diário novo.
static func iniciar(origem: String, genero: String, local: String) -> void:
	zerar()
	id = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_").replace("T", "_")
	info = {"origem": origem, "genero": genero, "local": local, "versao": ProjectSettings.get_setting("application/config/version", "")}
	evento("inicio", "Começou como %s (%s), em %s." % [Origens.nome(origem), "mulher" if genero == "f" else "homem", local])


static func _jogador() -> Node2D:
	var arv := Engine.get_main_loop() as SceneTree
	return arv.get_first_node_in_group("jogador") as Node2D if arv != null else null


static func _relogio() -> Array:
	var arv := Engine.get_main_loop() as SceneTree
	var c: Node = arv.get_first_node_in_group("ciclo_dia_noite") if arv != null else null
	if c == null:
		return [1, 0, 0]
	return [int(c.dia), int(float(c.minutos) / 60.0), int(fmod(float(c.minutos), 60.0))]


## Registra um evento do jogador ('tipo': inicio, morte, renascer, troca, reputacao, crime, abate, doenca, cura,
## habilidade, trabalho, recado, rumor, sono, lugar, mundo...).
static func evento(tipo: String, texto: String, extra: Dictionary = {}) -> void:
	if id == "":
		return
	var r := _relogio()
	var j := _jogador()
	var p := IsoMath.tela_para_mundo(j.global_position) if j != null else Vector2.ZERO
	var e := {"h": snappedf(Reputacao.agora_h(), 0.01), "dia": r[0], "hora": "%02d:%02d" % [r[1], r[2]], "real": roundi(real_s),
		"tipo": tipo, "texto": texto, "p": [roundi(p.x), roundi(p.y)]}
	e.merge(extra)
	eventos.append(e)
	if eventos.size() > EVENTOS_MAX:
		eventos = eventos.slice(eventos.size() - EVENTOS_MAX)


static func abate(tipo: String) -> void:
	if id != "":
		abates[tipo] = int(abates.get(tipo, 0)) + 1


## Chamado pelo GerenteComunidades a cada 0,5 s: rota, tempo por lugar, doença e o salvamento automático.
static func passo(dt: float) -> void:
	if id == "":
		return
	var j := _jogador()
	if j == null or bool(j.get("morto")):
		return
	real_s += dt
	_t_amostra -= dt
	_t_auto += dt
	var p := IsoMath.tela_para_mundo((j.dirigindo if j.dirigindo != null else j).global_position)
	if not _lugar.is_empty():
		tempos[_lugar] = float(tempos.get(_lugar, 0.0)) + dt
	if _t_amostra <= 0.0:
		_t_amostra = AMOSTRA_S
		rota.append([roundi(p.x), roundi(p.y), snappedf(Reputacao.agora_h(), 0.01), roundi(float(j.vida))])
		if rota.size() > ROTA_MAX:
			rota = rota.slice(rota.size() - ROTA_MAX)
		var com := Comunidades.em(p)
		var lugar := Comunidades.nome(com) if com != "" else _sem_preposicao(Respawn.nome_do_lugar(p))
		if lugar != _lugar:
			_lugar = lugar
			evento("lugar", "Pegou a %s." % lugar if lugar.begins_with("estrada") else "Chegou a %s." % lugar)
		var d := str((j.doenca as Dictionary).get("tipo", ""))
		if d != _doenca:
			if d != "":
				evento("doenca", "Ficou doente: %s." % d)
			else:
				evento("cura", "Livrou-se de %s." % _doenca)
			_doenca = d
	if _t_auto >= AUTO_S:
		_t_auto = 0.0
		exportar("automatico")


## "em Porto Atlântico" / "perto de Areal" → o nome do lugar (ou "estrada perto de ...").
static func _sem_preposicao(t: String) -> String:
	for pre in ["em ", "no ", "na ", "nos ", "nas "]:
		if t.begins_with(pre):
			return t.substr(pre.length())
	return "estrada (%s)" % t if t != "" else "estrada"


# ───────────────────────────── exportar ─────────────────────────────

static func pasta() -> String:
	var base := ProjectSettings.globalize_path("res://diarios") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir().path_join("diarios")
	return base.path_join("partida_%s" % id)


## Grava o texto, os dados e o resumo HTML na pasta do jogo. 'motivo': morte, fechou, automatico.
static func exportar(motivo: String) -> void:
	if id == "":
		return
	var dir := pasta()
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.has_feature("editor"):
		var gi := ProjectSettings.globalize_path("res://diarios/.gdignore")
		if not FileAccess.file_exists(gi):
			var f0 := FileAccess.open(gi, FileAccess.WRITE)
			if f0 != null:
				f0.close()
	var dados := _dados(motivo)
	_gravar(dir.path_join("eventos.json"), JSON.stringify(dados, "\t"))
	_gravar(dir.path_join("diario.txt"), _texto(dados))
	_gravar(dir.path_join("resumo.html"), _html(dados))


static func _gravar(caminho: String, conteudo: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		push_warning("DiarioPartida: não foi possível gravar %s (erro %d)." % [caminho, FileAccess.get_open_error()])
		return
	f.store_string(conteudo)
	f.close()


static func _dados(motivo: String) -> Dictionary:
	var r := _relogio()
	var reps: Dictionary = {}
	for c in Comunidades.ids():
		reps[Comunidades.nome(str(c))] = Reputacao.valor(str(c))
	var noticias: Array = []
	for e in Simulacao.diario:
		noticias.append({"dia": e["dia"], "hora": e["hora"], "com": Comunidades.nome(str(e["com"])) if str(e["com"]) != "" else "", "texto": e["texto"]})
	var mortos: Array = []
	for k in Reputacao.mortos:
		var partes := str(k).split("/")
		if partes.size() == 2:
			mortos.append("%s (%s)" % [Consequencias.nome_npc(partes[0], partes[1]), Comunidades.nome(partes[0])])
	return {"id": id, "motivo": motivo, "exportado": Time.get_datetime_string_from_system(false, true), "info": info,
		"dia": r[0], "hora": "%02d:%02d" % [r[1], r[2]], "real_s": roundi(real_s), "eventos": eventos, "rota": rota,
		"tempos": tempos, "abates": abates, "reputacao": reps, "humana": roundi(Reputacao.humana), "noticias": noticias,
		"mortos": mortos, "medicina": Medicina.habilidades, "px": MinimapaBase.PX, "w": MinimapaBase.W, "h": MinimapaBase.H}


static func _duracao(s: float) -> String:
	var m := int(s / 60.0)
	return "%d h %02d min" % [m / 60, m % 60] if m >= 60 else "%d min" % m


static func _texto(d: Dictionary) -> String:
	var l: PackedStringArray = []
	var inf: Dictionary = d["info"]
	l.append("AFTERKIN: NASCIDOS DA RUÍNA — DIÁRIO DA PARTIDA")
	l.append("Partida %s · exportado em %s (%s)" % [d["id"], d["exportado"], {"morte": "ao morrer", "fechou": "ao fechar o jogo", "automatico": "salvamento automático"}.get(d["motivo"], d["motivo"])])
	l.append("Origem: %s · %s · começou em %s" % [Origens.nome(str(inf.get("origem", ""))), "mulher" if str(inf.get("genero", "m")) == "f" else "homem", inf.get("local", "?")])
	l.append("Tempo real jogado: %s · no jogo: dia %d, %s" % [_duracao(float(d["real_s"])), int(d["dia"]), d["hora"]])
	var mortes := (d["eventos"] as Array).filter(func(e): return e["tipo"] == "morte").size()
	l.append("Mortes: %d" % mortes)
	l.append("")
	l.append("== LINHA DO TEMPO ==")
	for e in d["eventos"]:
		if str(e["tipo"]) == "reputacao":
			continue
		l.append("Dia %d, %s — %s" % [int(e["dia"]), e["hora"], e["texto"]])
	l.append("")
	l.append("== TEMPO EM CADA LUGAR ==")
	var tl: Array = (d["tempos"] as Dictionary).keys()
	tl.sort_custom(func(a, b): return float(d["tempos"][a]) > float(d["tempos"][b]))
	for k in tl:
		l.append("%s: %s" % [k, _duracao(float(d["tempos"][k]))])
	l.append("")
	l.append("== REPUTAÇÃO ==")
	for k in d["reputacao"]:
		l.append("%s: %d" % [k, int(d["reputacao"][k])])
	l.append("Humana geral: %d" % int(d["humana"]))
	l.append("")
	l.append("== INIMIGOS QUE VOCÊ MATOU ==")
	if (d["abates"] as Dictionary).is_empty():
		l.append("Nenhum.")
	for k in d["abates"]:
		l.append("%s: %d" % [k, int(d["abates"][k])])
	if not (d["mortos"] as Array).is_empty():
		l.append("")
		l.append("== MORADORES MORTOS ==")
		for m in d["mortos"]:
			l.append(str(m))
	l.append("")
	l.append("== O QUE ACONTECEU NO MUNDO (últimas notícias) ==")
	for n in d["noticias"]:
		l.append("Dia %d, %02dh — %s" % [int(n["dia"]), int(n["hora"]), n["texto"]])
	return "\n".join(l) + "\n"


static func _html(d: Dictionary) -> String:
	var modelo := FileAccess.get_file_as_string(MODELO_HTML)
	if modelo == "":
		return "<p>Modelo do resumo não encontrado.</p>"
	return modelo.replace("/*DADOS*/null", JSON.stringify(d)).replace("/*MAPA*/\"\"", "\"%s\"" % _mapa())


## O mapa da ilha (o mesmo do mapa do mundo, do cache em user://) reduzido à metade, em PNG base64.
static func _mapa() -> String:
	if _mapa_b64 != "":
		return _mapa_b64
	if MinimapaBase._arquivo_cache == "":
		MinimapaBase.preparar_cache()
	var arq := MinimapaBase._arquivo_cache
	if arq == "" or not FileAccess.file_exists(arq):
		return ""
	var img := Image.load_from_file(ProjectSettings.globalize_path(arq))
	if img == null:
		return ""
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	_mapa_b64 = "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
	return _mapa_b64


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"id": id, "info": info.duplicate(), "eventos": eventos.duplicate(true), "rota": rota.duplicate(true),
		"tempos": tempos.duplicate(), "abates": abates.duplicate(), "real_s": real_s}


static func restaurar(d: Dictionary) -> void:
	zerar()
	id = str(d.get("id", ""))
	if id == "":                               # save de antes da etapa 13: começa um diário agora
		id = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_").replace("T", "_")
	info = (d.get("info", {}) as Dictionary).duplicate()
	eventos = (d.get("eventos", []) as Array).duplicate(true)
	rota = (d.get("rota", []) as Array).duplicate(true)
	tempos = (d.get("tempos", {}) as Dictionary).duplicate()
	abates = (d.get("abates", {}) as Dictionary).duplicate()
	real_s = float(d.get("real_s", 0.0))
	evento("carregou", "Partida carregada.")
