class_name PortaoNo
extends StaticBody2D
## Portão no vão de uma cerca (V13: gate, toggleGate, nearGate, drawGate — l.289, 991-994, 1571).
## Duas folhas que recolhem para os mourões ao abrir; fechado, bloqueia a passagem (inclusive inimigos e carros).
## "ferro" = portão do acampamento (V13); "madeira" = quintais, roças e casa isolada.
## Origem do nó = meio do vão; 'a' e 'b' são os mourões, em coordenadas de MUNDO.

const ALCANCE_EXTRA := 70.0          ## V13: d < w/2 + 70
const PASSAGEM := 20.0               ## meia largura do vão que precisa estar livre para fechar

var a := Vector2.ZERO
var b := Vector2.ZERO
var estilo: String = "madeira"
var aberto: bool = false
var comunidade: String = ""          ## portão de comunidade: abre e fecha pelo horário (GerenteComunidades)

var _t := 0.0                        ## 0 fechado → 1 aberto (animação)
var _la := Vector2.ZERO
var _lb := Vector2.ZERO
var _col := CollisionPolygon2D.new()


func _ready() -> void:
	add_to_group("interativo")
	add_to_group("portao")
	light_mask = 2
	var meio := (a + b) * 0.5
	position = IsoMath.mundo_para_tela(meio)
	_la = IsoMath.mundo_para_tela(a) - position
	_lb = IsoMath.mundo_para_tela(b) - position
	var n := (b - a).normalized().orthogonal() * 6.0
	_col.polygon = PackedVector2Array([
		IsoMath.mundo_para_tela(a - n - meio), IsoMath.mundo_para_tela(b - n - meio),
		IsoMath.mundo_para_tela(b + n - meio), IsoMath.mundo_para_tela(a + n - meio)])
	_col.disabled = aberto
	add_child(_col)
	_t = 1.0 if aberto else 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var alvo := 1.0 if aberto else 0.0
	_t += (alvo - _t) * minf(1.0, delta * 5.0)
	if absf(alvo - _t) < 0.01:
		_t = alvo
		set_process(false)
	queue_redraw()


# ───────────────────────────── interação ─────────────────────────────

func _mundo_rel(no: Node2D) -> Vector2:
	return IsoMath.tela_para_mundo(no.global_position - global_position)


func distancia_ao_jogador() -> float:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	return INF if j == null else _mundo_rel(j).length()


func _e_o_alvo() -> bool:
	var d := distancia_ao_jogador()
	if d > a.distance_to(b) * 0.5 + ALCANCE_EXTRA:
		return false
	for o in get_tree().get_nodes_in_group("portao"):
		if o != self and o.distancia_ao_jogador() < d:
			return false
	return true


func prioridade_interacao() -> int:
	return 6


func texto_interacao() -> String:
	if not _e_o_alvo():
		return ""
	if comunidade != "":
		if aberto:
			return ""
		var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
		var de_dia: bool = ciclo != null and Comunidades.portao_aberto(comunidade, float(ciclo.minutos))
		if de_dia:
			return "Portão de %s: fechado para você (fale com o guarda)" % Comunidades.nome(comunidade)
		return "E — chamar o guarda (%s, fechado até de manhã)" % Comunidades.nome(comunidade)
	return "E — %s portão" % ("fechar" if aberto else "abrir")


