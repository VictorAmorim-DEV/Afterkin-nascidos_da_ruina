#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — prepara a casa HD (fachada, interior, portas e janelas).

Uso (na raiz do projeto):
    python tools/preparar_casa_hd.py

Entrada (assets/new_assets/): casa_fachada_hd.png, casa_interior_iso_hd.png,
                              portas_janelas_hd.png
Saída (assets/sprites_hd_recortados/):
    casa/interior_sala.png     interior isométrico (piso, móveis, paredes altas) da SALA
    casa/interior_cozinha.png  idem, da COZINHA
    casa/fachada_sala.png      telhado + parede frontal da SALA
    casa/fachada_cozinha.png   idem, da COZINHA
    casa/*_n.png               mapas de normais gerados do próprio desenho (relevo)
    portas_janelas/*.png       24 sprites de portas e janelas, fechadas e abertas

As duas imagens da casa foram desenhadas na mesma posição e escala, então a fachada
é recortada em duas metades pela MESMA linha que separa os cômodos (CORTE, abaixo).
Escondendo uma metade, aparece o interior daquele cômodo — o corte estilo
Project Zomboid. A outra metade continua fechada.

O fundo preto é removido por preenchimento a partir da borda, então preto DENTRO
do desenho (vãos, sombras) é preservado.

Requisitos: Python 3, numpy, opencv-python, Pillow.
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTRADA = "assets/new_assets"
SAIDA = "assets/sprites_hd_recortados"

LIMIAR_PRETO = 14          # canal mais claro <= isto conta como "preto de fundo"
FORCA_RELEVO = 2.2         # altura do relevo nos mapas de normais

# Linha que separa SALA (esquerda) de COZINHA (direita), em px das imagens da casa.
# Acompanha o topo da parede interna e desce pela ponta dela até a base da casa, de
# modo que a sala fica com a parede interna inteira e a cozinha com o telhado acima dela.
CORTE = [(880, 0), (880, 167), (1046, 245), (1046, 887)]

# nomes dos 24 sprites da folha de portas e janelas, na ordem da grade (6 por linha)
NOMES_PJ = [
    "porta_tabuas_fechada", "porta_tabuas_aberta", "porta_almofadada_fechada",
    "porta_almofadada_aberta", "porta_vidro4_fechada", "porta_vidro4_aberta",
    "porta_vidro4b_fechada", "porta_vidro4b_aberta", "porta_vidro1_fechada",
    "porta_vidro1_aberta", "porta_veneziana_fechada", "porta_veneziana_aberta",
    "janela_postigo_fechada", "janela_postigo_aberta", "janela_postigo_aberta_b",
    "janela_postigo_aberta_c", "janela_simples_fechada", "janela_simples_quebrada",
    "janela_baixa_fechada", "janela_baixa_aberta", "janela_baixa_aberta_b",
    "janela_baixa_aberta_c", "janela_alta_fechada", "janela_alta_aberta",
]


def remover_fundo(caminho):
    """Tira o fundo preto ligado à borda; preto interno é mantido."""
    rgb = np.array(Image.open(caminho).convert("RGB"))
    escuro = (rgb.max(2) <= LIMIAR_PRETO).astype(np.uint8)
    miolo = cv2.erode(escuro, np.ones((3, 3), np.uint8))
    n, lab = cv2.connectedComponents(miolo, connectivity=4)
    borda = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    fundo = np.isin(lab, borda[borda > 0]).astype(np.uint8)
    fundo = cv2.dilate(fundo, np.ones((3, 3), np.uint8)) & escuro
    fg = (1 - fundo).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    pequenos = np.nonzero(st[:, cv2.CC_STAT_AREA] < 40)[0]
    fg[np.isin(lab, pequenos[pequenos > 0])] = 0
    alfa = np.clip((cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 0.6) - 0.25) / 0.5, 0, 1) * fg
    a8 = (alfa * 255 + 0.5).astype(np.uint8)
    rgba = np.dstack([rgb, a8])
    rgba[a8 == 0, :3] = 0
    return rgba


def mapa_de_normais(rgba, forca=FORCA_RELEVO):
    """Normal map tangente a partir do brilho do próprio desenho (relevo 2D)."""
    cinza = cv2.cvtColor(rgba[..., :3], cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    cinza = cv2.bilateralFilter(cinza, 7, 0.12, 7)        # tira ruído, mantém arestas
    dx = cv2.Sobel(cinza, cv2.CV_32F, 1, 0, ksize=5) * forca
    dy = cv2.Sobel(cinza, cv2.CV_32F, 0, 1, ksize=5) * forca
    nx, ny, nz = -dx, -dy, np.ones_like(dx)
    norma = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.dstack([nx / norma, ny / norma, nz / norma]) * 0.5 + 0.5
    n = (rgb * 255 + 0.5).astype(np.uint8)
    n[rgba[..., 3] == 0] = (128, 128, 255)                # fora do desenho: normal reta
    return n


def mascara_lado(forma, lado):
    """Máscara 0/255 de um lado da linha CORTE."""
    h, w = forma
    m = np.zeros((h, w), np.uint8)
    x = 0 if lado == "sala" else w
    poli = np.array([(x, 0)] + CORTE + [(x, h)], np.int32)   # topo -> corte -> base
    cv2.fillPoly(m, [poli], 255)
    return m


def salvar(rgba, rel, com_normais=True):
    cam = os.path.join(RAIZ, SAIDA, rel)
    os.makedirs(os.path.dirname(cam), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(cam, optimize=True)
    print("  %-34s %dx%d" % (rel, rgba.shape[1], rgba.shape[0]))
    if com_normais:
        n = mapa_de_normais(rgba)
        Image.fromarray(n, "RGB").save(cam[:-4] + "_n.png", optimize=True)


def cortar_portas_janelas(rgba):
    n, lab, st, _ = cv2.connectedComponentsWithStats((rgba[..., 3] > 40).astype(np.uint8), 8)
    pecas = sorted([tuple(st[i, :4]) for i in range(1, n) if st[i, 4] > 3000],
                   key=lambda g: (g[1] // 150, g[0]))
    if len(pecas) != len(NOMES_PJ):
        print("  AVISO: achei %d peças, esperava %d" % (len(pecas), len(NOMES_PJ)))
    info = {}
    for (x, y, w, h), nome in zip(pecas, NOMES_PJ):
        rec = rgba[y:y + h, x:x + w].copy()
        cam = os.path.join(RAIZ, SAIDA, "portas_janelas", nome + ".png")
        os.makedirs(os.path.dirname(cam), exist_ok=True)
        Image.fromarray(rec, "RGBA").save(cam, optimize=True)
        info[nome] = [int(x), int(y), int(w), int(h)]
    print("  portas_janelas/                    %d sprites" % len(info))
    return info


def main():
    entrada = os.path.join(RAIZ, ENTRADA)
    faltando = [f for f in ("casa_fachada_hd", "casa_interior_iso_hd", "portas_janelas_hd")
                if not os.path.isfile(os.path.join(entrada, f + ".png"))]
    if faltando:
        print("ERRO: não encontrei em %s: %s" % (ENTRADA, ", ".join(faltando)))
        return 1
    print("removendo o fundo preto e gerando os recortes:")
    interior = remover_fundo(os.path.join(entrada, "casa_interior_iso_hd.png"))
    fachada = remover_fundo(os.path.join(entrada, "casa_fachada_hd.png"))
    pj = remover_fundo(os.path.join(entrada, "portas_janelas_hd.png"))

    for lado in ("sala", "cozinha"):
        m = mascara_lado(fachada.shape[:2], lado)
        for arte, rotulo in ((interior, "interior"), (fachada, "fachada")):
            peca = arte.copy()
            peca[m == 0] = 0
            salvar(peca, "casa/%s_%s.png" % (rotulo, lado))
    info = cortar_portas_janelas(pj)

    with open(os.path.join(RAIZ, SAIDA, "casa", "casa.json"), "w", encoding="utf-8") as f:
        json.dump({"tamanho": [int(interior.shape[1]), int(interior.shape[0])],
                   "corte": CORTE, "portas_janelas": info}, f, ensure_ascii=False, indent=1)
    print("pronto.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
