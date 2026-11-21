class_name Consequencias
extends RefCounted
## Consequências pessoais do que o jogador faz com os moradores (retorno do teste de 21/11/2026, etapa 11b;
## docs/DECISOES_DESIGN.md "Etapa 11b").
##
## Fase A — cobrança: cada NPC lembra se foi a VÍTIMA, se VIU ou se OUVIU falar (Reputacao.memorias, com o alvo).
## A vítima de uma agressão e quem viu um assassinato não conversam até o jogador se redimir; quem viu uma agressão
## ou um furto cobra toda vez, mas deixa mudar de assunto; quem só ouviu pergunta uma vez. Respostas: pedir
## desculpas (sozinho ou com uma reparação), mentir/se justificar (só cola com quem ouviu) e ameaçar (o NPC fica com
## medo por uns dias, a reputação cai e a ameaça vira boato).

const DIAS_MEDO := 3
const GRAVIDADE := ["assassinato", "agressao", "ameaca", "roubo_errante", "furto", "ajuda_errante", "defesa"]
const POSITIVOS := ["ajuda_errante", "defesa"]
## Valor (Escambo.VALORES) da reparação que o NPC aceita, por evento e por como ele soube.
const REPARACAO := {
	"agressao": {"vitima": 12.0, "viu": 6.0, "ouviu": 4.0},
	"assassinato": {"viu": 45.0, "ouviu": 20.0},
	"furto": {"vitima": 8.0, "viu": 6.0, "ouviu": 4.0},
	"ameaca": {"vitima": 8.0, "viu": 4.0, "ouviu": 2.0},
	"roubo_errante": {"ouviu": 4.0},
}
const ITENS_REPARACAO := ["comida", "agua_limpa", "pano", "bandagem", "soro", "municao", "antibiotico"]
const PARENTESCO := {"mae": ["minha mãe", "f"], "pai": ["meu pai", "m"], "filho": ["meu filho", "m"],
	"filha": ["minha filha", "f"], "irmao": ["meu irmão", "m"], "irma": ["minha irmã", "f"],
	"marido": ["meu marido", "m"], "esposa": ["minha mulher", "f"]}

static var medo: Dictionary = {}               ## "com/npc" -> dia até quando tem medo do jogador
static var luto: Dictionary = {}               ## com -> [{npc, nome, dia, causa}]
static var titulos: Dictionary = {}            ## "com/npc" -> título do papel que assumiu ("líder")
static var sucessores: Dictionary = {}         ## "com/npc" -> {de: quem morreu, papel: lider/guarda/medico}
## "com/parente" -> {morto, dia, pistas, estado (procurando/enganado/vinganca/resolvido/desistiu/morto), suspeito,
##                   perguntou_dia, modo (atacar/emboscar/contratar/justica), confessou, agente, grupo, desde_h, valor}
static var investigacoes: Dictionary = {}
static var avisos_guarda: Dictionary = {}      ## com -> segundos (Time) do último aviso do guarda ao expulso


static func zerar() -> void:
	medo = {}
	luto = {}
	titulos = {}
	sucessores = {}
	investigacoes = {}
	avisos_guarda = {}


static func _dia() -> int:
	return Reputacao._dia()


static func _npc_dados(com: String, npc: String) -> Dictionary:
	for n in Comunidades.dados(com).get("npcs", []):
		if str((n as Dictionary)["id"]) == npc:
			return n
	return {}


static func nome_npc(com: String, npc: String) -> String:
	return str(_npc_dados(com, npc).get("nome", "um morador"))


static func feminino(com: String, npc: String) -> bool:
	return str(_npc_dados(com, npc).get("genero", "m")) == "f"


## Como 'quem' chama 'alvo': "minha mãe", "o Jajá"... (parentesco do arquivo da comunidade).
static func chamar(com: String, quem: String, alvo: String) -> String:
	var par: Dictionary = _npc_dados(com, quem).get("parentes", {})
	for rel in par:
		if str(par[rel]) == alvo and PARENTESCO.has(str(rel)):
			return str(PARENTESCO[str(rel)][0])
	var nome := nome_npc(com, alvo)
	if nome.begins_with("Dona ") or nome.begins_with("Seu ") or nome.begins_with("Dr. "):
		return nome
	return ("a " if feminino(com, alvo) else "o ") + nome


## Parentes vivos de 'npc' na comunidade: [{id, rel}] (o que 'npc' é para cada um deles vem do arquivo do parente).
static func parentes(com: String, npc: String) -> Array:
	var out: Array = []
	for n in Comunidades.dados(com).get("npcs", []):
		var nd: Dictionary = n
		var par: Dictionary = nd.get("parentes", {})
		for rel in par:
			if str(par[rel]) == npc and Reputacao.vivo(com, str(nd["id"])):
				out.append({"id": str(nd["id"]), "rel": str(rel)})
	return out


# ───────────────────────────── fase A: cobrança ─────────────────────────────

## A lembrança mais grave ainda não resolvida que o NPC tem do jogador; {} se nada.
static func pendencia(com: String, npc: String) -> Dictionary:
	var mem: Array = Reputacao.memoria(com, npc)
	for ev in GRAVIDADE:
		var melhor: Dictionary = {}
		for m in mem:
			var md: Dictionary = m
			if str(md["ev"]) != ev or str(md.get("resolvido", "")) != "":
				continue
			if ev in POSITIVOS and bool(md.get("cobrado", false)):
				continue
			if str(md["como"]) == "ouviu" and bool(md.get("cobrado", false)):
				continue                               # quem só ouviu pergunta uma vez
			if melhor.is_empty() or _peso_como(str(md["como"])) > _peso_como(str(melhor["como"])):
				melhor = md
		if not melhor.is_empty():
			return melhor
	return {}


