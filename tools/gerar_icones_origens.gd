extends SceneTree
## Gera os ícones de inventário da pistola, munição e bandagem (etapa 5 do marco 1: kits das origens),
## no tamanho dos ícones existentes. Rodar: <godot> --headless --path . -s tools/gerar_icones_origens.gd
## Depois: <godot> --headless --import, para criar os .import.

const PASTA := "res://assets/ui/icons/icon_%s.png"


func _init() -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(PASTA % "comida"))
	var n: int = ref.get_width() if ref != null else 128
	_desenhar(n, _pistola).save_png(ProjectSettings.globalize_path(PASTA % "pistola"))
	_desenhar(n, _municao).save_png(ProjectSettings.globalize_path(PASTA % "municao"))
	_desenhar(n, _bandagem).save_png(ProjectSettings.globalize_path(PASTA % "bandagem"))
	print("ícones gerados (%d px)" % n)
	quit()


## Pinta pixel a pixel com 'cor_em(px, py)', em coordenadas de uma grade de 128 (escala para 'n').
func _desenhar(n: int, cor_em: Callable) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	for y in n:
		for x in n:
			var c: Color = cor_em.call(x / s, y / s)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return img


func _pistola(px: float, py: float) -> Color:
	var aco := Color(0.22, 0.24, 0.27)
	var borda := Color(0.08, 0.09, 0.1)
	# ferrolho/cano
	if px > 18.0 and px < 112.0 and py > 34.0 and py < 58.0:
		return borda if (px < 21.0 or px > 109.0 or py < 37.0 or py > 55.0) else aco.lightened(0.15 if py < 42.0 else 0.0)
	# cabo inclinado
	var cx := 30.0 + (py - 58.0) * 0.35
	if py >= 58.0 and py < 112.0 and px > cx and px < cx + 28.0:
		return borda if (px < cx + 3.0 or px > cx + 25.0 or py > 109.0) else Color(0.3, 0.2, 0.13)
	# guarda-mato
	if py >= 58.0 and py < 76.0 and px > 58.0 and px < 80.0:
		var dentro := px > 62.0 and px < 76.0 and py < 72.0
		return Color(0, 0, 0, 0) if dentro else borda
	return Color(0, 0, 0, 0)


func _municao(px: float, py: float) -> Color:
	# três cartuchos em pé
	for i in 3:
		var x0 := 26.0 + i * 28.0
		if px > x0 and px < x0 + 18.0:
			if py > 30.0 and py < 54.0:
				var ponta := (py - 30.0) / 24.0          # ogiva arredondada
				if absf(px - (x0 + 9.0)) < 9.0 * sqrt(ponta):
					return Color(0.72, 0.45, 0.25)
			elif py >= 54.0 and py < 104.0:
				return Color(0.85, 0.7, 0.3) if px > x0 + 3.0 else Color(0.62, 0.5, 0.2)
	return Color(0, 0, 0, 0)


func _bandagem(px: float, py: float) -> Color:
	# rolo de atadura visto de lado, com a ponta solta
	var c := Vector2(54.0, 64.0)
	var d := Vector2(px, py).distance_to(c)
	if d < 40.0:
		if d < 13.0:
			return Color(0.75, 0.72, 0.66)          # miolo
		var faixa := int(d / 5.0) % 2 == 0
		return Color(0.96, 0.95, 0.92) if faixa else Color(0.86, 0.85, 0.82)
	if px >= 54.0 and px < 116.0 and py > 92.0 and py < 104.0:
		return Color(0.95, 0.94, 0.9)
	# cruz vermelha
	if (absf(px - 100.0) < 4.0 and absf(py - 36.0) < 12.0) or (absf(py - 36.0) < 4.0 and absf(px - 100.0) < 12.0):
		return Color(0.85, 0.15, 0.15)
	return Color(0, 0, 0, 0)
