class_name Agua
extends Node
## Água para beber e encher garrafas (docs/DECISOES_DESIGN.md Q29). Fica como filho do jogador, no grupo
## "interativo": à beira de um rio ou lago (MapaMundi) ou sobre uma poça da rua (Quadras), E bebe direto da fonte
## e enche as garrafas vazias da mochila com água suja.
## Água parada (poça) é perto e muito contaminada; rio e lago são mais limpos, mas ficam longe e expostos.
## Água do mar não serve. Água suja de garrafa ainda arrisca disenteria: ferva numa fogueira.

const CHANCE_POCA := 0.5             ## chance de disenteria bebendo direto de uma poça
const CHANCE_RIO := 0.15             ## ... de um rio ou lago
const CHANCE_GARRAFA_SUJA := 0.35    ## ... bebendo uma garrafa de água suja
const GOLE := 50.0                   ## quanto de sede um gole direto da fonte mata
const RAIO_POCA := 1.1 * IsoMath.METRO

var _fonte := ""                     ## "", "poca", "rio" ou "mar"
var _t := 0.0


func _ready() -> void:
	add_to_group("interativo")


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_fonte = _procurar()


func _jogador() -> Node2D:
	return get_parent() as Node2D


## Que água o jogador tem ao alcance agora: o ponto onde está e 1 m à frente.
func _procurar() -> String:
	var j := _jogador()
	if j == null or j.dirigindo != null or j.morto:
		return ""
	var w := IsoMath.tela_para_mundo(j.global_position)
	var frente := w + Vector2.from_angle(j.face) * IsoMath.METRO
	for p: Vector2 in [w, frente]:
		if MapaMundi.agua(p.x, p.y) > 0:
			return "mar" if MapaMundi.eh_mar(p.x, p.y) else "rio"
	var r := Vector2(RAIO_POCA, RAIO_POCA)
	for d in Quadras.detalhes_no(Rect2(w - r, r * 2.0)):
		var dd: Dictionary = d
		if dd["t"] == "poca" and (dd["p"] as Vector2).distance_to(w) < RAIO_POCA:
			return "poca"
	return ""


## Água doce mais próxima do ponto 'w' (mundo), até 'max_m' metros: {"tipo": "poca"/"rio", "m": distância,
## "rumo": "N", "NE"...} ou {} se não houver. Varre em anéis de 10 m; serve ao bilhete do começo da partida.
static func mais_perto(w: Vector2, max_m: float = 1500.0) -> Dictionary:
	var M := IsoMath.METRO
	var melhor := {}
	var r := Vector2(max_m, max_m) * M
	for d in Quadras.detalhes_no(Rect2(w - r, r * 2.0)):
		var dd: Dictionary = d
		var dist: float = (dd["p"] as Vector2).distance_to(w)
		if dd["t"] == "poca" and (melhor.is_empty() or dist < float(melhor["m"]) * M):
			melhor = {"tipo": "poca", "m": dist / M, "dir": (dd["p"] as Vector2) - w}
	var limite: float = float(melhor["m"]) if not melhor.is_empty() else max_m
	var raio := 10.0
	while raio < limite:
		for k in 72:
			var dir := Vector2.from_angle(TAU * k / 72.0)
			var p := w + dir * raio * M
			if MapaMundi.agua(p.x, p.y) > 0 and not MapaMundi.eh_mar(p.x, p.y):
				melhor = {"tipo": "rio", "m": raio, "dir": dir}
				limite = 0.0
				break
		raio += 10.0
	if melhor.is_empty():
		return {}
	var v: Vector2 = melhor["dir"]
	var graus := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)    # 0 = norte (−y do mundo), 90 = leste (+x)
	melhor["rumo"] = ["norte", "nordeste", "leste", "sudeste", "sul", "sudoeste", "oeste", "noroeste"][roundi(graus / 45.0) % 8]
	return melhor


func prioridade_interacao() -> int:
	return 1                          # abaixo de tudo: só vale quando não há outra coisa para pegar ou usar


func texto_interacao() -> String:
	match _fonte:
		"mar":
			return "Água salgada: não serve para beber"
		"poca":
			return "E — beber da poça" + _texto_garrafas()
		"rio":
			return "E — beber água" + _texto_garrafas()
	return ""


func _texto_garrafas() -> String:
	var n: int = _jogador().inventario.contar("garrafa")
	return " e encher %d garrafa(s)" % n if n > 0 else ""


## Outro interativo com algo a dizer e mais prioritário tem a vez (pegar item, vasculhar...).
func _outro_tem_a_vez() -> bool:
	for no in get_tree().get_nodes_in_group("interativo"):
		if no != self and no.has_method("texto_interacao") and no.texto_interacao() != "":
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _fonte == "" or _fonte == "mar":
		return
	if _outro_tem_a_vez():
		return
	get_viewport().set_input_as_handled()
	var j := _jogador()
	# primeiro enche as garrafas (troca garrafa vazia por água suja, no que couber)
	var cheias := 0
	var n: int = j.inventario.contar("garrafa")
	if n > 0:
		j.inventario.remover("garrafa", n)
		var sobra: int = j.inventario.adicionar_parcial("agua_suja", n)
		if sobra > 0:
			j.inventario.adicionar_parcial("garrafa", sobra)
		cheias = n - sobra
	var extra := " Encheu %d garrafa(s) de água suja." % cheias if cheias > 0 else ""
	var poca := _fonte == "poca"
	if not j.beber(GOLE, CHANCE_POCA if poca else CHANCE_RIO, "água da poça" if poca else "água do rio", extra) \
			and cheias > 0:
		j.aviso(extra.strip_edges())
