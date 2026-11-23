class_name VidaComunidade
extends RefCounted
## Vida na comunidade (marco 2, etapa 12; docs/DECISOES_DESIGN.md Q49 e Q52, respostas de 21/11/2026).
##
## - Dormir: a cama de hóspede (CamaHospede) só para quem tem reputação alta (REP_DORMIR). Dentro dos muros nada
##   ataca, e com reputação alta o guarda abre o portão de noite.
## - Estrutura: barril de água limpa (de graça com reputação, senão custa comida), bancada (receitas 25% mais baratas)
##   e a enfermaria (o médico da comunidade cuida de você uma vez por dia; de graça com reputação, senão com um item).
## - Trabalhos em tempo real, oferecidos nas conversas: vigiar o portão (guarda), ajudar no forte da comunidade
##   (pesca, caça, roça), consertar o muro e recados (levar uma encomenda à vizinha ou buscar o que falta). O jogador
##   fica no lugar enquanto o relógio corre; afastar-se pausa. Reputação por trabalho tem teto por dia.
## - Portão: com reputação −20 ou menos o portão não abre para você e só se fala com o guarda pelo portão, que oferece
##   uma tarefa de redenção ou aceita um presente. Abaixo de −40 ninguém conversa (DialogoUI).

const REP_DORMIR := 30
const REP_AGUA := 15
const REP_BANCADA := 15
const REP_ENFERMARIA := 20
const REP_NOITE := 30                  ## o guarda abre o portão de noite
const REP_BARRADO := -20
const TETO_DIA := 8                    ## reputação máxima por dia com trabalhos (recados não contam)
const ABRIR_S := 25.0                  ## segundos que o portão fica aberto quando o guarda abre de noite

## Trabalhos do forte de cada comunidade (pelo "forte" do arquivo; "pesca" é o padrão).
const FORTES := {
	"pesca": {"texto": "Posso ajudar na pesca?", "fazendo": "limpando peixe e consertando rede", "fala": "Ajuda sempre. Pega aquela rede ali e não sai de perto até terminar."},
	"caca": {"texto": "Posso ajudar com as armadilhas?", "fazendo": "montando armadilhas e limpando caça", "fala": "Pode. Fica ali e arma os laços do jeito que eu mostrar."},
	"agricultura": {"texto": "Posso ajudar na roça?", "fazendo": "capinando e colhendo", "fala": "Enxada ali. Até o sol baixar, se aguentar."},
}

## {tipo, com, ponto: Vector2, raio, horas, progresso, texto, item, qtd, destino, rep, consome}
static var atual: Dictionary = {}
static var ganhos: Dictionary = {}     ## "com/dia" -> reputação ganha com trabalhos nesse dia
static var tratado_dia: Dictionary = {}  ## com -> dia em que a enfermaria já cuidou do jogador
static var presente_dia: Dictionary = {} ## com -> dia em que o guarda já aceitou um presente
static var abrir_ate: Dictionary = {}  ## com -> segundos (Time) até quando o portão fica aberto para o jogador
static var retornos: Dictionary = {}   ## "com/npc" -> {tipo, forte, dia}: trabalho terminado que esse NPC ainda vai comentar
static var _aviso_longe := false


static func zerar() -> void:
	atual = {}
	ganhos = {}
	tratado_dia = {}
	presente_dia = {}
	abrir_ate = {}
	retornos = {}


static func _dia() -> int:
	return Reputacao._dia()


static func _jogador() -> Node2D:
	var arv := Engine.get_main_loop() as SceneTree
	return arv.get_first_node_in_group("jogador") as Node2D if arv != null else null


static func _papel(com: String, npc: String) -> String:
	var p := str(Consequencias._npc_dados(com, npc).get("papel", ""))
	var s: Dictionary = Consequencias.sucessores.get("%s/%s" % [com, npc], {})
	if str(s.get("papel", "")) == "lider":
		return "lider"
	if str(s.get("papel", "")) == "guarda":
		return "guarda"
	return "guarda" if p.begins_with("guarda") else p