static func _peso_como(como: String) -> int:
	return {"vitima": 3, "viu": 2, "ouviu": 1}.get(como, 0)


## Marca como resolvidas todas as lembranças do mesmo evento e do mesmo jeito (pedido aceito, ameaça...).
static func _resolver(com: String, npc: String, ev: String, como_resolveu: String) -> void:
	for m in Reputacao.memoria(com, npc):
		var md: Dictionary = m
		if str(md["ev"]) == ev and str(md.get("resolvido", "")) == "":
			md["resolvido"] = como_resolveu
			md["cobrado"] = true


static func com_medo(com: String, npc: String) -> bool:
	return int(medo.get("%s/%s" % [com, npc], -1)) >= _dia()


## Bloqueia a conversa normal? (vítima de agressão, quem viu um assassinato, parente de quem você matou.)
static func bloqueia(md: Dictionary) -> bool:
	var ev := str(md["ev"])
	var como := str(md["como"])
	return (ev in ["agressao", "ameaca", "furto"] and como == "vitima") or (ev == "assassinato" and como != "ouviu")


## Monta a conversa de cobrança do NPC. Devolve {} (nada a cobrar) ou {"nos": {...}, "no": id de abertura}.
## 'seguir' é o nó da conversa normal (para "mudar de assunto" quando o NPC deixa).
static func cobranca(com: String, npc: String, ctx: Dictionary, seguir: String) -> Dictionary:
	var md := pendencia(com, npc)
	if md.is_empty():
		if com_medo(com, npc):
			return {"no": "_c_medo", "nos": {"_c_medo": {"fala": "(%s evita olhar para você.) O que... o que você quer?" \
				% ("Ela" if feminino(com, npc) else "Ele"), "sem_sair": true, "opcoes": [{"texto": "...", "vai": seguir}]}}}
		return {}
	var ev := str(md["ev"])
	var como := str(md["como"])
	var alvo := str(md.get("alvo", ""))
	if ev in POSITIVOS:
		md["cobrado"] = true
		var f := {"ajuda_errante": {"viu": "Eu vi você ajudando aquela gente.", "ouviu": "Passou um andarilho aqui falando bem de você. Disse que você salvou a pele dele."},
			"defesa": {"viu": "Eu vi você enfrentar aquela coisa perto do muro. Obrigado.", "ouviu": "Soube que você enfrentou um monstro perto do muro. A gente agradece."}}
		return {"no": "_c_bom", "nos": {"_c_bom": {"fala": str((f[ev] as Dictionary).get(como, f[ev]["ouviu"])), "sem_sair": true,
			"opcoes": [{"texto": "Fiz o que tinha de fazer.", "vai": seguir}]}}}
	md["cobrado"] = true
	var nos: Dictionary = {}
	var fala := _fala_cobranca(com, npc, ev, como, alvo)
	var opcoes: Array = []
	var chave := {"ev": ev, "como": como}
	# desculpas
	opcoes.append({"texto": _texto_desculpa(ev, como), "vai": "_c_desc", "efeitos": [{"cobranca": "desculpa", "dados": chave}]})
	var rep := _reparacao(ctx["jogador"], ev, como)
	if not rep.is_empty():
		opcoes.append({"texto": "Me desculpa. Toma %s, pra compensar." % Itens.texto_lista([rep]), "vai": "_c_desc",
			"efeitos": [{"cobranca": "reparar", "dados": chave, "item": rep[0], "qtd": rep[1]}]})
	opcoes.append({"texto": _texto_mentira(ev, como, alvo != "" and feminino(com, alvo)), "vai": "_c_mentira", "efeitos": [{"cobranca": "mentir", "dados": chave}]})
	opcoes.append({"texto": "Abre a boca de novo e você vai ver.", "vai": "_c_ameaca", "efeitos": [{"cobranca": "ameacar", "dados": chave}]})
	if not bloqueia(md):
		opcoes.append({"texto": "Deixa isso pra lá. Queria falar de outra coisa.", "vai": seguir})
	nos["_c_abre"] = {"fala": fala, "opcoes": opcoes}
	# os nós de resposta são preenchidos pelo efeito (a fala depende do resultado)
	nos["_c_desc"] = {"fala": "...", "_dinamico": true}
	nos["_c_mentira"] = {"fala": "...", "_dinamico": true}
	nos["_c_ameaca"] = {"fala": "...", "_dinamico": true}
	ctx["_seguir"] = seguir
	return {"no": "_c_abre", "nos": nos}


static func _fala_cobranca(com: String, npc: String, ev: String, como: String, alvo: String) -> String:
	var quem := chamar(com, npc, alvo) if alvo != "" and alvo != npc else ""
	var parente := quem.begins_with("minha ") or quem.begins_with("meu ")
	match ev:
		"agressao":
			if como == "vitima":
				return "Você me bateu. Do nada. Some da minha frente."
			if como == "viu":
				return ("Você bateu %s. Eu vi. Acha que eu vou esquecer?" % _com_prep(quem)) if parente \
					else ("Eu vi você bater %s. O que deu em você?" % _com_prep(quem) if quem != "" else "Eu vi você levantar a mão pra gente daqui.")
			return "Andam dizendo que você bateu %s. É verdade?" % _com_prep(quem) if quem != "" else "Me contaram que você atacou um dos nossos. É verdade?"
		"assassinato":
			if como == "viu":
				return ("Você matou %s. Eu vi. Eu vi tudo." % quem) if quem != "" else "Eu vi o que você fez. Não chega perto de mim."
			return "Dizem que foi você que matou %s. Fala que não é verdade." % quem if quem != "" else "Dizem que você matou gente daqui."
		"furto":
			if como == "vitima":
				return "Você entrou na minha casa e mexeu nas minhas coisas. Eu vi."
			return "Eu vi você mexendo no que não é seu." if como == "viu" else "Andam dizendo que você pega o que não é seu."
		"ameaca":
			return "Você me ameaçou. Achou que eu ia ficar quieto?" if como == "vitima" else ("Eu vi você ameaçar %s." % quem if quem != "" else "Dizem que você anda ameaçando gente daqui.")
		"roubo_errante":
			return "Passou um andarilho aqui dizendo que você assalta gente na estrada."
	return "..."


