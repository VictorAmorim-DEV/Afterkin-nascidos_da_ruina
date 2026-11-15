class_name SombraSol
extends RefCounted
## Sombras do sol (V13: sol, sombraSol, sombraChar, silhueta — l.1520-1530): a silhueta de cada objeto e personagem
## achatada no chão (f) e inclinada para o lado (k), longa de manhã e à tarde, curta ao meio-dia; some à noite.
##
## Todas as sombras usam UM ShaderMaterial: o DiaNoite atualiza o sol uma vez por quadro e todas acompanham.
## A origem do nó da sombra é o ponto em que o objeto toca o chão; o shader inclina em volta dela no espaço do
## canvas (funciona com sprite espelhado ou escalado). As sombras ficam em z −1: abaixo de tudo que está em pé.

## Liga/desliga todas as sombras do sol (futura opção do menu de configurações, aba Vídeo).
static var ativo: bool = true

const SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform float k = 0.5;
uniform float f = 0.3;
uniform float alfa = 0.3;
void vertex() {
	vec2 g = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 ancora = MODEL_MATRIX[3].xy;
	vec2 d = g - ancora;
	vec2 n = ancora + vec2(d.x - k * d.y, d.y * f);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(n, 0.0, 1.0)).xy;
}
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, step(0.5, texture(TEXTURE, UV).a) * alfa);
}
"""

static var _mat: ShaderMaterial = null


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat


## Posição do sol pela hora (V13: sol). Chamado pelo DiaNoite a cada quadro.
static func atualizar(minutos: float) -> void:
	var m := material()
	var h := minutos / 60.0
	if not ativo or h < 5.6 or h > 19.4:
		m.set_shader_parameter("alfa", 0.0)
		return
	var alt := sin((h - 5.6) / 13.8 * PI)
	m.set_shader_parameter("k", 0.5 + 1.1 * (1.0 - alt))
	m.set_shader_parameter("f", 0.3)
	m.set_shader_parameter("alfa", 0.36 * minf(1.0, alt * 2.5))


## Configura um nó de sombra (filho do objeto, com a origem no ponto de apoio no chão).
static func preparar(no: CanvasItem) -> void:
	no.material = material()
	no.z_as_relative = false
	no.z_index = -1
	no.light_mask = 0
	no.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Sombra de uma textura inteira cujo ponto de apoio é 'pivo' (px da imagem), na escala dada.
static func de_textura(tex: Texture2D, pivo: Vector2, escala: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "SombraSol"
	s.texture = tex
	s.centered = false
	s.offset = -pivo
	s.scale = escala
	preparar(s)
	return s


## Sombra de personagem: copia animação, quadro e espelho do sprite a cada quadro; fica no chão quando ele pula.
class Personagem extends AnimatedSprite2D:
	var fonte: AnimatedSprite2D

	func _ready() -> void:
		name = "SombraSol"
		SombraSol.preparar(self)
		centered = fonte.centered
		offset = fonte.offset
		scale = fonte.scale

	func _process(_d: float) -> void:
		if not is_instance_valid(fonte):
			return
		visible = fonte.is_visible_in_tree()
		if sprite_frames != fonte.sprite_frames:
			sprite_frames = fonte.sprite_frames
		if animation != fonte.animation:
			animation = fonte.animation
		frame = fonte.frame
		flip_h = fonte.flip_h
