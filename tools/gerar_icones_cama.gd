extends SceneTree
## Gera os ícones de inventário do pano e da cama (marco 2, etapa 2) e do rádio de pilha (etapa 9), no tamanho dos
## ícones existentes.
## Rodar: <godot> --headless --path . -s tools/gerar_icones_cama.gd
## Depois: <godot> --headless --import, para criar os .import.

const PASTA := "res://assets/ui/icons/icon_%s.png"
const BORDA := Color(0.1, 0.09, 0.08, 1.0)


func _init() -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(PASTA % "comida"))
	var n: int = ref.get_width() if ref != null else 128
	_pano(n).save_png(ProjectSettings.globalize_path(PASTA % "pano"))
	_cama(n).save_png(ProjectSettings.globalize_path(PASTA % "cama"))
	_radio(n).save_png(ProjectSettings.globalize_path(PASTA % "radio"))
	print("ícones gerados (%d px)" % n)
	quit()


## Retângulo cheio com borda de 2 px (coordenadas na grade de 128, escaladas para n).
func _ret(img: Image, s: float, x0: float, y0: float, x1: float, y1: float, cor: Color) -> void:
	var a := Vector2i(roundi(x0 * s), roundi(y0 * s))
	var b := Vector2i(roundi(x1 * s), roundi(y1 * s))
	var e := maxi(1, roundi(2.0 * s))
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			var na_borda := x < a.x + e or x >= b.x - e or y < a.y + e or y >= b.y - e
			img.set_pixel(x, y, BORDA if na_borda else cor)


## Pano dobrado: três camadas de tecido xadrez empilhadas.
func _pano(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	var cores := [Color(0.62, 0.3, 0.26), Color(0.32, 0.42, 0.6), Color(0.78, 0.72, 0.58)]
	for k in 3:
		var y0 := 34.0 + k * 22.0
		_ret(img, s, 18.0 + k * 4.0, y0, 110.0 - k * 4.0, y0 + 26.0, cores[k])
	# listras do xadrez na camada de cima
	for x in range(30, 100, 14):
		for y in range(roundi(36 * s), roundi(58 * s)):
			img.set_pixel(roundi(x * s), y, Color(0.45, 0.2, 0.18))
	return img


## Cama vista de lado: estrado, colchão, travesseiro, cobertor e cabeceira.
func _cama(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	var madeira := Color(0.47, 0.35, 0.24)
	_ret(img, s, 10.0, 34.0, 24.0, 96.0, madeira)            # cabeceira
	_ret(img, s, 106.0, 58.0, 118.0, 96.0, madeira)          # pé
	_ret(img, s, 10.0, 74.0, 118.0, 88.0, madeira)           # estrado
	_ret(img, s, 22.0, 58.0, 108.0, 76.0, Color(0.6, 0.55, 0.45))    # colchão
	_ret(img, s, 24.0, 48.0, 50.0, 62.0, Color(0.8, 0.77, 0.7))      # travesseiro
	_ret(img, s, 52.0, 54.0, 108.0, 68.0, Color(0.34, 0.38, 0.47))   # cobertor
	return img


## Rádio de pilha: caixa com alto-falante gradeado, dial e antena.
func _radio(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	for k in 40:                                      # antena inclinada
		var x := roundi((84 + k * 0.6) * s)
		var y := roundi((44 - k) * s)
		for d in 2:
			if x + d < n and y >= 0:
				img.set_pixel(x + d, y, BORDA)
	_ret(img, s, 14.0, 44.0, 114.0, 108.0, Color(0.36, 0.3, 0.24))     # caixa
	_ret(img, s, 24.0, 54.0, 66.0, 98.0, Color(0.18, 0.17, 0.16))      # alto-falante
	for y in range(58, 96, 6):
		for x in range(roundi(26 * s), roundi(64 * s)):
			img.set_pixel(x, roundi(y * s), Color(0.42, 0.4, 0.36))
	_ret(img, s, 74.0, 56.0, 106.0, 70.0, Color(0.85, 0.78, 0.5))      # dial
	_ret(img, s, 80.0, 80.0, 94.0, 94.0, Color(0.6, 0.58, 0.55))       # botão
	return img
