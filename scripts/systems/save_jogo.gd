class_name SaveJogo
extends RefCounted
## Salvar e carregar a partida (RECURSO NOVO: a V13 não tem save). Um arquivo JSON em user://.
##
## Salva o jogador (posição, raça e forma, vitais, XP, doença, mochila), o totem e o abrigo, o relógio e o que o
## mundo lembra (galhos e pedras pegos, portões, inimigos restantes por chunk, ninhos vasculhados). O mundo em si
## é determinístico pela semente: não precisa ir para o arquivo. Carros movidos voltam ao lugar de origem.
##
## Carregar recarrega a cena: o Mundo põe o jogador na posição salva antes da primeira carga de chunks e a
## SelecaoRaca, em vez de abrir, aplica o resto (raça, mochila, totem, relógio).

const ARQUIVO := "user://partida.json"
const VERSAO := 2                      ## 2: mundo da ilha (o save do mundo antigo não vale mais)

## Partida lida do disco esperando a cena recarregar (vazio = começo normal).
static var pendente: Dictionary = {}


static func existe() -> bool:
	return FileAccess.file_exists(ARQUIVO)


## Data e hora do último save, para mostrar no menu ("" se não houver).
static func quando() -> String:
	var d := _ler()
	return str(d.get("quando", "")) if not d.is_empty() else ""


static func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


static func _vec(a: Variant) -> Vector2:
	var l: Array = a
	return Vector2(float(l[0]), float(l[1]))


## Salva a partida em andamento. Devolve a mensagem para o jogador.
static func salvar(arvore: SceneTree) -> String:
	var j := arvore.get_first_node_in_group("jogador")
	var m := arvore.get_first_node_in_group("mundo")
	var ciclo := arvore.get_first_node_in_group("ciclo_dia_noite")
	if j == null or m == null:
		return "Nada para salvar."
	if j.morto:
		return "Não dá para salvar depois de morrer."
	var d := {
		"versao": VERSAO,
		"quando": Time.get_datetime_string_from_system(false, true),
		"jogador": j.dados_para_salvar(),
		"territorio": j.territorio.dados_para_salvar(),
		"relogio": {"dia": ciclo.dia, "minutos": ciclo.minutos} if ciclo != null else {},
		"mundo": m.dados_para_salvar(),
		"descobertas": Descobertas.dados_para_salvar(),
	}
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return "Não foi possível salvar (erro %d)." % FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return "Partida salva."


static func _ler() -> Dictionary:
	if not existe():
		return {}
	var texto := FileAccess.get_file_as_string(ARQUIVO)
	var dados: Variant = JSON.parse_string(texto)
	if not dados is Dictionary:
		return {}
	return dados


## Lê o save e recarrega a cena; a partida é aplicada quando ela estiver pronta. Devolve a mensagem de erro, ou "".
static func carregar(arvore: SceneTree) -> String:
	var d := _ler()
	if d.is_empty():
		return "Nenhuma partida salva."
	if int(d.get("versao", 0)) != VERSAO:
		return "A partida salva é de outra versão do jogo."
	pendente = d
	arvore.paused = false
	arvore.reload_current_scene()
	return ""


## Mundo._ready: posição do jogador e memória do mundo, antes da primeira carga de chunks.
static func aplicar_mundo(mundo: Node) -> void:
	if pendente.is_empty():
		return
	var pj: Dictionary = pendente.get("jogador", {})
	if pj.has("p") and mundo.jogador != null:
		mundo.jogador.position = IsoMath.mundo_para_tela(_vec(pj["p"]))
		var cam := mundo.get_viewport().get_camera_2d()
		if cam != null:
			cam.global_position = mundo.jogador.global_position
	mundo.restaurar(pendente.get("mundo", {}))


## Depois que a cena inteira está pronta: jogador, totem e relógio. Limpa o pendente.
static func aplicar_resto(arvore: SceneTree) -> void:
	if pendente.is_empty():
		return
	var j := arvore.get_first_node_in_group("jogador")
	if j != null:
		j.restaurar(pendente.get("jogador", {}))
		j.territorio.restaurar(pendente.get("territorio", {}))
	var ciclo := arvore.get_first_node_in_group("ciclo_dia_noite")
	var rel: Dictionary = pendente.get("relogio", {})
	if ciclo != null and not rel.is_empty():
		ciclo.dia = int(rel["dia"])
		ciclo.minutos = float(rel["minutos"])
	Descobertas.restaurar(pendente.get("descobertas", {}))
	if j != null and bool(j.passos.get("_ativo", false)):
		arvore.call_group("primeiros_passos", "iniciar", j)
	pendente = {}
	if j != null:
		j.aviso("Partida carregada.")


## Converte uma lista do JSON (números vêm como float) de volta para slots de mochila.
static func slots_de(lista: Array) -> Array:
	var out: Array = []
	for x in lista:
		if x == null:
			out.append(null)
			continue
		var s: Dictionary = (x as Dictionary).duplicate()
		for k in ["quantidade", "maximo", "tier"]:
			if s.has(k):
				s[k] = int(s[k])
		out.append(s)
	return out
