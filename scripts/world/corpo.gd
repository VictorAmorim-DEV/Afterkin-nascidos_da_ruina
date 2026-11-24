class_name Corpo
extends Node2D
## O que fica de quem morreu (marco 3): preso ao nó morto (inimigo, morador ou errante), que entra no grupo "corpo".
## - Não some enquanto estiver perto: só a mais de LONGE do jogador (fora da tela, mesmo com o zoom mais afastado)
##   conta SOME_S segundos reais; a contagem pausa quando o jogador volta e continua quando ele se afasta de novo.
## - Corpo de gente dá para arrastar (E) e esconder; quem vê alguém arrastando um corpo conta ("corpo").
## - Um morador acordado que passar perto acha o corpo. Com marcas de dentes (beberam o sangue), a comunidade
##   entra em alerta (Simulacao.alertar): dorme mais leve e fica mais difícil de pegar.

const LONGE := 70.0 * IsoMath.METRO
const SOME_S := 300.0
const ACHA := 9.0 * IsoMath.METRO                ## de quantos metros um morador acordado nota o corpo
const ARRASTE := 1.6 * IsoMath.METRO

var nome := ""
var pessoa := false                              ## dá para arrastar e ser achado (moradores e errantes)
var _longe_s := 0.0
var _t := 0.0
var _sumindo := false


## Prende um Corpo ao nó que acabou de morrer.
static func anexar(no: Node2D, nome_corpo: String, de_pessoa: bool) -> Corpo:
	no.add_to_group("corpo")
	no.set_meta("morte_h", Reputacao.agora_h())
	var c := Corpo.new()
	c.name = "Corpo"
	c.nome = nome_corpo
	c.pessoa = de_pessoa
	no.add_child(c)
	return c


func _ready() -> void:
	if pessoa:
		add_to_group("interativo")


func _dono() -> Node2D:
	return get_parent() as Node2D


func _process(delta: float) -> void:
	if _sumindo:
		return
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	var dono := _dono()
	if j == null or dono == null:
		return
	var d := IsoMath.tela_para_mundo(dono.global_position - j.global_position).length()
	if d > LONGE and j.get("carregando") != dono:
		_longe_s += delta
		if _longe_s >= SOME_S:
			_sumir()
			return
	_t -= delta
	if _t <= 0.0 and pessoa and not dono.has_meta("achado"):
		_t = 1.0
		_procurar_quem_acha(dono)


func _sumir() -> void:
	_sumindo = true
	remove_from_group("interativo")
	var dono := _dono()
	var t := dono.create_tween()
	t.tween_property(dono, "modulate:a", 0.0, 2.0)
	t.tween_callback(dono.queue_free)


## Um morador acordado (de comunidade, que não está viajando) perto e no mesmo lugar acha o corpo.
func _procurar_quem_acha(dono: Node2D) -> void:
	var p := IsoMath.tela_para_mundo(dono.global_position)
	for n in get_tree().get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc == dono or npc.morto or npc.dormindo or npc.fora or npc.comunidade == "" or npc.desacordado():
			continue
		var pn := IsoMath.tela_para_mundo(npc.global_position)
		if pn.distance_to(p) > ACHA or Reputacao._predio_em(get_tree(), pn) != Reputacao._predio_em(get_tree(), p):
			continue
		dono.set_meta("achado", true)
		var lugar := Respawn.nome_do_lugar(p)
		if dono.has_meta("mordido"):
			npc.falar("Meu Deus... tem marcas de dentes no pescoço!", 4.0)
			Simulacao.alertar(npc.comunidade, "Acharam o corpo de %s %s, com marcas de dentes no pescoço." % [nome, lugar])
		else:
			npc.falar("Tem um corpo aqui! É %s..." % nome, 4.0)
			Simulacao.registrar_noticia(npc.comunidade, "Acharam o corpo de %s %s." % [nome, lugar], 2)
		return


# ───────────────────────────── arrastar ─────────────────────────────

func prioridade_interacao() -> int:
	return 7


func _perto() -> bool:
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	return j != null and not bool(j.morto) and IsoMath.tela_para_mundo(_dono().global_position - j.global_position).length() < ARRASTE


func texto_interacao() -> String:
	if not pessoa or _sumindo or not _perto():
		return ""
	var j := get_tree().get_first_node_in_group("jogador")
	return "E — %s o corpo de %s" % ["soltar" if j.get("carregando") == _dono() else "arrastar", nome]


func _unhandled_input(event: InputEvent) -> void:
	if not pessoa or _sumindo or not event.is_action_pressed("interact") or not _perto():
		return
	var j := get_tree().get_first_node_in_group("jogador") as Node2D
	if j.dirigindo != null:
		return
	get_viewport().set_input_as_handled()
	Sangue.arrastar(j, _dono())
