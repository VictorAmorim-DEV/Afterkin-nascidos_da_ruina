#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — monta uma casa MODULAR a partir do kit de peças.

Uso (na raiz do projeto, depois de tools/preparar_kit_modular.py):
    python tools/gerar_construcao.py

Gera scenes/world/buildings/casa_abandonada.tscn (e as texturas dos telhados).

A casa é descrita pela PLANTA abaixo, num grid isométrico em que 1 célula = 3 m:
    tela.x = (x - y) * 74      tela.y = (x + y) * 37        (px de tela, origem = canto norte)
Cada parede de 1 célula, cada piso, cada telhado, porta e janela é um NÓ próprio:

    Piso_<x>_<y>          Sprite2D do piso de cada célula
    Parede_<...>          StaticBody2D (parede.gd) com a peça Alta e a peça Baixa,
                          a colisão e o oclusor de luz daquele trecho
    Porta_/Janela_<...>   abertura.gd, encaixada DENTRO do vão da parede com moldura
    Telhado<Cômodo>       telhado de cada cômodo
    Escuro<Cômodo>        sombra que cobre o cômodo ainda não revelado
    Area<Cômodo>          Area2D exata do piso do cômodo
    Conteudo<Cômodo>      móveis/objetos do cômodo (Y-Sort)

Quais paredes abaixam e quais telhados somem quando um cômodo é revelado NÃO é
anotado à mão: o script calcula, pela geometria, quais peças tapariam o piso daquele
cômodo na tela (ver tapa_piso). Mudou a planta, é só gerar de novo.
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = "assets/sprites_hd_recortados/kit_casa"
NOME = "casa_abandonada"

MX, MY = 74.0, 37.0          # meia-célula na tela (px)
ESC = 0.5                    # as texturas do kit estão em 2x
ESPESSURA = 5.0              # meia-espessura da colisão das paredes (px de tela)

# ---------------- PLANTA ----------------
# cômodos: nome -> (x0, y0, x1, y1, piso)
COMODOS = {
    "sala":    (0, 0, 2, 2, "piso_madeira"),
    "cozinha": (2, 0, 4, 2, "piso_pedra"),
}
# paredes: (eixo, posição, índice, peça)
#   eixo "x": parede na linha y = posição, da célula x = índice até índice + 1
#   eixo "y": parede na linha x = posição, da célula y = índice até índice + 1
PAREDES = [
    ("x", 0, 0, "lisa"), ("x", 0, 1, "lisa"), ("x", 0, 2, "lisa"), ("x", 0, 3, "lisa"),     # fundo (norte)
    ("y", 0, 0, "lisa"), ("y", 0, 1, "lisa"),                                              # fundo (oeste)
    ("x", 2, 0, "janela"), ("x", 2, 1, "lisa"), ("x", 2, 2, "porta"), ("x", 2, 3, "lisa"),  # frente (sul)
    ("y", 4, 0, "lisa"), ("y", 4, 1, "janela2"),                                           # frente (leste)
    ("y", 2, 0, "lisa"), ("y", 2, 1, "porta"),                                             # parede interna
]
# objetos dentro dos cômodos: (cômodo, cena em scenes/world/props_hd, x, y em células)
CONTEUDO = [
    ("sala", "caixote", 0.45, 0.5), ("sala", "barril_azul", 0.4, 1.5), ("sala", "caixa_madeira", 1.5, 0.4),
    ("cozinha", "caixa_madeira", 3.5, 0.45), ("cozinha", "barril_azul", 2.5, 0.4),
]
# telhado de duas águas com a cumeeira ao longo do eixo X (no meio da casa)
CUMEEIRA_Y, CUMEEIRA_ALT, BEIRAL, BEIRAL_PONTA = 1.0, 40.0, 0.10, 0.10


def S(x, y):
    """célula -> px de tela (relativo à origem da casa)."""
    return ((x - y) * MX, (x + y) * MY)


def n(v):
    s = "%.2f" % v
    return s.rstrip("0").rstrip(".") if "." in s else s


def vec(p):
    return "Vector2(%s, %s)" % (n(p[0]), n(p[1]))


def pts(ps):
    return "PackedVector2Array(%s)" % ", ".join("%s, %s" % (n(p[0]), n(p[1])) for p in ps)


