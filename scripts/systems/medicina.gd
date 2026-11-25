class_name Medicina
extends RefCounted
## Especialização Medicina (marco 2, etapa 11; docs/DECISOES_DESIGN.md Q19, Q38, Q44, Q48 e Q52).
##
## O mestre é o NPC com papel "mestre_medicina" (na 2a, o Dr. Heitor da Vila dos Pescadores). Ele ensina em 4 passos,
## e cada passo cumprido dá uma habilidade, sempre nesta ordem: Diagnóstico → Tratar ferimentos → Preparar remédios →
## Cirurgia de campo. O Enfermeiro(a) já sabe diagnosticar e começa no segundo passo.
## A tarefa de cada passo nasce da necessidade do momento (Q48): um ferido sem tratamento numa comunidade vizinha,
## os remédios da vila no fim, a comida acabando... e, sem aperto, coisas que todo médico quer (um manual, água limpa,
## pano para ataduras). Cada tipo de tarefa aparece uma vez só na cadeia.
## Reputação mínima para começar cada lição (Q52: com reputação baixa o mestre não ensina). Se o mestre morre, a
## cadeia para (Q44): não há mais quem ensine.
## Depois da cadeia completa, as comunidades sem médico com alguém ferido mandam pedir ajuda ao jogador (vai para o
## diário da Simulacao, e daí para as novidades, o mural e as conversas). Tratar quem pediu rende reputação extra.

const HABILIDADES: Array[String] = ["diagnostico", "tratar_ferimentos", "preparar_remedios", "cirurgia"]
const NOMES := {"diagnostico": "Diagnóstico", "tratar_ferimentos": "Tratar ferimentos",
	"preparar_remedios": "Preparar remédios", "cirurgia": "Cirurgia de campo"}
const DESCRICOES := {
	"diagnostico": "Você vê o estágio e o prazo das doenças, e a gravidade de quem está ferido.",
	"tratar_ferimentos": "Bandagens recuperam 35 de vida (eram 15) e você pode tratar feridos com bandagem ou antibiótico.",
	"preparar_remedios": "Fabrica bandagem (pano + água limpa), soro caseiro e kit cirúrgico.",
	"cirurgia": "Com um kit cirúrgico, tira alguém da beira da morte: você mesmo ou um ferido grave.",
}
const REP_MIN: Array[int] = [15, 20, 30, 40]   ## reputação na comunidade do mestre para começar cada passo
const REP_POR_PASSO := 5
const REP_PEDIDO := 10                          ## tratar quem mandou pedir ajuda
const AULA_H := 2.0                             ## horas de jogo de cada lição
const BANDAGEM_MEDICO := 35.0

static var habilidades: Array = []              ## habilidades aprendidas (o diagnóstico do Enfermeiro(a) vem da origem)
static var tarefa: Dictionary = {}              ## {tipo, item, qtd, com, npc, nome, feito}
static var feitas: Array = []                   ## tipos de tarefa já cumpridos
static var pedidos: Dictionary = {}             ## "com/npc" -> true: pedido de ajuda anunciado e ainda não atendido
static var _proposta: Dictionary = {}           ## tarefa oferecida na conversa, antes de o jogador aceitar
static var _aula: String = ""                   ## habilidade da lição que acabou de ser dada (para a fala)


static func zerar() -> void:
	habilidades = []
	tarefa = {}
	feitas = []
	pedidos = {}
	_proposta = {}
	_aula = ""


static func _jogador() -> Node:
	var arv := Engine.get_main_loop() as SceneTree
	return arv.get_first_node_in_group("jogador") if arv != null else null


static func tem(hab: String) -> bool:
	if habilidades.has(hab):
		return true
	var j := _jogador()
	return hab == "diagnostico" and j != null and str(j.origem) == "enfermeiro"


## Quantas habilidades já tem = o passo em que está (0 a 4).
static func passo() -> int:
	for i in HABILIDADES.size():
		if not tem(HABILIDADES[i]):
			return i
	return HABILIDADES.size()


static func completa() -> bool:
	return passo() >= HABILIDADES.size()


