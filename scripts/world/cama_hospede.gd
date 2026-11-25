class_name CamaHospede
extends CamaNo
## Cama de hóspede de uma comunidade (etapa 12, VidaComunidade): só para quem tem reputação alta. Deitar e
## descansar ou dormir, como na cama do jogador, mas não dá para recolher e não é ponto de renascimento (Q51).

var comunidade: String = ""


func _ready() -> void:
	super._ready()
	remove_from_group("cama")                  # não entra na lista de camas do jogador
	add_to_group("cama_hospede")


func _e_o_alvo() -> bool:
	return _dist() <= ALCANCE


func texto_interacao() -> String:
	var j := _jogador()
	if j == null or j.descansando != null or not _e_o_alvo():
		return ""
	if Reputacao.valor(comunidade) < VidaComunidade.REP_DORMIR:
		return "Cama de hóspede %s: só para quem a gente conhece" % Comunidades.de(comunidade)
	return "E — cama de hóspede (descansar, dormir)"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _e_o_alvo():
		return
	var j := _jogador()
	if j == null or j.dirigindo != null or j.morto or j.descansando != null or j.dormindo:
		return
	get_viewport().set_input_as_handled()
	if Vigilancia.em_quarentena(comunidade):
		j.aviso("“Quarentena. Essa cama não é pra você agora.”")
		return
	if Reputacao.valor(comunidade) < VidaComunidade.REP_DORMIR:
		j.aviso("“Essa cama é pra quem a gente conhece.” (reputação %d de %d)" % [Reputacao.valor(comunidade), VidaComunidade.REP_DORMIR])
		return
	var menu := MenuCama.new()
	menu.cama = self
	menu.hospede = true
	get_tree().current_scene.add_child(menu)
