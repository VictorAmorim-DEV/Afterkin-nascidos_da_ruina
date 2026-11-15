class_name Relevo
extends RefCounted
## Relevo (normal maps) para a luz 2D: a lanterna e os faróis passam a marcar volumes nos prédios, pedras, veículos,
## caixotes, barris e barricadas. O mapa normal sai da luminância da própria imagem (Sobel): partes claras "saltam",
## frestas e juntas "afundam". Formato OpenGL (Y para cima), como a Godot espera no CanvasTexture.
##
## Sprites: tools/gerar_normais.gd grava <imagem>_n.png ao lado; com_normal() embrulha a textura num CanvasTexture
## quando o arquivo existe. Atlas das paredes (TexturasParede): o normal é gerado na carga.

const FORCA := 2.2

static var _cache: Dictionary = {}


## A textura com o normal map ao lado (<caminho>_n.png), ou a própria textura se não houver.
static func com_normal(tex: Texture2D) -> Texture2D:
	if tex == null or tex.resource_path == "":
		return tex
	var p := tex.resource_path
	if _cache.has(p):
		return _cache[p]
	var n := p.get_basename() + "_n.png"
	var out: Texture2D = tex
	if ResourceLoader.exists(n):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = tex
		ct.normal_texture = load(n)
		out = ct
	_cache[p] = out
	return out


## Normal map de uma imagem (alfa preservado: o contorno do sprite não ganha borda falsa).
static func gerar(img: Image, forca: float = FORCA) -> Image:
	var src := img.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var alt := PackedFloat32Array()
	alt.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			alt[y * w + x] = c.get_luminance() * c.a
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var xa := maxi(x - 1, 0)
			var xb := mini(x + 1, w - 1)
			var ya := maxi(y - 1, 0)
			var yb := mini(y + 1, h - 1)
			var dx := (alt[ya * w + xb] + 2.0 * alt[y * w + xb] + alt[yb * w + xb]) \
				- (alt[ya * w + xa] + 2.0 * alt[y * w + xa] + alt[yb * w + xa])
			var dy := (alt[yb * w + xa] + 2.0 * alt[yb * w + x] + alt[yb * w + xb]) \
				- (alt[ya * w + xa] + 2.0 * alt[ya * w + x] + alt[ya * w + xb])
			var n := Vector3(-dx * forca, dy * forca, 1.0).normalized()      # dy da imagem desce; o Y do normal sobe
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, src.get_pixel(x, y).a))
	return out