## {com, npc, nome} do mestre de Medicina vivo; {} se não há (ou morreu).
static func mestre() -> Dictionary:
	for id in Comunidades.ids():
		for n in Comunidades.dados(str(id)).get("npcs", []):
			var nd: Dictionary = n
			if str(nd.get("papel", "")) == "mestre_medicina" and Reputacao.vivo(str(id), str(nd["id"])):
				return {"com": str(id), "npc": str(nd["id"]), "nome": str(nd["nome"])}
	for id in Comunidades.ids():                   # o aprendiz que assumiu e já sabe bastante também ensina
		var m: Dictionary = Simulacao.estado(str(id)).get("medico", {})
		if not m.is_empty() and str(m.get("npc", "")) != "" and float(m["nivel"]) >= 0.85 and Reputacao.vivo(str(id), str(m["npc"])):
			return {"com": str(id), "npc": str(m["npc"]), "nome": Consequencias.nome_npc(str(id), str(m["npc"]))}
	return {}


# ───────────────────────────── tarefas ─────────────────────────────

## Escolhe a tarefa do próximo passo pela necessidade do momento. {} se nada serve (não deve acontecer).
static func gerar_tarefa(com_mestre: String) -> Dictionary:
	var c := Simulacao.estado(com_mestre)
	var opcoes: Array = []                      # [prioridade, tarefa]
	var fr := _ferido_para_tarefa(com_mestre)
	if not fr.is_empty():
		opcoes.append([10.0 + float(fr["grav"]), fr])
	var remedio := int(c.get("remedio", 3))
	opcoes.append([6.0 if remedio < 3 else 1.5, {"tipo": "remedio", "item": "antibiotico", "qtd": 2 if remedio < 3 else 1}])
	if float(c.get("comida", 6.0)) < 2.5:
		opcoes.append([5.0, {"tipo": "comida", "item": "comida", "qtd": 6}])
	opcoes.append([3.0, {"tipo": "livro", "item": "manual_medico", "qtd": 1}])
	opcoes.append([2.0, {"tipo": "agua", "item": "agua_limpa", "qtd": 3}])
	opcoes.append([1.0, {"tipo": "pano", "item": "pano", "qtd": 4}])
	var melhor: Dictionary = {}
	var pmax := -1.0
	for o in opcoes:
		var t: Dictionary = o[1]
		if feitas.has(str(t["tipo"])):
			continue
		var p: float = float(o[0]) + randf() * 0.5
		if p > pmax:
			pmax = p
			melhor = t
	if melhor.is_empty():
		melhor = {"tipo": "agua", "item": "agua_limpa", "qtd": 3}
	melhor = melhor.duplicate()
	melhor["feito"] = false
	return melhor


## O ferido sem tratamento mais grave das outras comunidades (na do mestre, ele mesmo cuida), com nome.
static func _ferido_para_tarefa(com_mestre: String) -> Dictionary:
	var melhor: Dictionary = {}
	for id in Simulacao.com:
		if str(id) == com_mestre:
			continue
		for f in (Simulacao.com[id]["feridos"] as Array):
			var fd: Dictionary = f
			if str(fd["quem"]) == "" or bool(fd["tratado"]) or str(fd["hosp"]) != "":
				continue
			if melhor.is_empty() or float(fd["grav"]) > float(melhor["grav"]):
				melhor = {"tipo": "ferido", "com": str(id), "npc": str(fd["quem"]), "nome": str(fd["nome"]), "grav": float(fd["grav"])}
	return melhor


## "pronta" (dá para entregar), "falta" ou "perdida" (o ferido morreu, sarou sozinho ou foi levado ao médico).
static func situacao(j: Node) -> String:
	if tarefa.is_empty():
		return ""
	if str(tarefa["tipo"]) == "ferido":
		if bool(tarefa["feito"]):
			return "pronta"
		var fd := Simulacao.ferido(str(tarefa["com"]), str(tarefa["npc"]))
		return "perdida" if fd.is_empty() or str(fd["hosp"]) != "" or bool(fd["tratado"]) else "falta"
	return "pronta" if j != null and j.inventario.contar(str(tarefa["item"])) >= int(tarefa["qtd"]) else "falta"


## Texto curto da tarefa (HUD): "trate Guga (Santuário do Sol)", "traga 2 antibióticos".
static func texto_tarefa(t: Dictionary = tarefa) -> String:
	if t.is_empty():
		return ""
	if str(t["tipo"]) == "ferido":
		return "trate %s (%s)" % [t["nome"], Comunidades.nome(str(t["com"]))]
	return "traga %d %s ao mestre" % [int(t["qtd"]), Itens.nome(str(t["item"])).to_lower()]