## Quem responde pela comunidade agora (a líder do arquivo ou quem assumiu). "" se ninguém.
static func lider(com: String) -> String:
	for k in Consequencias.sucessores:
		var partes := str(k).split("/")
		if partes[0] == com and str(Consequencias.sucessores[k]["papel"]) == "lider" and Reputacao.vivo(com, partes[1]):
			return partes[1]
	for n in Comunidades.dados(com).get("npcs", []):
		if str((n as Dictionary).get("papel", "")) == "lider" and Reputacao.vivo(com, str((n as Dictionary)["id"])):
			return str((n as Dictionary)["id"])
	return ""


# ───────────────────────────── portão ─────────────────────────────

## O portão fica fechado para o jogador (reputação baixa) quando ele chega perto.
static func barrado(com: String) -> bool:
	return Reputacao.valor(com) <= REP_BARRADO


static func portao_fechado_para(com: String, pj: Vector2) -> bool:
	if not barrado(com):
		return false
	var g := Comunidades.geo(com)
	return not g.is_empty() and (g["area"] as Rect2).grow(25.0 * IsoMath.METRO).has_point(pj)


## O guarda abriu o portão para o jogador (de noite, com reputação alta)?
static func aberto_para_jogador(com: String) -> bool:
	return float(abrir_ate.get(com, -1.0)) > Time.get_ticks_msec() / 1000.0


## E no portão fechado de noite: com reputação alta, o guarda abre. Devolve o aviso.
static func pedir_para_entrar(com: String) -> String:
	if barrado(com) or Consequencias.expulso(com):
		return "Ninguém responde. Ou fingem que não ouviram."
	if Reputacao.valor(com) < REP_NOITE:
		return "Uma voz do outro lado: \"De noite não abre. Volta de manhã.\""
	abrir_ate[com] = Time.get_ticks_msec() / 1000.0 + ABRIR_S
	return "O guarda reconhece você e abre o portão. \"Entra logo, que de noite não fica aberto.\""


# ───────────────────────────── conversa ─────────────────────────────

## Abertura do guarda quando o jogador está barrado (só se fala pelo portão). {} se não for o caso.
static func abertura_barrado(com: String, npc: String, ctx: Dictionary, _seguir: String) -> Dictionary:
	if not barrado(com) or _papel(com, npc) != "guarda" or Consequencias.expulso(com):
		return {}
	var opcoes: Array = [{"texto": "Me deixa entrar.", "vai": "_v_nao"}]
	opcoes.append({"texto": "Como eu resolvo isso?", "vai": "_v_redencao", "efeitos": [{"vida": "redencao"}]})
	if int(presente_dia.get(com, -1)) != _dia():
		var rep := Consequencias._reparacao_valor(ctx["jogador"], 10.0)
		if not rep.is_empty():
			opcoes.append({"texto": "Toma %s. É pra vila." % Itens.texto_lista(rep), "vai": "_v_presente",
				"efeitos": [{"vida": "presente", "itens": rep}]})
	return {"no": "_v_barrado", "nos": {
		"_v_barrado": {"fala": "Daí mesmo. Com o que andam dizendo de você, esse portão não abre.", "opcoes": opcoes},
		"_v_nao": {"fala": "Não. E não insiste."},
		"_v_redencao": {"fala": "...", "_dinamico": true},
		"_v_presente": {"fala": "(Pega pela grade.) Vou entregar. Não muda tudo, mas ajuda."}}}


