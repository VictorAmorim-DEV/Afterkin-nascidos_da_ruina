#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — gera a textura de luz da lanterna.

Uso (na raiz do projeto):
    python tools/gerar_luzes.py

assets/luzes/lanterna.png (512x512): o centro da imagem é o jogador; o cone aponta
para a direita (+X), com meia-abertura de 0,42 rad (protótipo V13) e 256 px de alcance,
mais um brilho curto em volta do jogador. Branco = luz, preto = sem luz.
"""
import os
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N, R = 512, 256.0
MEIA_ABERTURA = 0.42
BRILHO_RAIO, BRILHO_FORCA = 0.175, 0.35      # brilho em volta do jogador (2,6 m de 15 m)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main():
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    x, y = x - N / 2 + 0.5, y - N / 2 + 0.5
    d = np.hypot(x, y) / R
    ang = np.abs(np.arctan2(y, x))
    cone = (1.0 - suave(MEIA_ABERTURA * 0.55, MEIA_ABERTURA, ang)) * (1.0 - suave(0.25, 1.0, d)) ** 1.3
    brilho = BRILHO_FORCA * (1.0 - suave(0.0, BRILHO_RAIO, d))
    luz = np.clip(np.maximum(cone, brilho), 0.0, 1.0) * (d < 1.0)
    img = (luz * 255.0 + 0.5).astype(np.uint8)
    saida = os.path.join(RAIZ, "assets/luzes")
    os.makedirs(saida, exist_ok=True)
    Image.fromarray(np.dstack([img, img, img]), "RGB").save(os.path.join(saida, "lanterna.png"), optimize=True)
    print("assets/luzes/lanterna.png gerada")


if __name__ == "__main__":
    main()
