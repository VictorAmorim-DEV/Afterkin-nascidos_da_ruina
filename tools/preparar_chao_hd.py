#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — prepara o chão HD da cena de teste.

Uso (na raiz do projeto, depois de tools/recortar_hd.py):
    python tools/preparar_chao_hd.py

Os recortes de assets/sprites_hd_recortados/terrenos/ são manchas vistas de cima com
borda irregular, não tiles. Este script monta duas texturas que se repetem sem emenda:
  chao/grama.png    miolo da mancha de grama, espelhado 2x2 (repete nos dois eixos)
  chao/estrada.png  estrada reta com acostamento, espelhada no comprimento (repete em Y);
                    as laterais irregulares (com transparência) são mantidas para a
                    estrada se misturar com a grama.
O script scripts/world/ground.gd projeta essas texturas em isométrico.
"""
import json, os, sys
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = os.path.join(RAIZ, "assets/sprites_hd_recortados")
# posição aproximada (centro) de cada mancha na folha terrenos_hd.png
GRAMA_EM = (1390, 910)
ESTRADA_EM = (485, 150)


def mancha(manifesto, centro):
    ts = [m for m in manifesto if m["arquivo"].startswith("terrenos/")]
    m = min(ts, key=lambda m: (m["origem"][0] + m["origem"][2] / 2 - centro[0]) ** 2 +
                              (m["origem"][1] + m["origem"][3] / 2 - centro[1]) ** 2)
    return m["nome"], np.array(Image.open(os.path.join(REC, m["arquivo"])).convert("RGBA"))


def miolo_opaco(img, margem):
    """Maior retângulo central totalmente opaco (encolhe a margem até caber)."""
    h, w = img.shape[:2]
    while margem < min(h, w) // 2 - 8:
        rec = img[margem:h - margem, margem:w - margem]
        if rec[..., 3].min() >= 250:
            return rec
        margem += 4
    raise SystemExit("não achei um miolo opaco")


def main():
    with open(os.path.join(REC, "manifesto.json"), encoding="utf-8") as f:
        manifesto = json.load(f)
    saida = os.path.join(REC, "chao")
    os.makedirs(saida, exist_ok=True)

    nome, g = mancha(manifesto, GRAMA_EM)
    g = miolo_opaco(g, 30)
    g[..., 3] = 255
    cima = np.concatenate([g, g[:, ::-1]], 1)
    grama = np.concatenate([cima, cima[::-1]], 0)
    Image.fromarray(grama, "RGBA").convert("RGB").save(os.path.join(saida, "grama.png"), optimize=True)
    print("grama.png    %dx%d  (de %s)" % (grama.shape[1], grama.shape[0], nome))

    nome, e = mancha(manifesto, ESTRADA_EM)
    h, w = e.shape[:2]
    faixa = e[:, w // 2 - 40:w // 2 + 40, 3]                  # miolo do asfalto
    linhas = np.nonzero(faixa.min(1) >= 250)[0]
    y0, y1 = linhas.min() + 6, linhas.max() - 5
    e = e[y0:y1]
    estrada = np.concatenate([e, e[::-1]], 0)
    Image.fromarray(estrada, "RGBA").save(os.path.join(saida, "estrada.png"), optimize=True)
    print("estrada.png  %dx%d  (de %s)" % (estrada.shape[1], estrada.shape[0], nome))


if __name__ == "__main__":
    sys.exit(main())