## "por" com artigo: "pela minha mãe", "pelo Jajá", "pela Vila dos Pescadores", "por Dona Marlene".
static func por(quem: String) -> String:
	if quem.begins_with("minha ") or quem.begins_with("a "):
		return "pela " + quem.trim_prefix("a ")
	if quem.begins_with("meu ") or quem.begins_with("o "):
		return "pelo " + quem.trim_prefix("o ")
	return "por " + quem


## Para o diário: "Dona Marlene, a mãe dele" (parente) ou só o nome.
static func _de_quem(com: String, quem: String, morto: String) -> String:
	var rel := chamar(com, quem, morto)
	var nome := nome_npc(com, morto)
	if rel.begins_with("minha ") or rel.begins_with("meu "):
		var dono := "dela" if feminino(com, quem) else "dele"
		return "%s, %s %s" % [nome, ("a " if rel.begins_with("minha ") else "o ") + rel.substr(rel.find(" ") + 1), dono]
	return nome


## "bateu na minha mãe" / "bateu no Jajá" / "bateu em Dona Marlene".
static func _com_prep(quem: String) -> String:
	if quem.begins_with("minha ") or quem.begins_with("a "):
		return "na " + quem.trim_prefix("a ")
	if quem.begins_with("meu ") or quem.begins_with("o "):
		return "no " + quem.trim_prefix("o ")
	return "em " + quem


static func _texto_desculpa(ev: String, como: String) -> String:
	if ev == "assassinato":
		return "Eu não queria. Me perdoa."
	return "Me desculpa. Perdi a cabeça." if como != "ouviu" else "É verdade. E eu me arrependo."


static func _texto_mentira(ev: String, como: String, alvo_f: bool = false) -> String:
	if como == "ouviu":
		return "Não fui eu. Isso é conversa."
	return {"agressao": "Foi legítima defesa.", "assassinato": "Foi legítima defesa. Era %s ou eu." % ("ela" if alvo_f else "ele"),
		"furto": "Tava abandonado, achei que não era de ninguém.", "ameaca": "Era brincadeira."}.get(ev, "Não foi bem assim.")


## Reparação que o jogador pode oferecer: [item, qtd] mais barato que chegue ao valor pedido; [] se não tem.
static func _reparacao(j: Node, ev: String, como: String) -> Array:
	var pede: float = float((REPARACAO.get(ev, {}) as Dictionary).get(como, 0.0))
	if pede <= 0.0 or j == null:
		return []
	var melhor: Array = []
	var custo := INF
	for item in ITENS_REPARACAO:
		var v: float = float(Escambo.VALORES.get(item, 0.0))
		if v <= 0.0:
			continue
		var qtd := ceili(pede / v)
		if j.inventario.contar(item) >= qtd and qtd * v < custo:
			custo = qtd * v
			melhor = [item, qtd]
	return melhor


