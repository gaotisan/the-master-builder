"""EL COLOR DEL ACTO I (2026-10-25): un solo grado para todo, horneado en las
texturas (cero coste en el juego).

La referencia son las imagenes de estilo (estilo_1..4: caliza palida, cielo
frio, un sol bajo). Cada textura se lleva hacia ellas en Lab (la media y la
desviacion de a y b, a medias: que se parezcan sin perder lo suyo), con menos
saturacion, y las sombras levantadas (nada de negros). Medido el 2026-10-25:
el juego iba con saturacion 77-99 y 16-33 % de casi negro; las imagenes de
estilo, 63-72 y 3-14 %.

Uso: from grado import graduar; rgba = graduar(rgba_bgra_uint8, plano="primer")
"""
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
REFS = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_primer_plano")

# por plano: [cuanto se acerca al color de estilo, cuanto baja la saturacion,
# cuanto levanta las sombras, bruma hacia el cielo]
PLANOS = {
    "primer": [0.55, 0.82, 0.30, 0.00],
    "trasera": [0.6, 0.75, 0.40, 0.18],
    "medio": [0.45, 0.80, 0.30, 0.10],
    "lejos": [0.35, 0.85, 0.20, 0.00],
    # el suelo de arena: es todo un color, acercarlo a la media lo volvia rosa
    "suelo": [0.0, 0.88, 0.10, 0.00],
}
CIELO_BGR = np.array([222, 214, 196], np.float32)       # la calima clara de las imagenes de estilo

_obj = None


def objetivo():
    """Media y desviacion de a, b (Lab) de lo que no es cielo en la tira del acto."""
    global _obj
    if _obj is None:
        px = []
        # (la tira del acto: la luz y el color de todo el nivel)
        tira = os.path.join(os.path.dirname(REFS), "egipto_tira2")
        fuentes = [os.path.join(tira, f) for f in sorted(os.listdir(tira)) if f.endswith(".png")]
        for f in fuentes:
            im = cv2.imdecode(np.fromfile(f, np.uint8), cv2.IMREAD_COLOR)
            lab = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(np.float32)
            px.append(lab[im.shape[0] // 3:].reshape(-1, 3))
        px = np.concatenate(px)
        _obj = (px.mean(0), px.std(0))
    return _obj


def graduar(img, plano="primer"):
    """img: BGR o BGRA uint8. Devuelve lo mismo graduado."""
    acerca, sat, levanta, bruma = PLANOS[plano]
    bgr = img[..., :3]
    alfa = img[..., 3] if img.shape[2] == 4 else None
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    sel = (alfa > 128) if alfa is not None else np.ones(lab.shape[:2], bool)
    if sel.sum() < 50:
        return img
    m = lab[sel].mean(0)
    s = lab[sel].std(0) + 1e-3
    mo, so = objetivo()
    for c in (1, 2):
        # hacia la media y la desviacion de las imagenes de estilo, a medias
        nuevo = (lab[..., c] - m[c]) * (so[c] / s[c]) + mo[c]
        lab[..., c] = lab[..., c] * (1 - acerca) + nuevo * acerca
        # menos saturacion (a y b hacia el gris, 128)
        lab[..., c] = 128 + (lab[..., c] - 128) * sat
    # sombras levantadas (L 0..255): las oscuras suben, las claras casi no
    L = lab[..., 0] / 255.0
    L = L + levanta * (1 - L) ** 2.2 * 0.5
    lab[..., 0] = np.clip(L, 0, 1) * 255
    out = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR).astype(np.float32)
    if bruma > 0:
        out = out * (1 - bruma) + CIELO_BGR * bruma
    out = np.clip(out, 0, 255).astype(np.uint8)
    if alfa is not None:
        return np.dstack([out, alfa])
    return out
