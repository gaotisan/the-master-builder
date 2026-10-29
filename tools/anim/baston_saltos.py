"""LOS SALTOS DEL BASTON (2026-10-29; el usuario: "al trepar el baculo no es
consistente, se rompe su posicion en relacion al cuerpo, en ambos trepar").
En baston_seguimiento.json (de raw/master_builder/anim/baston/exportar.py) el
pivote va a ~(-40, +45) px de la capucha, pero en algunos tramos el seguimiento
se fue ~70 px a un lado (trepar 70-75, trepar_mediano 36-43 y 52-60). Aqui, en
cada animacion: la capucha de cada fotograma (lo gris mas alto, seguido por
continuidad: con las manos en alto, lo mas alto eran las manos), lo que el
baston se separa de ella, y los fotogramas que se salen de lo de alrededor
(la mediana de la animacion) mas de UMBRAL px se rehacen con la separacion interpolada de
los buenos de los lados. El giro y lo demas, igual.
Si se vuelve a exportar el seguimiento, volver a pasar esto.

Uso (desde el proyecto): python -I tools/anim/baston_saltos.py [anim ...] [--ver carpeta] [--solo-ver]
  sin anims: trepar y trepar_mediano; --solo-ver no escribe (lista lo que haria).
"""
import json
import math
import os
import re
import sys

import cv2
import numpy as np

SEGUIMIENTO = "assets/characters/baston/baston_seguimiento.json"
FRAMES = "resources/characters/peregrino_frames.tres"
UMBRAL = 25.0

t = open(FRAMES, encoding="utf-8").read()
ext = dict((i, p) for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t))
sub = {}
for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*'
                     r'region = Rect2\(([^)]*)\)\s*margin = Rect2\(([^)]*)\)', t):
    sub[m.group(1)] = (ext[m.group(2)], [int(round(float(v))) for v in m.group(3).split(",")],
                       [int(round(float(v))) for v in m.group(4).split(",")])
cache = {}


def frames(name):
    i = t.find('"name": &"%s"' % name)
    if i < 0:
        return []
    j = t.rfind('"frames": [', 0, i)
    return re.findall(r'SubResource\("([^"]+)"\)', t[j:i])


def img(sid):
    p, r, mg = sub[sid]
    if p not in cache:
        cache[p] = cv2.imread(p, -1)
    x, y, w, h = r
    o = np.zeros((h + mg[3], w + mg[2], 4), np.uint8)
    o[mg[1]:mg[1] + h, mg[0]:mg[0] + w] = cache[p][y:y + h, x:x + w]
    return o


def capucha(p, cerca=None):
    """(x, y) de la capucha respecto al centro de la casilla: lo gris mas alto
    (con cerca, solo lo gris a menos de 45 px de alli)."""
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(int)
    g = a & ((rgb.max(2) - rgb.min(2)) < 28) & (rgb.max(2) > 110)
    H, W = a.shape
    ys, xs = np.nonzero(g)
    if cerca is not None:
        sel = np.hypot(xs - (cerca[0] + W / 2), ys - (cerca[1] + H / 2)) < 45
        if sel.sum() > 20:
            ys, xs = ys[sel], xs[sel]
    top = ys.min()
    hx = xs[ys < top + 40].mean()
    return float(hx - W / 2), float(np.nonzero(a[:, int(hx)])[0].min() - H / 2)


def arreglar(n, L):
    fr = frames(n)
    caps = []
    for s in fr:
        caps.append(capucha(img(s), caps[-1] if caps else None))
    caps = np.array(caps)
    rel = np.array([[f[0], f[1]] for f in L[:len(fr)]]) - caps
    # (contra la mediana de toda la animacion: los tramos malos duran hasta 9
    # fotogramas y una mediana corta se los tragaba)
    med = np.median(rel, 0)
    malo = np.hypot(*(rel - med).T) > UMBRAL
    buenos = np.nonzero(~malo)[0]
    nuevos = [list(f) for f in L]
    for i in np.nonzero(malo)[0]:
        r = [np.interp(i, buenos, rel[buenos, c]) for c in (0, 1)]
        nuevos[i][0] = round(float(caps[i][0] + r[0]), 2)
        nuevos[i][1] = round(float(caps[i][1] + r[1]), 2)
    return nuevos, [int(i) for i in np.nonzero(malo)[0]], fr


def ver(carpeta, n, fr, filas, malos):
    B = cv2.imread("assets/characters/baston/baston.png", -1)
    sel = malos[::max(1, len(malos) // 8)][:8] if malos else []
    out = []
    for i in sel:
        p = img(fr[i])
        H, W = p.shape[:2]
        x, y, r = filas[i][:3]
        bh, bw = B.shape[:2]
        M = cv2.getRotationMatrix2D((bw / 2, 40), -math.degrees(r), 1.0)
        M[0, 2] += W / 2 + x - bw / 2
        M[1, 2] += H / 2 + y - 40
        capa = cv2.warpAffine(B, M, (W, H), borderValue=(0, 0, 0, 0))
        a = capa[..., 3:] / 255.0
        o = capa[..., :3] * a + 200 * (1 - a)
        b = p[..., 3:] / 255.0
        out.append((p[..., :3] * b + o * (1 - b)).astype(np.uint8))
    if out:
        Hh = max(q.shape[0] for q in out)
        out = [cv2.copyMakeBorder(q, 0, Hh - q.shape[0], 0, 0, cv2.BORDER_CONSTANT, value=(200, 200, 200)) for q in out]
        cv2.imwrite(os.path.join(carpeta, "s_%s.png" % n), np.hstack(out))


def main():
    anims = [a for a in sys.argv[1:] if not a.startswith("--") and not os.path.isdir(a)] or ["trepar", "trepar_mediano"]
    S = json.load(open(SEGUIMIENTO, encoding="utf-8"))
    carpeta = sys.argv[sys.argv.index("--ver") + 1] if "--ver" in sys.argv else None
    for n in anims:
        if not isinstance(S.get(n), list) or len(frames(n)) != len(S[n]):
            continue
        nuevos, malos, fr = arreglar(n, S[n])
        print(n, "rehechos:", malos)
        if carpeta:
            ver(carpeta, n, fr, nuevos, malos)
        S[n] = nuevos
    if "--solo-ver" not in sys.argv:
        json.dump(S, open(SEGUIMIENTO, "w", encoding="utf-8"), separators=(",", ":"))


if __name__ == "__main__":
    main()