## Efeito {"cobranca": acao, "dados": {ev, como}, ...} das respostas; escreve a fala do nó seguinte.
static func responder(e: Dictionary, ctx: Dictionary, nos: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var d: Dictionary = e["dados"]
	var ev := str(d["ev"])
	var como := str(d["como"])
	var seguir := str(ctx.get("_seguir", "fim"))
	var rep := Reputacao.valor(com)
	var ela := feminino(com, npc)
	var aceita := {"texto": "Obrigado.", "vai": seguir}
	match str(e["cobranca"]):
		"desculpa":
			var ok := false
			match como:
				"ouviu":
					ok = ev != "assassinato" or rep >= 20
				"viu":
					ok = ev != "assassinato" and (rep >= 10 or randf() < 0.5)
				"vitima":
					ok = rep >= 30 or (ev != "agressao" and randf() < 0.4)
			if ok:
				_resolver(com, npc, ev, "desculpa")
				Reputacao.mudar(com, 2)
				nos["_c_desc"] = {"fala": "...Tá. Mas não se repete.", "sem_sair": true, "opcoes": [aceita]}
			else:
				nos["_c_desc"] = {"fala": "Desculpa? Desculpa não tira roxo." if ev == "agressao" and como == "vitima" \
					else ("Desculpa não traz ninguém de volta." if ev == "assassinato" else "Palavra é fácil.")}
		"reparar":
			var j: Node = ctx["jogador"]
			j.inventario.remover(str(e["item"]), int(e["qtd"]))
			msgs.append("Você deu %s." % Itens.texto_lista([[str(e["item"]), int(e["qtd"])]]))
			if ev == "assassinato" and como == "viu" and rep < 0:
				nos["_c_desc"] = {"fala": "(%s pega, mas não olha para você.) Isso não muda nada." % ("Ela" if ela else "Ele")}
				Reputacao.mudar(com, 2)
			else:
				_resolver(com, npc, ev, "reparacao")
				Reputacao.mudar(com, 5)
				nos["_c_desc"] = {"fala": "(%s pega e guarda.) Tá bom. Fica por isso." % ("Ela" if ela else "Ele"), "sem_sair": true,
					"opcoes": [aceita]}
		"mentir":
			if como == "ouviu" and randf() < 0.6:
				_resolver(com, npc, ev, "desmentido")
				Reputacao.mudar(com, 3)
				nos["_c_mentira"] = {"fala": "Hm. Gente fala demais mesmo. Esquece.", "sem_sair": true, "opcoes": [aceita]}
			else:
				Reputacao.mudar(com, -3)
				nos["_c_mentira"] = {"fala": "Eu estava lá. Não me faz de bob%s." % ("a" if ela else "o") if como != "ouviu" \
					else "Sei. (Não acreditou.)"}
		"ameacar":
			_resolver(com, npc, ev, "medo")
			medo["%s/%s" % [com, npc]] = _dia() + DIAS_MEDO
			Reputacao.mudar(com, -5)
			Reputacao.pendentes.append({"com": com, "ev": "ameaca", "peso": int(Reputacao.EVENTOS["ameaca"]["peso"]),
				"hora": Reputacao.agora_h() + randf_range(4.0, 8.0), "testemunha": "%s/%s" % [com, npc], "origem": com, "alvo": npc})
			nos["_c_ameaca"] = {"fala": "(%s recua.) T-tá. Tá bom. Ninguém falou nada." % ("Ela" if ela else "Ele"), "sem_sair": true,
				"opcoes": [{"texto": "Assim é melhor.", "vai": seguir}]}
	if not bloqueia(d):                            # quem não bloqueia deixa mudar de assunto mesmo sem perdoar
		for k in ["_c_desc", "_c_mentira"]:
			var no: Dictionary = nos.get(k, {})
			if not no.has("opcoes") and not bool(no.get("_dinamico", false)):
				no["opcoes"] = [{"texto": "Deixa isso pra lá. Queria falar de outra coisa.", "vai": seguir}]
	return msgs


## Um morador com nome morreu ('causa': "jogador", "ferimento", "cidade"): luto, quem assume o papel dele e,
## com os parentes, a investigação (fase C).
static func morte(com: String, npc: String, causa: String) -> void:
	if com == "" or npc == "" or npc.begins_with("figurante"):
		return
	for l in luto.get(com, []):
		if str((l as Dictionary)["npc"]) == npc:
			return                                   # já tratada (as várias origens de morte podem avisar duas vezes)
	if not luto.has(com):
		luto[com] = []
	(luto[com] as Array).append({"npc": npc, "nome": nome_npc(com, npc), "dia": _dia(), "causa": causa})
	Simulacao.esquecer_npc(com, npc)
	var ela := feminino(com, npc)
	if causa == "cidade":
		Simulacao.registrar_noticia(com, "%s fez uma vigília por %s, que não voltou da cidade." % [_cap(Comunidades.com_artigo(com)), nome_npc(com, npc)])
	else:
		Simulacao.registrar_noticia(com, "%s enterrou %s." % [_cap(Comunidades.com_artigo(com)), nome_npc(com, npc)])
	_suceder(com, npc, ela)
	_investigar(com, npc, causa)


## Quem assume o papel do morto: a liderança, o portão, a enfermaria (o aprendiz, com a experiência que tiver).
static func _suceder(com: String, npc: String, ela: bool) -> void:
	var d := _npc_dados(com, npc)
	var papel := str(d.get("papel", ""))
	var morto := nome_npc(com, npc)
	var med: Dictionary = Simulacao.estado(com).get("medico", {})
	if str(med.get("npc", "")) == npc:
		var novo := Simulacao.perdeu_medico(com, npc)
		if novo != "":
			titulos["%s/%s" % [com, novo]] = "cuida dos feridos"
			sucessores["%s/%s" % [com, novo]] = {"de": npc, "papel": "medico"}
			Simulacao.registrar_noticia(com, "%s assumiu a enfermaria no lugar d%s %s. Ainda está aprendendo, mas é o que %s tem." \
				% [nome_npc(com, novo), "a" if ela else "o", morto, Comunidades.com_artigo(com)])
		else:
			Simulacao.registrar_noticia(com, "Sem %s, %s ficou sem ninguém que saiba Medicina." % [morto, Comunidades.com_artigo(com)])
	var cand: Array = []
	if papel == "lider":
		cand = ["guarda_dia", "guarda", "guarda_noite", "comerciante", "cacador", "medico", "pescadora", "pescador", "catadora"]
	elif papel.begins_with("guarda"):
		cand = ["guarda_dia", "guarda_noite", "guarda", "cacador", "pescador", "pescadora", "catadora"]
	else:
		return
	var quem := ""
	var pref := str(d.get("sucessor", ""))
	if pref != "" and Reputacao.vivo(com, pref):
		quem = pref
	for c in cand:
		if quem != "":
			break
		for n in Comunidades.dados(com).get("npcs", []):
			var nd: Dictionary = n
			var nid := str(nd["id"])
			if nid != npc and Reputacao.vivo(com, nid) and (str(nd.get("papel", "")) == c or nid == c) \
					and not sucessores.has("%s/%s" % [com, nid]):
				quem = nid
				break
	if quem == "":
		return
	if papel == "lider":
		titulos["%s/%s" % [com, quem]] = "líder"
		sucessores["%s/%s" % [com, quem]] = {"de": npc, "papel": "lider"}
		Simulacao.registrar_noticia(com, "Sem %s, %s passou a responder %s." % [morto, nome_npc(com, quem), por(Comunidades.com_artigo(com))])
	else:
		sucessores["%s/%s" % [com, quem]] = {"de": npc, "papel": "guarda"}
		Simulacao.registrar_noticia(com, "%s passou a cobrir o portão no lugar d%s %s." % [nome_npc(com, quem), "a" if ela else "o", morto])


## Título do NPC na conversa: o do arquivo, ou o papel que assumiu.
static func titulo(com: String, npc: String, padrao: String) -> String:
	return str(titulos.get("%s/%s" % [com, npc], padrao))


## A tarefa da rotina, com o turno de portão de quem morreu passando para quem assumiu.
static func rotina(com: String, npc: String, fase: String, padrao: String) -> String:
	var s: Dictionary = sucessores.get("%s/%s" % [com, npc], {})
	if s.is_empty() or str(s["papel"]) != "guarda":
		return padrao
	var r: Dictionary = _npc_dados(com, str(s["de"])).get("rotina", {})
	return "portao" if str(r.get(fase, "")) == "portao" else padrao


## Mortes recentes na comunidade (últimos 'dias').
static func mortes_recentes(com: String, dias: int = 4) -> Array:
	return (luto.get(com, []) as Array).filter(func(l): return _dia() - int((l as Dictionary)["dia"]) <= dias)


## O texto cita alguém que já morreu? (as falas e opções que falam do morto como vivo somem)
static func cita_morto(texto: String) -> bool:
	for k in Reputacao.mortos:
		var partes := str(k).split("/")
		if partes.size() != 2:
			continue
		var curto := _nome_curto(nome_npc(partes[0], partes[1]))
		if curto != "" and _tem_palavra(texto, curto):
			return true
	return false


## 'palavra' aparece inteira no texto (sem ser pedaço de outra palavra)?
static func _tem_palavra(texto: String, palavra: String) -> bool:
	var i := texto.find(palavra)
	while i >= 0:
		var antes := texto.substr(i - 1, 1) if i > 0 else " "
		var depois := texto.substr(i + palavra.length(), 1)
		if not _letra(antes) and not _letra(depois):
			return true
		i = texto.find(palavra, i + 1)
	return false


static func _letra(c: String) -> bool:
	return c != "" and c.to_lower() != c.to_upper()


static func _nome_curto(nome: String) -> String:
	if nome == "um morador":
		return ""
	var p := nome.split(" ")
	return p[p.size() - 1] if p.size() > 1 and p[0] in ["Dona", "Seu", "Dr.", "Dra."] else nome


## Conversa ouvida de luto (uma por morte recente): [fala a, fala b] ou [].
static func conversa_luto(com: String) -> Array:
	for l in mortes_recentes(com, 3):
		var ld: Dictionary = l
		var chave := "luto_ouvido_%s_%s" % [com, ld["npc"]]
		if Conversas.flags.has(chave):
			continue
		Conversas.flags[chave] = true
		var nome := str(ld["nome"])
		if str(ld["causa"]) == "jogador" and not _assassino_sabido(com, str(ld["npc"])):
			return ["Ainda não acredito no que fizeram com %s." % nome, "Quem fez aquilo tá por aí. Pode estar aqui do lado."]
		if str(ld["causa"]) == "jogador":
			return ["Foi aquela pessoa de fora. Matou %s." % nome, "E ainda tem coragem de aparecer por aqui."]
		if str(ld["causa"]) == "cidade":
			return ["%s não voltou. Eu disse que a cidade não perdoa." % nome, "Ninguém merecia morrer sozinho lá."]
		return ["Pelo menos %s não sofre mais." % nome, "A gente fez o que pôde."]
	return []


## Abertura de luto: o NPC fala da morte recente uma vez (parente, quem assumiu ou um morador). {} se nada.
static func abertura_luto(com: String, npc: String, seguir: String) -> Dictionary:
	for l in mortes_recentes(com):
		var ld: Dictionary = l
		var chave := "luto_%s_%s_%s" % [com, npc, ld["npc"]]
		if Conversas.flags.has(chave):
			continue
		Conversas.flags[chave] = true
		var morto := str(ld["npc"])
		var nome := str(ld["nome"])
		var quem := chamar(com, npc, morto)
		var parente := quem.begins_with("minha ") or quem.begins_with("meu ")
		var mf := feminino(com, morto)
		var suc: Dictionary = sucessores.get("%s/%s" % [com, npc], {})
		var fala := ""
		if parente:
			fala = "(Os olhos vermelhos.) %s... A gente enterrou ontem. Eu nem consegui me despedir." % _cap(quem)
			if str(ld["causa"]) == "jogador" and not _assassino_sabido(com, morto, npc):
				fala += " Alguém fez aquilo com %s. E eu vou descobrir quem." % ("ela" if mf else "ele")
		elif str(suc.get("de", "")) == morto:
			match str(suc["papel"]):
				"lider":
					fala = "Desde que %s se foi, sou eu que respondo por aqui. Não pedi por isso." % nome
				"guarda":
					fala = "Agora o portão é comigo também. %s cuidava dele melhor do que eu." % nome
				_:
					fala = "Sou eu que cuido dos feridos agora. Não sei metade do que %s sabia, mas tô aprendendo." % nome
		else:
			match str(ld["causa"]):
				"jogador":
					fala = "Enterramos %s. Morreu de um jeito que ninguém merece." % nome
				"cidade":
					fala = "%s não voltou da cidade. A gente tá de luto." % nome
				_:
					fala = "Enterramos %s. Ainda não dá pra acreditar." % nome
		return {"no": "_luto", "nos": {"_luto": {"fala": fala, "sem_sair": true, "opcoes": [
			{"texto": "Meus pêsames.", "vai": seguir, "luto": true}]}}}
	return {}


## O NPC (ou alguém da comunidade, sem 'npc') já sabe que foi o jogador que matou 'morto'?
static func _assassino_sabido(com: String, morto: String, npc: String = "") -> bool:
	var chaves: Array = []
	if npc != "":
		chaves.append("%s/%s" % [com, npc])
	else:
		for n in Comunidades.dados(com).get("npcs", []):
			chaves.append("%s/%s" % [com, str((n as Dictionary)["id"])])
	for k in chaves:
		for m in Reputacao.memorias.get(k, []):
			var md: Dictionary = m
			if str(md["ev"]) == "assassinato" and str(md.get("alvo", "")) == morto:
				return true
	return false


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


# ───────────────────────────── fase C: investigação (parentes) ─────────────────────────────

## Parentes de quem o jogador matou: quem não viu quer descobrir quem foi (pergunta, junta pistas, ouve o boato).
static func _investigar(com: String, morto: String, causa: String) -> void:
	if causa != "jogador":
		return
	for p in parentes(com, morto):
		var pid := str((p as Dictionary)["id"])
		var k := "%s/%s" % [com, pid]
		investigacoes[k] = {"morto": morto, "dia": _dia(), "pistas": 0.0, "estado": "procurando", "suspeito": "",
			"perguntou_dia": -1, "modo": "", "confessou": false, "agente": "", "grupo": "", "desde_h": Reputacao.agora_h()}
		if _assassino_sabido(com, morto, pid):
			_descobrir(com, pid, "viu")
		else:
			Simulacao.registrar_noticia(com, "%s não para de perguntar quem matou %s." % [nome_npc(com, pid), _de_quem(com, pid, morto)])


## Alguém viu o jogador fazer 'ev' contra 'alvo' (Reputacao.registrar). O parente que viu a morte já sabe (morte()).
static func testemunhado(_ev: String, _alvo: String, _viram: Array) -> void:
	pass


## O boato de um assassinato chegou à comunidade: o parente que procurava descobre.
static func boato_correu(com: String, b: Dictionary) -> void:
	if str(b.get("ev", "")) != "assassinato" or str(b.get("alvo", "")) == "":
		return
	for k in investigacoes.keys():
		var inv: Dictionary = investigacoes[k]
		var partes := str(k).split("/")
		if partes[0] == com and str(inv["morto"]) == str(b["alvo"]) and str(inv["estado"]) in ["procurando", "enganado"]:
			_descobrir(com, partes[1], "ouviu")


## A cada turno da Simulacao (6 h de jogo): pistas, desistência e o andamento das vinganças.
static func turno(h: float) -> void:
	for k in investigacoes.keys():
		var inv: Dictionary = investigacoes[k]
		var partes := str(k).split("/")
		var com := partes[0]
		var npc := partes[1]
		if not Reputacao.vivo(com, npc):
			inv["estado"] = "morto"
			continue
		match str(inv["estado"]):
			"procurando":
				if _assassino_sabido(com, str(inv["morto"]), npc):
					_descobrir(com, npc, "ouviu")
				elif randf() < 0.08:
					inv["pistas"] = float(inv["pistas"]) + 0.35
					if float(inv["pistas"]) >= 1.0:
						if randf() < 0.6:
							Simulacao.registrar_noticia(com, "%s juntou as pistas e diz que sabe quem matou %s." % [nome_npc(com, npc), _de_quem(com, npc, str(inv["morto"]))])
							_descobrir(com, npc, "pistas")
						else:
							inv["estado"] = "enganado"
							inv["suspeito"] = "saqueadores"
							Simulacao.registrar_noticia(com, "%s está convencid%s de que foi o bando de saqueadores." % [nome_npc(com, npc), "a" if feminino(com, npc) else "o"])
				elif _dia() - int(inv["dia"]) > 10:
					inv["estado"] = "desistiu"
			"enganado":
				if _dia() - int(inv["dia"]) > 4 and randf() < 0.05:
					inv["estado"] = "procurando"           # a verdade ainda pode aparecer
					inv["pistas"] = 0.5
			"vinganca":
				_vinganca_turno(com, npc, inv, h)


## O parente descobriu que foi o jogador: escolhe como se vingar (pelo jeito e pelo papel dele).
static func _descobrir(com: String, npc: String, _como: String) -> void:
	var k := "%s/%s" % [com, npc]
	var inv: Dictionary = investigacoes.get(k, {})
	if inv.is_empty() or str(inv["estado"]) == "vinganca":
		return
	inv["estado"] = "vinganca"
	var papel := str(_npc_dados(com, npc).get("papel", ""))
	var pesos: Dictionary
	if bool(inv["confessou"]):
		pesos = {"justica": 0.7, "atacar": 0.3}
	elif papel.begins_with("guarda") or papel == "cacador":
		pesos = {"atacar": 0.5, "emboscar": 0.3, "justica": 0.2}
	else:
		pesos = {"justica": 0.4, "contratar": 0.3, "emboscar": 0.2, "atacar": 0.1}
	_iniciar_modo(com, npc, inv, _sortear(pesos))


static func _sortear(pesos: Dictionary) -> String:
	var total := 0.0
	for k in pesos:
		total += float(pesos[k])
	var r := randf() * total
	for k in pesos:
		r -= float(pesos[k])
		if r <= 0.0:
			return str(k)
	return str(pesos.keys()[0])


static func _iniciar_modo(com: String, npc: String, inv: Dictionary, modo: String) -> void:
	var nome := nome_npc(com, npc)
	var ela := feminino(com, npc)
	var morto := _de_quem(com, npc, str(inv["morto"]))      # para o diário (terceira pessoa)
	inv["modo"] = modo
	inv["desde_h"] = Reputacao.agora_h()
	match modo:
		"atacar":
			Simulacao.registrar_noticia(com, "%s jurou que, se encontrar quem matou %s, não vai conversar." % [nome, morto])
		"emboscar":
			inv["agente"] = Errantes.vingador(com, npc, nome, ela, "Isso é %s!" % por(chamar(com, npc, str(inv["morto"]))))
			Simulacao.registrar_noticia(com, "%s saiu %s armad%s, atrás de quem matou %s." % [nome, Comunidades.de(com), "a" if ela else "o", morto])
		"contratar":
			inv["grupo"] = Errantes.contratar(com, Reputacao.agora_h() + 120.0)
			if str(inv["grupo"]) == "":
				_iniciar_modo(com, npc, inv, "emboscar")
				return
			Simulacao.registrar_noticia(com, "Dizem que %s pagou o bando de saqueadores para caçar uma pessoa de fora." % nome)
		"justica":
			inv["valor"] = 60.0
			for outra in Comunidades.ids():
				if str(outra) != com:
					Reputacao.pendentes.append({"com": str(outra), "ev": "assassinato", "peso": int(Reputacao.EVENTOS["assassinato"]["peso"]) / 2,
						"hora": Reputacao.agora_h() + randf_range(12.0, 24.0), "testemunha": "", "origem": str(outra), "alvo": ""})
			Simulacao.registrar_noticia(com, "%s foi às outras comunidades contar quem matou %s, e quer justiça." % [nome, morto])


static func _vinganca_turno(com: String, npc: String, inv: Dictionary, h: float) -> void:
	match str(inv["modo"]):
		"emboscar":
			var a: Dictionary = Errantes.agentes.get(str(inv["agente"]), {})
			if a.is_empty() or bool(a.get("voltou", false)) or not bool(a.get("vivo", false)):
				if not a.is_empty() and bool(a.get("voltou", false)):
					Errantes.agentes.erase(str(inv["agente"]))
					Simulacao.registrar_noticia(com, "%s voltou para casa sem achar quem procurava. Mas não esqueceu." % nome_npc(com, npc))
				inv["agente"] = ""
				inv["modo"] = "atacar"
		"contratar":
			if h > float(inv["desde_h"]) + 120.0:
				inv["modo"] = "atacar"
		"justica":
			if h > float(inv["desde_h"]) + 120.0:          # 5 dias sem reparação: parte para outra
				_iniciar_modo(com, npc, inv, "contratar" if randf() < 0.5 else "emboscar")


## O NPC está fora por causa da vingança (saiu atrás do jogador)?
static func ausente(com: String, npc: String) -> bool:
	var inv: Dictionary = investigacoes.get("%s/%s" % [com, npc], {})
	return not inv.is_empty() and str(inv["estado"]) == "vinganca" and str(inv["modo"]) == "emboscar" and str(inv["agente"]) != ""


## Conversa com o parente que investiga ou cobra justiça. {} se nada.
static func abertura_parente(com: String, npc: String, ctx: Dictionary, seguir: String) -> Dictionary:
	var inv: Dictionary = investigacoes.get("%s/%s" % [com, npc], {})
	if inv.is_empty():
		return {}
	var morto := str(inv["morto"])
	var quem := chamar(com, npc, morto)
	var mf := feminino(com, morto)
	if str(inv["estado"]) == "procurando" and int(inv["perguntou_dia"]) != _dia():
		inv["perguntou_dia"] = _dia()
		return {"no": "_inv", "nos": {"_inv": {"fala": "Você anda por aí. No dia em que %s morreu... você viu alguma coisa? Qualquer coisa." % quem,
			"opcoes": [
				{"texto": "Não vi nada. Sinto muito.", "vai": "_inv_r", "efeitos": [{"investig": "nada"}]},
				{"texto": "Vi um bando de saqueadores rondando por aqui.", "vai": "_inv_r", "efeitos": [{"investig": "culpar"}]},
				{"texto": "Fui eu. Me perdoa.", "vai": "_inv_r", "efeitos": [{"investig": "confessar"}]}]},
			"_inv_r": {"fala": "...", "_dinamico": true}}}
	if str(inv["estado"]) == "vinganca" and str(inv["modo"]) == "justica":
		var rep := _reparacao_valor(ctx["jogador"], float(inv.get("valor", 60.0)))
		var opcoes: Array = []
		if not rep.is_empty():
			opcoes.append({"texto": "Toma %s. Não traz %s de volta, mas é o que eu tenho." % [Itens.texto_lista(rep), "ela" if mf else "ele"],
				"vai": "_inv_r", "efeitos": [{"investig": "pagar", "itens": rep}]})
		opcoes.append({"texto": "Não devo nada a ninguém.", "vai": "_inv_r", "efeitos": [{"investig": "recusar"}]})
		return {"no": "_just", "nos": {"_just": {"fala": "Você matou %s. Todo mundo vai saber o que você é. Ou você paga pelo que fez." % quem,
			"opcoes": opcoes}, "_inv_r": {"fala": "...", "_dinamico": true}}}
	return {}


## Reparação alta (justiça): uma combinação dos itens de valor da mochila que chegue a 'pede'. [] se não alcança.
static func _reparacao_valor(j: Node, pede: float) -> Array:
	if j == null:
		return []
	var out: Array = []
	var falta := pede
	for item in ["antibiotico", "municao", "kit_cirurgico", "bandagem", "soro", "agua_limpa", "comida"]:
		if falta <= 0.0:
			break
		var v: float = float(Escambo.VALORES.get(item, 0.0))
		var tem: int = j.inventario.contar(item)
		if v <= 0.0 or tem <= 0:
			continue
		var qtd := mini(tem, ceili(falta / v))
		out.append([item, qtd])
		falta -= qtd * v
	return out if falta <= 0.0 else []


## Efeito {"investig": ...} das respostas ao parente.
static func responder_parente(e: Dictionary, ctx: Dictionary, nos: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var inv: Dictionary = investigacoes.get("%s/%s" % [com, npc], {})
	if inv.is_empty():
		return msgs
	var ela := feminino(com, npc)
	var morto := _de_quem(com, npc, str(inv["morto"]))      # para o diário (terceira pessoa)
	match str(e["investig"]):
		"nada":
			if randf() < 0.25:
				inv["pistas"] = float(inv["pistas"]) + 0.3
				nos["_inv_r"] = {"fala": "(%s te olha demorado.) ...Tá. Se lembrar de alguma coisa, me fala." % ("Ela" if ela else "Ele")}
			else:
				nos["_inv_r"] = {"fala": "Tá. Obrigad%s mesmo assim." % ("a" if ela else "o")}
		"culpar":
			if randf() < 0.6:
				inv["estado"] = "enganado"
				inv["suspeito"] = "saqueadores"
				nos["_inv_r"] = {"fala": "Aqueles desgraçados... Eu sabia. Eles vão pagar."}
				Simulacao.registrar_noticia(com, "%s jura que foi o bando de saqueadores que matou %s." % [nome_npc(com, npc), morto])
			else:
				inv["pistas"] = float(inv["pistas"]) + 0.4
				nos["_inv_r"] = {"fala": "Saqueador não faz daquele jeito. (Desconfiad%s.) Você tem certeza?" % ("a" if ela else "o")}
		"confessar":
			inv["confessou"] = true
			Reputacao._lembrar("%s/%s" % [com, npc], "assassinato", "ouviu", str(inv["morto"]))
			_resolver(com, npc, "assassinato", "")       # a cobrança vira a da vingança
			for m in Reputacao.memoria(com, npc):
				(m as Dictionary)["cobrado"] = true
			_descobrir(com, npc, "confessou")
			nos["_inv_r"] = {"fala": "(Silêncio.) ...Sai da minha frente. Agora."}
		"pagar":
			var j: Node = ctx["jogador"]
			for it in e["itens"]:
				j.inventario.remover(str(it[0]), int(it[1]))
			msgs.append("Você deu %s." % Itens.texto_lista(e["itens"]))
			inv["estado"] = "resolvido"
			Reputacao.mudar(com, 10)
			nos["_inv_r"] = {"fala": "(%s pega, sem olhar para você.) Isso fica entre nós. Mas não aparece mais na minha frente." % ("Ela" if ela else "Ele")}
			Simulacao.registrar_noticia(com, "%s aceitou uma reparação pela morte de %s." % [nome_npc(com, npc), morto])
		"recusar":
			nos["_inv_r"] = {"fala": "Então tá. Você escolheu."}
			_iniciar_modo(com, npc, inv, "contratar" if randf() < 0.5 else "emboscar")
	return msgs


# ───────────────────────────── fases D e E: hostilidade ─────────────────────────────

## A comunidade sabe que o jogador matou gente dela e a reputação despencou: não entra mais.
static func expulso(com: String) -> bool:
	if Reputacao.valor(com) > -30:
		return false
	for n in Comunidades.dados(com).get("npcs", []):
		var id := str((n as Dictionary)["id"])
		if not Reputacao.vivo(com, id):
			continue
		for m in Reputacao.memoria(com, id):
			var md: Dictionary = m
			if str(md["ev"]) == "assassinato" and str(md.get("resolvido", "")) in ["", "medo"]:
				return true
	return false


## O NPC ataca o jogador agora? (vingança "atacar", ou guarda expulsando o assassino de dentro dos muros, depois do aviso)
static func hostil(com: String, npc: String, j: Node2D, no: Node = null) -> bool:
	var inv: Dictionary = investigacoes.get("%s/%s" % [com, npc], {})
	if not inv.is_empty() and str(inv["estado"]) == "vinganca" and str(inv["modo"]) == "atacar":
		return true
	if j == null:
		return false
	var papel := str(_npc_dados(com, npc).get("papel", ""))
	var guarda := papel.begins_with("guarda") or str((sucessores.get("%s/%s" % [com, npc], {}) as Dictionary).get("papel", "")) == "guarda"
	if not guarda or not expulso(com):
		return false
	if Comunidades.em(IsoMath.tela_para_mundo(j.global_position)) != com:
		return false
	var agora := Time.get_ticks_msec() / 1000.0
	var t: float = float(avisos_guarda.get(com, -1.0))
	if t < 0.0 or agora - t > 120.0:
		avisos_guarda[com] = agora               # o guarda avisa antes; 8 s depois, ataca
		if no != null and no.has_method("falar"):
			no.falar("Você não é bem-vindo aqui. Sai agora, ou vai sair carregado.", 5.0)
		return false
	return agora - t > 8.0


## Frase do NPC atacando.
static func grito(com: String, npc: String) -> String:
	var inv: Dictionary = investigacoes.get("%s/%s" % [com, npc], {})
	if not inv.is_empty() and str(inv["estado"]) == "vinganca":
		return "Isso é %s!" % por(chamar(com, npc, str(inv["morto"])))
	return "Eu avisei! Fora daqui!"


## O portão fica fechado para o jogador expulso quando ele chega perto (os moradores não ficam presos o dia todo).
static func portao_fechado_para(com: String, pj: Vector2) -> bool:
	if not expulso(com):
		return false
	var g := Comunidades.geo(com)
	return not g.is_empty() and (g["area"] as Rect2).grow(25.0 * IsoMath.METRO).has_point(pj)


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	return {"medo": medo.duplicate(), "luto": luto.duplicate(true), "titulos": titulos.duplicate(),
		"sucessores": sucessores.duplicate(true), "investigacoes": investigacoes.duplicate(true)}


static func restaurar(d: Dictionary) -> void:
	zerar()
	var md: Dictionary = d.get("medo", {})
	for k in md:
		medo[str(k)] = int(md[k])
	var ld: Dictionary = d.get("luto", {})
	for k in ld:
		var lista: Array = []
		for l in ld[k]:
			var x: Dictionary = (l as Dictionary).duplicate()
			x["dia"] = int(x["dia"])
			lista.append(x)
		luto[str(k)] = lista
	titulos = (d.get("titulos", {}) as Dictionary).duplicate()
	sucessores = (d.get("sucessores", {}) as Dictionary).duplicate(true)
	var inv: Dictionary = d.get("investigacoes", {})
	for k in inv:
		var x: Dictionary = (inv[k] as Dictionary).duplicate(true)
		for c in ["dia", "perguntou_dia"]:
			x[c] = int(x.get(c, -1))
		for c in ["pistas", "desde_h", "valor"]:
			if x.has(c):
				x[c] = float(x[c])
		investigacoes[str(k)] = x
