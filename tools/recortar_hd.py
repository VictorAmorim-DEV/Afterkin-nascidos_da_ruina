#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — remoção de fundo e fatiamento das folhas HD.

Uso (na raiz do projeto):
    python tools/recortar_hd.py
    python tools/recortar_hd.py --entrada assets/new_assets --saida assets/sprites_hd_recortados

Como funciona:
  1. FUNDO: as folhas já trazem um canal alfa "sujo" (o fundo marrom-esverdeado fica
     semitransparente, ~0–20%, e os objetos ~98%). O script aplica níveis nesse alfa:
     tudo abaixo de ALFA_MIN vira 100% transparente, tudo acima de ALFA_MAX vira opaco.
  2. BORDAS: a cor do fundo que vazou para os pixels de borda é substituída pela cor
     do interior do objeto (inpaint), evitando o "halo" marrom.
  3. FATIAMENTO: detecta cada objeto por componentes conexos da máscara e salva um PNG
     por objeto, com nome por categoria (regra por posição na folha, ver FOLHAS).
  4. Gera manifesto.json (nome, folha, retângulo de origem) e uma prancha de conferência.

Requisitos: Python 3, numpy, opencv-python, Pillow.
"""
import argparse, json, os, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw

ALFA_MIN, ALFA_MAX = 110, 215     # níveis aplicados ao alfa original (0–255)
MARGEM = 2                        # px transparentes em volta de cada recorte

# Regras de categoria: (nome, x0, y0, x1, y1, altura_min) testadas em ordem sobre o
# CENTRO do objeto na folha. altura_min = só vale para objetos com essa altura ou mais.
FOLHAS = {
    "objetos_natureza_hd": dict(
        pasta="objetos_natureza", unir=4, erosao=0, frag_max=700, area_min=90,
        regras=[
            ("arvore",      0,    0, 1536,  330, 150),
            ("veiculo",     0,  555, 1270,  700, 70),
            ("torre",    1390,  730, 1536,  930, 120),
            ("pedra",       0,  470,  490,  565, 0),
            ("tronco",    490,  465,  840,  575, 0),
            ("vegetacao",   0,    0, 1536,  565, 0),
            ("vegetacao", 1255, 555, 1536,  660, 0),
            ("recipiente",  0,  690, 1290,  790, 0),
            ("barricada",   0,  780,  650,  930, 0),
            ("cerca",     650,  780, 1290,  925, 0),
            ("poste",    1280,  780, 1400,  930, 0),
        ], padrao="objeto"),
    "construcoes_hd": dict(
        pasta="construcoes", unir=4, erosao=0, frag_max=700, area_min=90,
        regras=[
            ("predio",      0,    0, 1536,  470, 0),
            ("interior",    0,  470, 1536,  685, 0),
            ("telhado",     0,  680,  580,  840, 0),
            ("parede",    580,  690, 1536,  865, 0),
            ("tenda",       0,  820,  840, 1024, 60),
        ], padrao="objeto"),
    "terrenos_hd": dict(
        pasta="terrenos", unir=0, erosao=9, frag_max=0, area_min=4000,
        regras=[("terreno", 0, 0, 1536, 1024, 0)], padrao="terreno"),
}


def limpar_fundo(rgba):
    """Devolve (rgb, alfa 0–255) com fundo 100% transparente e bordas sem halo."""
    rgb = np.ascontiguousarray(rgba[..., :3])
    a = rgba[..., 3].astype(np.float32)
    alfa = np.clip((a - ALFA_MIN) / float(ALFA_MAX - ALFA_MIN), 0.0, 1.0)
    alfa = alfa * alfa * (3.0 - 2.0 * alfa)                       # curva suave
    # remove a cor do fundo que vazou para as bordas semitransparentes
    borda = ((alfa > 0.0) & (alfa < 0.97)).astype(np.uint8) * 255
    fora = (alfa <= 0.0).astype(np.uint8) * 255
    perto = cv2.dilate((alfa >= 0.97).astype(np.uint8) * 255, np.ones((7, 7), np.uint8))
    pintar = cv2.bitwise_or(borda, cv2.bitwise_and(fora, perto))
    rgb = cv2.inpaint(rgb, pintar, 3, cv2.INPAINT_TELEA)
    return rgb, (alfa * 255.0 + 0.5).astype(np.uint8)


def rotular(alfa, cfg):
    """Componentes conexos da máscara.
    Sementes = miolo bem opaco de cada objeto (separa vizinhos que só se encostam pela
    borda suave); depois os rótulos crescem até a borda real. 'erosao' afasta ainda mais
    as sementes (terrenos). Fragmentos pequenos colados num objeto são absorvidos por ele."""
    mask = (alfa > 110).astype(np.uint8)
    base = (alfa > cfg.get("semente", 235)).astype(np.uint8)
    if cfg["erosao"]:
        e = cfg["erosao"]
        base = cv2.erode(base, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * e + 1,) * 2))
    n, lab = cv2.connectedComponents(base, connectivity=8)
    lab = lab.astype(np.int32)
    k = np.ones((3, 3), np.uint8)
    for _ in range(60):                           # cresce os rótulos até a borda real
        cresc = cv2.dilate(lab.astype(np.float32), k).astype(np.int32)
        novo = np.where((lab == 0) & (mask > 0), cresc, lab)
        if np.array_equal(novo, lab):
            break
        lab = novo
    resto = ((mask > 0) & (lab == 0)).astype(np.uint8)
    n2, lab2 = cv2.connectedComponents(resto, connectivity=8)
    lab = np.where(lab2 > 0, lab2 + n - 1, lab)
    n += n2 - 1
    # absorve fragmentos (folhas soltas, pontas de galho) no objeto vizinho
    area = np.bincount(lab.ravel(), minlength=n)
    kk = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * cfg["unir"] + 1,) * 2) if cfg["unir"] else None
    if kk is not None:
        for i in np.argsort(area):
            if i == 0 or area[i] == 0 or area[i] > cfg["frag_max"]:
                continue
            ys, xs = np.nonzero(lab == i)
            y0, y1, x0, x1 = max(0, ys.min() - 8), ys.max() + 9, max(0, xs.min() - 8), xs.max() + 9
            sub = lab[y0:y1, x0:x1]
            viz = sub[(cv2.dilate((sub == i).astype(np.uint8), kk) > 0) & (sub != i) & (sub != 0)]
            if len(viz):
                j = np.bincount(viz).argmax()
                sub[sub == i] = j
                area[j] += area[i]; area[i] = 0
    return n, lab


def categoria(cfg, cx, cy, h):
    for nome, x0, y0, x1, y1, hmin in cfg["regras"]:
        if x0 <= cx < x1 and y0 <= cy < y1 and h >= hmin:
            return nome
    return cfg["padrao"]


def processar(caminho, cfg, saida):
    rgba = np.array(Image.open(caminho).convert("RGBA"))
    H, W = rgba.shape[:2]
    rgb, alfa = limpar_fundo(rgba)
    n, lab = rotular(alfa, cfg)
    pecas = []
    for i in range(1, n):
        ys, xs = np.nonzero((lab == i) & (alfa > 110))
        if len(xs) < cfg["area_min"]:
            continue
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        pecas.append(dict(i=i, x0=int(x0), y0=int(y0), x1=int(x1), y1=int(y1),
                          cat=categoria(cfg, (x0 + x1) / 2, (y0 + y1) / 2, y1 - y0)))
    # ordem de leitura: de cima para baixo (faixas de 70 px), da esquerda para a direita
    pecas.sort(key=lambda p: (p["cat"], (p["y0"] + p["y1"]) // 2 // 70, p["x0"]))
    pasta = os.path.join(saida, cfg["pasta"])
    os.makedirs(pasta, exist_ok=True)
    cont, manifesto = {}, []
    reconst = np.zeros((H, W, 4), np.uint8)
    for p in pecas:
        cont[p["cat"]] = cont.get(p["cat"], 0) + 1
        nome = "%s_%02d" % (p["cat"], cont[p["cat"]])
        x0, y0 = max(0, p["x0"] - MARGEM), max(0, p["y0"] - MARGEM)
        x1, y1 = min(W, p["x1"] + MARGEM), min(H, p["y1"] + MARGEM)
        dono = lab[y0:y1, x0:x1] == p["i"]
        # inclui a borda suave (alfa baixo) em volta do objeto, sem invadir o vizinho
        dono = cv2.dilate(dono.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        dono &= (lab[y0:y1, x0:x1] == p["i"]) | (lab[y0:y1, x0:x1] == 0)
        a = np.where(dono, alfa[y0:y1, x0:x1], 0).astype(np.uint8)
        rec = np.dstack([rgb[y0:y1, x0:x1], a])
        rec[a == 0, :3] = 0
        Image.fromarray(rec, "RGBA").save(os.path.join(pasta, nome + ".png"), optimize=True)
        reconst[y0:y1, x0:x1][a > 0] = rec[a > 0]
        manifesto.append(dict(nome=nome, arquivo="%s/%s.png" % (cfg["pasta"], nome),
                              folha=os.path.basename(caminho), origem=[x0, y0, x1 - x0, y1 - y0]))
    # prancha de conferência: recortes sobre magenta com o nome de cada um
    pr = Image.new("RGBA", (W, H), (255, 0, 255, 255))
    pr.alpha_composite(Image.fromarray(reconst, "RGBA"))
    pr = pr.resize((W * 2, H * 2), Image.LANCZOS)
    d = ImageDraw.Draw(pr)
    for m in manifesto:
        x, y, w, h = m["origem"]
        d.rectangle([x * 2, y * 2, (x + w) * 2, (y + h) * 2], outline=(255, 255, 0, 255))
        d.text((x * 2 + 3, y * 2 + 2), m["nome"], fill=(255, 255, 255, 255),
               stroke_width=2, stroke_fill=(0, 0, 0, 255))
    os.makedirs(os.path.join(saida, "_conferencia"), exist_ok=True)
    pr.convert("RGB").save(os.path.join(saida, "_conferencia", cfg["pasta"] + ".jpg"), quality=88)
    print("%-24s %3d recortes  %s" % (os.path.basename(caminho), len(manifesto),
          ", ".join("%s=%d" % kv for kv in sorted(cont.items()))))
    return manifesto


def main():
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    padrao = "assets/hd_assets" if os.path.isdir(os.path.join(raiz, "assets/hd_assets")) else "assets/new_assets"
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--entrada", default=padrao)
    ap.add_argument("--saida", default="assets/sprites_hd_recortados")
    a = ap.parse_args()
    entrada, saida = os.path.join(raiz, a.entrada), os.path.join(raiz, a.saida)
    manifesto = []
    for nome, cfg in FOLHAS.items():
        caminho = os.path.join(entrada, nome + ".png")
        if not os.path.isfile(caminho):
            print("AVISO: não encontrei", caminho); continue
        manifesto += processar(caminho, cfg, saida)
    # impede a Godot de importar as pranchas de conferência
    open(os.path.join(saida, "_conferencia", ".gdignore"), "w").close()
    with open(os.path.join(saida, "manifesto.json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, ensure_ascii=False, indent=1)
    print("Total: %d recortes em %s" % (len(manifesto), a.saida))


if __name__ == "__main__":
    sys.exit(main())