def comodo_em(x, y, margem=0.02):
    for nome, (x0, y0, x1, y1, _) in COMODOS.items():
        if x0 + margem < x < x1 - margem and y0 + margem < y < y1 - margem:
            return nome
    return None


def comodos_tapados(pontos, alt0, alt1):
    """Cômodos cujo piso fica escondido, na tela, atrás de algo que está sobre 'pontos'
    (em células) entre as alturas alt0 e alt1 (px de tela). Um ponto a uma altura h
    aparece na tela no mesmo lugar do piso em (x - s, y - s), com s = h / (2 * MY)."""
    tapados = {}
    for (x, y) in pontos:
        for h in np.linspace(max(alt0, 4.0), alt1, 12):
            s = h / (2.0 * MY)
            c = comodo_em(x - s, y - s)
            if c:
                tapados[c] = tapados.get(c, 0) + 1
    return sorted(c for c, q in tapados.items() if q >= 6)


def lados_da_parede(eixo, pos, i):
    """Cômodos encostados nos dois lados de um trecho de parede."""
    if eixo == "x":
        a, b = comodo_em(i + 0.5, pos - 0.5), comodo_em(i + 0.5, pos + 0.5)
    else:
        a, b = comodo_em(pos - 0.5, i + 0.5), comodo_em(pos + 0.5, i + 0.5)
    return [c for c in (a, b) if c]


def gerar_telhado(kit, comodo, alt_parede):
    """Deforma o painel de telhado do kit para cobrir o cômodo. Devolve (arquivo, canto, tamanho)."""
    x0, y0, x1, y1, _ = COMODOS[comodo]
    xs_casa = [c[0] for c in COMODOS.values()] + [c[2] for c in COMODOS.values()]
    xa = x0 - (BEIRAL_PONTA if x0 == min(xs_casa) else 0)
    xb = x1 + (BEIRAL_PONTA if x1 == max(xs_casa) else 0)
    hr = alt_parede + CUMEEIRA_ALT
    he = alt_parede - BEIRAL * CUMEEIRA_ALT

    def P(x, y, h):                      # em px 2x
        return np.array([(x - y) * MX * 2, (x + y) * MY * 2 - h * 2], np.float32)
    sul = [P(xa, CUMEEIRA_Y, hr), P(xb, CUMEEIRA_Y, hr), P(xb, y1 + BEIRAL, he), P(xa, y1 + BEIRAL, he)]
    norte = [P(xa, CUMEEIRA_Y, hr), P(xb, CUMEEIRA_Y, hr), P(xb, y0 - BEIRAL, he), P(xa, y0 - BEIRAL, he)]
    oitao = [P(x1, y0, alt_parede), P(x1, y1, alt_parede), P(x1, CUMEEIRA_Y, hr)] if x1 == max(xs_casa) else None
    todos = np.array(sul + norte + (oitao or []))
    mn = np.floor(todos.min(0)) - 4
    tam = (np.ceil(todos.max(0)) - mn + 4).astype(int)
    tela = np.zeros((tam[1], tam[0], 4), np.float32)

    def compor(camada):
        a = camada[..., 3:4] / 255.0
        tela[..., :3] = camada[..., :3] * a + tela[..., :3] * (1 - a)
        tela[..., 3:4] = np.maximum(tela[..., 3:4], camada[..., 3:4])

    painel = np.array(Image.open(os.path.join(RAIZ, KIT, "telhado_painel.png")).convert("RGBA")).astype(np.float32)
    c = kit["pecas"]["telhado_painel"]["cantos"]
    origem = np.float32([c["cima"], c["esq"], c["baixo"], c["dir"]])
    origem = origem.mean(0) + (origem - origem.mean(0)) * 0.9     # o painel sobra um pouco: sem falhas na borda
    painel[..., :3] *= painel[..., 3:4] / 255.0

    def agua(quad, brilho):
        """Uma água do telhado: forro escuro + o painel do kit deformado para o quadrilátero."""
        destino = np.float32([p - mn for p in quad])
        base = np.zeros_like(tela)
        cv2.fillPoly(base, [np.int32(destino)], (46 * brilho, 36 * brilho, 32 * brilho, 255), lineType=cv2.LINE_AA)
        compor(base)
        w = cv2.warpPerspective(painel, cv2.getPerspectiveTransform(origem, destino), (int(tam[0]), int(tam[1])),
                                flags=cv2.INTER_LINEAR)
        al = np.maximum(w[..., 3:4], 1e-3)
        w[..., :3] = np.where(w[..., 3:4] > 1, w[..., :3] * 255.0 / al, 0) * brilho
        w[..., 3] *= base[..., 3] / 255.0                         # recorta o painel no contorno exato da água
        compor(w)

    agua(norte, 0.62)          # água de trás, vista de cima e na sombra
    # oitão: triângulo de parede entre o topo da parede e a cumeeira, na ponta leste
    if oitao is not None:
        par = np.array(Image.open(os.path.join(RAIZ, KIT, "parede_lisa_y.png")).convert("RGBA")).astype(np.float32)
        b = kit["pecas"]["parede_lisa_y"]["base"]
        cam = np.zeros_like(tela)
        for j in range(y0, y1):
            q = P(x1, j + 1, alt_parede * 0.55) - mn          # peça de parede erguida até o oitão
            ox, oy = int(q[0] - b[0][0]), int(q[1] - b[0][1])
            h, w = par.shape[:2]
            ya, yb, xa2, xb2 = max(oy, 0), min(oy + h, tam[1]), max(ox, 0), min(ox + w, tam[0])
            rec = par[ya - oy:yb - oy, xa2 - ox:xb2 - ox]
            reg = cam[ya:yb, xa2:xb2]
            al = rec[..., 3:4] / 255.0
            reg[..., :3] = rec[..., :3] * al + reg[..., :3] * (1 - al)
            reg[..., 3:4] = np.maximum(reg[..., 3:4], rec[..., 3:4])
        m = np.zeros(tela.shape[:2], np.uint8)
        cv2.fillPoly(m, [np.int32([p - mn for p in oitao])], 255, lineType=cv2.LINE_AA)
        cam[..., 3] *= m / 255.0
        cam[..., :3] *= 0.82
        compor(cam)
    agua(sul, 1.0)             # água da frente (cumeeira do painel -> cumeeira da casa)
    img = np.clip(tela + 0.5, 0, 255).astype(np.uint8)
    img[img[..., 3] == 0, :3] = 0
    arq = "telhado_%s.png" % comodo
    Image.fromarray(img, "RGBA").save(os.path.join(RAIZ, KIT, arq), optimize=True)
    return arq, (mn[0] / 2.0, mn[1] / 2.0), (xa, xb)


