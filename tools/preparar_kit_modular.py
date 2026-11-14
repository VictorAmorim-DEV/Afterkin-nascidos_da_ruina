#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — recorta e padroniza o kit modular de construção.

Uso (na raiz do projeto):
    python tools/preparar_kit_modular.py

Entrada:  assets/new_assets/kit_modular_casa_hd.png
Saída:    assets/sprites_hd_recortados/kit_casa/*.png  +  kit.json

A folha foi desenhada à mão livre: cada parede tem um comprimento e uma inclinação
um pouco diferentes. Para as peças ENCAIXAREM num grid isométrico 2:1, cada uma é
"retificada": a base e o topo viram linhas 2:1 exatas, o comprimento vira o de um
módulo (MODULO px) e a altura a de uma parede (ALTURA px). Linhas verticais continuam
verticais, então portas e janelas não entortam.

Tudo sai em resolução 2x (na cena as peças usam escala 0,5):
    módulo de parede = 148 x 74 px (1 célula = 3 m)   altura da parede = 196 px (3,2 m,
    para o vão da porta ficar com 2,1 m)

Cada peça de parede sai em duas orientações:
    *_y   parede ao longo do eixo Y do mundo  ( / na tela, como na folha)
    *_x   parede ao longo do eixo X do mundo  ( \\ na tela, espelhada)
Os vãos de porta e janela ficam transparentes, e a posição de cada vão vai para o
kit.json — é ali dentro que a cena encaixa as portas e janelas.

Requisitos: Python 3, numpy, opencv-python, Pillow.
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTRADA = "assets/new_assets/kit_modular_casa_hd.png"
SAIDA = "assets/sprites_hd_recortados/kit_casa"

MODULO = 148          # comprimento de um módulo de parede na tela, em px (2x)
ALTURA = 196          # altura da parede em px (2x)
ALTURA_BAIXA = 64     # altura da parede cortada (estilo Project Zomboid)
SOBRA = 4             # px a mais no comprimento, para as peças se sobreporem sem fresta
V = 0.70              # escala vertical das peças sem altura padronizada
MARGEM = 10
FORCA_RELEVO = 2.2

# ordem das peças na folha (linha a linha, da esquerda para a direita)
PECAS = ["parede_lisa", "parede_curta", "canto_portas", "parede_janela", "parede_janela2",
         "baixa_a", "baixa_b", "pisos", "telhado_b", "telhado_c",
         "porta_fechada", "porta_aberta", "janela_fechada", "janela_aberta",
         "telhado_painel", "telhado_d"]


def remover_fundo(rgb):
    escuro = (rgb.max(2) <= 14).astype(np.uint8)
    miolo = cv2.erode(escuro, np.ones((3, 3), np.uint8))
    n, lab = cv2.connectedComponents(miolo, connectivity=4)
    borda = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    fundo = cv2.dilate(np.isin(lab, borda[borda > 0]).astype(np.uint8), np.ones((3, 3), np.uint8)) & escuro
    return (1 - fundo).astype(np.uint8)


def abrir_vaos(rgb, fg, area_min=1200):
    """Buracos pretos fechados (vão de porta/janela) viram transparência."""
    preto = ((rgb.max(2) <= 8) & (fg > 0)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(preto, connectivity=4)
    vaos = np.zeros_like(fg)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= area_min:
            vaos[lab == i] = 1
    vaos = cv2.dilate(vaos, np.ones((3, 3), np.uint8))
    return fg & (1 - vaos), vaos


def linhas(m, f0=0.2, f1=0.8):
    """Ajusta as retas do topo e da base do recorte (y = a*x + b, em px do recorte)."""
    w = m.shape[1]
    xs, yt, yb = [], [], []
    for c in range(int(w * f0), int(w * f1)):
        col = np.nonzero(m[:, c])[0]
        if len(col):
            xs.append(c); yt.append(col.min()); yb.append(col.max())
    return np.polyfit(xs, yt, 1), np.polyfit(xs, yb, 1)


def retificar(rgba, topo, base, altura=None, largura=MODULO + SOBRA, extra=None):
    """Remapeia a peça: base -> reta 2:1 exata; se 'altura' for dada, o topo também.
    Devolve (imagem, ancora) — ancora = ponto esquerdo-inferior da base na imagem."""
    h, w = rgba.shape[:2]
    sx = largura / float(w)
    alt_arte = lambda x: (base[0] * x + base[1]) - (topo[0] * x + topo[1])
    alt_ref = altura if altura else V * alt_arte(w / 2.0)
    acima = int(alt_ref + 0.5 * largura + (extra or 0)) + MARGEM
    H = acima + MARGEM * 3
    W = int(largura) + 2 * MARGEM
    y0 = H - MARGEM * 2                            # y da base em x' = 0
    xo, yo = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32))
    xa = (xo - MARGEM) / sx                        # coluna na arte
    yb_saida = y0 - 0.5 * (xo - MARGEM)            # base 2:1 na saída
    escala_v = (alt_arte(xa) / alt_ref) if altura else np.full_like(xa, 1.0 / V)
    ya = (base[0] * xa + base[1]) - (yb_saida - yo) * escala_v
    pre = rgba.astype(np.float32)
    pre[..., :3] *= pre[..., 3:4] / 255.0
    out = cv2.remap(pre, xa, ya.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    a = np.maximum(out[..., 3:4], 1e-3)
    out[..., :3] = np.where(out[..., 3:4] > 1.0, out[..., :3] * 255.0 / a, 0)
    return np.clip(out + 0.5, 0, 255).astype(np.uint8), (MARGEM, y0)


def normais(rgba):
    cinza = cv2.cvtColor(rgba[..., :3], cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    cinza = cv2.bilateralFilter(cinza, 7, 0.12, 7)
    dx = cv2.Sobel(cinza, cv2.CV_32F, 1, 0, ksize=5) * FORCA_RELEVO
    dy = cv2.Sobel(cinza, cv2.CV_32F, 0, 1, ksize=5) * FORCA_RELEVO
    nz = np.ones_like(dx)
    norma = np.sqrt(dx * dx + dy * dy + nz)
    n = ((np.dstack([-dx / norma, -dy / norma, nz / norma]) * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)
    n[rgba[..., 3] == 0] = (128, 128, 255)
    return n


class Kit:
    def __init__(self):
        self.info = {"modulo": MODULO, "altura": ALTURA, "altura_baixa": ALTURA_BAIXA, "pecas": {}}
        self.dir = os.path.join(RAIZ, SAIDA)
        os.makedirs(self.dir, exist_ok=True)

    def salvar(self, nome, img, com_normais=False, **dados):
        img = img.copy()
        img[img[..., 3] == 0, :3] = 0
        Image.fromarray(img, "RGBA").save(os.path.join(self.dir, nome + ".png"), optimize=True)
        if com_normais:
            Image.fromarray(normais(img), "RGB").save(os.path.join(self.dir, nome + "_n.png"), optimize=True)
        dados["tamanho"] = [int(img.shape[1]), int(img.shape[0])]
        self.info["pecas"][nome] = dados

    def parede(self, nome, img, ancora, vao=None):
        """Salva a parede nas duas orientações. ancora = base esquerda-inferior (em _y)."""
        W = img.shape[1]
        ax, ay = ancora
        d = {"base": [[ax, ay], [ax + MODULO, ay - MODULO // 2]]}
        dx = {"base": [[W - ax - MODULO, ay - MODULO // 2], [W - ax, ay]]}
        if vao is not None:
            ys, xs = np.nonzero(vao)
            x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
            d["vao"] = [x0, y0, x1, y1]
            dx["vao"] = [W - x1, y0, W - x0, y1]
            d["vao_base"] = dx["vao_base"] = [round((x0 - ax) / float(MODULO), 3), round((x1 - ax) / float(MODULO), 3)]
        self.salvar(nome + "_y", img, True, **d)
        if "vao_base" in dx:      # espelhada, a fração ao longo da base inverte
            f0, f1 = dx["vao_base"]
            dx["vao_base"] = [round(1 - f1, 3), round(1 - f0, 3)]
        self.salvar(nome + "_x", img[:, ::-1], True, **dx)


def main():
    cam = os.path.join(RAIZ, ENTRADA)
    if not os.path.isfile(cam):
        print("ERRO: não encontrei", ENTRADA); return 1
    rgb = np.array(Image.open(cam).convert("RGB"))
    fg = remover_fundo(rgb)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    caixas = sorted([tuple(int(v) for v in st[i, :4]) for i in range(1, n) if st[i, 4] > 2500],
                    key=lambda g: (0 if g[1] < 400 else 1 if g[1] < 640 else 2, g[0]))
    if len(caixas) != len(PECAS):
        print("ERRO: achei %d peças na folha, esperava %d" % (len(caixas), len(PECAS))); return 1
    rec = {}
    for nome, (x, y, w, h) in zip(PECAS, caixas):
        rec[nome] = (rgb[y:y + h, x:x + w], fg[y:y + h, x:x + w].copy())
    kit = Kit()

    def rgba_de(cor, m):
        return np.dstack([cor, m * 255]).astype(np.uint8)

    # ---------- paredes altas ----------
    for nome, origem in (("parede_lisa", "parede_lisa"), ("parede_janela", "parede_janela"),
                         ("parede_janela2", "parede_janela2"), ("parede_porta", "canto_portas")):
        cor, m = rec[origem]
        if origem == "canto_portas":              # só a metade esquerda (a parede "/" com porta)
            topo_col = [np.nonzero(m[:, c])[0].min() if m[:, c].any() else 9999 for c in range(m.shape[1])]
            quina = int(np.argmin(topo_col[100:300])) + 100 + 6
            cor, m = cor[:, :quina], m[:, :quina].copy()
        m, vaos = abrir_vaos(cor, m)
        topo, base = linhas(m | vaos, 0.15, 0.75)
        img, anc = retificar(rgba_de(cor, m), topo, base, altura=ALTURA)
        vao = None
        if vaos.any():
            vimg, _ = retificar(rgba_de(cor, vaos), topo, base, altura=ALTURA)
            vao = vimg[..., 3] > 128
        kit.parede(nome, img, anc, vao)
        if nome == "parede_porta":                # versão baixa: a mesma peça cortada
            xo, yo = np.meshgrid(np.arange(img.shape[1]), np.arange(img.shape[0]))
            corte = (anc[1] - 0.5 * (xo - anc[0])) - ALTURA_BAIXA
            baixa = img.copy()
            baixa[yo < corte] = 0
            kit.parede("baixa_porta", baixa, anc, vao & (yo >= corte))

    # ---------- paredes baixas do kit ----------
    for nome, origem in (("baixa_lisa", "baixa_a"), ("baixa_lisa2", "baixa_b")):
        cor, m = rec[origem]
        topo, base = linhas(m, 0.15, 0.7)
        img, anc = retificar(rgba_de(cor, m), topo, base, extra=40)
        kit.parede(nome, img, anc)

    # ---------- portas e janelas (mesma inclinação das paredes) ----------
    for fechada, aberta in (("porta_fechada", "porta_aberta"), ("janela_fechada", "janela_aberta")):
        cor, m = rec[fechada]
        topo, base = linhas(m)
        for nome in (fechada, aberta):
            c2, m2 = rec[nome]
            if nome == "porta_aberta":            # o vão escuro da porta aberta fica transparente
                m2, _ = abrir_vaos(c2, m2, 800)
            # a peça aberta usa as retas da fechada (a folha aberta atrapalha o ajuste)
            b2 = (base[0], base[1] + (c2.shape[0] - cor.shape[0]))
            img, _ = retificar(rgba_de(c2, m2), topo, b2, largura=c2.shape[1] * V, extra=70)
            ys, xs = np.nonzero(img[..., 3] > 30)
            img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            kit.salvar(nome + "_y", img)
            kit.salvar(nome + "_x", img[:, ::-1])

    # ---------- pisos: dois losangos encostados; separa e ajusta ao losango da célula ----------
    cor, m = rec["pisos"]
    meio = m.shape[1] // 2
    corte = meio - 40 + int(np.argmin(m[:, meio - 40:meio + 40].sum(0)))
    for nome, sl in (("piso_madeira", slice(0, corte)), ("piso_pedra", slice(corte, m.shape[1]))):
        c2, m2 = cor[:, sl], m[:, sl]
        nn, ll, ss, _ = cv2.connectedComponentsWithStats(m2, connectivity=8)     # só o losango, sem lascas do vizinho
        m2 = (ll == 1 + int(ss[1:, cv2.CC_STAT_AREA].argmax())).astype(np.uint8)
        ys, xs = np.nonzero(m2)
        esq = (xs.min(), ys[xs == xs.min()].min())
        dir_ = (xs.max(), ys[xs == xs.max()].min())
        cima = (xs[ys == ys.min()].mean(), ys.min())
        M = cv2.getAffineTransform(np.float32([esq, cima, dir_]),
                                   np.float32([(2, MODULO // 2 + 2), (MODULO + 2, 2), (2 * MODULO + 2, MODULO // 2 + 2)]))
        img = cv2.warpAffine(rgba_de(c2, m2), M, (2 * MODULO + 4, MODULO + 30), flags=cv2.INTER_LINEAR)
        kit.salvar(nome, img, origem=[MODULO + 2, 2])     # origem = canto de cima do losango

    # ---------- telhado: painel inteiro + os 4 cantos, para a cena deformar por cômodo ----------
    cor, m = rec["telhado_painel"]
    ys, xs = np.nonzero(m)
    pts = np.stack([xs, ys], 1)
    cantos = {"esq": pts[xs.argmin()], "cima": pts[ys.argmin()], "dir": pts[xs.argmax()], "baixo": pts[ys.argmax()]}
    kit.salvar("telhado_painel", rgba_de(cor, m), cantos={k: [int(v[0]), int(v[1])] for k, v in cantos.items()})

    with open(os.path.join(kit.dir, "kit.json"), "w", encoding="utf-8") as f:
        json.dump(kit.info, f, ensure_ascii=False, indent=1)
    print("kit modular: %d texturas em %s" % (len(kit.info["pecas"]), SAIDA))
    for k, v in kit.info["pecas"].items():
        if "vao" in v:
            print("  %-18s vão %s  ao longo da base %s" % (k, v["vao"], v["vao_base"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
