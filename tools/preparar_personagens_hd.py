#!/usr/bin/env python3
"""
Afterkin: Nascidos da Ruína — prepara as folhas HD de personagens.

Uso (na raiz do projeto):
    python tools/preparar_personagens_hd.py

O que faz:
  1. FUNDO: remove o fundo preto de personagens_acoes_hd.png e personagens_corrida_hd.png.
     Só o preto LIGADO À BORDA da folha é removido (preenchimento por inundação), então
     roupas e cabelos pretos dentro do contorno do personagem são preservados.
     As folhas sem fundo vão para assets/sprites_hd_recortados/personagens/.
  2. QUADROS: localiza cada quadro e remonta um atlas por raça em grade uniforme
     (CELULA x CELULA px, pés sempre no mesmo ponto: PIVO). Linhas do atlas:
        0 andar de frente   1 andar de lado   2 andar de costas
        3 atacar (frente, lado, costas) + caído
        4 agachar (frente, lado, costas) + deitado
        5 correr de lado (folha de corrida)
  3. ANIMAÇÕES: grava um SpriteFrames por raça em resources/sprite_frames/<raca>.tres.

Requisitos: Python 3, numpy, opencv-python, Pillow.
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTRADA = "assets/new_assets"
SAIDA = "assets/sprites_hd_recortados/personagens"
RECURSOS = "resources/sprite_frames"

LIMIAR_PRETO = 14          # canal mais claro <= isto conta como "preto de fundo"
PRETO_PURO, BURACO_MIN = 2, 40   # buraco interno: preto <= PRETO_PURO com área >= BURACO_MIN px
FATOR_CORRIDA = 0.78       # a folha de corrida foi desenhada maior; reduz para a mesma proporção
PE = 8                     # px livres abaixo dos pés dentro da célula

# folha de ações: faixa de x de cada raça e nº de colunas; as 5 linhas são iguais para todas
ACOES_LINHAS = [0, 178, 331, 482, 646, 790]
ACOES = [  # (raça, x0, x1, colunas)
    ("humano",       0,    397, 4),
    ("homem_rato",   397,  713, 3),
    ("rato_gigante", 713, 1066, 4),
    ("vampiro",      1066, 1443, 4),
    ("zumbi",        1443, 1774, 4),
]
# folha de corrida: uma raça por linha, 9 quadros cada
CORRIDA_LINHAS = [0, 233, 372, 516, 747, 1024]
CORRIDA = ["humano", "rato_gigante", "rato_feral", "vampiro", "zumbi"]
CORRIDA_COLUNAS = 9

VEL_ANDAR, VEL_CORRER = 5.0, 14.0     # quadros por segundo (na velocidade de referência)


def remover_fundo(caminho):
    rgb = np.array(Image.open(caminho).convert("RGB"))
    escuro = (rgb.max(2) <= LIMIAR_PRETO).astype(np.uint8)
    # erosão de 1 px: o fundo não "vaza" para dentro do personagem por frestas finas
    miolo = cv2.erode(escuro, np.ones((3, 3), np.uint8))
    n, lab = cv2.connectedComponents(miolo, connectivity=4)
    borda = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    fundo = np.isin(lab, borda[borda > 0]).astype(np.uint8)
    fundo = cv2.dilate(fundo, np.ones((3, 3), np.uint8)) & escuro
    fg = (1 - fundo).astype(np.uint8)
    # buracos fechados de preto puro (volta do rabo, vão entre as pernas) também são fundo
    puro = ((rgb.max(2) <= PRETO_PURO) & (fg > 0)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(puro, connectivity=4)
    buracos = np.nonzero(st[:, cv2.CC_STAT_AREA] >= BURACO_MIN)[0]
    fg[np.isin(lab, buracos[buracos > 0])] = 0
    # remove respingos soltos (menos de 30 px) que sobraram no fundo
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    pequenos = np.nonzero(st[:, cv2.CC_STAT_AREA] < 30)[0]
    fg[np.isin(lab, pequenos)] = 0
    alfa = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 0.6)      # borda levemente suave
    alfa = np.clip((alfa - 0.25) / 0.5, 0, 1) * fg
    a8 = (alfa * 255 + 0.5).astype(np.uint8)
    rgba = np.dstack([rgb, a8])
    rgba[a8 == 0, :3] = 0
    return rgba


def cortes_em_vales(mask, x0, x1, k):
    """Divide [x0, x1) em k quadros cortando nos vales (colunas mais vazias)."""
    perfil = mask[:, x0:x1].sum(0).astype(np.float32)
    cols = np.nonzero(perfil > 0)[0]
    if len(cols) == 0:
        return None
    a, b = cols.min(), cols.max() + 1
    passo = (b - a) / float(k)
    suave = cv2.GaussianBlur(perfil.reshape(1, -1), (0, 0), 2.0).ravel()
    cortes = [a]
    for i in range(1, k):
        c = a + passo * i
        j0, j1 = int(max(cortes[-1] + passo * 0.45, c - passo * 0.4)), int(min(b - 1, c + passo * 0.4))
        custo = suave[j0:j1 + 1] + 0.02 * np.abs(np.arange(j0, j1 + 1) - c)
        cortes.append(j0 + int(custo.argmin()))
    cortes.append(b)
    return [x0 + c for c in cortes]


def extrair(rgba, x0, x1, y0, y1, k):
    """Devolve k recortes (aparados) da faixa, da esquerda para a direita."""
    mask = rgba[y0:y1, :, 3] > 40
    cs = cortes_em_vales(mask, x0, x1, k)
    quadros = []
    if cs is None:
        return quadros
    for i in range(k):
        sub = rgba[y0:y1, cs[i]:cs[i + 1]]
        m = sub[..., 3] > 40
        # fica só com o maior componente + vizinhos próximos (descarta ponta do quadro ao lado)
        n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), connectivity=8)
        if n <= 1:
            quadros.append(None); continue
        maior = 1 + int(st[1:, cv2.CC_STAT_AREA].argmax())
        perto = cv2.dilate((lab == maior).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
        manter = np.zeros(n, bool)
        for j in range(1, n):
            manter[j] = j == maior or (st[j, cv2.CC_STAT_AREA] > 12 and perto[lab == j].any())
        m2 = manter[lab]
        ys, xs = np.nonzero(m2)
        rec = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
        rec[~m2[ys.min():ys.max() + 1, xs.min():xs.max() + 1]] = 0
        quadros.append(rec)
    return quadros


def reduzir(q, fator):
    """Redimensiona um quadro RGBA com alfa pré-multiplicado (sem franja escura)."""
    h, w = q.shape[:2]
    f = q.astype(np.float32)
    f[..., :3] *= f[..., 3:4] / 255.0
    r = cv2.resize(f, (max(1, int(round(w * fator))), max(1, int(round(h * fator)))), interpolation=cv2.INTER_AREA)
    al = np.maximum(r[..., 3:4], 1e-3)
    r[..., :3] = np.where(r[..., 3:4] > 0.5, r[..., :3] * 255.0 / al, 0)
    return np.clip(r + 0.5, 0, 255).astype(np.uint8)


def tres(raca, celula, linhas, colunas_por_linha):
    """Texto do SpriteFrames (.tres) da raça."""
    cw, ch = celula
    subs, anims = [], []
    pos = {l: i for i, l in enumerate(sorted(linhas))}      # linha lógica -> linha no atlas

    def quadro(l, c):
        ident = "q_%d_%d" % (l, c)
        if ident not in [s[0] for s in subs]:
            subs.append((ident, l, c))
        return '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % ident

    def anim(nome, quadros, fps, loop=True):
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                     % (", ".join(quadros), "true" if loop else "false", nome, fps))

    n = colunas_por_linha
    if 0 in linhas:
        for l, d in ((0, "frente"), (1, "lado"), (2, "costas")):
            anim("andar_" + d, [quadro(l, c) for c in range(n[l])], VEL_ANDAR)
        ult = n[3] - 1                      # última coluna das linhas 3 e 4 = caído / deitado
        dirs = ("frente", "lado", "costas")
        for i, d in enumerate(dirs):
            c = i if i < ult else 0         # raça com 3 colunas reutiliza a pose de frente
            anim("atacar_" + d, [quadro(3, c)], 1.0, False)
            anim("agachar_" + d, [quadro(4, c)], 1.0, False)
        anim("caido", [quadro(3, ult)], 1.0, False)
        anim("deitado", [quadro(4, ult)], 1.0, False)
    if 5 in linhas:
        anim("correr", [quadro(5, c) for c in range(n[5])], VEL_CORRER)
    anims.sort(key=lambda a: a.split('&"')[1])
    t = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(subs) + 2)
    t += '[ext_resource type="Texture2D" path="res://%s/%s.png" id="1_atlas"]\n\n' % (SAIDA, raca)
    for ident, l, c in subs:
        t += '[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1_atlas")\nregion = Rect2(%d, %d, %d, %d)\n\n' \
             % (ident, c * cw, pos[l] * ch, cw, ch)
    t += "[resource]\nanimations = [%s]\n" % ", ".join(anims)
    return t


def main():
    saida = os.path.join(RAIZ, SAIDA)
    os.makedirs(saida, exist_ok=True)
    os.makedirs(os.path.join(RAIZ, RECURSOS), exist_ok=True)
    folhas = {}
    for nome in ("personagens_acoes_hd", "personagens_corrida_hd"):
        cam = os.path.join(RAIZ, ENTRADA, nome + ".png")
        if not os.path.isfile(cam):
            print("ERRO: não encontrei", cam); return 1
        folhas[nome] = remover_fundo(cam)
        Image.fromarray(folhas[nome], "RGBA").save(os.path.join(saida, nome + ".png"), optimize=True)
        print("fundo removido:", nome + ".png")
    acoes, corrida = folhas["personagens_acoes_hd"], folhas["personagens_corrida_hd"]

    racas = {}                                  # raça -> {linha: [quadros]}
    for raca, x0, x1, k in ACOES:
        for l in range(5):
            racas.setdefault(raca, {})[l] = extrair(acoes, x0, x1, ACOES_LINHAS[l], ACOES_LINHAS[l + 1], k)
    for l, raca in enumerate(CORRIDA):
        qs = extrair(corrida, 0, corrida.shape[1], CORRIDA_LINHAS[l], CORRIDA_LINHAS[l + 1], CORRIDA_COLUNAS)
        racas.setdefault(raca, {})[5] = [None if q is None else reduzir(q, FATOR_CORRIDA) for q in qs]
    todos = [q for r in racas.values() for qs in r.values() for q in qs if q is not None]
    cw = int(np.ceil((max(q.shape[1] for q in todos) + 4) / 8.0) * 8)
    ch = int(np.ceil((max(q.shape[0] for q in todos) + PE + 4) / 8.0) * 8)
    pivo = (cw // 2, ch - PE)
    altura_humano = int(np.median([q.shape[0] for q in racas["humano"][0]]))
    info = dict(celula=[cw, ch], pivo=list(pivo), altura_humano_px=altura_humano,
                escala_sugerida=round(53.0 / altura_humano, 4), racas={})
    for raca, linhas in racas.items():
        pos = {l: i for i, l in enumerate(sorted(linhas))}  # sem linhas vazias no atlas
        atlas = np.zeros((len(pos) * ch, 9 * cw, 4), np.uint8)
        ncols = {}
        for l, qs in linhas.items():
            ncols[l] = len(qs)
            for c, q in enumerate(qs):
                if q is None:
                    continue
                h, w = q.shape[:2]
                x = c * cw + pivo[0] - w // 2
                y = pos[l] * ch + pivo[1] - h
                atlas[y:y + h, x:x + w] = q
        # apara colunas vazias à direita
        atlas = atlas[:, :max(ncols.values()) * cw]
        Image.fromarray(atlas, "RGBA").save(os.path.join(saida, raca + ".png"), optimize=True)
        with open(os.path.join(RAIZ, RECURSOS, raca + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(tres(raca, (cw, ch), linhas, ncols))
        info["racas"][raca] = dict(atlas="%s/%s.png" % (SAIDA, raca), linhas=sorted(linhas), colunas=ncols)
        print("%-13s atlas %dx%d  linhas %s" % (raca, atlas.shape[1], atlas.shape[0], sorted(linhas)))
    with open(os.path.join(saida, "atlas.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    print("célula %dx%d  pivô %s  humano em pé = %d px  escala p/ 53 px = %.4f"
          % (cw, ch, pivo, altura_humano, 53.0 / altura_humano))
    return 0


if __name__ == "__main__":
    sys.exit(main())
