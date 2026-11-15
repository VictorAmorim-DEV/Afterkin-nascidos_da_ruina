extends SceneTree
## Gera os normal maps (<imagem>_n.png) dos sprites que reagem à luz com relevo: veículos, pedras, caixotes, barris,
## sacos de areia e barricadas. Rodar:  godot --headless --path . -s res://tools/gerar_normais.gd
## Depois: godot --headless --import --path .   (para a Godot importar os PNGs novos)

const PASTA := "res://assets/sprites_hd_recortados/objetos_natureza/"
const IMAGENS := ["veiculo_01", "veiculo_02", "veiculo_03", "veiculo_04", "veiculo_05", "veiculo_06", "pedra_03", "pedra_05",
	"recipiente_01", "recipiente_02", "recipiente_04", "barricada_01", "barricada_02", "barricada_03", "barricada_05",
	"barricada_07", "barricada_08"]


func _initialize() -> void:
	for nome in IMAGENS:
		var tex: Texture2D = load(PASTA + nome + ".png")
		var n := Relevo.gerar(tex.get_image())
		var destino := ProjectSettings.globalize_path(PASTA + nome + "_n.png")
		print(nome, " -> ", n.save_png(destino))
	quit()