## Opções extras da conversa (DialogoUI): trabalhos, recados, enfermaria e entrega de encomenda.
static func opcoes(arvore: Dictionary, ctx: Dictionary, abertura: bool) -> Array:
	var out: Array = []
	if not abertura:
		return out
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var j: Node = ctx["jogador"]
	var nos: Dictionary = arvore["nos"]
	var rep := Reputacao.valor(com)
	# entrega de encomenda / item buscado
	if not atual.is_empty() and str(atual["tipo"]) in ["encomenda", "buscar"] and str(atual["destino_com"]) == com \
			and str(atual["destino_npc"]) == npc:
		var pronto: bool = j != null and j.inventario.contar(str(atual["item"])) >= int(atual["qtd"])
		if pronto:
			var txt := "Trouxe uma encomenda %s." % Comunidades.de(str(atual["com"])) if str(atual["tipo"]) == "encomenda" \
				else "Trouxe o que você pediu."
			nos["_v_entrega"] = {"fala": "...", "_dinamico": true}
			out.append({"texto": txt, "vai": "_v_entrega", "efeitos": [{"vida": "entregar"}]})
	if rep <= REP_BARRADO:
		return out
	# enfermaria
	var med: Dictionary = Simulacao.estado(com).get("medico", {})
	if str(med.get("npc", "")) == npc and j != null and (float(j.vida) < float(j.vida_max) - 1.0 or not (j.doenca as Dictionary).is_empty()) \
			and int(tratado_dia.get(com, -1)) != _dia():
		nos["_v_enf"] = {"fala": "...", "_dinamico": true}
		if rep >= REP_ENFERMARIA:
			out.append({"texto": "Pode dar uma olhada em mim?", "vai": "_v_enf", "efeitos": [{"vida": "enfermaria"}]})
		else:
			var pag := Consequencias._reparacao_valor(j, 10.0)
			if not pag.is_empty():
				out.append({"texto": "Pode cuidar de mim? Pago com %s." % Itens.texto_lista(pag), "vai": "_v_enf",
					"efeitos": [{"vida": "enfermaria", "itens": pag}]})
	if not atual.is_empty() or rep < 0:
		return out                                 # um trabalho de cada vez; com reputação negativa não oferecem
	var papel := _papel(com, npc)
	if papel == "guarda":
		nos["_v_vigia"] = {"fala": "Ajuda é bem-vinda. Fica perto do portão, de olho na estrada, até a próxima troca. Se vier coisa, grita.",
			"opcoes": [{"texto": "Combinado.", "vai": "fim", "efeitos": [{"vida": "vigia"}]}, {"texto": "Agora não.", "vai": "fim"}]}
		out.append({"texto": "Precisa de ajuda na vigia?", "vai": "_v_vigia"})
	elif papel in ["pescador", "pescadora", "cacador", "catadora", "catador"]:
		var f: Dictionary = FORTES.get(_forte(com), FORTES["pesca"])
		nos["_v_forte"] = {"fala": str(f["fala"]),
			"opcoes": [{"texto": "Combinado.", "vai": "fim", "efeitos": [{"vida": "forte"}]}, {"texto": "Agora não.", "vai": "fim"}]}
		out.append({"texto": str(f["texto"]), "vai": "_v_forte"})
	elif papel == "lider":
		nos["_v_servico"] = {"fala": "...", "_dinamico": true}
		out.append({"texto": "Tem algum serviço ou recado?", "vai": "_v_servico", "efeitos": [{"vida": "servico"}]})
	return out


## Quem deu um trabalho comenta quando você volta (etapa 14b): uma pergunta e duas respostas; depois a conversa segue
## normal. Vale por 3 dias; {} se não há nada a comentar.
static func abertura_retorno(com: String, npc: String, seguir: String) -> Dictionary:
	var k := "%s/%s" % [com, npc]
	if not retornos.has(k):
		return {}
	var r: Dictionary = retornos[k]
	retornos.erase(k)
	if _dia() - int(r["dia"]) > 3:
		return {}
	var o := "Obrigada" if Consequencias.feminino(com, npc) else "Obrigado"
	var pergunta := ""
	var resp: Array = []                         # [texto do jogador, fala do NPC]
	match str(r["tipo"]):
		"vigia":
			pergunta = "E a vigia? Viu alguma coisa na estrada?"
			resp = [["Tudo quieto.", "Melhor assim. Turno quieto é turno bom. %s por segurar o portão." % o],
				["Vi uns vultos lá longe, perto das árvores.", "(Franze a testa.) Vou avisar o pessoal da noite. Bom ter mais um par de olhos aqui."]]
		"conserto":
			pergunta = "Passei no muro agora há pouco. Ficou firme."
			resp = [["Deu trabalho, mas segura.", "Segura, sim. Uma noite a menos de medo. %s, de verdade." % o],
				["Precisando, é só chamar.", "Vou lembrar disso. Aqui ninguém esquece quem ajudou."]]
		_:
			match str(r["forte"]):
				"caca":
					pergunta = "Conferi os laços que você armou. Dois já pegaram coisa."
				"agricultura":
					pergunta = "Vi o canteiro. Capinou direitinho, hein? Tem gente aqui que não faz metade."
				_:
					pergunta = "(Confere os nós da rede.) Ficou boa. Melhor que muita que eu vejo por aí."
			resp = [["Aprendi olhando vocês.", "Pois aprendeu bem. Volta quando quiser: mão boa nunca sobra."],
				["Cansa mais do que parece.", "(Ri.) Cansa. Mas a comida de amanhã saiu dessas mãos. %s." % o]]
	var nos := {"_v_retorno": {"fala": pergunta, "opcoes": []}}
	for i in resp.size():
		var id := "_v_retorno%d" % i
		nos[id] = {"fala": str(resp[i][1]), "opcoes": [{"texto": "Outra coisa...", "vai": seguir}]}
		(nos["_v_retorno"]["opcoes"] as Array).append({"texto": str(resp[i][0]), "vai": id})
	return {"no": "_v_retorno", "nos": nos}


