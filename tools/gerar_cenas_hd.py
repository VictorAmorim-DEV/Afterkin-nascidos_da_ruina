#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — gera as cenas de objetos HD (scenes/world/props_hd/).

Uso (na raiz do projeto, depois de rodar tools/recortar_hd.py):
    python tools/gerar_cenas_hd.py              # só as cenas dos objetos
    python tools/gerar_cenas_hd.py --cenario    # também REESCREVE scenes/world/test_level.tscn

Para cada objeto da tabela PROPS o script mede, pelo contorno do recorte, a BASE no chão
(canto esquerdo, pivô e canto direito) e grava uma cena StaticBody2D com o script
IsoProp (sprite fatiado para a profundidade) e um CollisionShape2D em losango na base.
Para adicionar um objeto, inclua uma linha em PROPS; para corrigir uma base medida
errado, informe base=((xe, ye), (xp, yp), (xd, yd)) em px da imagem.

Escala: o personagem tem 53 px de tela = 1,75 m (30,3 px por metro).
"""
import argparse, os, sys
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = "assets/sprites_hd_recortados"

# nome da cena: (recorte, escala, modo)   modo: 'caixa' = base pelo contorno inteiro
#                                               'tronco' = base só no pé (árvores, postes)
PROPS = {
    "kombi":            ("objetos_natureza/veiculo_01", 0.80, "caixa"),
    "carro_capo_aberto":("objetos_natureza/veiculo_02", 0.70, "caixa"),
    "picape":           ("objetos_natureza/veiculo_03", 0.70, "caixa"),
    "sedan_enferrujado":("objetos_natureza/veiculo_04", 0.70, "caixa"),
    "sedan_amarelo":    ("objetos_natureza/veiculo_05", 0.70, "caixa"),
    "jipe":             ("objetos_natureza/veiculo_06", 0.78, "caixa"),
    "barreira_curta":   ("objetos_natureza/barricada_01", 0.60, "caixa"),
    "barreira_quebrada":("objetos_natureza/barricada_02", 0.60, "caixa"),
    "barreira_listrada":("objetos_natureza/barricada_03", 0.60, "caixa"),
    "barreira_longa":   ("objetos_natureza/barricada_05", 0.60, "caixa"),
    "barreira_destruida":("objetos_natureza/barricada_06", 0.60, "caixa"),
    "sacos_areia_a":    ("objetos_natureza/barricada_07", 0.60, "caixa"),
    "sacos_areia_b":    ("objetos_natureza/barricada_08", 0.60, "caixa"),
    "caixote":          ("objetos_natureza/recipiente_01", 0.60, "caixa"),
    "caixa_madeira":    ("objetos_natureza/recipiente_02", 0.60, "caixa"),
    "barril_azul":      ("objetos_natureza/recipiente_04", 0.60, "caixa"),
    "arvore_jovem":     ("objetos_natureza/arvore_01", 0.80, "tronco"),
    "mato_alto":        ("objetos_natureza/vegetacao_18", 0.34, "tronco"),
    "mato_fino":        ("objetos_natureza/vegetacao_19", 0.30, "tronco"),
    "mato_seco":        ("objetos_natureza/vegetacao_29", 0.30, "tronco"),
    "mato_rasteiro":    ("objetos_natureza/vegetacao_31", 0.30, "tronco"),
    "capim":            ("objetos_natureza/vegetacao_40", 0.30, "tronco"),
    "capim_alto":       ("objetos_natureza/vegetacao_48", 0.34, "tronco"),
    "arbusto_largo":    ("objetos_natureza/vegetacao_02", 0.40, "tronco"),
    "arbusto_redondo":  ("objetos_natureza/vegetacao_10", 0.40, "tronco"),
    "arbusto_baixo":    ("objetos_natureza/vegetacao_20", 0.40, "tronco"),
    "arbusto_folhudo":  ("objetos_natureza/vegetacao_33", 0.40, "tronco"),
    "entulho_pedras":   ("objetos_natureza/pedra_05", 0.45, "caixa"),
    "entulho_laje":     ("objetos_natureza/pedra_03", 0.45, "caixa"),
    "arvore_frondosa":  ("objetos_natureza/arvore_02", 0.80, "tronco"),
    "arvore_outono":    ("objetos_natureza/arvore_03", 0.80, "tronco"),
    "palmeira":         ("objetos_natureza/arvore_04", 0.80, "tronco"),
    "arvore_fina":      ("objetos_natureza/arvore_05", 0.80, "tronco"),
    "arvore_morta":     ("objetos_natureza/arvore_06", 0.80, "tronco"),
}

# cenário de teste: (cena, x, y) com a posição do PIVÔ em unidades de mundo.
# A estrada HD corre ao longo do eixo Y; o asfalto vai de x = 134 a 440, com a faixa
# amarela em x = 287 (ver scripts/world/ground.gd e tools/preparar_chao_hd.py).
CENARIO = [
    ("kombi", 425, 60), ("sedan_enferrujado", 270, -330), ("picape", 430, 470),
    ("sedan_amarelo", 275, 800), ("carro_capo_aberto", -260, 330), ("jipe", -120, -400),
    ("barreira_longa", 250, 215), ("barreira_curta", 300, 190), ("barreira_listrada", 300, -620),
    ("barreira_destruida", 440, -600), ("sacos_areia_b", 100, 150), ("sacos_areia_a", 560, 250),
    ("arvore_frondosa", -220, -160), ("arvore_outono", -780, -280), ("arvore_fina", -140, -640),
    ("arvore_jovem", -300, 420), ("palmeira", -300, 640), ("arvore_morta", 780, -200),
    ("arvore_frondosa", 940, 330), ("arvore_fina", 900, 780), ("arvore_outono", 900, -620),
    ("arvore_jovem", -90, -280),
    ("caixote", -150, 40), ("caixa_madeira", -620, 840),
]

# recipientes vasculháveis (scripts/items/lootavel.gd): nó do cenário -> tabela de loot da V13
LOOTAVEIS = {"Caixote1": "caixa", "CaixaMadeira1": "caixa", "EntulhoPedras1": "scrap", "EntulhoLaje1": "scrap"}


# objetos só de enfeite: sem colisão e sem bloquear a luz (o jogador passa por cima)
DECORATIVOS = {"mato_alto", "mato_fino", "mato_seco", "mato_rasteiro", "capim", "capim_alto",
               "arbusto_largo", "arbusto_redondo", "arbusto_baixo", "arbusto_folhudo",
               "entulho_pedras", "entulho_laje"}

# edifícios procedurais (scripts/world/edificio.gd, portado da V13):
#   (nome do nó, tile x, tile y do canto norte, largura e altura em tiles, frente, semente)
# 1 tile = 64 u. A casa abaixo ocupa x de -1088 a -448 e y de 192 a 704, com a porta na face sul.
EDIFICIOS = [
    ("Casa1", -17, 3, 10, 8, "s", 3),
]

# mato, arbustos e entulho em volta da casa (sem colisão)
ENTORNO = [
    ("capim_alto", -1070, 735), ("mato_alto", -980, 750), ("arbusto_baixo", -880, 740), ("capim", -640, 745),
    ("mato_fino", -560, 760), ("capim_alto", -470, 735), ("entulho_pedras", -900, 800),
    ("arbusto_largo", -410, 240), ("mato_seco", -420, 380), ("capim", -415, 520), ("mato_rasteiro", -425, 660),
    ("arbusto_redondo", -1125, 250), ("mato_alto", -1120, 420), ("capim", -1118, 600),
    ("arbusto_folhudo", -1000, 160), ("mato_fino", -760, 160), ("entulho_laje", -560, 160), ("capim_alto", -400, 760),
]


def medir_base(caminho, modo):
    """Devolve (esq, pivo, dir) em px da imagem."""
    a = np.array(Image.open(caminho).convert("RGBA"))[..., 3] > 128
    h, w = a.shape
    ys, xs = np.nonzero(a)
    if modo == "tronco":
        yb = ys.max()
        pe = xs[ys > yb - 0.07 * h]
        x0, x1 = np.percentile(pe, 2), np.percentile(pe, 98)
        px, meia = (x0 + x1) / 2, (x1 - x0) / 2 * 0.8
        py = yb - meia * 0.25
        px, py, meia = float(px), float(py), float(meia)
        return (px - meia, py - meia / 2), (px, py), (px + meia, py - meia / 2)
    m = max(2, int(w * 0.03))
    esq = (float(xs.min()), float(ys[xs <= xs.min() + m].max()))
    dir_ = (float(xs.max()), float(ys[xs >= xs.max() - m].max()))
    casco = cv2.convexHull(np.stack([xs, ys], 1).astype(np.int32)).reshape(-1, 2).astype(float)
    abaixo = (casco[:, 1] - esq[1]) * (dir_[0] - esq[0]) - (casco[:, 0] - esq[0]) * (dir_[1] - esq[1])
    p = casco[abaixo.argmax()]
    return esq, (float(p[0]), float(p[1])), dir_


def n(v):
    s = "%.2f" % v
    return s.rstrip("0").rstrip(".") if "." in s else s


def vec(p):
    return "Vector2(%s, %s)" % (n(p[0]), n(p[1]))


def cena_prop(nome, rec, escala, base):
    e, p, d = base
    ce = ((e[0] - p[0]) * escala, (e[1] - p[1]) * escala)
    cd = ((d[0] - p[0]) * escala, (d[1] - p[1]) * escala)
    pts = [(0, 0), ce, (ce[0] + cd[0], ce[1] + cd[1]), cd]
    no = "".join(t.capitalize() for t in nome.split("_"))
    if nome in DECORATIVOS:
        return f'''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/world/iso_prop.gd" id="1_prop"]
[ext_resource type="Texture2D" path="res://{REC}/{rec}.png" id="2_tex"]

[node name="{no}" type="StaticBody2D"]
y_sort_enabled = true
collision_layer = 0
collision_mask = 0
script = ExtResource("1_prop")
textura = ExtResource("2_tex")
escala = {n(escala)}
base_esq = {vec(e)}
pivo = {vec(p)}
base_dir = {vec(d)}
luz_checar_obstaculos = false
'''
    return f'''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/world/iso_prop.gd" id="1_prop"]
[ext_resource type="Texture2D" path="res://{REC}/{rec}.png" id="2_tex"]

[sub_resource type="ConvexPolygonShape2D" id="shape_base"]
points = PackedVector2Array({", ".join(n(c) for q in pts for c in q)})

[sub_resource type="OccluderPolygon2D" id="oclusor_base"]
polygon = PackedVector2Array({", ".join(n(c) for q in pts for c in q)})

[node name="{no}" type="StaticBody2D"]
y_sort_enabled = true
script = ExtResource("1_prop")
textura = ExtResource("2_tex")
escala = {n(escala)}
base_esq = {vec(e)}
pivo = {vec(p)}
base_dir = {vec(d)}

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("shape_base")

[node name="LightOccluder2D" type="LightOccluder2D" parent="."]
occluder = SubResource("oclusor_base")
'''


def cena_teste():
    usados = sorted({c[0] for c in CENARIO + ENTORNO})
    ext = "".join(f'[ext_resource type="PackedScene" path="res://scenes/world/props_hd/{u}.tscn" id="p_{u}"]\n' for u in usados)
    nos, cont = "", {}
    for nome, x, y in CENARIO + ENTORNO:
        cont[nome] = cont.get(nome, 0) + 1
        no = "".join(t.capitalize() for t in nome.split("_")) + str(cont[nome])
        tela = ((x - y) * 0.5, (x + y) * 0.25)          # projeção isométrica 2:1
        nos += f'[node name="{no}" parent="." instance=ExtResource("p_{nome}")]\nposition = {vec(tela)}\n\n'
        if no in LOOTAVEIS:
            nos += (f'[node name="Loot" type="Node2D" parent="{no}"]\nposition = Vector2(0, -8)\n'
                    f'script = ExtResource("s_lootavel")\ntipo = "{LOOTAVEIS[no]}"\n\n')
    ext += '[ext_resource type="Script" path="res://scripts/world/edificio.gd" id="s_edificio"]\n'
    ext += '[ext_resource type="Script" path="res://scripts/items/lootavel.gd" id="s_lootavel"]\n'
    for nome, tx, ty, larg, alt, frente, semente in EDIFICIOS:
        nos += (f'[node name="{nome}" type="Node2D" parent="."]\nposition = {vec(((tx - ty) * 32.0, (tx + ty) * 16.0))}\n'
                f'script = ExtResource("s_edificio")\nlargura_tiles = {larg}\naltura_tiles = {alt}\n'
                f'frente = "{frente}"\nsemente = {semente}\n\n')
    return f'''[gd_scene load_steps={len(usados) + 7} format=3]

[ext_resource type="Script" path="res://scripts/world/ground.gd" id="1_ground"]
[ext_resource type="Texture2D" path="res://{REC}/chao/grama.png" id="2_grama"]
[ext_resource type="Texture2D" path="res://{REC}/chao/estrada.png" id="4_estrada"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="3_player"]
{ext}
[node name="TestLevel" type="Node2D"]
y_sort_enabled = true

[node name="Ground" type="Node2D" parent="."]
z_index = -2
texture_filter = 2
script = ExtResource("1_ground")
grama = ExtResource("2_grama")
estrada = ExtResource("4_estrada")

[node name="Player" parent="." instance=ExtResource("3_player")]

{nos}'''.rstrip("\n") + "\n"


def gravar(rel, texto):
    cam = os.path.join(RAIZ, rel)
    os.makedirs(os.path.dirname(cam), exist_ok=True)
    with open(cam, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cenario", action="store_true", help="reescreve scenes/world/test_level.tscn")
    a = ap.parse_args()
    for nome, reg in PROPS.items():
        rec, escala, modo = reg[:3]
        cam = os.path.join(RAIZ, REC, rec + ".png")
        if not os.path.isfile(cam):
            print("AVISO: recorte não encontrado:", cam); continue
        base = reg[3] if len(reg) > 3 else medir_base(cam, modo)
        gravar(f"scenes/world/props_hd/{nome}.tscn", cena_prop(nome, rec, escala, base))
        print("%-20s escala %.2f  base %s" % (nome, escala, [tuple(round(v, 1) for v in q) for q in base]))
    if a.cenario:
        gravar("scenes/world/test_level.tscn", cena_teste())
        print("scenes/world/test_level.tscn reescrita com %d objetos" % len(CENARIO))


if __name__ == "__main__":
    sys.exit(main())
