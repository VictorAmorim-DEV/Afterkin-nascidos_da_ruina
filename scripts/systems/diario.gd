class_name Diario
extends RefCounted
## Diário do jogador (tecla J; marco 3, etapa 3.6; docs/DECISOES_DESIGN.md, "Diário do jogador").
## Separado do registro de playtest (DiarioPartida). O que é de cada personagem fica no jogador (`diario`, regra do
## co-op: abates, marcos, espécies vistas, tempo vivo); o que é do mundo (rumores, lugares, comunidades) vem dos
## sistemas que já guardam isso. Aqui ficam as regras e os textos; a tela é a DiarioUI.

const VE_M := 12.0                       ## distância em que um monstro conta como visto

## Espécies da página "Raças e espécies", em ordem. "ouvida" é o que se sabe por conversa; "vista", de perto.
const ESPECIES := [
	{"id": "human", "nome": "Humano", "raca": "Humanos",
		"ouvida": "Gente como você.",
		"vista": "Gente como você. Uns ajudam, uns roubam, e todo mundo tem medo do escuro."},
	{"id": "zombie", "nome": "Zumbi", "raca": "Necróticos",
		"ouvida": "Dizem que há mortos que levantam.",
		"vista": "Mortos que levantam. Lentos, mas não param, e a mordida deixa febre (a febre da carniça)."},
	{"id": "rat", "nome": "Rato gigante", "raca": "Bestiais",
		"ouvida": "Dizem que no sul tem gente que vira fera.",
		"vista": "Bichos do tamanho de um cão, em bando. Mordem e fogem. Há quem diga que alguns já foram gente."},
	{"id": "vampire", "nome": "Vampiro", "raca": "Profanos",
		"ouvida": "Os da noite. A Vila tranca o portão quando escurece por causa deles.",
		"vista": "Os da noite. Fogem do sol e dormem nas casas de dia. A mordida funda passa a infecção, e quem chega ao fim vira um deles."},
	{"id": "mae", "nome": "Mãe da Colônia", "raca": "Profanos",
		"ouvida": "O Dr. Heitor fala de uma coisa velha e inchada num ninho de morcegos, depois da curva do lago. O sangue dela segura a mordida.",
		"vista": "Velha, inchada, cercada de morcegos. Morde e chama a revoada. O sangue antigo dela é o ingrediente do antídoto."},
]

## Marcos que viram [✓] na página do registro, na voz do personagem.
const MARCOS := {
	"primeira_noite": "Sobrevivi à primeira noite.",
	"noite_ataque": "Sobrevivi à noite do ataque.",
	"mordido": "Fui mordido por um vampiro.",
	"curado": "Sobrevivi à mordida de um vampiro.",
	"transformado": "Virei um deles.",
	"mae": "Matei a Mãe da Colônia.",
	"medico": "Me tornei médico com o Dr. Heitor.",
}


static func _d(j: Node) -> Dictionary:
	var d: Dictionary = j.diario
	if not d.has("abates"):
		d["abates"] = {}
		d["marcos"] = {}
		d["especies"] = {}
		d["inicio_h"] = Reputacao.agora_h()
		d["vivo_desde_h"] = Reputacao.agora_h()
		d["mortes"] = 0
	return d


## Começo da partida (ou partida carregada sem diário): garante a estrutura e a própria espécie.
static func iniciar(j: Node) -> void:
	_d(j)
	ver(j, "human" if str(j.raca) == "human" else str(j.raca), false)


static func abate(j: Node, nome: String) -> void:
	if j == null:
		return
	var ab: Dictionary = _d(j)["abates"]
	ab[nome] = int(ab.get(nome, 0)) + 1


## Marca um marco (uma vez só). Devolve true se é novo.
static func marcar(j: Node, id: String) -> bool:
	if j == null:
		return false
	var m: Dictionary = _d(j)["marcos"]
	if m.has(id):
		return false
	m[id] = Reputacao.agora_h()
	return true


static func tem(j: Node, id: String) -> bool:
	return (_d(j)["marcos"] as Dictionary).has(id)


## Espécie vista de perto (ou só ouvida, com 'so_ouviu'). Vista vale mais que ouvida. Avisa quando é nova.
static func ver(j: Node, id: String, avisar: bool = true, so_ouviu: bool = false) -> void:
	if j == null:
		return
	var es: Dictionary = _d(j)["especies"]
	var antes := str(es.get(id, ""))
	var como := "ouvida" if so_ouviu else "vista"
	if antes == "vista" or antes == como:
		return
	es[id] = como
	if avisar:
		j.aviso("Diário: %s (%s) — %s." % [_nome_especie(id), _raca_especie(id), "ouvi falar" if so_ouviu else "vi com os meus olhos"])


