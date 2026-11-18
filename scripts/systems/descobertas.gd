class_name Descobertas
extends RefCounted
## O que o jogador já conhece do mundo (docs/DECISOES_DESIGN.md, ajustes do playtest, item 3):
## - a névoa do mapa: uma máscara de células de 8 px do mapa-base (1024 u, ~21 m), revelada num raio em volta dele;
## - os acampamentos descobertos (no mapa, "?" até chegar perto; aí aparece "Local descoberto: ...");
## - o marcador que ele pôs no mapa.
## Cidades e vilarejos têm o nome conhecido desde o começo; os ícones (hospital, mercado...) só aparecem nas células
## já reveladas. Tudo entra no save.

const CELULA := 8                                       ## px do mapa-base por célula da névoa
const RAIO_REVELA_M := 60.0
const RAIO_ACAMPAMENTO := 1100.0                        ## u: a mesma distância do nome do lugar no HUD
## Usos de prédio que viram ícone no mapa, com o rótulo da legenda.
const POI := {"hospital": "Hospital", "farmacia": "Farmácia", "mercado": "Supermercado", "delegacia": "Delegacia",
	"posto": "Posto de combustível", "oficina": "Oficina", "escola": "Escola", "igreja": "Igreja",
	"restaurante": "Restaurante"}

static var mascara: Image = null                       ## L8: 255 = revelado
static var versao := 0                                   ## muda quando a máscara muda (o mapa refaz a textura)
static var acampamentos: Array = []                      ## nomes descobertos
static var marcador := Vector2.INF                       ## ponto do mundo marcado no mapa (INF = nenhum)
static var _pois: Array = []


static func _w() -> int:
	return ceili(float(MinimapaBase.W) / CELULA)


static func _h() -> int:
	return ceili(float(MinimapaBase.H) / CELULA)


## Começo de partida: nada descoberto.
static func zerar() -> void:
	mascara = Image.create_empty(_w(), _h(), false, Image.FORMAT_L8)
	acampamentos = []
	marcador = Vector2.INF
	versao += 1


static func _garantir() -> void:
	if mascara == null:
		zerar()


## Revela um círculo de 'raio_m' metros em volta de 'p' (mundo). Devolve true se algo novo apareceu.
static func revelar(p: Vector2, raio_m: float = RAIO_REVELA_M) -> bool:
	_garantir()
	var cel := MinimapaBase.PX * CELULA
	var c := p / cel
	var r := raio_m * IsoMath.METRO / cel
	var novo := false
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if x < 0 or y < 0 or x >= mascara.get_width() or y >= mascara.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(c) > r:
				continue
			if mascara.get_pixel(x, y).r < 0.5:
				mascara.set_pixel(x, y, Color.WHITE)
				novo = true
	if novo:
		versao += 1
	return novo


## Revela um retângulo inteiro do mundo (a cidade onde o personagem morava).
static func revelar_retangulo(r: Rect2) -> void:
	_garantir()
	var cel := MinimapaBase.PX * CELULA
	for y in range(maxi(0, floori(r.position.y / cel)), mini(mascara.get_height(), ceili(r.end.y / cel))):
		for x in range(maxi(0, floori(r.position.x / cel)), mini(mascara.get_width(), ceili(r.end.x / cel))):
			mascara.set_pixel(x, y, Color.WHITE)
	versao += 1


static func revelado(p: Vector2) -> bool:
	_garantir()
	var cel := MinimapaBase.PX * CELULA
	var x := floori(p.x / cel)
	var y := floori(p.y / cel)
	if x < 0 or y < 0 or x >= mascara.get_width() or y >= mascara.get_height():
		return false
	return mascara.get_pixel(x, y).r > 0.5


## Acampamento perto de 'p' ainda não descoberto: marca e devolve o nome ("" se nada novo).
static func descobrir_acampamento(p: Vector2) -> String:
	for c in MundoGen.acampamentos():
		var cd: Dictionary = c
		if not acampamentos.has(cd["nome"]) and p.distance_to(cd["c"]) < RAIO_ACAMPAMENTO:
			acampamentos.append(cd["nome"])
			return str(cd["nome"])
	return ""


## Pontos de interesse de todas as áreas urbanas: [{"p": centro (mundo), "uso": ...}] (calculado uma vez).
static func pois() -> Array:
	if not _pois.is_empty():
		return _pois
	for b in Quadras.blocos():
		var bv: Vector3i = b
		for s in Quadras._bloco(bv.x, bv.y, bv.z)["specs"]:
			var sd: Dictionary = s
			if sd["k"] != "edificio" or not sd.has("o"):
				continue
			var uso: String = str((sd["o"] as Dictionary).get("uso", ""))
			if POI.has(uso):
				var tam := Vector2(int(sd["w"]), int(sd["h"])) * Edificio.TILE
				_pois.append({"p": (sd["p"] as Vector2) + tam * 0.5, "uso": uso})
	return _pois


# ───────────────────────────── save ─────────────────────────────

static func dados_para_salvar() -> Dictionary:
	_garantir()
	return {"mascara": Marshalls.raw_to_base64(mascara.get_data().compress(FileAccess.COMPRESSION_ZSTD)),
		"tam": mascara.get_data().size(), "acampamentos": acampamentos.duplicate(),
		"marcador": [] if marcador == Vector2.INF else [marcador.x, marcador.y]}


static func restaurar(d: Dictionary) -> void:
	zerar()
	if d.is_empty():
		return
	var bruto := Marshalls.base64_to_raw(str(d.get("mascara", "")))
	var dados := bruto.decompress(int(d.get("tam", 0)), FileAccess.COMPRESSION_ZSTD)
	if dados.size() == _w() * _h():
		mascara = Image.create_from_data(_w(), _h(), false, Image.FORMAT_L8, dados)
	acampamentos = (d.get("acampamentos", []) as Array).duplicate()
	var m: Array = d.get("marcador", [])
	marcador = Vector2(float(m[0]), float(m[1])) if m.size() == 2 else Vector2.INF
	versao += 1
