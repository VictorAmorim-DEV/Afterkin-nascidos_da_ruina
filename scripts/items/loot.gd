class_name Loot
extends RefCounted
## Lógica comum de vasculhar (V13: EDIF_interagir / loot): sorteia, confere espaço e guarda.


## 'ao_concluir' roda quando o recipiente foi mesmo esvaziado (não roda com a mochila cheia).
static func vasculhar(jogador: Node, tipo: String, rng: RandomNumberGenerator, ao_concluir: Callable) -> void:
	var g := Itens.saque(tipo, rng)
	var nome: String = Itens.CONTEM.get(tipo, tipo)
	if not jogador.inventario.pode_adicionar(g):
		jogador.aviso("Inventário cheio! Libere espaço para coletar.")
		return
	jogador.inventario.adicionar_itens(g)
	var p := IsoMath.tela_para_mundo(jogador.global_position)
	if Comunidades.em(p) != "":
		Reputacao.registrar("furto", p)          # tudo ali é de alguém; só é furto se alguém vir
	jogador.get_tree().call_group("primeiros_passos", "evento", "vasculhou")
	ao_concluir.call()
	if randf() < 0.07:                          # um bilhete no meio das coisas (Rumores, canal "bilhete")
		var rid := Rumores.sortear_do_canal("bilhete")
		if rid != "":
			Rumores.conhecer(rid)
			jogador.aviso("Um bilhete no meio das coisas: %s (Rumor anotado: %s)" % [str(Rumores.dados(rid).get("texto", "")), Rumores.titulo(rid)])
			return
	if g.is_empty():
		jogador.aviso("Nada útil %s %s." % ["na" if nome.ends_with("a") else "no", nome])
	else:
		jogador.aviso("Você vasculhou %s: %s." % [nome, Itens.texto_lista(g)])
