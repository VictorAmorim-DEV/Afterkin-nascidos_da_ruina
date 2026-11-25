class_name Vigilancia
extends RefCounted
## A comunidade e a infecção (marco 3.5c, docs/DECISOES_DESIGN.md Q60–Q66). Por jogador (co-op), por comunidade.
## - Vistoria no portão (Portaria): o guarda olha o pescoço e, da Sede em diante, os olhos. Contar → quarentena sem
##   perda; mentir passa com 85% com a mordida coberta e 25% descoberta (olhos à vista: ×0,3); em alerta ele exige
##   ver o pescoço. Pego mentindo: −10 e quarentena.
## - Quarentena: só o médico e o líder conversam; os serviços fecham; acaba quando o médico confirma a cura.
## - Quem nota: da Sede em diante, quem conversa com você de olhos à vista nota. Acoberta quem você ajudou (ou com a
##   comunidade te respeitando); o neutro conta com 50% (sempre, em alerta); o guarda e o desconfiado contam sempre.
##   Contado, a comunidade sabe em 1–2 h de jogo e vem a quarentena.
## - Transformado conhecido: reconhecido a menos de 6 m (de capuz e de noite, 50%): o guarda e até 3 dos mais fortes
##   atacam, os outros fogem, a reputação vai a −40 e o portão fecha.

const DESCONFIADOS := {"vila_dos_pescadores": "comerciante", "santuario_do_sol": "cacador"}
const MENTIRA_COBERTA := 0.85
const MENTIRA_DESCOBERTA := 0.25
const OLHOS_VISTOS := 0.3
const MULTA_MENTIRA := 10
const CONTA_NEUTRO := 0.5
const ATRASO_H := Vector2(1.0, 2.0)
const REP_ACOBERTA := 50
const VE_MONSTRO := 6.0 * IsoMath.METRO
const FORTES := ["guarda", "cacador", "pescador"]   ## quem pega em arma quando aparece um monstro
const AJUDANTES := 3
const QUEM_FALA := ["lider", "mestre_medicina"]     ## quem fala com quem está de quarentena

static var quarentena: Dictionary = {}       ## com -> true
static var monstro: Dictionary = {}          ## com -> true: sabem que você virou um deles
static var pendentes: Array = []             ## [{com, hora, quem}] alguém vai contar
static var notou: Dictionary = {}            ## "com/npc" -> dia em que notou
static var _visto: Dictionary = {}           ## "com/npc" -> true: já tentou te reconhecer (vampiro)


static func zerar() -> void:
	quarentena = {}
	monstro = {}
	pendentes = []
	notou = {}
	_visto = {}


static func em_quarentena(com: String) -> bool:
	return quarentena.has(com)


static func _papel(npc: Npc) -> String:
	return str(npc.dados.get("papel", ""))


## Esta pessoa fala com quem está de quarentena? (o médico e o líder)
static func fala_na_quarentena(npc: Npc) -> bool:
	if _papel(npc) in QUEM_FALA:
		return true
	return str(Simulacao.estado(npc.comunidade).get("medico", {}).get("npc", "")) == str(npc.dados.get("id", ""))


static func fala_quarentena(npc: Npc) -> String:
	if _papel(npc).begins_with("guarda") and npc.tarefa == "portao":
		return "Quarentena é quarentena. Se quiser sair, eu abro; entrar de novo, só com o doutor dizendo que tá limpo."
	return ["Fica aí, por favor. Vai pra enfermaria e espera o doutor.", "Não chega perto. Quarentena, né? Fala com o doutor.",
		"(Dá um passo para trás.) Desculpa. Vai pra enfermaria."][absi(hash(str(npc.dados.get("id", "")))) % 3]


static func por_em_quarentena(com: String, j: Node, motivo: String) -> void:
	if quarentena.has(com) or monstro.has(com):
		return
	quarentena[com] = true
	if j != null:
		j.aviso("Quarentena %s: só o médico e o líder falam com você até o médico dizer que você está limpo." % Comunidades.de(com))
	DiarioPartida.evento("quarentena", "Ficou de quarentena %s (%s)." % [Comunidades.de(com), motivo])
	Simulacao.registrar_noticia(com, "Tem alguém de fora mordido, de quarentena.", 1)