## Linha do HUD: "MEDICINA 2/4: traga 3 água limpa ao mestre"; "" sem cadeia em andamento.
static func linha_hud() -> String:
	if tarefa.is_empty():
		return ""
	var j := _jogador()
	var st := situacao(j)
	var fim := " · volte ao mestre" if st == "pronta" else (" · fale com o mestre" if st == "perdida" else "")
	return "MEDICINA %d/4: %s%s" % [passo() + 1, texto_tarefa(), fim]


## Fala do mestre pedindo a tarefa.
static func _pedido(t: Dictionary) -> String:
	match str(t["tipo"]):
		"ferido":
			var fem := _feminino(str(t["com"]), str(t["npc"]))
			return "%s, %s, está %s e ninguém lá sabe cuidar. Eu não consigo ir. Vá você: leve antibiótico, limpe, " \
				% [t["nome"], Comunidades.de(str(t["com"])), "ferida" if fem else "ferido"] \
				+ "feche e dê o remédio. Eu explico como. Quando %s estiver %s, volte aqui." % ["ela" if fem else "ele", "tratada" if fem else "tratado"]
		"remedio":
			return "Os remédios da vila estão no fim. Traga %d antibiótico%s; o hospital de Porto Atlântico deve ter. " \
				% [int(t["qtd"]), "s" if int(t["qtd"]) > 1 else ""] + "Não é para mim: é para quem chegar ferido amanhã."
		"comida":
			return "Doente com fome não sara. A comida da vila está acabando: traga %d comidas para quem está de cama." % int(t["qtd"])
		"livro":
			return "Perdi meus livros na queda, e a memória já não é a mesma. Um manual de pronto-socorro: hospital, " \
				+ "farmácia, consultório, gaveta de escritório. Traga um e a gente estuda junto."
		"agua":
			return "Metade da medicina é água limpa. Ferva e traga %d garrafas de água limpa para a enfermaria." % int(t["qtd"])
		"pano":
			return "Pano limpo vira atadura, compressa, tipoia. Traga %d panos: lençol, cortina, o que achar." % int(t["qtd"])
	return "Traga o que eu pedi."


## Fala do mestre durante a lição de cada habilidade.
const FALAS_AULA := {
	"diagnostico": "Sente aí. Febre, pulso, a cor da pele, o cheiro de uma ferida... (Ele te ensina a examinar, e as horas passam.) Agora você sabe o que tem, e quanto tempo tem.",
	"tratar_ferimentos": "Corte se lava, se fecha e se vigia. (Duas horas de prática, com a Dona Marlene fazendo de paciente.) Suas bandagens agora valem o dobro, e você pode cuidar de quem estiver ferido.",
	"preparar_remedios": "Remédio de farmácia acaba. (Ele mostra como ferver pano, fazer soro com sal e açúcar e montar um kit.) Agora você faz os seus.",
	"cirurgia": "Isto aqui eu não consigo mais fazer. Você vai. (Ele guia suas mãos até tarde.) Com um kit cirúrgico, você tira alguém da beira da morte. Inclusive você.",
}


static func _feminino(com: String, npc: String) -> bool:
	for n in Comunidades.dados(com).get("npcs", []):
		if str((n as Dictionary)["id"]) == npc:
			return str((n as Dictionary).get("genero", "m")) == "f"
	return false


# ───────────────────────────── conversa com o mestre ─────────────────────────────

## Opções extras da conversa (DialogoUI): com o mestre, as da cadeia; com um ferido, a de tratar. Põe os nós que
## elas usam em 'arvore["nos"]' (ids começando com "_med") e devolve as opções para acrescentar à lista.
static func opcoes(arvore: Dictionary, ctx: Dictionary, lista: Array, abertura: bool) -> Array:
	var out: Array = []
	var nos: Dictionary = arvore["nos"]
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var j: Node = ctx["jogador"]
	var m := mestre()
	if abertura and not m.is_empty() and str(m["com"]) == com and str(m["npc"]) == npc and not completa():
		out.append_array(_opcoes_mestre(nos, ctx, j))
	if abertura and not m.is_empty() and str(m["com"]) == com and str(m["npc"]) == npc:
		out.append_array(_opcoes_infeccao(nos, ctx, j))
	var tr := _opcao_tratar(nos, ctx, j, lista)
	if not tr.is_empty():
		out.append(tr)
	return out


