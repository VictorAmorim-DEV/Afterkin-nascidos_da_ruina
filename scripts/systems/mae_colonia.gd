class_name MaeColonia
extends RefCounted
## Mãe da Colônia (marco 3): mini boss de cada ninho de morcegos, um vampiro antigo e inchado. Forte, morde mais vezes
## e chama revoadas de morcegos. Morta, dá um "sangue antigo" para cada jogador perto (o Dr. Heitor prepara o antídoto
## com ele) e renasce depois de 1 h real com a sala aberta (DiarioPartida.real_s só corre com o jogo rodando).
## Não é preciso destruir o ninho para isso.

const RENASCE_S := 3600.0
const VIDA := 260.0
const RECARGA_MORDIDA := 12.0
const RECARGA_REVOADA := 25.0
const REVOADA_ALCANCE := 8.0 * IsoMath.METRO
const DROP_ALCANCE := 25.0 * IsoMath.METRO       ## quem estiver até aqui quando ela morre ganha o sangue antigo

static var mortes: Dictionary = {}                ## "x,y" do ninho -> DiarioPartida.real_s da morte


static func zerar() -> void:
	mortes = {}


static func chave(p_ninho: Vector2) -> String:
	return "%d,%d" % [roundi(p_ninho.x), roundi(p_ninho.y)]


## Ela está no ninho agora? (nunca morreu, ou já passou 1 h real desde a morte)
static func presente(p_ninho: Vector2) -> bool:
	var k := chave(p_ninho)
	return not mortes.has(k) or DiarioPartida.real_s - float(mortes[k]) >= RENASCE_S


static func morreu(p_ninho: Vector2) -> void:
	mortes[chave(p_ninho)] = DiarioPartida.real_s


## Um sangue antigo para cada jogador perto (regra do co-op: com 3 perto, 3 drops).
static func dar_sangue(arv: SceneTree, onde_tela: Vector2) -> void:
	for n in arv.get_nodes_in_group("jogador"):
		var j := n as Node2D
		if j == null or bool(j.morto):
			continue
		if IsoMath.tela_para_mundo(j.global_position - onde_tela).length() > DROP_ALCANCE:
			continue
		if j.inventario.adicionar_itens([["sangue_antigo", 1]]):
			j.aviso("A Mãe da Colônia caiu. Você recolhe o sangue antigo dela: o Dr. Heitor sabe o que fazer com isso.")
		else:
			ItemNoChao.largar(j.get_parent(), onde_tela + Vector2(0, 4), "sangue_antigo", 1)
			j.aviso("A Mãe da Colônia caiu. O sangue antigo ficou no chão (mochila cheia).")
		DiarioPartida.evento("abate", "Matou a Mãe da Colônia e recolheu o sangue antigo.")


static func dados_para_salvar() -> Dictionary:
	return {"mortes": mortes.duplicate()}


static func restaurar(d: Dictionary) -> void:
	mortes = (d.get("mortes", {}) as Dictionary).duplicate()
