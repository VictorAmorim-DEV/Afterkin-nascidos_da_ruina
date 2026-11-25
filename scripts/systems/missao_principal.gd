class_name MissaoPrincipal
extends RefCounted
## Missão principal do ato 1 (marco 3, etapa 3.7; docs/DECISOES_DESIGN.md, "O começo" e "Ato 1").
## É do mundo (do grupo, regra do co-op): o passo vale para todos e vai no save do mundo.
## Passos: 1 acordar e achar o Toné → 2 Dona Iracema → 3 Dr. Heitor → 4 "Veja com seus olhos" (achar o ninho) →
## 5 "A noite do ataque" → 6 desfecho. 99 = encerrada (o jogo fica livre). Cada passo aparece no "Objetivo atual" do
## diário (Diario.objetivo) e as falas entram na conversa como opções (DialogoUI), pelo efeito {"missao": "..."}.

const COM := "vila_dos_pescadores"
const MEDICO := "medico"
const PRIMEIRA_FALA := "O que aconteceu? Onde estou?"

const ENCERRADA := 99
## Quem conduz cada passo da conversa: passo -> id do NPC na Vila.
const QUEM := {1: "guarda_dia", 2: "lider", 3: "medico"}
const OBJETIVOS := {
	1: "Descobrir quem me trouxe: falar com o Toné, o guarda do portão da Vila.",
	2: "Falar com a Dona Iracema, a líder da Vila (de dia, na praça).",
	3: "Falar com o Dr. Heitor, o médico (de dia, na enfermaria).",
	4: "Veja com seus olhos: encontrar o ninho de morcegos de que o Dr. Heitor falou.",
	5: "Voltar para dentro do muro da Vila antes de escurecer.",
}
const ACHA_NINHO := 12.0 * IsoMath.METRO       ## chegar a esta distância de um ninho conta como "ver com seus olhos"

static var passo := 0                       ## 0 = ainda não acordou


static func zerar() -> void:
	passo = 0


## Índice da casa do médico na geometria da Vila (a enfermaria).
static func _casa_medico() -> int:
	for n in Comunidades.dados(COM).get("npcs", []):
		var nd: Dictionary = n
		if str(nd.get("id", "")) == MEDICO:
			return int(nd.get("casa", 0))
	return 0


## Ponto (mundo) na rua, em frente à enfermaria; INF se a Vila não existe.
static func ponto_enfermaria() -> Vector2:
	var g := Comunidades.geo(COM)
	if g.is_empty() or (g["casas"] as Array).is_empty():
		return Vector2.INF
	var casas: Array = g["casas"]
	return casas[_casa_medico() % casas.size()]


## Leva o jogador à porta da enfermaria, revela a Vila no mapa e, quando a casa terminar de ser construída,
## põe ele ao lado da cama (Edificio constrói fatiado; o prédio só fica 'pronto' depois de alguns quadros).
static func levar_a_enfermaria(j: Node) -> void:
	var p := ponto_enfermaria()
	if p == Vector2.INF:
		return
	var g := Comunidades.geo(COM)
	var area: Rect2 = g["area"]
	Descobertas.revelar_retangulo(area.grow(20.0 * IsoMath.METRO))
	var mundo := j.get_tree().get_first_node_in_group("mundo")
	if mundo != null and mundo.has_method("teleportar"):
		mundo.teleportar(p)
	_ir_para_a_cama(j)


static func _ir_para_a_cama(j: Node) -> void:
	var g := Comunidades.geo(COM)
	var lotes: Array = g.get("lotes", [])
	if lotes.is_empty():
		return
	var lote: Vector2 = lotes[_casa_medico() % lotes.size()]
	var arvore := j.get_tree()
	for k in 120:                                       # até ~60 s reais (a cutscene pausa a construção)
		var cama := _cama_da_casa(arvore, lote)
		if cama != Vector2.INF:
			if is_instance_valid(j):
				j.global_position = IsoMath.mundo_para_tela(cama)
			return
		await arvore.create_timer(0.5, true).timeout
		if not is_instance_valid(j):
			return


## Ponto (mundo) ao lado da cama do prédio do lote, ou INF se a casa ainda não está pronta.
static func _cama_da_casa(arvore: SceneTree, lote: Vector2) -> Vector2:
	for e in arvore.get_nodes_in_group("edificio"):
		var ed := e as Edificio
		if ed == null or not ed.pronto:
			continue
		var origem := IsoMath.tela_para_mundo(ed.global_position)
		if origem.distance_to(lote) > 3.0 * IsoMath.METRO:
			continue
		var camas: Array = ed.moveis.filter(func(m): return m.tipo == "cama")
		if camas.is_empty():
			return origem
		var m: Dictionary = camas[0]
		return origem + Vector2(m.x1 + 18.0, (m.y0 + m.y1) / 2.0)   # em pé, ao lado da cama
	return Vector2.INF


## Fim da cutscene: o personagem abre os olhos na enfermaria.
static func acordar(j: Node) -> void:
	if passo < 1:
		passo = 1
	j.aviso(PRIMEIRA_FALA)
	await j.get_tree().create_timer(5.0).timeout
	if is_instance_valid(j) and passo == 1:
		j.aviso("Alguém do lado de fora: \"Foi o Toné que trouxe, ontem à noite. Tá lá no portão.\"")


static func ativa() -> bool:
	return passo >= 1 and passo < ENCERRADA


## O objetivo do passo atual ("" sem missão): o diário mostra.
static func objetivo() -> String:
	return str(OBJETIVOS.get(passo, "")) if ativa() else ""


