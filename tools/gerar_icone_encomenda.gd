extends SceneTree
## Gera o ícone da encomenda (marco 2, etapa 12: recados entre comunidades), no tamanho dos ícones existentes.
## Rodar: <godot> --headless --path . -s tools/gerar_icone_encomenda.gd
## Depois: <godot> --headless --import, para criar o .import.

const PASTA := "res://assets/ui/icons/icon_%s.png"
const BORDA := Color(0.1, 0.09, 0.08, 1.0)


func _init() -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(PASTA % "comida"))
	var n: int = ref.get_width() if ref != null else 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	_ret(img, s, 18.0, 34.0, 110.0, 108.0, Color(0.62, 0.48, 0.32), true)     # caixa de papelão
	_ret(img, s, 18.0, 34.0, 110.0, 50.0, Color(0.7, 0.55, 0.37), true)       # aba de cima
	_ret(img, s, 60.0, 30.0, 68.0, 112.0, Color(0.82, 0.76, 0.6), false)      # corda vertical
	_ret(img, s, 14.0, 66.0, 114.0, 74.0, Color(0.82, 0.76, 0.6), false)      # corda horizontal
	_ret(img, s, 56.0, 20.0, 72.0, 34.0, Color(0.82, 0.76, 0.6), false)       # laço
	img.save_png(ProjectSettings.globalize_path(PASTA % "encomenda"))
	print("ícone gerado (%d px)" % n)
	quit()


func _ret(img: Image, s: float, x0: float, y0: float, x1: float, y1: float, cor: Color, borda: bool) -> void:
	var a := Vector2i(roundi(x0 * s), roundi(y0 * s))
	var b := Vector2i(roundi(x1 * s), roundi(y1 * s))
	var e := maxi(1, roundi(2.0 * s))
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			var na_borda := borda and (x < a.x + e or x >= b.x - e or y < a.y + e or y >= b.y - e)
			img.set_pixel(x, y, BORDA if na_borda else cor)
