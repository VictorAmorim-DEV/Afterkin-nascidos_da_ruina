extends SceneTree
## Gera os ícones de inventário dos itens da Medicina (marco 2, etapa 11): manual de pronto-socorro, soro caseiro e
## kit cirúrgico, no tamanho dos ícones existentes.
## Rodar: <godot> --headless --path . -s tools/gerar_icones_medicina.gd
## Depois: <godot> --headless --import, para criar os .import.

const PASTA := "res://assets/ui/icons/icon_%s.png"
const BORDA := Color(0.1, 0.09, 0.08, 1.0)


func _init() -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(PASTA % "comida"))
	var n: int = ref.get_width() if ref != null else 128
	_manual(n).save_png(ProjectSettings.globalize_path(PASTA % "manual_medico"))
	_soro(n).save_png(ProjectSettings.globalize_path(PASTA % "soro"))
	_kit(n).save_png(ProjectSettings.globalize_path(PASTA % "kit_cirurgico"))
	print("ícones gerados (%d px)" % n)
	quit()


## Retângulo cheio com borda de 2 px (coordenadas na grade de 128, escaladas para n).
func _ret(img: Image, s: float, x0: float, y0: float, x1: float, y1: float, cor: Color, borda: bool = true) -> void:
	var a := Vector2i(roundi(x0 * s), roundi(y0 * s))
	var b := Vector2i(roundi(x1 * s), roundi(y1 * s))
	var e := maxi(1, roundi(2.0 * s))
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			var na_borda := borda and (x < a.x + e or x >= b.x - e or y < a.y + e or y >= b.y - e)
			img.set_pixel(x, y, BORDA if na_borda else cor)


## Cruz vermelha (centro cx, cy; braço de meia largura w e meio comprimento l).
func _cruz(img: Image, s: float, cx: float, cy: float, w: float, l: float, cor: Color) -> void:
	_ret(img, s, cx - w, cy - l, cx + w, cy + l, cor, false)
	_ret(img, s, cx - l, cy - w, cx + l, cy + w, cor, false)


## Livro de capa verde-escura com a cruz vermelha num quadro branco e as folhas aparecendo embaixo.
func _manual(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	_ret(img, s, 26.0, 22.0, 104.0, 112.0, Color(0.86, 0.83, 0.74))          # folhas
	_ret(img, s, 22.0, 16.0, 100.0, 106.0, Color(0.22, 0.36, 0.3))           # capa
	_ret(img, s, 22.0, 16.0, 32.0, 106.0, Color(0.16, 0.26, 0.22))           # lombada
	_ret(img, s, 46.0, 36.0, 88.0, 78.0, Color(0.92, 0.9, 0.84))             # quadro branco
	_cruz(img, s, 67.0, 57.0, 5.0, 15.0, Color(0.78, 0.16, 0.14))
	_ret(img, s, 44.0, 86.0, 90.0, 90.0, Color(0.7, 0.66, 0.5), false)       # título
	return img


## Garrafa transparente com soro (líquido turvo claro) e um rótulo com a cruz.
func _soro(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	_ret(img, s, 56.0, 10.0, 72.0, 22.0, Color(0.25, 0.45, 0.7))             # tampa
	_ret(img, s, 54.0, 20.0, 74.0, 36.0, Color(0.74, 0.84, 0.86))            # gargalo
	_ret(img, s, 38.0, 34.0, 90.0, 116.0, Color(0.74, 0.84, 0.86))           # corpo
	_ret(img, s, 42.0, 56.0, 86.0, 112.0, Color(0.9, 0.88, 0.72), false)     # soro
	_ret(img, s, 44.0, 66.0, 84.0, 96.0, Color(0.96, 0.95, 0.9))             # rótulo
	_cruz(img, s, 64.0, 81.0, 3.0, 9.0, Color(0.78, 0.16, 0.14))
	return img


## Estojo de lona aberto: lâmina, tesoura (dois aros), agulha com linha e um rolo de pano.
func _kit(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	_ret(img, s, 10.0, 30.0, 118.0, 100.0, Color(0.42, 0.44, 0.34))          # estojo
	_ret(img, s, 16.0, 36.0, 112.0, 94.0, Color(0.52, 0.54, 0.42), false)    # forro
	_ret(img, s, 24.0, 44.0, 30.0, 86.0, Color(0.78, 0.8, 0.82))             # lâmina
	_ret(img, s, 24.0, 70.0, 30.0, 86.0, Color(0.3, 0.26, 0.22))             # cabo
	_ret(img, s, 40.0, 44.0, 46.0, 72.0, Color(0.78, 0.8, 0.82))             # tesoura
	_ret(img, s, 36.0, 72.0, 46.0, 82.0, Color(0.2, 0.2, 0.22))
	_ret(img, s, 46.0, 72.0, 56.0, 82.0, Color(0.2, 0.2, 0.22))
	_ret(img, s, 64.0, 44.0, 67.0, 80.0, Color(0.85, 0.86, 0.88), false)     # agulha
	_ret(img, s, 67.0, 50.0, 70.0, 84.0, Color(0.15, 0.15, 0.4), false)      # linha
	_ret(img, s, 78.0, 48.0, 106.0, 84.0, Color(0.92, 0.9, 0.84))            # rolo de pano
	_ret(img, s, 78.0, 60.0, 106.0, 64.0, Color(0.8, 0.78, 0.7), false)
	_cruz(img, s, 92.0, 39.0, 2.0, 5.0, Color(0.78, 0.16, 0.14))
	return img
