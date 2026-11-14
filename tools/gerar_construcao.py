#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — gera a cena da casa em camadas (estilo Project Zomboid).

Uso (na raiz do projeto, depois de tools/preparar_casa_hd.py):
    python tools/gerar_construcao.py

Gera scenes/world/buildings/casa_abandonada.tscn.

TODAS as medidas abaixo estão em px das imagens da casa (1774x887), que foram
desenhadas na mesma posição e escala. O nó raiz da cena tem escala ESCALA, então
dentro da cena tudo continua em px da imagem — é só medir na arte e anotar aqui.
A origem do nó é PIVO (o canto do chão mais perto da câmera).

Camadas:
    Interior<Cômodo>  piso, móveis e paredes altas do fundo daquele cômodo
    Fachada<Cômodo>   telhado + parede frontal daquele cômodo
As quatro peças foram recortadas pela MESMA linha, então encaixam sem emenda:
mostrando o interior de um cômodo e a fachada do outro, a casa continua inteira.
Cada metade da fachada some quando o cômodo dela é revelado (o jogador entra ou
abre uma porta/janela dele); a outra continua fechada, escondendo aquele cômodo.

As duas metades usam o script IsoProp: a arte é fatiada em colunas ordenadas pela
base da casa, então o jogador passa na frente da parede quando está do lado de fora
e atrás dela quando está dentro.
"""
import json, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = "assets/sprites_hd_recortados"
NOME = "casa_abandonada"

ESCALA = 0.29                      # px da imagem -> px de tela (porta de 2,1 m = 63 px)
PIVO = (700, 845)                  # origem do nó: canto do chão mais perto da câmera
BASE_ESQ, BASE_DIR = (250, 690), (1690, 588)     # cantos do chão, para a ordenação

# --- cômodos: polígono do piso (onde o jogador anda) ---
COMODOS = {
    "sala":    [(500, 460), (830, 370), (1040, 448), (1020, 650)],
    "cozinha": [(830, 370), (1030, 320), (1570, 520), (1310, 610), (1040, 645), (1040, 448)],
}
# --- paredes: (nome, p0, p1, espessura em y) ---  espessura negativa = parede do fundo
PAREDES = [
    ("FundoSala",     (500, 460), (830, 370), -24),
    ("FundoCozinha",  (830, 370), (1030, 320), -24),
    ("LateralDireita", (1030, 320), (1570, 520), -24),
    ("FrenteCozinhaA", (1570, 520), (1310, 610), 24),
    ("FrenteCozinhaB", (1310, 610), (1250, 618), 24),
    ("FrenteCozinhaC", (1130, 633), (1040, 645), 24),
    ("FrenteSalaA",   (1020, 650), (927, 616), 24),
    ("FrenteSalaB",   (824, 578), (500, 460), 24),
    ("InternaA",      (830, 370), (885, 390), -16),
    ("InternaB",      (975, 424), (1040, 448), -16),
]
# --- blocos: colisão do CORPO da casa visto de fora (sem oclusão de luz) ---
# As paredes acima ficam na borda do piso. Por fora, a parede desenhada desce até o
# chão; estes polígonos fecham essa faixa para o jogador não andar "por dentro" da
# fachada. A varanda (degraus até a porta) fica livre entre as duas colunas.
BLOCOS = [
    ("CorpoSalaEsq",   [(500, 460), (824, 578), (824, 800), (700, 828), (250, 668)]),
    ("CorpoSalaDir",   [(927, 616), (1020, 650), (1040, 752), (927, 777)]),
    ("CorpoEntradaEsq", [(1020, 650), (1130, 633), (1130, 760), (1040, 752)]),
    ("ColunaDireita",  [(1300, 612), (1350, 606), (1350, 665), (1300, 668)]),
    ("CorpoCanteiro",  [(1310, 610), (1570, 520), (1690, 600), (1350, 720)]),
    ("MuroDoQuintal",  [(55, 540), (190, 470), (250, 560), (250, 668), (60, 610)]),
]
# --- aberturas: porta/janela que abrem na tecla E ---
# vao: trecho da parede que elas fecham | sprites: (camada, x0,y0,x1,y1, espelhado)
ABERTURAS = [
    dict(nome="PortaEntrada", rotulo="a porta", comodos=["cozinha"], alcance=115,
         fechada="porta_tabuas_fechada", aberta="porta_tabuas_aberta",
         vao=((1250, 618), (1130, 633)), espessura=24, ponto=(1190, 640),
         sprites=[("fachada_cozinha", 1120, 440, 1265, 665, False),
                  ("interior_cozinha", 1128, 488, 1252, 652, False)]),
    dict(nome="JanelaSala", rotulo="a janela", comodos=["sala"], alcance=150,
         fechada="janela_postigo_fechada", aberta="janela_postigo_aberta",
         vao=((927, 616), (824, 578)), espessura=24, ponto=(876, 700),
         corredor=[(824, 578), (927, 616), (927, 777), (824, 800)],
         sprites=[("fachada_sala", 782, 448, 979, 598, True),
                  ("interior_sala", 777, 585, 987, 697, True)]),
    dict(nome="PortaInterna", rotulo="a porta do cômodo", comodos=["sala", "cozinha"], alcance=95,
         fechada="porta_almofadada_fechada", aberta="porta_almofadada_aberta",
         vao=((885, 390), (975, 424)), espessura=-16, ponto=(930, 407),
         sprites=[("interior_sala", 882, 222, 978, 432, True)]),
]


def n(v):
    s = "%.2f" % v
    return s.rstrip("0").rstrip(".") if "." in s else s


def vec(p):
    return "Vector2(%s, %s)" % (n(p[0] - PIVO[0]), n(p[1] - PIVO[1]))


def pts(ps):
    return "PackedVector2Array(%s)" % ", ".join(
        "%s, %s" % (n(p[0] - PIVO[0]), n(p[1] - PIVO[1])) for p in ps)


def faixa(p0, p1, esp):
    """Quadrilátero de uma parede: o segmento e o mesmo segmento deslocado em y."""
    return [p0, p1, (p1[0], p1[1] + esp), (p0[0], p0[1] + esp)]


def main():
    with open(os.path.join(RAIZ, REC, "casa", "casa.json"), encoding="utf-8") as f:
        casa = json.load(f)
    pj = casa["portas_janelas"]

    ext, sub, nos = [], [], []
    ext.append('[ext_resource type="Script" path="res://scripts/world/construcao.gd" id="1_casa"]')
    ext.append('[ext_resource type="Script" path="res://scripts/world/iso_prop.gd" id="2_prop"]')
    ext.append('[ext_resource type="Script" path="res://scripts/world/abertura.gd" id="3_abre"]')
    camadas = ["interior_sala", "interior_cozinha", "fachada_sala", "fachada_cozinha"]
    for arq in camadas:
        ext.append('[ext_resource type="Texture2D" path="res://%s/casa/%s.png" id="t_%s"]' % (REC, arq, arq))
        ext.append('[ext_resource type="Texture2D" path="res://%s/casa/%s_n.png" id="n_%s"]' % (REC, arq, arq))
        sub.append('[sub_resource type="CanvasTexture" id="ct_%s"]\n'
                   'diffuse_texture = ExtResource("t_%s")\n'
                   'normal_texture = ExtResource("n_%s")' % (arq, arq, arq))
    usadas = sorted({a[k] for a in ABERTURAS for k in ("fechada", "aberta")})
    for u in usadas:
        ext.append('[ext_resource type="Texture2D" path="res://%s/portas_janelas/%s.png" id="pj_%s"]' % (REC, u, u))

    # ---------- raiz ----------
    nos.append('[node name="%s" type="Node2D"]\n'
               'y_sort_enabled = true\nscale = Vector2(%s, %s)\nscript = ExtResource("1_casa")\n'
               'comodos = PackedStringArray("sala", "cozinha")'
               % ("".join(t.capitalize() for t in NOME.split("_")), n(ESCALA), n(ESCALA)))

    # ---------- interior de cada cômodo (ordenado atrás do jogador) ----------
    for lado in ("sala", "cozinha"):
        nos.append('[node name="Interior%s" type="Sprite2D" parent="."]\n'
                   'modulate = Color(1, 1, 1, 0)\nlight_mask = 2\ntexture_filter = 2\n'
                   'position = Vector2(0, %s)\ntexture = SubResource("ct_interior_%s")\n'
                   'centered = false\noffset = Vector2(%s, %s)'
                   % (lado.capitalize(), n(-PIVO[1] - 80), lado, n(-PIVO[0]), n(80)))

    # ---------- as duas metades da fachada ----------
    for arq, lado in (("fachada_sala", "sala"), ("fachada_cozinha", "cozinha")):
        nos.append('[node name="Fachada%s" type="StaticBody2D" parent="."]\n'
                   'y_sort_enabled = true\ncollision_layer = 0\ncollision_mask = 0\n'
                   'script = ExtResource("2_prop")\ntextura = SubResource("ct_%s")\nescala = 1.0\n'
                   'base_esq = Vector2(%s, %s)\npivo = Vector2(%s, %s)\nbase_dir = Vector2(%s, %s)\n'
                   'largura_fatia = 64.0\nfolga = 26.0\nluz_por_lado = false\nluz_checar_obstaculos = false'
                   % (lado.capitalize(), arq, n(BASE_ESQ[0]), n(BASE_ESQ[1]),
                      n(PIVO[0]), n(PIVO[1]), n(BASE_DIR[0]), n(BASE_DIR[1])))

    # ---------- paredes (colisão + oclusão da luz) ----------
    nos.append('[node name="Paredes" type="StaticBody2D" parent="."]')
    for nome, p0, p1, esp in PAREDES:
        nos.append('[node name="%s" type="CollisionPolygon2D" parent="Paredes"]\npolygon = %s'
                   % (nome, pts(faixa(p0, p1, esp))))
    for nome, poli in BLOCOS:
        nos.append('[node name="%s" type="CollisionPolygon2D" parent="Paredes"]\npolygon = %s' % (nome, pts(poli)))
    nos.append('[node name="Oclusores" type="Node2D" parent="."]')
    for nome, p0, p1, esp in PAREDES:
        sub.append('[sub_resource type="OccluderPolygon2D" id="oc_%s"]\npolygon = %s'
                   % (nome, pts(faixa(p0, p1, esp))))
        nos.append('[node name="%s" type="LightOccluder2D" parent="Oclusores"]\noccluder = SubResource("oc_%s")'
                   % (nome, nome))

    # ---------- áreas dos cômodos ----------
    for comodo, poli in COMODOS.items():
        nos.append('[node name="Area%s" type="Area2D" parent="."]\ncollision_layer = 0\ncollision_mask = 2'
                   % comodo.capitalize())
        nos.append('[node name="Piso" type="CollisionPolygon2D" parent="Area%s"]\npolygon = %s'
                   % (comodo.capitalize(), pts(poli)))

    # ---------- aberturas ----------
    for a in ABERTURAS:
        caminhos = []
        for k, (camada, x0, y0, x1, y1, esp) in enumerate(a["sprites"]):
            sn = "%s_%s" % (a["nome"], camada)
            tw, th = pj[a["fechada"]][2], pj[a["fechada"]][3]
            sx, sy = (x1 - x0) / float(tw), (y1 - y0) / float(th)
            # dobradiça: o sprite cresce a partir da origem, então a origem é a dobradiça
            px = x1 if esp else x0
            nos.append('[node name="%s" type="Sprite2D" parent="."]\nlight_mask = 2\ntexture_filter = 2\n'
                       'position = %s\nscale = Vector2(%s, %s)\ntexture = ExtResource("pj_%s")\n'
                       'centered = false\noffset = Vector2(0, %s)'
                       % (sn, vec((px, y1)), n(-sx if esp else sx), n(sy),
                          a["fechada"], n((y0 - y1) / sy)))
            caminhos.append('NodePath("../%s")' % sn)
        nos.append('[node name="Vao%s" type="CollisionPolygon2D" parent="Paredes"]\npolygon = %s'
                   % (a["nome"], pts(a.get("corredor") or faixa(a["vao"][0], a["vao"][1], a["espessura"]))))
        sub.append('[sub_resource type="OccluderPolygon2D" id="oc_Vao%s"]\npolygon = %s'
                   % (a["nome"], pts(faixa(a["vao"][0], a["vao"][1], a["espessura"]))))
        nos.append('[node name="Vao%s" type="LightOccluder2D" parent="Oclusores"]\noccluder = SubResource("oc_Vao%s")'
                   % (a["nome"], a["nome"]))
        nos.append('[node name="%s" type="Node2D" parent="."]\nposition = %s\nscript = ExtResource("3_abre")\n'
                   'rotulo = "%s"\nalcance = %s\ncomodos = PackedStringArray(%s)\n'
                   'textura_fechada = ExtResource("pj_%s")\ntextura_aberta = ExtResource("pj_%s")\n'
                   'sprites = Array[NodePath]([%s])\ncolisao = NodePath("../Paredes/Vao%s")\noclusor = NodePath("../Oclusores/Vao%s")'
                   % (a["nome"], vec(a["ponto"]), a["rotulo"], n(a["alcance"] * ESCALA),
                      ", ".join('"%s"' % c for c in a["comodos"]),
                      a["fechada"], a["aberta"], ", ".join(caminhos), a["nome"], a["nome"]))

    cena = "[gd_scene load_steps=%d format=3]\n\n%s\n\n%s\n\n%s\n" % (
        len(ext) + len(sub) + 1, "\n".join(ext), "\n\n".join(sub), "\n\n".join(nos))
    cam = os.path.join(RAIZ, "scenes/world/buildings", NOME + ".tscn")
    os.makedirs(os.path.dirname(cam), exist_ok=True)
    with open(cam, "w", encoding="utf-8", newline="\n") as f:
        f.write(cena)
    print("scenes/world/buildings/%s.tscn — %d paredes, %d aberturas, %d cômodos"
          % (NOME, len(PAREDES), len(ABERTURAS), len(COMODOS)))


if __name__ == "__main__":
    sys.exit(main())
