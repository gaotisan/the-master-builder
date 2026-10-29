"""EL BASTON A LA ESPALDA FLOTANDO (2026-10-29, Egipto; el usuario: "cuando esta
subido a las piedras y se lanza/cae, esa animacion (que viene como de flotar) no
tiene puesto el baculo"). flotar_bajar, flotar_posarse y flotar_quieto (las de
flotar_limpio.json, que no estan en baston_seguimiento.json) llevan el baston
como el salto y el reposo: en baston_seguimiento.json el pivote va SIEMPRE a
(-40.5, +45.5) px de la capucha (lo mas alto de lo gris; medido en salto_parado
30-40, reposo y andar, +-1 px), asi que aqui se pone igual sobre la capucha de
cada fotograma, suavizada. El giro va del del salto (el 37, que casa con el 0
de flotar_bajar) al del reposo (el ultimo de flotar_posarse casa con el reposo).
flotar_girar (solo con luz, en la hojarasca) no lo lleva.
Filas como baston_caida.json: [x, y, giro, visible (0 detras), corte (1 = entero)].

Salida: assets/characters/baston/baston_flotar.json (baston.gd, con en_flotar).
Uso (desde el proyecto): python -I tools/anim/baston_flotar.py [--ver carpeta]
"""
import json
import math
import os
import sys

import cv2
import numpy as np

FICHA = "assets/characters/peregrino/flotar_limpio.json"
SEGUIMIENTO = "assets/characters/baston/baston_seguimiento.json"
SALIDA = "assets/characters/baston/baston_flotar.json"
REL = (-40.5, 45.5)     # el pivote respecto a la capucha
SUAVE = 5               # fotogramas de la media de la capucha


def capucha(p):
    """Lo mas alto de lo gris (capucha y barba): x media de la capucha y su borde de arriba."""
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(int)
    g = a & ((rgb.max(2) - rgb.min(2)) < 28) & (rgb.max(2) > 110)
    ys, xs = np.nonzero(g)
    top = ys.min()
    hx = xs[ys < top + 40].mean()
    return hx, np.nonzero(a[:, int(hx)])[0].min()


def main():
    F = json.load(open(FICHA, encoding="utf-8"))
    S = json.load(open(SEGUIMIENTO, encoding="utf-8"))
    g_salto = S["salto_parado"][37][2]
    g_reposo = S["reposo"][0][2]
    g_medio = (g_salto + g_reposo) / 2
    giros = {"flotar_bajar": (g_salto, g_medio), "flotar_posarse": (g_medio, g_reposo),
             "flotar_quieto": (g_salto, g_salto)}
    datos = {}
    hojas = {}
    for n, (g0, g1) in giros.items():
        d = F[n]
        w, h = d["casilla"]
        ruta = d["hoja"].replace("res://", "")
        hoja = hojas.setdefault(ruta, cv2.imread(ruta, -1))
        ims = [hoja[(i // d["cols"]) * h:(i // d["cols"]) * h + h, (i % d["cols"]) * w:(i % d["cols"]) * w + w]
               for i in range(d["n"])]
        pts = np.array([capucha(p) for p in ims], np.float32)
        k = SUAVE // 2
        pad = np.pad(pts, ((k, k), (0, 0)), mode="wrap" if d["bucle"] else "edge")
        pts = np.array([pad[i:i + SUAVE].mean(0) for i in range(len(pts))])
        N = len(ims)
        filas = []
        for i, (hx, ty) in enumerate(pts):
            t = i / max(N - 1, 1)
            filas.append([round(float(hx - w / 2 + REL[0]), 1), round(float(ty - h / 2 + REL[1]), 1),
                          round(g0 + (g1 - g0) * t, 4), 0, 1.0])
        datos[n] = filas
        if "--ver" in sys.argv:
            ver(sys.argv[sys.argv.index("--ver") + 1], n, ims, filas)
    json.dump(datos, open(SALIDA, "w", encoding="utf-8"))
    print({k: len(v) for k, v in datos.items()})


def ver(carpeta, n, ims, filas):
    B = cv2.imread("assets/characters/baston/baston.png", -1)
    sel = np.linspace(0, len(ims) - 1, 7).astype(int)
    out = []
    for j in sel:
        p = ims[j]
        H, W = p.shape[:2]
        x, y, r = filas[j][:3]
        bh, bw = B.shape[:2]
        M = cv2.getRotationMatrix2D((bw / 2, 40), -math.degrees(r), 1.0)
        M[0, 2] += W / 2 + x - bw / 2
        M[1, 2] += H / 2 + y - 40
        capa = cv2.warpAffine(B, M, (W, H), borderValue=(0, 0, 0, 0))
        a = capa[..., 3:] / 255.0
        o = capa[..., :3] * a + 200 * (1 - a)
        b = p[..., 3:] / 255.0
        out.append((p[..., :3] * b + o * (1 - b)).astype(np.uint8))
    Hh = max(q.shape[0] for q in out)
    out = [cv2.copyMakeBorder(q, 0, Hh - q.shape[0], 0, 0, cv2.BORDER_CONSTANT, value=(200, 200, 200)) for q in out]
    cv2.imwrite(os.path.join(carpeta, "b_%s.png" % n), np.hstack(out))


if __name__ == "__main__":
    main()
