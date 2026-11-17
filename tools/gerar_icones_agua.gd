extends SceneTree
## Gera os ícones de inventário da garrafa vazia, água suja, água limpa e fogueira (etapa 3 do marco 1),
## no tamanho dos ícones existentes. Rodar: <godot> --headless --path . -s tools/gerar_icones_agua.gd
## Depois: <godot> --headless --import, para criar os .import.

const PASTA := "res://assets/ui/icons/icon_%s.png"


func _init() -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(PASTA % "comida"))
	var n: int = ref.get_width() if ref != null else 128
	_garrafa(n, Color(0, 0, 0, 0)).save_png(ProjectSettings.globalize_path(PASTA % "garrafa"))
	_garrafa(n, Color(0.52, 0.46, 0.28, 0.95)).save_png(ProjectSettings.globalize_path(PASTA % "agua_suja"))
	_garrafa(n, Color(0.38, 0.68, 0.95, 0.95)).save_png(ProjectSettings.globalize_path(PASTA % "agua_limpa"))
	_fogueira(n).save_png(ProjectSettings.globalize_path(PASTA % "fogueira"))
	print("ícones gerados (%d px)" % n)
	quit()


## Garrafa de plástico vista de frente; 'liquido' com alfa 0 = vazia.
func _garrafa(n: int, liquido: Color) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	var vidro := Color(0.82, 0.9, 0.95, 0.55)
	var borda := Color(0.12, 0.16, 0.2, 1.0)
	for y in n:
		for x in n:
			var px := (x - n * 0.5) / s
			var py := y / s
			var meia := 0.0                      # meia-largura da garrafa nesta altura
			if py >= 14.0 and py < 24.0:
				meia = 9.0                         # tampa
			elif py >= 24.0 and py < 38.0:
				meia = lerpf(9.0, 24.0, (py - 24.0) / 14.0)   # gargalo abrindo para o ombro
			elif py >= 38.0 and py <= 116.0:
				meia = 24.0
			if meia <= 0.0 or absf(px) > meia + 2.0:
				continue
			var c := vidro
			if py < 24.0:
				c = Color(0.2, 0.45, 0.75, 1.0)    # tampa azul
			elif py > 60.0 and liquido.a > 0.0:
				c = liquido
			if absf(px) > meia or py > 114.0 or (py >= 14.0 and py < 16.0):
				c = borda
			elif absf(px + meia * 0.55) < 3.0 and py > 40.0 and py < 108.0:
				c = c.lightened(0.45)              # reflexo
			img.set_pixel(x, y, c)
	return img


func _fogueira(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	for y in n:
		for x in n:
			var px := (x - n * 0.5) / s
			var py := y / s
			var c := Color(0, 0, 0, 0)
			# chamas: três triângulos arredondados
			var h := 1.0 - (py - 30.0) / 70.0      # 1 no alto, 0 na base
			if py > 30.0 and py < 100.0:
				var larg := (1.0 - h) * 34.0
				if absf(px) < larg:
					c = Color(0.95, 0.4, 0.08)
					if absf(px) < larg * 0.6 and py > 50.0:
						c = Color(1.0, 0.72, 0.15)
					if absf(px) < larg * 0.3 and py > 72.0:
						c = Color(1.0, 0.95, 0.6)
			# lenhas cruzadas
			if py > 96.0 and py < 112.0 and absf(px) < 44.0:
				var d1 := absf((py - 104.0) - px * 0.25)
				var d2 := absf((py - 104.0) + px * 0.25)
				if d1 < 5.0 or d2 < 5.0:
					c = Color(0.36, 0.22, 0.11)
			img.set_pixel(x, y, c)
	return img