static func _avancar(para: int) -> void:
	if passo < para:
		passo = para
		DiarioPartida.evento("missao", "Missão principal: %s" % str(OBJETIVOS.get(para, "passo %d" % para)))


# ───────────────────────────── conversas ─────────────────────────────

const FALA_TONE := "Olha só, de pé! (Ele baixa a espingarda.) Fui eu, sim, cidadão. Ontem, voltando da ronda, achei " \
	+ "seu carro de rodas pro ar na estrada da costa, e três deles rondando, de olho brilhando. Dei dois tiros pro alto, " \
	+ "eles sumiram no mato, e eu te arrastei até a caminhonete. Procedimento: ninguém fica pra trás. (Ele desvia o " \
	+ "olhar.) Não mais.%s\n\nO Dr. Heitor costurou sua cabeça. Agora vai falar com a Dona Iracema. Aqui ninguém fica " \
	+ "sem ela saber."
const TONE_ORIGEM := {
	"policial": " Vi o distintivo no painel e pensei: esse é dos nossos.",
	"mecanico": " Ainda tentei desvirar o carro. Vai ter que arrumar outro, mecânico.",
	"enfermeiro": " Achei uma maleta de primeiros socorros no banco. O doutor ficou de olho nela.",
	"mestre_obras": " Tinha uma trena e um capacete no banco de trás. Muro aqui sempre precisa de quem entenda.",
}
const FALA_IRACEMA := "Então você é o achado do Toné. (Ela te mede de cima a baixo.) Escuta, {meu filho/minha filha}: " \
	+ "aqui a regra é simples. O portão abre às seis e fecha às seis, e depois disso não abre pra ninguém, nem pra mim. " \
	+ "Comida e cama a gente divide com quem trabalha: rede, peixe, muro, o que tiver. Ninguém aqui é de ferro, mas " \
	+ "ninguém fica parado.\n\nE o Dr. Heitor quer te ver. Vai lá antes que ele venha te buscar."
const FALA_HEITOR := "Ah, o paciente andando. Ótimo. Deixa eu ver esse corte... (Ele examina a sua cabeça.) " \
	+ "Cicatrizando. Você teve sorte de o Toné te achar antes deles.%s\n\nEu também preparo um soro que segura a " \
	+ "mordida por umas horas. Sai caro: os ingredientes estão acabando.\n\nE um pedido: vá até esse ninho, de dia, e " \
	+ "veja com seus olhos onde eles dormem. Não entre. Quem vê uma vez não volta mais tarde pra Vila."


## Opção da missão na conversa com quem conduz o passo atual (só na abertura).
static func opcoes(arvore: Dictionary, ctx: Dictionary, abertura: bool) -> Array:
	var out: Array = []
	if not abertura or not ativa() or str(ctx["com"]) != COM or str(QUEM.get(passo, "")) != str(ctx["npc"]):
		return out
	var nos: Dictionary = arvore["nos"]
	var j: Node = ctx["jogador"]
	match passo:
		1:
			var extra := str(TONE_ORIGEM.get(str(j.origem), "")) if j != null else ""
			nos["_m_tone"] = {"fala": FALA_TONE % extra, "efeitos": [{"missao": "tone"}],
				"opcoes": [{"texto": "Obrigado, Toné. Eu te devo essa.", "vai": "_m_tone_fim"}]}
			nos["_m_tone_fim"] = {"fala": "Deve nada. Só não me faça voltar lá fora pra te buscar de novo."}
			out.append({"texto": "Foi você que me trouxe pra cá?", "vai": "_m_tone"})
		2:
			nos["_m_iracema"] = {"fala": FALA_IRACEMA, "efeitos": [{"missao": "iracema"}]}
			out.append({"texto": "O Toné disse pra eu falar com a senhora.", "vai": "_m_iracema"})
		3:
			var contou := bool(Conversas.flags.get("heitor_conta_ninho", false))
			var hist := "" if contou else "\n\nVocê deve estar se perguntando o que era aquilo na estrada. " + Medicina.HISTORIA
			nos["_m_heitor"] = {"fala": FALA_HEITOR % hist, "efeitos": [{"missao": "heitor"}]}
			out.append({"texto": "A Dona Iracema disse que o senhor queria me ver.", "vai": "_m_heitor"})
	return out


## Efeito {"missao": acao} de uma fala da missão.
static func efeito(acao: String, ctx: Dictionary) -> PackedStringArray:
	var msgs: PackedStringArray = []
	match acao:
		"tone":
			_avancar(2)
		"iracema":
			Reputacao.mudar(COM, 5, "acolhido pela Vila")
			_avancar(3)
		"heitor":
			if not bool(Conversas.flags.get("heitor_conta_ninho", false)):
				msgs.append_array(Medicina.efeito("historia", ctx))   # a história do ninho, das feras e dos mortos
			_avancar(4)
	if ativa():
		msgs.append("Objetivo: %s" % objetivo())
	return msgs


## A cada segundo (DiarioUI): passos que se cumprem andando pelo mundo.
static func vigiar(j: Node) -> void:
	if passo != 4 or j == null or bool(j.morto):
		return
	var pj := IsoMath.tela_para_mundo(j.global_position)
	for p in MundoGen.ninhos():
		if p.distance_to(pj) <= ACHA_NINHO:
			_avancar(5)
			j.aviso("O cheiro de morcego e coisa podre. É aqui que eles dormem. Objetivo: %s" % objetivo())
			return


static func dados_para_salvar() -> Dictionary:
	return {"passo": passo}


static func restaurar(d: Dictionary) -> void:
	passo = int(d.get("passo", 0))