## Alguém (jogador ou inimigo) parado no vão?
func _vao_ocupado() -> bool:
	var dir := (b - a).normalized()
	var meia := a.distance_to(b) * 0.5 + 12.0
	var corpos: Array = get_tree().get_nodes_in_group("jogador") + get_tree().get_nodes_in_group("inimigo")
	corpos.append_array(get_tree().get_nodes_in_group("npc"))
	for c in corpos:
		var p := _mundo_rel(c as Node2D)
		if absf(p.dot(dir)) < meia and absf(p.dot(dir.orthogonal())) < PASSAGEM:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	if get_tree().get_nodes_in_group("item_chao").any(func(i): return i.texto_interacao() != ""):
		return
	var j := get_tree().get_first_node_in_group("jogador")
	if j == null or j.dirigindo != null:
		return
	if comunidade != "":
		var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
		if aberto or (ciclo != null and Comunidades.portao_aberto(comunidade, float(ciclo.minutos))):
			return                               # de dia, quem decide é o guarda (conversa)
		get_viewport().set_input_as_handled()
		j.aviso(VidaComunidade.pedir_para_entrar(comunidade))   # de noite: com reputação alta, o guarda abre
		return
	get_viewport().set_input_as_handled()
	if aberto and _vao_ocupado():
		j.aviso("Saia da passagem antes de fechar o portão.")
		return
	alternar()
	j.aviso("Portão aberto. Cuidado: o que está lá fora também pode entrar." if aberto else "Portão fechado e trancado.")


## Portão de comunidade: abre ou fecha pelo horário (não vai para a memória do Mundo; o horário decide de novo).
func definir_aberto(v: bool) -> void:
	if v == aberto:
		return
	if not v and _vao_ocupado():
		return                                   # alguém na passagem: fecha na próxima checagem
	aberto = v
	_col.set_deferred("disabled", aberto)
	set_process(true)


func alternar() -> void:
	aberto = not aberto
	_col.set_deferred("disabled", aberto)
	set_process(true)
	var m := get_tree().get_first_node_in_group("mundo")
	if m != null and m.has_method("lembrar_portao"):
		m.lembrar_portao((a + b) * 0.5, aberto)


# ───────────────────────────── desenho (V13: drawGate) ─────────────────────────────

func _draw() -> void:
	var ferro := estilo == "ferro"
	var h := 60.0 if ferro else 56.0
	var w := a.distance_to(b)
	draw_line(_la + Vector2(0, 2), _lb + Vector2(0, 2), Color(0, 0, 0, 0.3), 5.0)      # sombra no chão
	var dir := (_lb - _la) / w                 # tela por u de mundo, ao longo do vão
	var meia := w * 0.5 * (1.0 - 0.82 * _t)    # as folhas recolhem para os mourões
	_folha(_la + dir * 8.0, _la + dir * (8.0 + meia), h, ferro)
	_folha(_lb - dir * 8.0, _lb - dir * (8.0 + meia), h, ferro)
	for p in [_la, _lb]:
		var pp: Vector2 = p
		draw_rect(Rect2(pp.x - 6.0, pp.y - h - 18.0, 12.0, h + 18.0), Color8(74, 77, 79))
		draw_rect(Rect2(pp.x - 6.0, pp.y - h - 18.0, 4.0, h + 18.0), Color8(107, 110, 112))
		draw_rect(Rect2(pp.x - 8.0, pp.y - h - 21.0, 16.0, 5.0), Color8(46, 48, 50))
		draw_rect(Rect2(pp.x - 3.0, pp.y - h - 11.0, 6.0, 17.0), Color8(138, 31, 31))


func _folha(p0: Vector2, p1: Vector2, h: float, ferro: bool) -> void:
	if p0.distance_to(p1) < 1.0:
		return
	var up := Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([p0, p1, p1 + up, p0 + up]), Color8(29, 33, 38) if ferro else Color8(95, 70, 48))
	if ferro:
		var i4 := Vector2(0, -4)
		draw_colored_polygon(PackedVector2Array([p0 + i4, p1 + i4, p1 + up - i4, p0 + up - i4]), Color8(74, 47, 34))
		draw_line(p0 + up * 0.42, p1 + up * 0.42, Color8(122, 74, 44), 3.0)
	var n: int = maxi(1, roundi(p0.distance_to(p1) / 8.0))
	for i in range(1, n):
		var q := p0.lerp(p1, float(i) / n)
		draw_line(q + Vector2(0, -4), q + up + Vector2(0, 4), Color(0, 0, 0, 0.3), 1.4)