static func liberar(com: String) -> void:
	quarentena.erase(com)
	DiarioPartida.evento("quarentena", "Saiu da quarentena %s." % Comunidades.de(com))


# ───────────────────────────── vistoria no portão ─────────────────────────────

## O que o guarda decide sobre a infecção no controle. {} = nada a ver, segue o exame comum;
## senão {"entra", "fala", "aviso"?}. 'modo' "contar" = o jogador disse que foi mordido.
static func vistoria(j: Node, com: String, modo: String) -> Dictionary:
	if str(j.raca) == "vampire":
		conhecido_monstro(com, j)
		return {"entra": false, "fala": "(Ele recua um passo e engatilha.) Esses olhos... É UM DELES! ALARME!"}
	if not Infeccao.ativa(j):
		return {}
	if modo == "contar":
		por_em_quarentena(com, j, "contou a mordida no portão")
		return {"entra": true, "fala": "Mordido... (Ele respira fundo.) Obrigado por não mentir. Entra, mas direto pra enfermaria: vou chamar o doutor. Até ele dizer o contrário, quarentena."}
	if quarentena.has(com):
		return {"entra": true, "fala": "Ainda de quarentena. Direto pra enfermaria."}
	var alerta := Simulacao.alerta(com)
	var c := MENTIRA_COBERTA if (Infeccao.protegido(j) and not alerta) else MENTIRA_DESCOBERTA
	if Infeccao.olhos_mudados(j) and not Infeccao.olhos_cobertos(j):
		c *= OLHOS_VISTOS
	if randf() < c:
		return {}
	por_em_quarentena(com, j, "pego mentindo no portão")
	if modo == "confia":                    # quem confia em você chama o médico, sem castigo
		return {"entra": true, "fala": "(Ele segura o seu queixo e olha o pescoço.) Isso é mordida. Eu vou chamar o doutor agora. Quarentena, até ele dizer que tá limpo."}
	Reputacao.mudar(com, -MULTA_MENTIRA, "mentiu sobre a mordida no portão")
	return {"entra": true, "fala": "(Ele puxa a sua gola.) \"Nenhuma mordida\", é? Entra, e direto pra enfermaria. Quarentena.",
		"aviso": "Pego mentindo: a comunidade vai lembrar."}


# ───────────────────────────── quem nota ─────────────────────────────

## Ao abrir a conversa (DialogoUI): da Sede em diante, de olhos à vista, quem fala com você nota. Devolve a abertura
## de quem acoberta ({no, nos}) ou {} (nada, ou ele vai contar: o aviso diz que ele olhou demais).
static func abertura_notar(npc: Npc, ctx: Dictionary, seguir: String) -> Dictionary:
	var j: Node = ctx["jogador"]
	var com := npc.comunidade
	if com == "" or str(j.raca) != "human" or not Infeccao.olhos_mudados(j) or Infeccao.olhos_cobertos(j):
		return {}
	if quarentena.has(com) or monstro.has(com):
		return {}
	var chave := "%s/%s" % [com, str(npc.dados.get("id", ""))]
	var dia := int(Reputacao.agora_h() / 24.0)
	if int(notou.get(chave, -1)) == dia:
		return {}
	notou[chave] = dia
	var papel := _papel(npc)
	var sempre := papel.begins_with("guarda") or str(DESCONFIADOS.get(com, "")) == str(npc.dados.get("id", ""))
	if not sempre and acoberta(npc):
		return {"no": "_acoberta", "nos": {"_acoberta": {"fala": "(Baixinho.) Vi seus olhos. Não vou contar pra ninguém... mas se cuida.",
			"opcoes": [{"texto": "Obrigado.", "vai": seguir}]}}}
	if sempre or Simulacao.alerta(com) or randf() < CONTA_NEUTRO:
		pendentes.append({"com": com, "hora": Reputacao.agora_h() + randf_range(ATRASO_H.x, ATRASO_H.y), "quem": npc.nome()})
	j.aviso("%s olhou para os seus olhos por tempo demais." % npc.nome())
	return {}