def main():
    with open(os.path.join(RAIZ, KIT, "kit.json"), encoding="utf-8") as f:
        kit = json.load(f)
    pc = kit["pecas"]
    ALT = kit["altura"] * ESC                 # altura da parede na tela
    ext, sub, nos = {}, [], []

    def tex(nome, normais=False):
        """id de uma textura (CanvasTexture com relevo quando normais=True)."""
        if nome not in ext:
            ext[nome] = '[ext_resource type="Texture2D" path="res://%s/%s.png" id="t_%s"]' % (KIT, nome, nome)
        if not normais:
            return 'ExtResource("t_%s")' % nome
        if nome + "_n" not in ext:
            ext[nome + "_n"] = '[ext_resource type="Texture2D" path="res://%s/%s_n.png" id="t_%s_n"]' % (KIT, nome, nome)
            sub.append('[sub_resource type="CanvasTexture" id="ct_%s"]\ndiffuse_texture = ExtResource("t_%s")\n'
                       'normal_texture = ExtResource("t_%s_n")' % (nome, nome, nome))
        return 'SubResource("ct_%s")' % nome

    scripts = ['[ext_resource type="Script" path="res://scripts/world/construcao.gd" id="s_casa"]',
               '[ext_resource type="Script" path="res://scripts/world/iso_prop.gd" id="s_prop"]',
               '[ext_resource type="Script" path="res://scripts/world/parede.gd" id="s_parede"]',
               '[ext_resource type="Script" path="res://scripts/world/abertura.gd" id="s_abre"]']
    lista = ", ".join('"%s"' % c for c in COMODOS)
    nos.append('[node name="%s" type="Node2D"]\ny_sort_enabled = true\nscript = ExtResource("s_casa")\n'
               'comodos = PackedStringArray(%s)' % ("".join(t.capitalize() for t in NOME.split("_")), lista))

    # ---------- pisos e sombras ----------
    for comodo, (x0, y0, x1, y1, piso) in COMODOS.items():
        o = pc[piso]["origem"]
        for cy in range(y0, y1):
            for cx in range(x0, x1):
                nos.append('[node name="Piso_%d_%d" type="Sprite2D" parent="."]\nz_index = -1\ntexture_filter = 2\n'
                           'position = %s\nscale = Vector2(0.5, 0.5)\ntexture = %s\ncentered = false\noffset = Vector2(%d, %d)'
                           % (cx, cy, vec(S(cx, cy)), tex(piso), -o[0], -o[1]))
    for comodo, (x0, y0, x1, y1, _) in COMODOS.items():
        nos.append('[node name="Escuro%s" type="Polygon2D" parent="."]\nvisible = false\nz_index = -1\n'
                   'color = Color(0.02, 0.02, 0.03, 0.9)\npolygon = %s'
                   % (comodo.capitalize(), pts([S(x0, y0), S(x1, y0), S(x1, y1), S(x0, y1)])))

    # ---------- paredes ----------
    resumo = []
    for eixo, pos, i, peca in PAREDES:
        nome = "Parede_%s%d_%d" % (eixo.upper(), pos, i)
        sufixo = "_" + eixo
        alta = "parede_%s%s" % (peca, sufixo)
        baixa = ("baixa_porta" if peca == "porta" else "baixa_lisa2" if (i + pos) % 2 else "baixa_lisa") + sufixo
        if eixo == "x":                           # "\" na tela: pivô = ponta direita (a mais baixa)
            p0, p1 = (i, pos), (i + 1, pos)
            pivo_cel = p1
        else:                                     # "/" na tela: pivô = ponta esquerda (a mais baixa)
            p0, p1 = (pos, i + 1), (pos, i)
            pivo_cel = p0
        origem = S(*pivo_cel)
        amostras = [(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t) for t in np.linspace(0.05, 0.95, 10)]
        baixa_para = comodos_tapados(amostras, 0.0, ALT)
        resumo.append((nome, baixa_para))

        def no_peca(rotulo, t, alfa):
            b = pc[t]["base"]
            pv = b[1] if eixo == "x" else b[0]
            return ('[node name="%s" type="StaticBody2D" parent="%s"]\n%sy_sort_enabled = true\ncollision_layer = 0\n'
                    'collision_mask = 0\nscript = ExtResource("s_prop")\ntextura = %s\nescala = 0.5\n'
                    'base_esq = Vector2(%d, %d)\npivo = Vector2(%d, %d)\nbase_dir = Vector2(%d, %d)\n'
                    'luz_por_lado = false\nluz_checar_obstaculos = false'
                    % (rotulo, nome, "" if alfa else "modulate = Color(1, 1, 1, 0)\n", tex(t, True),
                       b[0][0], b[0][1], pv[0], pv[1], b[1][0], b[1][1]))

        nos.append('[node name="%s" type="StaticBody2D" parent="."]\ny_sort_enabled = true\nposition = %s\n'
                   'script = ExtResource("s_parede")\nbaixa_para = PackedStringArray(%s)'
                   % (nome, vec(origem), ", ".join('"%s"' % c for c in baixa_para)))
        nos.append(no_peca("Alta", alta, True))
        nos.append(no_peca("Baixa", baixa, False))

        # base da parede em coordenadas locais (da esquerda para a direita na tela)
        b = pc[alta]["base"]
        pv = b[1] if eixo == "x" else b[0]
        loc = lambda q: ((q[0] - pv[0]) * ESC, (q[1] - pv[1]) * ESC)
        e0, e1 = loc(b[0]), loc(b[1])
        ponto = lambda f: (e0[0] + (e1[0] - e0[0]) * f, e0[1] + (e1[1] - e0[1]) * f)
        faixa = lambda f0, f1: [(ponto(f0)[0], ponto(f0)[1] - ESPESSURA), (ponto(f1)[0], ponto(f1)[1] - ESPESSURA),
                                (ponto(f1)[0], ponto(f1)[1] + ESPESSURA), (ponto(f0)[0], ponto(f0)[1] + ESPESSURA)]
        vao = pc[alta].get("vao_base")
        trechos = [("", 0.0, 1.0)] if not vao else [("A", 0.0, vao[0]), ("B", vao[1], 1.0)]
        if vao and peca != "porta":               # janela: a parede continua inteira para a colisão
            nos.append('[node name="Colisao" type="CollisionPolygon2D" parent="%s"]\npolygon = %s' % (nome, pts(faixa(0, 1))))
        for r, f0, f1 in trechos:
            if not vao or peca == "porta":
                nos.append('[node name="Colisao%s" type="CollisionPolygon2D" parent="%s"]\npolygon = %s' % (r, nome, pts(faixa(f0, f1))))
            oid = "oc_%s%s" % (nome, r)
            sub.append('[sub_resource type="OccluderPolygon2D" id="%s"]\npolygon = %s' % (oid, pts(faixa(f0, f1))))
            nos.append('[node name="Oclusor%s" type="LightOccluder2D" parent="%s"]\noccluder = SubResource("%s")' % (r, nome, oid))
        if not vao:
            continue

        # ---------- abertura encaixada no vão ----------
        eh_porta = peca == "porta"
        tipo = "porta" if eh_porta else "janela"
        oid = "oc_%sVao" % nome
        sub.append('[sub_resource type="OccluderPolygon2D" id="%s"]\npolygon = %s' % (oid, pts(faixa(vao[0], vao[1]))))
        nos.append('[node name="OclusorVao" type="LightOccluder2D" parent="%s"]\noccluder = SubResource("%s")' % (nome, oid))
        if eh_porta:
            nos.append('[node name="ColisaoVao" type="CollisionPolygon2D" parent="%s"]\npolygon = %s' % (nome, pts(faixa(vao[0], vao[1]))))
        centro = ponto((vao[0] + vao[1]) / 2.0)
        r = pc[alta]["vao"]                        # retângulo do vão na textura
        folga = 0.10 if eh_porta else 0.22        # a peça tem moldura própria: passa um pouco do vão
        vw, vh = (r[2] - r[0]) * (1 + 2 * folga), (r[3] - r[1]) * (1 + folga * (1.0 if eh_porta else 2.0))
        vx0 = r[0] - (r[2] - r[0]) * folga
        vy0 = r[1] - (r[3] - r[1]) * folga
        tf, ta = "%s_fechada%s" % (tipo, sufixo), "%s_aberta%s" % (tipo, sufixo)
        wf, hf = pc[tf]["tamanho"]
        wa, ha = pc[ta]["tamanho"]
        sx, sy = vw / wf * ESC, vh / hf * ESC
        pai = nome if eh_porta else nome + "/Alta"   # a janela some junto com a parede alta
        y_ordem = centro[1] + 3.0
        for rot, t, w_, h_ in (("Fechada", tf, wf, hf), ("Aberta", ta, wa, ha)):
            if eh_porta:                           # alinha pela quina de cima do batente (dobradiça)
                x_tex = vx0 if eixo == "y" else vx0 + vw - w_ * sx / ESC
                y_tex = vy0
            else:                                  # janela aberta: centraliza no vão (as folhas abrem para os lados)
                x_tex = vx0 + (vw - w_ * sx / ESC) / 2.0
                y_tex = vy0 + (vh - h_ * sy / ESC) / 2.0
            px, py = loc((x_tex, y_tex))
            nos.append('[node name="%s%s" type="Sprite2D" parent="%s"]\n%slight_mask = 2\ntexture_filter = 2\n'
                       'position = %s\nscale = Vector2(%s, %s)\ntexture = %s\ncentered = false\noffset = Vector2(0, %s)'
                       % (tipo.capitalize(), rot, pai, "visible = false\n" if rot == "Aberta" else "",
                          vec((px, y_ordem)), n(sx), n(sy), tex(t), n((py - y_ordem) / sy)))
        # lados da parede (para o salto da janela) e cômodos que a abertura revela
        normal = (-MX * 0.3, MY * 0.3) if eixo == "x" else (MX * 0.3, MY * 0.3)     # aponta para +y / +x do mundo
        lados = lados_da_parede(eixo, pos, i)
        prefixo = "../" if eh_porta else "../../"
        no_ab = "%s_%s%d_%d" % (tipo.capitalize(), eixo.upper(), pos, i)
        nos.append('[node name="%s" type="Node2D" parent="%s"]\nposition = %s\nscript = ExtResource("s_abre")\n'
                   'tipo = "%s"\nrotulo = "%s"\ncomodos = PackedStringArray(%s)\n'
                   'no_fechada = NodePath("../%s%sFechada")\nno_aberta = NodePath("../%s%sAberta")\n'
                   '%soclusor = NodePath("../OclusorVao")\nlado_a = %s\nlado_b = %s'
                   % (no_ab, nome, vec(centro), tipo, "a porta" if eh_porta else "a janela",
                      ", ".join('"%s"' % c for c in lados),
                      "" if eh_porta else "Alta/", tipo.capitalize(), "" if eh_porta else "Alta/", tipo.capitalize(),
                      'colisao = NodePath("../ColisaoVao")\n' if eh_porta else "",
                      vec((-normal[0], -normal[1])), vec(normal)))

    # ---------- conteúdo, áreas e telhados ----------
    usados = sorted({c[1] for c in CONTEUDO})
    for u in usados:
        ext["p_" + u] = '[ext_resource type="PackedScene" path="res://scenes/world/props_hd/%s.tscn" id="p_%s"]' % (u, u)
    for comodo, (x0, y0, x1, y1, _) in COMODOS.items():
        C = comodo.capitalize()
        nos.append('[node name="Conteudo%s" type="Node2D" parent="."]\ny_sort_enabled = true' % C)
        k = 0
        for cm, cena, x, y in CONTEUDO:
            if cm == comodo:
                k += 1
                nos.append('[node name="%s%d" parent="Conteudo%s" instance=ExtResource("p_%s")]\nposition = %s'
                           % ("".join(t.capitalize() for t in cena.split("_")), k, C, cena, vec(S(x, y))))
        e = 0.07
        nos.append('[node name="Area%s" type="Area2D" parent="."]\ncollision_layer = 0\ncollision_mask = 2' % C)
        nos.append('[node name="Piso" type="CollisionPolygon2D" parent="Area%s"]\npolygon = %s'
                   % (C, pts([S(x0 + e, y0 + e), S(x1 - e, y0 + e), S(x1 - e, y1 - e), S(x0 + e, y1 - e)])))
    for comodo, (x0, y0, x1, y1, _) in COMODOS.items():
        arq, canto, (xa, xb) = gerar_telhado(kit, comodo, ALT)
        amostras = [(x, y) for x in np.linspace(xa, xb, 9) for y in np.linspace(y0 - BEIRAL, y1 + BEIRAL, 9)]
        some_para = sorted(set(comodos_tapados(amostras, ALT * 0.9, ALT + CUMEEIRA_ALT)) | {comodo})
        resumo.append(("Telhado" + comodo.capitalize(), some_para))
        y_ordem = S(x1, y1)[1] + 1.0
        ext["telhado_" + comodo] = '[ext_resource type="Texture2D" path="res://%s/%s" id="t_telhado_%s"]' % (KIT, arq, comodo)
        nos.append('[node name="Telhado%s" type="Sprite2D" parent="."]\nlight_mask = 2\ntexture_filter = 2\n'
                   'position = Vector2(0, %s)\nscale = Vector2(0.5, 0.5)\ntexture = ExtResource("t_telhado_%s")\n'
                   'centered = false\noffset = Vector2(%s, %s)\nmetadata/some_para = PackedStringArray(%s)'
                   % (comodo.capitalize(), n(y_ordem), comodo, n(canto[0] * 2), n((canto[1] - y_ordem) * 2),
                      ", ".join('"%s"' % c for c in some_para)))

    cab = scripts + list(ext.values())
    cena = "[gd_scene load_steps=%d format=3]\n\n%s\n\n%s\n\n%s\n" % (
        len(cab) + len(sub) + 1, "\n".join(cab), "\n\n".join(sub), "\n\n".join(nos))
    cam = os.path.join(RAIZ, "scenes/world/buildings", NOME + ".tscn")
    os.makedirs(os.path.dirname(cam), exist_ok=True)
    with open(cam, "w", encoding="utf-8", newline="\n") as f:
        f.write(cena)
    print("scenes/world/buildings/%s.tscn — %d paredes, %d cômodos" % (NOME, len(PAREDES), len(COMODOS)))
    for nome, quem in resumo:
        if quem:
            print("  %-16s %s quando revelado: %s" % (nome, "some" if nome.startswith("Telhado") else "abaixa", ", ".join(quem)))


if __name__ == "__main__":
    sys.exit(main())
