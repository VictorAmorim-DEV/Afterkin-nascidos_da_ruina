class_name IsoMath
extends RefCounted
## Projeção isométrica 2:1 do protótipo V13:
##   tela.x = (x - y) * 0.5      tela.y = (x + y) * 0.25
## "Mundo" = coordenadas lógicas do mapa (1 tile = 64 u). "Tela" = posição dos nós na Godot.

const TILE := 64.0
const METRO := 49.48
const ISO := Transform2D(Vector2(0.5, 0.25), Vector2(-0.5, 0.25), Vector2.ZERO)


static func mundo_para_tela(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 0.5, (p.x + p.y) * 0.25)


static func tela_para_mundo(p: Vector2) -> Vector2:
	return Vector2(p.x + 2.0 * p.y, 2.0 * p.y - p.x)