static func _opcoes_mestre(nos: Dictionary, ctx: Dictionary, j: Node) -> Array:
	var com := str(ctx["com"])
	var p := passo()
	var rep := Reputacao.valor(com)
	var aceitar := {"texto": "Combinado.", "vai": "fim", "efeitos": [{"med": "aceitar"}]}
	if tarefa.is_empty():
		var pergunta := "O senhor ensinaria Medicina?" if p == 0 or (p == 1 and str(j.origem) == "enfermeiro" and habilidades.is_empty()) \
			else "Estou pronto para a próxima lição."
		if rep < REP_MIN[mini(habilidades.size(), REP_MIN.size() - 1)]:     # o Enfermeiro(a) tem uma lição a menos
			nos["_med_nao"] = {"fala": "Ensinar leva tempo, e tempo eu só gasto com quem eu conheço. Ajude a vila primeiro; depois a gente conversa." \
				if p == 0 else "Ainda não. Andam falando coisas de você por aqui. Resolva isso primeiro."}
			return [{"texto": pergunta, "vai": "_med_nao"}]
		_proposta = gerar_tarefa(com)
		var abre := ""
		if p == 0:
			abre = "Ensino. Mas não é coisa de uma tarde, e eu não ensino de graça: ensino quem ajuda. "
		elif p == 1 and habilidades.is_empty():
			abre = "Você já sabe examinar; isso a escola te deu. O resto eu ensino. Mas primeiro me ajude: "
		else:
			abre = "Bom. Antes da próxima lição, uma coisa que a gente precisa agora. "
		nos["_med_proposta"] = {"fala": abre + _pedido(_proposta),
			"opcoes": [aceitar, {"texto": "Agora não dá.", "vai": "fim"}]}
		return [{"texto": pergunta, "vai": "_med_proposta"}]
	match situacao(j):
		"pronta":
			var hab: String = HABILIDADES[p]
			var texto := "%s está %s." % [str(tarefa["nome"]), "tratada" if _feminino(str(tarefa["com"]), str(tarefa["npc"])) else "tratado"] \
				if str(tarefa["tipo"]) == "ferido" else "Trouxe o que o senhor pediu."
			if rep < 0:
				nos["_med_rep"] = {"fala": "Obrigado. Mas depois do que andam dizendo de você, eu não vou ensinar nada agora."}
				return [{"texto": texto, "vai": "_med_rep"}]
			var depois := "\n\nNão tenho mais o que te ensinar. Quem precisar de médico agora vai te procurar." if p == HABILIDADES.size() - 1 else ""
			nos["_med_aula"] = {"fala": str(FALAS_AULA[hab]) + depois, "efeitos": [{"med": "entregar"}], "sem_sair": true,
				"opcoes": [{"texto": "Obrigado, doutor.", "vai": "fim", "efeitos": [{"med": "aula"}]}]}
			return [{"texto": texto, "vai": "_med_aula"}]
		"perdida":
			var t_velha := tarefa
			tarefa = {}
			_proposta = gerar_tarefa(com)
			var motivo := "Soube de %s. Não é culpa sua: às vezes chega tarde. " % t_velha["nome"]
			nos["_med_perdida"] = {"fala": motivo + "Mas a gente segue. " + _pedido(_proposta),
				"opcoes": [aceitar, {"texto": "Agora não dá.", "vai": "fim"}]}
			return [{"texto": "Sobre o que o senhor me pediu...", "vai": "_med_perdida"}]
	nos["_med_lembrar"] = {"fala": _pedido(tarefa)}
	return [{"texto": "O que era mesmo que o senhor precisava?", "vai": "_med_lembrar"}]


# ───────────────────────────── a mordida (marco 3, cura em camadas) ─────────────────────────────

const PRECO_SORO := 30.0                       ## o soro de contenção sai caro (valor no escambo do médico)
const TRATAR_SEDE_H := 3.0
const PREPARAR_H := 2.0
static var _preco_soro: Array = []

const HISTORIA := "Os da noite. (Ele fecha a porta antes de continuar.) Eu já fui atrás de cura, sabe? Uma expedição, " \
	+ "eu e mais quatro, num ninho de morcegos depois da curva do lago. Lá dorme uma coisa que a gente chamou de Mãe " \
	+ "da Colônia: velha, inchada, cercada de morcego. O sangue dela é o que segura a mordida; com ele eu preparo o " \
	+ "antídoto. Voltamos dois. Eu não vou de novo.\n\nSe um dia você for, vá de dia, com luz, arma e bandagem. " \
	+ "E não vá sozinho se puder evitar. Ah, e não são só eles, não: andam dizendo que no sul tem gente que vira fera, " \
	+ "e que há mortos que levantam. O mundo ficou grande demais pra gente."