## Ouviu falar de várias espécies de uma vez (uma conversa): um aviso só.
static func ouvir(j: Node, ids: Array) -> void:
	if j == null:
		return
	var es: Dictionary = _d(j)["especies"]
	var novas: PackedStringArray = []
	for id in ids:
		if not es.has(str(id)):
			ver(j, str(id), false, true)
			novas.append(_nome_especie(str(id)))
	if not novas.is_empty():
		j.aviso("Diário: ouvi falar de %s." % ", ".join(novas))


static func _especie(id: String) -> Dictionary:
	for e in ESPECIES:
		if str((e as Dictionary)["id"]) == id:
			return e
	return {}


static func _nome_especie(id: String) -> String:
	return str(_especie(id).get("nome", id))


static func _raca_especie(id: String) -> String:
	return str(_especie(id).get("raca", "?"))


## O jogador morreu e voltou: o tempo vivo recomeça.
static func morreu(j: Node) -> void:
	var d := _d(j)
	d["mortes"] = int(d["mortes"]) + 1
	d["vivo_desde_h"] = Reputacao.agora_h()


## A cada segundo (DiarioUI): espécies à vista e marcos que se medem pelo estado.
static func vigiar(j: Node) -> void:
	if j == null or bool(j.morto):
		return
	var pj := IsoMath.tela_para_mundo(j.global_position)
	for n in j.get_tree().get_nodes_in_group("inimigo"):
		var ini := n as Node2D
		if ini == null or not ini.is_visible_in_tree():
			continue
		if IsoMath.tela_para_mundo(ini.global_position).distance_to(pj) > VE_M * IsoMath.METRO:
			continue
		ver(j, "mae" if str(ini.get("chefe")) == "mae" else str(ini.get("raca")))
	if not tem(j, "primeira_noite"):                   # o dia seguinte amanheceu (6h) com ele vivo
		var ciclo := j.get_tree().get_first_node_in_group("ciclo_dia_noite")
		if ciclo != null and Reputacao.agora_h() - float(_d(j)["inicio_h"]) >= 12.0 and int(ciclo.minutos) >= 360 \
				and int(ciclo.minutos) < 720:
			if marcar(j, "primeira_noite"):
				j.aviso("O sol nasceu. Você sobreviveu à primeira noite.")
	if Medicina.completa():
		marcar(j, "medico")
	if Infeccao.ativa(j):
		marcar(j, "mordido")
	if str(j.raca) == "vampire" and tem(j, "mordido"):
		marcar(j, "transformado")


# ───────────────────────────── página 1: agora ─────────────────────────────

## O objetivo atual: a missão principal (3.7) manda; senão, a cura; senão, sobreviver.
static func objetivo(j: Node) -> String:
	var missao := MissaoPrincipal.objetivo()
	if missao != "":
		return missao
	if str(j.raca) == "vampire":
		return "Sobreviver como um deles: fugir do sol, dormir no escuro e achar sangue."
	if Infeccao.ativa(j):
		var e := Infeccao.estagio(j)
		if e >= 3:
			return "Não há mais cura. Fazer o que der com as horas que restam."
		if j.inventario.contar("antidoto") > 0:
			if e >= 2:
				return "Levar o antídoto ao Dr. Heitor: na Sede, ele só funciona com tratamento."
			return "Tomar o antídoto (mochila) antes que a infecção chegue à Sede."
		if j.inventario.contar("sangue_antigo") > 0:
			return "Levar o sangue antigo ao Dr. Heitor, na Vila dos Pescadores, para ele preparar o antídoto."
		if bool(Conversas.flags.get("heitor_conta_ninho", false)):
			return "Matar a Mãe da Colônia no ninho de morcegos, depois da curva do lago, e trazer o sangue antigo."
		return "Achar a cura: o médico da Vila dos Pescadores deve saber o que fazer com a mordida."
	return "Sobreviver. Conhecer a ilha e descobrir o que aconteceu com o mundo."


## "Vivo há 2 dias e 5 h" (desde a última morte) e o total da partida.
static func tempo(j: Node) -> String:
	var d := _d(j)
	var agora := Reputacao.agora_h()
	var vivo := maxf(0.0, agora - float(d["vivo_desde_h"]))
	var total := maxf(0.0, agora - float(d["inicio_h"]))
	var txt := "Vivo há %s." % _dias_horas(vivo)
	if int(d["mortes"]) > 0:
		txt += " No total, %s, e %d %s." % [_dias_horas(total), int(d["mortes"]), "morte" if int(d["mortes"]) == 1 else "mortes"]
	return txt


static func _dias_horas(h: float) -> String:
	var dias := floori(h / 24.0)
	var horas := floori(fmod(h, 24.0))
	if dias <= 0:
		return "%d h" % horas
	return "%d %s e %d h" % [dias, "dia" if dias == 1 else "dias", horas]


