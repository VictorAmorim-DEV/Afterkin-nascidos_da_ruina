class_name Vento
extends RefCounted
## Vento nas plantas: um shader 2D que entorta a copa (o topo da imagem) e deixa a base parada. A fase vem da posição
## do objeto no mundo, então cada árvore balança no seu tempo, e duas ondas somadas evitam o vaivém de metrônomo.
## Um material por intensidade (árvore, arbusto/mato, plantação), compartilhado por todos: custo só na GPU.
## Vento.forca (0 = parado) vira opção do menu de configurações depois.

const SHADER := """shader_type canvas_item;
uniform float amp = 6.0;          // px de tela no topo da imagem
uniform float forca = 1.0;
uniform float topo_uv = 0.0;      // 0: usa UV.y da textura (sprites); 1: usa COLOR.a como altura (plantações)
void vertex() {
	vec2 o = MODEL_MATRIX[3].xy;
	float alto = mix(clamp(1.0 - UV.y, 0.0, 1.0), COLOR.a, topo_uv);
	alto = alto * alto;
	float fase = o.x * 0.0041 + o.y * 0.0029;
	float s = sin(TIME * 1.7 + fase) * 0.65 + sin(TIME * 4.1 + fase * 2.3) * 0.25 + sin(TIME * 0.6 + fase * 0.5) * 0.35;
	VERTEX.x += s * amp * forca * alto;
	if (topo_uv > 0.5) {
		COLOR.a = 1.0;
	}
}
"""

## Prefixos dos props que balançam e a amplitude (px de tela) do topo.
const PROPS := {"arvore": 5.0, "palmeira": 7.0, "arbusto": 3.0, "mato": 3.5, "capim": 4.0}

static var forca: float = 1.0:
	set(v):
		forca = v
		for m in _mats.values():
			(m as ShaderMaterial).set_shader_parameter("forca", v)

static var _mats: Dictionary = {}
static var _shader: Shader = null


static func material(amp: float, por_cor: bool = false) -> ShaderMaterial:
	var chave := "%s_%s" % [amp, por_cor]
	if not _mats.has(chave):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("amp", amp)
		m.set_shader_parameter("forca", forca)
		m.set_shader_parameter("topo_uv", 1.0 if por_cor else 0.0)
		_mats[chave] = m
	return _mats[chave]


## Liga o vento num prop de vegetação (IsoProp) pelo nome da cena; devolve se ligou.
static func aplicar(no: Node, nome: String) -> bool:
	if not no is IsoProp:
		return false
	for pre in PROPS:
		if nome.begins_with(pre):
			(no as IsoProp).definir_material(material(PROPS[pre]))
			return true
	return false