static func _forte(com: String) -> String:
	var f := str(Comunidades.dados(com).get("forte", "pesca")).to_lower()
	if f.begins_with("ca"):
		return "caca"
	if f.begins_with("agri") or f.begins_with("ro"):
		return "agricultura"
	return "pesca"


## Efeitos {"vida": ...} das conversas.
static func efeito(e: Dictionary, ctx: Dictionary, nos: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	var com := str(ctx["com"])
	var npc := str(ctx["npc"])
	var j: Node = ctx["jogador"]
	var g := Comunidades.geo(com)
	match str(e["vida"]):
		"vigia":
			var portao: Dictionary = _portao_perto(com, j)
			_comecar({"tipo": "vigia", "com": com, "ponto": portao.get("dentro", g.get("centro", Vector2.ZERO)), "raio": 9.0 * IsoMath.METRO,
				"horas": 2.0, "texto": "vigiando o portão", "rep": 3})
			msgs.append("Trabalho: vigie o portão por 2 h de jogo (fique perto dele).")
		"forte":
			var f: Dictionary = FORTES.get(_forte(com), FORTES["pesca"])
			var lista: Array = g.get("trabalho", [g.get("centro", Vector2.ZERO)])
			_comecar({"tipo": "forte", "com": com, "ponto": lista[randi() % lista.size()], "raio": 5.0 * IsoMath.METRO,
				"horas": 2.0, "texto": str(f["fazendo"]), "rep": 2})
			msgs.append("Trabalho: %s por 2 h de jogo (o HUD mostra para onde ir)." % str(f["fazendo"]))
		"servico":
			nos["_v_servico"] = _oferecer_servico(com, npc, j)
		"aceitar_servico":
			var s: Dictionary = e["servico"]
			_comecar(s.duplicate(true))
			if str(s["tipo"]) == "encomenda" and j != null:
				var resto: int = j.inventario.adicionar_parcial("encomenda", 1)
				if resto > 0:
					j.largar_item("encomenda", resto)
				msgs.append("Você recebeu a encomenda.")
			msgs.append("Recado: %s." % texto_atual())
		"entregar":
			if j != null:
				j.inventario.remover(str(atual["item"]), int(atual["qtd"]))
			var origem := str(atual["com"])
			var rep := int(atual.get("rep", 5))
			Reputacao.mudar(origem, rep, "cumpriu um recado")
			if origem != com:
				Reputacao.mudar(com, 3, "trouxe uma encomenda")
				var co := Simulacao.estado(origem)
				var cd := Simulacao.estado(com)
				if not co.is_empty() and not cd.is_empty():
					co["rel"][com] = int(co["rel"].get(com, 0)) + 5
					cd["rel"][origem] = int(cd["rel"].get(origem, 0)) + 5
				Simulacao.registrar_noticia(com, "Alguém de fora trouxe uma encomenda %s." % Comunidades.de(origem))
			else:
				Simulacao.ajustar(com, str(atual["item"]), int(atual["qtd"]))
			nos["_v_entrega"] = {"fala": "Obrigad%s. Vou mandar avisar que chegou." % ("a" if Consequencias.feminino(com, npc) else "o") \
				if origem != com else "Era disso mesmo que a gente precisava. Obrigado."}
			msgs.append("Recado cumprido (+%d de reputação %s)." % [rep, Comunidades.em_nome(origem)])
			DiarioPartida.evento("recado", "Cumpriu um recado %s (%s)." % [Comunidades.de(origem), texto_atual()])
			atual = {}
		"enfermaria":
			for it in e.get("itens", []):
				j.inventario.remover(str(it[0]), int(it[1]))
			tratado_dia[com] = _dia()
			var nivel := Simulacao.nivel_medico(com)
			j.vida = minf(j.vida_max, j.vida + (j.vida_max - j.vida) * clampf(nivel, 0.4, 1.0))
			var curou := ""
			var c := Simulacao.estado(com)
			var tipo := str((j.doenca as Dictionary).get("tipo", ""))
			if tipo in ["Disenteria", "Leptospirose", "Febre da carniça"] and int(c.get("remedio", 0)) > 0:
				c["remedio"] = int(c["remedio"]) - 1
				j.doenca = {}
				curou = " e deu o remédio para a %s" % tipo.to_lower()
			elif tipo != "":
				curou = ". Para %s eu não tenho remédio" % tipo.to_lower()
			nos["_v_enf"] = {"fala": "(Examina, limpa e enfaixa%s.) Pronto. Agora vê se não volta pior." % curou}
		"redencao":
			if not atual.is_empty():
				nos["_v_redencao"] = {"fala": "Termina primeiro o que você já começou. Depois a gente conversa."}
			else:
				var s := _buscar(com, npc, 8)
				nos["_v_redencao"] = {"fala": "Quer que confiem em você? Faz alguma coisa pela vila. %s" % _fala_buscar(s),
					"opcoes": [{"texto": "Combinado.", "vai": "fim", "efeitos": [{"vida": "aceitar_servico", "servico": s}]},
						{"texto": "Agora não.", "vai": "fim"}]}
		"presente":
			for it in e["itens"]:
				j.inventario.remover(str(it[0]), int(it[1]))
			presente_dia[com] = _dia()
			Reputacao.mudar(com, 4, "deu um presente à comunidade")
			msgs.append("Você deu %s." % Itens.texto_lista(e["itens"]))
	if not atual.is_empty() and not atual.has("npc"):
		atual["npc"] = npc                         # quem deu o trabalho comenta quando você voltar
	return msgs


static func _portao_perto(com: String, j: Node) -> Dictionary:
	var ps: Array = Comunidades.geo(com).get("portoes", [])
	if ps.is_empty():
		return {}
	var pj := IsoMath.tela_para_mundo((j as Node2D).global_position) if j != null else Vector2.ZERO
	var melhor: Dictionary = ps[0]
	for p in ps:
		if ((p as Dictionary)["meio"] as Vector2).distance_to(pj) < (melhor["meio"] as Vector2).distance_to(pj):
			melhor = p
	return melhor


## O líder oferece um serviço pela necessidade: buscar o que falta, levar uma encomenda à vizinha ou consertar o muro.
static func _oferecer_servico(com: String, npc: String, j: Node) -> Dictionary:
	var s: Dictionary = {}
	var fala := ""
	var c := Simulacao.estado(com)
	var vizinha := ""
	for outra in Comunidades.ids():
		if str(outra) != com and lider(str(outra)) != "" and int((c.get("rel", {}) as Dictionary).get(str(outra), 0)) > -30:
			vizinha = str(outra)
	var r := randf()
	if float(c.get("comida", 6.0)) < 2.5 or int(c.get("remedio", 3)) < 2 or (r < 0.35):
		s = _buscar(com, npc, 5)
		fala = _fala_buscar(s)
	elif vizinha != "" and r < 0.7:
		s = {"tipo": "encomenda", "com": com, "item": "encomenda", "qtd": 1, "destino_com": vizinha, "destino_npc": lider(vizinha), "rep": 5}
		fala = "Leva isso até %s, %s. Entrega na mão e volta." % [Consequencias.nome_npc(vizinha, lider(vizinha)), Comunidades.em_nome(vizinha)]
	else:
		var g := Comunidades.geo(com)
		var area: Rect2 = g["area"]
		var ponto := Vector2(area.position.x + randf_range(0.2, 0.8) * area.size.x, area.position.y + 40.0 if randf() < 0.5 else area.end.y - 40.0)
		s = {"tipo": "conserto", "com": com, "ponto": ponto, "raio": 4.0 * IsoMath.METRO, "horas": 1.5,
			"texto": "consertando o muro", "rep": 3, "consome": [["madeira", 3]]}
		fala = "O muro tá cedendo num trecho. Se tiver madeira (umas 3), dá uma mão lá. Eu te mostro onde."
		if j != null and j.inventario.contar("madeira") < 3:
			fala = "O muro tá cedendo num trecho, mas precisa de madeira, umas 3. Volta quando tiver."
			return {"fala": fala}
	return {"fala": fala, "opcoes": [{"texto": "Combinado.", "vai": "fim", "efeitos": [{"vida": "aceitar_servico", "servico": s}]},
		{"texto": "Agora não.", "vai": "fim"}]}


## Buscar o que a comunidade precisa (pela simulação) e entregar a 'npc'.
static func _buscar(com: String, npc: String, rep: int) -> Dictionary:
	var c := Simulacao.estado(com)
	var item := "sucata"
	var qtd := 6
	if float(c.get("comida", 6.0)) < 2.5:
		item = "comida"
		qtd = 5
	elif int(c.get("remedio", 3)) < 2:
		item = "bandagem"
		qtd = 2
	elif randf() < 0.5:
		item = ["madeira", "pano", "agua_limpa"][randi() % 3]
		qtd = {"madeira": 6, "pano": 4, "agua_limpa": 2}[item]
	return {"tipo": "buscar", "com": com, "item": item, "qtd": qtd, "destino_com": com, "destino_npc": npc, "rep": rep}


static func _fala_buscar(s: Dictionary) -> String:
	return "A gente tá precisando de %s. Traz %d e entrega pra mim." % [Itens.nome(str(s["item"])).to_lower(), int(s["qtd"])]


# ───────────────────────────── trabalho em andamento ─────────────────────────────

static func _comecar(t: Dictionary) -> void:
	t["progresso"] = 0.0
	atual = t
	_aviso_longe = false


static func texto_atual() -> String:
	if atual.is_empty():
		return ""
	match str(atual["tipo"]):
		"encomenda":
			return "leve a encomenda %s (%s)" % [_ao(str(atual["destino_com"]), str(atual["destino_npc"])), Comunidades.nome(str(atual["destino_com"]))]
		"buscar":
			return "traga %d %s %s" % [int(atual["qtd"]), Itens.nome(str(atual["item"])).to_lower(), _ao(str(atual["com"]), str(atual["destino_npc"]))]
	return "%s — %d%%" % [str(atual["texto"]), roundi(float(atual["progresso"]) * 100.0)]


## "ao Caio", "à Rosa", "à Dona Iracema", "ao Dr. Heitor".
static func _ao(com: String, npc: String) -> String:
	var quem := Consequencias.chamar(com, "", npc)
	if quem.begins_with("a ") or quem.begins_with("Dona "):
		return "à " + quem.trim_prefix("a ")
	if quem.begins_with("o "):
		return "ao " + quem.trim_prefix("o ")
	return "ao " + quem


## Linha do HUD: "TRABALHO: vigiando o portão — 40%" / "RECADO: leve a encomenda ao Caio (Santuário do Sol)".
static func linha_hud() -> String:
	if atual.is_empty():
		return ""
	var onde := ""
	var j := _jogador()
	if atual.has("ponto") and j != null:
		var v: Vector2 = (atual["ponto"] as Vector2) - IsoMath.tela_para_mundo(j.global_position)
		if v.length() > float(atual["raio"]):
			onde = " · vá até o lugar: %d m %s" % [roundi(v.length() / IsoMath.METRO), _direcao(v)]
	return ("RECADO: " if str(atual["tipo"]) in ["encomenda", "buscar"] else "TRABALHO: ") + texto_atual() + onde


## Direção na tela (norte = para cima): o mundo isométrico gira 45° em relação à tela.
static func _direcao(v: Vector2) -> String:
	var t := IsoMath.mundo_para_tela(v)
	var nomes := ["a leste", "a sudeste", "ao sul", "a sudoeste", "a oeste", "a noroeste", "ao norte", "a nordeste"]
	return nomes[posmod(roundi(t.angle() / (PI / 4.0)), 8)]


## Ponto do trabalho em andamento (para o mapa); Vector2.INF se não há.
static func ponto() -> Vector2:
	if atual.is_empty() or not atual.has("ponto"):
		return Vector2.INF
	return atual["ponto"]


## Chamado pelo GerenteComunidades a cada 0,5 s com as horas de jogo que passaram: avança o trabalho enquanto o
## jogador está no lugar.
static func passo(horas: float) -> void:
	if atual.is_empty() or not atual.has("ponto") or horas <= 0.0:
		return
	var j := _jogador()
	if j == null or bool(j.get("morto")):
		return
	var pj := IsoMath.tela_para_mundo(j.global_position)
	if pj.distance_to(atual["ponto"]) > float(atual["raio"]):
		if not _aviso_longe and float(atual["progresso"]) > 0.0:
			_aviso_longe = true
			j.aviso("Você se afastou do trabalho. Volte para continuar (%s)." % str(atual["texto"]))
		return
	_aviso_longe = false
	atual["progresso"] = minf(1.0, float(atual["progresso"]) + horas / float(atual["horas"]))
	if float(atual["progresso"]) >= 1.0:
		_concluir(j)


static func _concluir(j: Node) -> void:
	var com := str(atual["com"])
	for it in atual.get("consome", []):
		if j.inventario.contar(str(it[0])) < int(it[1]):
			j.aviso("Faltou %s para terminar o conserto." % Itens.nome(str(it[0])).to_lower())
			atual = {}
			return
	for it in atual.get("consome", []):
		j.inventario.remover(str(it[0]), int(it[1]))
	var chave := "%s/%d" % [com, _dia()]
	var ganho := mini(int(atual["rep"]), maxi(0, TETO_DIA - int(ganhos.get(chave, 0))))
	ganhos[chave] = int(ganhos.get(chave, 0)) + ganho
	Reputacao.mudar(com, ganho, "trabalho: " + str(atual["texto"]))
	var extra := ""
	match str(atual["tipo"]):
		"forte":
			Simulacao.ajustar(com, "comida", 3)
			if randf() < 0.35:
				var resto: int = j.inventario.adicionar_parcial("comida", 1)
				if resto > 0:
					j.largar_item("comida", resto)
				extra = " Ganhou 1 comida pela ajuda."
		"conserto":
			Simulacao.registrar_noticia(com, "Alguém de fora ajudou a consertar o muro %s." % Comunidades.de(com))
	if str(atual.get("npc", "")) != "" and str(atual["tipo"]) in ["vigia", "forte", "conserto"]:
		retornos["%s/%s" % [com, str(atual["npc"])]] = {"tipo": str(atual["tipo"]), "forte": _forte(com), "dia": _dia()}
	DiarioPartida.evento("trabalho", "Terminou um trabalho %s: %s (+%d de reputação)." % [Comunidades.em_nome(com), str(atual["texto"]), ganho])
	var volta := ""
	if retornos.has("%s/%s" % [com, str(atual.get("npc", ""))]):
		volta = " Passe para falar com %s." % Consequencias.nome_npc(com, str(atual["npc"]))
	j.aviso("Trabalho terminado (%s).%s%s%s" % [str(atual["texto"]), "" if ganho > 0 else " Já trabalhou bastante por hoje: sem reputação extra.", extra, volta])
	atual = {}


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	var a := atual.duplicate(true)
	if a.has("ponto"):
		var p: Vector2 = a["ponto"]
		a["ponto"] = [p.x, p.y]
	return {"atual": a, "ganhos": ganhos.duplicate(), "tratado": tratado_dia.duplicate(), "presente": presente_dia.duplicate(),
		"retornos": retornos.duplicate(true)}


static func restaurar(d: Dictionary) -> void:
	zerar()
	atual = (d.get("atual", {}) as Dictionary).duplicate(true)
	if atual.has("ponto"):
		var l: Array = atual["ponto"]
		atual["ponto"] = Vector2(float(l[0]), float(l[1]))
	for k in ["qtd", "rep"]:
		if atual.has(k):
			atual[k] = int(atual[k])
	for k in ["progresso", "horas", "raio"]:
		if atual.has(k):
			atual[k] = float(atual[k])
	for k in (d.get("ganhos", {}) as Dictionary):
		ganhos[str(k)] = int(d["ganhos"][k])
	for k in (d.get("tratado", {}) as Dictionary):
		tratado_dia[str(k)] = int(d["tratado"][k])
	for k in (d.get("presente", {}) as Dictionary):
		presente_dia[str(k)] = int(d["presente"][k])
	for k in (d.get("retornos", {}) as Dictionary):
		var r: Dictionary = d["retornos"][k]
		retornos[str(k)] = {"tipo": str(r.get("tipo", "")), "forte": str(r.get("forte", "pesca")), "dia": int(r.get("dia", 0))}