## Inimigos mortos por tipo, do mais abatido ao menos.
static func abates(j: Node) -> Array:
	var ab: Dictionary = _d(j)["abates"]
	var out: Array = []
	for k in ab:
		out.append([str(k), int(ab[k])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return out


## "O que está acontecendo comigo?": a doença com a causa e o estágio, e o que mais pesa no corpo e na vida social.
static func estado(j: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	if str(j.raca) == "vampire":
		out.append("Eu sou um deles agora. O sol queima e a fome é de sangue.")
	if Infeccao.ativa(j):
		var e := Infeccao.estagio(j)
		out.append("Infecção causada por mordida de vampiro — %s." % Infeccao.nome_estagio(e))
		out.append(_sente_infeccao(e))
		if float(j.doenca.get("pausa_h", 0.0)) > 0.0:
			out.append("O soro de contenção está segurando a infecção, por enquanto.")
		if Medicina.tem("diagnostico"):
			out.append("Pelo que eu sei de Medicina: faltam %d h para o fim." % maxi(0, ceili(float(j.doenca["horas"]))))
	elif not (j.doenca as Dictionary).is_empty():
		var tipo := str(j.doenca.get("tipo", ""))
		var causa := " (mordida de zumbi)" if str(j.doenca.get("origem", "")) == "zombie" else ""
		out.append("%s%s — %s." % [tipo, causa, ["começando", "piorando", "forte", "grave"][clampi(int(j.doenca.get("estagio", 0)), 0, 3)]])
	if float(j.sangue_t) > 0.0:
		out.append("Tem sangue no meu corpo: estou mais forte do que deveria.")
	if float(j.sequela_h) > 0.0:
		out.append("O corpo ainda está fraco do tratamento que falhou (vida máxima −%d)." % int(Infeccao.SEQUELA_VIDA))
	for com in Vigilancia.quarentena:
		out.append("Estou de quarentena %s: só o médico e o líder falam comigo." % Comunidades.de(str(com)))
	for com2 in Vigilancia.monstro:
		out.append("%s sabe o que eu virei. Lá, me tratam como monstro." % Comunidades.nome(str(com2)))
	if float(j.vida) < float(j.vida_max) * 0.35:
		out.append("Estou muito ferido.")
	if float(j.fome) < 25.0:
		out.append("Estou com muita fome.")
	if float(j.sede) < 25.0:
		out.append("Estou com muita sede.")
	if out.is_empty():
		out.append("Nada fora do normal. Por enquanto.")
	return out


static func _sente_infeccao(e: int) -> String:
	match e:
		0:
			return "A marca no pescoço arde. Por enquanto é só isso."
		1:
			return "Uma fome que comida não resolve. No escuro, enxergo mais do que deveria."
		2:
			return "O sol queima a pele e a comida enjoa. Meus olhos mudaram: quem olhar de perto vai notar."
	return "Algo dentro de mim parou de lutar. Nenhuma cura funciona mais."


# ───────────────────────────── página 2: registro ─────────────────────────────

## Seções do registro: [título, [[feito, texto], ...]]. O que é do mundo é lido dos sistemas que guardam.
static func registro(j: Node) -> Array:
	var out: Array = []
	var marcos: Array = []
	var m: Dictionary = _d(j)["marcos"]
	for id in MARCOS:
		if m.has(id):
			marcos.append([true, str(MARCOS[id])])
	if not marcos.is_empty():
		out.append(["O que já passei", marcos])
	var hab: Array = []
	for h in Medicina.HABILIDADES:
		hab.append([Medicina.tem(str(h)), "Medicina: %s" % str(Medicina.NOMES[h])])
	out.append(["Habilidades", hab])
	var lugares: Array = []
	for id2 in Respawn.lugares_descobertos(str(j.local_inicio)):
		lugares.append([true, Inicio.nome(str(id2))])
	for a in Descobertas.acampamentos:
		lugares.append([true, str(a)])
	for com in Respawn.comunidades_abertas():
		lugares.append([true, "%s (comunidade)" % Comunidades.nome(str(com))])
	out.append(["Lugares", lugares])
	var rum: Array = []
	for id3 in Conversas.rumores:
		var rid := str(id3)
		if rid.begins_with("nov_"):
			continue
		var achou := Rumores.descobertos.has(rid)
		rum.append([achou, "%s%s" % [Rumores.titulo(rid), " (achei o lugar)" if achou else ""]])
	if not rum.is_empty():
		out.append(["Rumores", rum])
	return out


# ───────────────────────────── página 3: raças e espécies ─────────────────────────────

## [[nome, raça, como ("" / "ouvida" / "vista"), texto], ...]
static func especies(j: Node) -> Array:
	var es: Dictionary = _d(j)["especies"]
	var out: Array = []
	for e in ESPECIES:
		var ed: Dictionary = e
		var como := str(es.get(str(ed["id"]), ""))
		out.append([str(ed["nome"]), str(ed["raca"]), como, str(ed.get(como, "")) if como != "" else ""])
	return out