## O médico mestre e a mordida: a história do ninho, o exame, o antídoto com sangue antigo, o tratamento da Sede
## e o soro de contenção (caro).
static func _opcoes_infeccao(nos: Dictionary, ctx: Dictionary, j: Node) -> Array:
	var out: Array = []
	if j == null or Reputacao.valor(str(ctx["com"])) < 0:
		return out
	var infectado := Infeccao.ativa(j)
	var contou := bool(Conversas.flags.get("heitor_conta_ninho", false))
	if not contou:
		var fala := HISTORIA
		if infectado:
			fala = "Mostra. (Ele examina o pescoço em silêncio.) %s\n\n%s" % [Infeccao.diagnostico(j), HISTORIA]
		nos["_inf_historia"] = {"fala": fala, "efeitos": [{"med": "historia"}]}
		out.append({"texto": "Doutor... fui mordido por um deles." if infectado else "O que o senhor sabe dos da noite?",
			"vai": "_inf_historia"})
	elif infectado:
		nos["_inf_exame"] = {"fala": "...", "_dinamico": true}
		out.append({"texto": "Pode examinar a mordida?", "vai": "_inf_exame", "efeitos": [{"med": "exame"}]})
	if not infectado and Vigilancia.em_quarentena(str(ctx["com"])):
		nos["_inf_limpo"] = {"fala": "(Ele examina o pescoço e os olhos com calma.) Limpo. Pode andar por aí: eu aviso o pessoal.",
			"efeitos": [{"med": "liberar"}]}
		out.append({"texto": "Doutor, pode ver se eu estou limpo?", "vai": "_inf_limpo"})
	if j.inventario.contar("sangue_antigo") > 0:
		nos["_inf_antidoto"] = {"fala": "Sangue antigo... ainda morno, depois de tudo. (Ele trabalha em silêncio por umas duas horas.) " \
			+ "Pronto: uma dose. Na marca ou na fome, ela resolve sozinha. Depois disso, me procure.",
			"efeitos": [{"med": "preparar"}]}
		out.append({"texto": "Trouxe o sangue antigo da Mãe da Colônia.", "vai": "_inf_antidoto"})
	if infectado and Infeccao.estagio(j) == 2 and j.inventario.contar("antidoto") > 0:
		nos["_inf_trat"] = {"fala": "...", "_dinamico": true}
		out.append({"texto": "Doutor, preciso do tratamento. Tenho o antídoto.", "vai": "_inf_trat",
			"efeitos": [{"med": "tratar_sede"}]})
	if contou:
		_preco_soro = Consequencias._reparacao_valor(j, PRECO_SORO)
		if not _preco_soro.is_empty():
			nos["_inf_soro"] = {"fala": "Isso não cura, entenda bem. Segura a febre por umas seis horas. (Ele te entrega um frasco escuro.)",
				"efeitos": [{"med": "soro"}]}
			out.append({"texto": "Me arruma um soro de contenção? Pago com %s." % Itens.texto_lista(_preco_soro),
				"vai": "_inf_soro"})
	return out