## Quem acoberta: alguém que você ajudou (tratou, curou) ou com a comunidade te respeitando.
static func acoberta(npc: Npc) -> bool:
	var com := npc.comunidade
	var id := str(npc.dados.get("id", ""))
	if Reputacao.valor(com) >= REP_ACOBERTA:
		return true
	return bool(Conversas.flags.get("%s_%s_tratado" % [com, id], false)) or bool(Conversas.flags.get("%s_%s_curado" % [com, id], false))


# ───────────────────────────── transformado ─────────────────────────────

## Sabem que você virou um deles: reputação a −40, portão fechado, o guarda e os fortes atacam.
static func conhecido_monstro(com: String, j: Node) -> void:
	if monstro.has(com):
		return
	monstro[com] = true
	quarentena.erase(com)
	var rep := Reputacao.valor(com)
	if rep > -40:
		Reputacao.mudar(com, -40 - rep, "viram que você virou um deles")
	if j != null:
		j.aviso("%s sabe o que você é agora. O portão fechou, e os guardas vêm atrás de você." % Comunidades.nome(com))
	DiarioPartida.evento("monstro", "%s descobriu que virou vampiro." % Comunidades.nome(com))
	Simulacao.registrar_noticia(com, "Um deles esteve aqui dentro, com cara de gente.", 3)


## Este morador parte para cima do monstro? (o guarda e até AJUDANTES dos mais fortes)
static func ataca(npc: Npc) -> bool:
	var com := npc.comunidade
	if not monstro.has(com):
		return false
	var papel := _papel(npc)
	if papel.begins_with("guarda"):
		return true
	if not papel in FORTES:
		return false
	var n := 0
	for o in npc.get_tree().get_nodes_in_group("npc"):
		var x := o as Npc
		if x == null or x.comunidade != com or x.morto or _papel(x).begins_with("guarda") or not _papel(x) in FORTES:
			continue
		if x == npc:
			return n < AJUDANTES
		n += 1
	return false


# ───────────────────────────── a cada meio segundo ─────────────────────────────

static func passo(arv: SceneTree) -> void:
	var agora := Reputacao.agora_h()
	var j := arv.get_first_node_in_group("jogador") as Node2D
	for i in range(pendentes.size() - 1, -1, -1):
		var p: Dictionary = pendentes[i]
		if agora < float(p["hora"]):
			continue
		pendentes.remove_at(i)
		var com := str(p["com"])
		if j != null and Infeccao.ativa(j) and not quarentena.has(com):
			por_em_quarentena(com, j, "%s contou dos seus olhos" % str(p["quem"]))
			Simulacao.registrar_noticia(com, "%s contou que viu os olhos de um deles em alguém de fora." % str(p["quem"]), 2)
	if j == null or bool(j.morto):
		return
	if str(j.raca) == "vampire":
		_reconhecer(arv, j)


## Vampiro perto de um morador acordado: ele te reconhece (de capuz e de noite, metade das vezes).
static func _reconhecer(arv: SceneTree, j: Node2D) -> void:
	var pj := IsoMath.tela_para_mundo(j.global_position)
	for n in arv.get_nodes_in_group("npc"):
		var npc := n as Npc
		if npc == null or npc.comunidade == "" or npc.morto or npc.dormindo or npc.desacordado() or monstro.has(npc.comunidade):
			continue
		if IsoMath.tela_para_mundo(npc.global_position).distance_to(pj) > VE_MONSTRO or not Reputacao._viu(npc, j, pj):
			continue
		var chave := "%s/%s" % [npc.comunidade, str(npc.dados.get("id", ""))]
		if _visto.has(chave):
			continue
		_visto[chave] = true
		if Sangue.rosto_coberto(j) and j._eh_noite() and randf() < 0.5:
			continue
		npc.falar("É UM DELES!", 3.0)
		conhecido_monstro(npc.comunidade, j)
		return


static func dados_para_salvar() -> Dictionary:
	return {"quarentena": quarentena.duplicate(), "monstro": monstro.duplicate(), "pendentes": pendentes.duplicate(true),
		"notou": notou.duplicate()}


static func restaurar(d: Dictionary) -> void:
	zerar()
	quarentena = (d.get("quarentena", {}) as Dictionary).duplicate()
	monstro = (d.get("monstro", {}) as Dictionary).duplicate()
	pendentes = (d.get("pendentes", []) as Array).duplicate(true)
	notou = (d.get("notou", {}) as Dictionary).duplicate()
