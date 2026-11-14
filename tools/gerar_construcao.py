#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — gera a cena de construção em camadas.

Uso (na raiz do projeto):
    python tools/gerar_construcao.py

Gera scenes/world/buildings/casa_abandonada.tscn com as camadas:
    Chao      interior visto de cima (recorte interior_XX) deformado para caber na base
              da fachada — piso, paredes internas e móveis pintados
    Interior  Y-Sort: móveis soltos e a folha da porta (o jogador passa na frente/atrás)
    Fachada   teto + paredes externas (recorte predio_XX), some quando o jogador entra
    Paredes   colisão das paredes externas, com a porta (abre na tecla E)
    Oclusores LightOccluder2D das paredes (bloqueiam a lanterna)
    AreaInterior  Area2D que detecta o jogador dentro da casa ou na soleira

A fachada é isométrica e o interior é visto de cima, então o interior é encaixado por
uma transformação afim: o retângulo das paredes externas do interior (INT_*) é levado
ao paralelogramo da base da fachada (FACH_ESQ, FACH_PIVO, FACH_DIR), medidos à mão.
Todas as paredes, a porta, a área e os móveis são definidos em px do INTERIOR.
"""
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = "assets/sprites_hd_recortados"

NOME = "casa_abandonada"
FACHADA = "construcoes/predio_03"
INTERIOR = "construcoes/interior_01"
ESCALA = 1.4                                   # porta da fachada = 2,1 m ≈ 64 px de tela

# base da fachada, em px do recorte predio_03: canto esquerdo, pivô (canto da frente), canto direito
FACH_ESQ, FACH_PIVO, FACH_DIR = (17, 141), (163, 178), (228, 148)
# vão da porta pintada na fachada (px do recorte): 4 cantos
FACH_PORTA = [(79, 157), (97, 161.5), (97, 118.5), (79, 114)]

# retângulo externo das paredes no recorte interior_01 (px) e espessura das paredes
INT_X0, INT_Y0, INT_X1, INT_Y1 = 20, 13, 213, 170
PAREDE = 9
PORTA_X0, PORTA_X1 = 100, 125                  # vão da porta na parede de baixo
# móveis soltos (cena em scenes/world/props_hd, posição do pivô em px do interior)
MOVEIS = [("barril_azul", 108, 36), ("caixote", 58, 100), ("caixa_madeira", 152, 90)]


def n(v):
    s = "%.2f" % v
    return s.rstrip("0").rstrip(".") if "." in s else s


def vec(p):
    return "Vector2(%s, %s)" % (n(p[0]), n(p[1]))


def pts(ps):
    return "PackedVector2Array(%s)" % ", ".join(n(c) for p in ps for c in p)


# cantos da base em px de tela, relativos ao pivô
E = ((FACH_ESQ[0] - FACH_PIVO[0]) * ESCALA, (FACH_ESQ[1] - FACH_PIVO[1]) * ESCALA)
D = ((FACH_DIR[0] - FACH_PIVO[0]) * ESCALA, (FACH_DIR[1] - FACH_PIVO[1]) * ESCALA)
T = (E[0] + D[0], E[1] + D[1])                 # canto de trás
LARG, ALT = float(INT_X1 - INT_X0), float(INT_Y1 - INT_Y0)
EIXO_X = ((D[0] - T[0]) / LARG, (D[1] - T[1]) / LARG)      # 1 px do interior para a direita
EIXO_Y = ((E[0] - T[0]) / ALT, (E[1] - T[1]) / ALT)        # 1 px do interior para baixo
ORIGEM = (T[0] - INT_X0 * EIXO_X[0] - INT_Y0 * EIXO_Y[0], T[1] - INT_X0 * EIXO_X[1] - INT_Y0 * EIXO_Y[1])


def m(u, v):
    """px do interior -> px de tela relativo ao pivô da casa."""
    return (ORIGEM[0] + u * EIXO_X[0] + v * EIXO_Y[0], ORIGEM[1] + u * EIXO_X[1] + v * EIXO_Y[1])


def ret(u0, v0, u1, v1, rel=(0.0, 0.0)):
    q = [m(u0, v0), m(u1, v0), m(u1, v1), m(u0, v1)]
    return [(x - rel[0], y - rel[1]) for x, y in q]


def main():
    x0, y0, x1, y1, p = INT_X0, INT_Y0, INT_X1, INT_Y1, PAREDE
    paredes = {
        "ParedeFundo": ret(x0, y0, x1, y0 + p),
        "ParedeEsquerda": ret(x0, y0, x0 + p, y1),
        "ParedeDireita": ret(x1 - p, y0, x1, y1),
        "ParedeFrenteA": ret(x0, y1 - p, PORTA_X0, y1),
        "ParedeFrenteB": ret(PORTA_X1, y1 - p, x1, y1),
    }
    porta = ret(PORTA_X0, y1 - p, PORTA_X1, y1)
    centro_porta = m((PORTA_X0 + PORTA_X1) / 2.0, y1 - p / 2.0)
    folha_fechada = ret(PORTA_X0, y1 - 7, PORTA_X1, y1 - 2, centro_porta)
    folha_aberta = ret(PORTA_X0 - 3, y1 - 4, PORTA_X0 + 3, y1 + PORTA_X1 - PORTA_X0, centro_porta)
    area_interior = ret(x0, y0, x1, y1)
    soleira = ret(PORTA_X0 - 8, y1, PORTA_X1 + 8, y1 + 16)
    # vão escuro sobre a porta pintada da fachada (aparece quando a porta está aberta)
    vao = [((x - FACH_PIVO[0]) * ESCALA, (y - FACH_PIVO[1]) * ESCALA) for x, y in FACH_PORTA]
    vao_y = max(q[1] for q in vao) + 3.0
    vao = [(x, y - vao_y) for x, y in vao]

    usados = sorted({mv[0] for mv in MOVEIS})
    sub, nos = "", ""
    for nome, q in paredes.items():
        nos += f'[node name="{nome}" type="CollisionPolygon2D" parent="Paredes"]\npolygon = {pts(q)}\n\n'
    nos += f'[node name="Porta" type="CollisionPolygon2D" parent="Paredes"]\npolygon = {pts(porta)}\n\n'
    nos += '[node name="Oclusores" type="Node2D" parent="."]\n\n'
    for nome, q in list(paredes.items()) + [("Porta", porta)]:
        sub += f'[sub_resource type="OccluderPolygon2D" id="oc_{nome}"]\npolygon = {pts(q)}\n\n'
        nos += f'[node name="{nome}" type="LightOccluder2D" parent="Oclusores"]\noccluder = SubResource("oc_{nome}")\n\n'
    moveis, cont = "", {}
    for nome, u, v in MOVEIS:
        cont[nome] = cont.get(nome, 0) + 1
        no = "".join(t.capitalize() for t in nome.split("_")) + str(cont[nome])
        moveis += f'[node name="{no}" parent="Interior" instance=ExtResource("m_{nome}")]\nposition = {vec(m(u, v))}\n\n'
    ext = "".join(f'[ext_resource type="PackedScene" path="res://scenes/world/props_hd/{u}.tscn" id="m_{u}"]\n' for u in usados)

    cena = f'''[gd_scene load_steps={len(usados) + 5 + len(paredes) + 1} format=3]

[ext_resource type="Script" path="res://scripts/world/construcao.gd" id="1_casa"]
[ext_resource type="Script" path="res://scripts/world/iso_prop.gd" id="2_prop"]
[ext_resource type="Texture2D" path="res://{REC}/{FACHADA}.png" id="3_fachada"]
[ext_resource type="Texture2D" path="res://{REC}/{INTERIOR}.png" id="4_interior"]
{ext}
{sub}[node name="{"".join(t.capitalize() for t in NOME.split("_"))}" type="Node2D"]
y_sort_enabled = true
script = ExtResource("1_casa")

[node name="Chao" type="Sprite2D" parent="."]
z_index = -1
texture_filter = 2
transform = Transform2D({EIXO_X[0]:.5f}, {EIXO_X[1]:.5f}, {EIXO_Y[0]:.5f}, {EIXO_Y[1]:.5f}, {ORIGEM[0]:.3f}, {ORIGEM[1]:.3f})
texture = ExtResource("4_interior")
centered = false

[node name="Interior" type="Node2D" parent="."]
y_sort_enabled = true

[node name="PortaFechada" type="Polygon2D" parent="Interior"]
position = {vec(centro_porta)}
light_mask = 2
color = Color(0.36, 0.25, 0.16, 1)
polygon = {pts(folha_fechada)}

[node name="PortaAberta" type="Polygon2D" parent="Interior"]
visible = false
position = {vec(centro_porta)}
light_mask = 2
color = Color(0.36, 0.25, 0.16, 1)
polygon = {pts(folha_aberta)}

{moveis}[node name="Fachada" type="StaticBody2D" parent="."]
y_sort_enabled = true
collision_layer = 0
collision_mask = 0
script = ExtResource("2_prop")
textura = ExtResource("3_fachada")
escala = {n(ESCALA)}
base_esq = {vec(FACH_ESQ)}
pivo = {vec(FACH_PIVO)}
base_dir = {vec(FACH_DIR)}
luz_checar_obstaculos = false

[node name="VaoDaPorta" type="Polygon2D" parent="Fachada"]
visible = false
position = Vector2(0, {n(vao_y)})
light_mask = 2
color = Color(0.03, 0.03, 0.04, 0.92)
polygon = {pts(vao)}

[node name="Paredes" type="StaticBody2D" parent="."]

{nos}[node name="AreaInterior" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2

[node name="Interior" type="CollisionPolygon2D" parent="AreaInterior"]
polygon = {pts(area_interior)}

[node name="Soleira" type="CollisionPolygon2D" parent="AreaInterior"]
polygon = {pts(soleira)}

[node name="PontoDaPorta" type="Marker2D" parent="."]
position = {vec(m((PORTA_X0 + PORTA_X1) / 2.0, y1 + 2))}
'''
    cam = os.path.join(RAIZ, "scenes/world/buildings")
    os.makedirs(cam, exist_ok=True)
    with open(os.path.join(cam, NOME + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
        f.write(cena)
    print("scenes/world/buildings/%s.tscn gerada" % NOME)
    print("base (tela, rel. ao pivô): esq %s  dir %s  trás %s" % (vec(E), vec(D), vec(T)))


if __name__ == "__main__":
    main()