static func _efeito_infeccao(acao: String, ctx: Dictionary, j: Node) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var nos: Dictionary = ctx.get("_nos", {})
	match acao:
		"historia":
			Conversas.flags["heitor_conta_ninho"] = true
			Diario.ouvir(j, ["vampire", "mae", "rat", "zombie"])   # a história fala do ninho, das feras e dos mortos
			var r := Rumores.conhecer("ninho_lago")
			if r != "":
				msgs.append(r)
		"exame":
			nos["_inf_exame"] = {"fala": "(Ele examina o pescoço e os olhos.) " + Infeccao.diagnostico(j)}
		"preparar":
			j.inventario.remover("sangue_antigo", 1)
			if j.inventario.adicionar_itens([["antidoto", 1]]):
				msgs.append("Recebeu: Antídoto.")
			else:
				ItemNoChao.largar(j.get_parent(), j.global_position, "antidoto", 1)
				msgs.append("O antídoto ficou no chão (mochila cheia).")
			j.passar_tempo(PREPARAR_H, "O preparo levou %d horas." % int(PREPARAR_H))
		"tratar_sede":
			j.inventario.remover("antidoto", 1)
			var r2 := Infeccao.tratar_sede(j, Infeccao.CHANCE_SEDE_MEDICO)
			var certo := not Infeccao.ativa(j)
			nos["_inf_trat"] = {"fala": ("(Horas de febre, agulha e pano frio.) Pronto. Olha pra mim... os olhos voltaram. Você está limpo." \
				if certo else "(Horas de febre, agulha e pano frio. Ele balança a cabeça.) Não pegou. Eu sinto muito. Ainda há tempo, mas pouco.")}
			msgs.append(r2)
			j.passar_tempo(TRATAR_SEDE_H, "O tratamento durou %d horas." % int(TRATAR_SEDE_H))
		"soro":
			for it in _preco_soro:
				j.inventario.remover(str(it[0]), int(it[1]))
			if j.inventario.adicionar_itens([["soro_contencao", 1]]):
				msgs.append("Recebeu: Soro de contenção.")
			else:
				ItemNoChao.largar(j.get_parent(), j.global_position, "soro_contencao", 1)
			_preco_soro = []
	return msgs


## Efeitos {"med": "..."} das conversas (Conversas.aplicar).
static func efeito(acao: String, ctx: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var j: Node = ctx["jogador"]
	if acao == "liberar":
		Vigilancia.liberar(str(ctx["com"]))
		return PackedStringArray(["Quarentena encerrada."])
	if acao in ["historia", "exame", "preparar", "tratar_sede", "soro"]:
		return _efeito_infeccao(acao, ctx, j)
	match acao:
		"aceitar":
			if _proposta.is_empty():
				return msgs
			tarefa = _proposta
			_proposta = {}
			if str(tarefa["tipo"]) == "ferido" and str(tarefa["npc"]) == "ferido" and str(tarefa["com"]) == "santuario_do_sol":
				Conversas.flags["heitor_sabe_guga"] = true      # as falas do Guga já conhecem "o médico me disse o que fazer"
			if str(tarefa["tipo"]) == "remedio":
				msgs.append(Rumores.conhecer("hospital_porto"))
			msgs.append("Medicina: %s." % texto_tarefa())
		"entregar":
			var hab: String = HABILIDADES[passo()]
			if str(tarefa.get("tipo", "")) != "ferido" and j != null:
				j.inventario.remover(str(tarefa["item"]), int(tarefa["qtd"]))
				Simulacao.ajustar(str(ctx["com"]), str(tarefa["item"]), int(tarefa["qtd"]))   # vai para as reservas da vila
			feitas.append(str(tarefa.get("tipo", "")))
			tarefa = {}
			habilidades.append(hab)
			_aula = hab
			Reputacao.mudar(str(ctx["com"]), REP_POR_PASSO, "aprendeu com o médico")
			msgs.append("Habilidade aprendida: %s. %s" % [NOMES[hab], DESCRICOES[hab]])
			DiarioPartida.evento("habilidade", "Aprendeu %s com %s." % [NOMES[hab], str(mestre().get("nome", "o mestre"))])
			if completa():
				msgs.append("Especialização completa: Medicina.")
				Simulacao.registrar_noticia(str(ctx["com"]), "%s terminou de ensinar Medicina a alguém de fora." % str(mestre().get("nome", "O médico")))
		"aula":
			if j != null and j.has_method("passar_tempo"):
				j.passar_tempo(AULA_H, "A lição durou %d horas." % int(AULA_H))
	return msgs


# ───────────────────────────── tratar feridos ─────────────────────────────

## Pode tratar este ferido? Com a habilidade, com bandagem ou antibiótico; sem ela, só com antibiótico e as
## instruções do mestre (a tarefa é este ferido).
static func _pode_tratar(com: String, npc: String, j: Node) -> String:
	if j == null:
		return ""
	var instruido := str(tarefa.get("tipo", "")) == "ferido" and str(tarefa["com"]) == com and str(tarefa["npc"]) == npc
	if j.inventario.contar("antibiotico") > 0 and (tem("tratar_ferimentos") or instruido):
		return "antibiotico"
	if j.inventario.contar("bandagem") > 0 and tem("tratar_ferimentos"):
		return "bandagem"
	return ""


static func _opcao_tratar(nos: Dictionary, ctx: Dictionary, j: Node, lista: Array) -> Dictionary:
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var fd := Simulacao.ferido(com, npc)
	if fd.is_empty() or bool(fd["tratado"]):
		return {}
	for o in lista:                              # a conversa escrita já tem uma opção de tratar (o Guga)
		var vai := str((o as Dictionary).get("vai", ""))
		for e in ((nos.get(vai, {}) as Dictionary).get("efeitos", []) as Array):
			if (e as Dictionary).has("tratar"):
				return {}
	var grave := float(fd["grav"]) >= 0.6
	var kit: bool = grave and tem("cirurgia") and j != null and j.inventario.contar("kit_cirurgico") > 0
	var item := "kit_cirurgico" if kit else _pode_tratar(com, npc, j)
	if item == "":
		return {}
	var exame := " (%s, gravidade %d%%)" % ["grave" if grave else "estável", roundi(float(fd["grav"]) * 100.0)] if tem("diagnostico") else ""
	var falas := {
		"kit_cirurgico": "(Você abre o kit, limpa, costura e drena. Leva um bom tempo.) ...Eu achei que não ia ver amanhã.",
		"antibiotico": "(Você limpa o ferimento, fecha e dá o antibiótico.) Arde... mas é um ardido bom. Obrigado.",
		"bandagem": "(Você lava, aperta e enfaixa direito.) Assim parece que vai fechar. Obrigado.",
	}
	nos["_med_tratar"] = {"fala": str(falas[item]), "efeitos": [{"pedir": item, "qtd": 1}, {"med_tratar": item}]}
	var texto := "Deixa eu operar isso. Tenho um kit." if kit else "Deixa eu cuidar desse ferimento."
	return {"texto": texto + exame, "vai": "_med_tratar"}


## Efeito {"med_tratar": item}: o jogador tratou o ferido com o item.
static func tratar_com(item: String, ctx: Dictionary) -> PackedStringArray:
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var msgs: PackedStringArray = []
	var reducao := {"kit_cirurgico": 0.5, "antibiotico": 0.2, "bandagem": 0.1}
	if Simulacao.tratar(com, npc, float(reducao.get(item, 0.15))):
		Reputacao.mudar(com, 6, "tratou um ferido")
		msgs.append("Você tratou %s." % Simulacao.ferido(com, npc).get("nome", "o ferido"))
	return msgs


## Chamado pela Simulacao quando o jogador trata um ferido: cumpre a tarefa e atende o pedido de ajuda.
static func tratou(com: String, npc: String) -> void:
	if str(tarefa.get("tipo", "")) == "ferido" and str(tarefa["com"]) == com and str(tarefa["npc"]) == npc:
		tarefa["feito"] = true
	var chave := "%s/%s" % [com, npc]
	if pedidos.has(chave):
		pedidos.erase(chave)
		Reputacao.mudar(com, REP_PEDIDO, "atendeu um pedido de ajuda")
		var j := _jogador()
		if j != null:
			j.aviso("%s agradece: você atendeu o pedido de ajuda (+reputação)." % _Cap(Comunidades.com_artigo(com)))


## A Simulacao avisa que uma comunidade sem médico tem um ferido: com a Medicina completa, ela manda pedir ajuda ao
## jogador (uma vez por ferido). Devolve true se o pedido foi feito agora.
static func pedir_ajuda(com: String, fd: Dictionary) -> bool:
	if not completa() or str(fd.get("quem", "")) == "" or Reputacao.valor(com) < 0:
		return false
	var chave := "%s/%s" % [com, str(fd["quem"])]
	if pedidos.has(chave):
		return false
	pedidos[chave] = true
	Simulacao.registrar_noticia(com, "%s mandou procurar quem sabe Medicina: %s está mal e precisa de cuidado." % [
		_Cap(Comunidades.com_artigo(com)), fd["nome"]])
	return true


static func _Cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"habilidades": habilidades.duplicate(), "tarefa": tarefa.duplicate(), "feitas": feitas.duplicate(),
		"pedidos": pedidos.keys()}


static func restaurar(d: Dictionary) -> void:
	zerar()
	for h in d.get("habilidades", []):
		habilidades.append(str(h))
	tarefa = (d.get("tarefa", {}) as Dictionary).duplicate()
	if tarefa.has("qtd"):
		tarefa["qtd"] = int(tarefa["qtd"])
	for t in d.get("feitas", []):
		feitas.append(str(t))
	for p in d.get("pedidos", []):
		pedidos[str(p)] = true
