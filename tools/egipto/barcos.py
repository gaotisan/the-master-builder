"""LOS BARCOS DEL ACTO I (2026-10-26): los faluchos facetados sobre verde
(raw/master_builder/referencias/egipto_barcos/velas.png), recortados con croma:
cada barco suelto, sin el verde ni su reflejo en los bordes (despill).

Escribe assets/egipto/acto1/barcos/barco_N.png. Uso: python tools/egipto/barcos.py
Tambien vale para otras piezas sobre verde (la nave, 2026-10-27):
    python tools/egipto/barcos.py origen.png carpeta_destino prefijo
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ORIGEN = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_barcos", "velas.png")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "barcos")


def main(origen=ORIGEN, destino=DESTINO, prefijo="barco"):
    os.makedirs(destino, exist_ok=True)
    im = cv2.imdecode(np.fromfile(origen, np.uint8), cv2.IMREAD_COLOR).astype(np.float32)
    b, g, r = im[..., 0], im[..., 1], im[..., 2]
    # cuanto verde de croma hay: el verde por encima del mayor de los otros dos
    verde = g - np.maximum(r, b)
    a = 1.0 - np.clip((verde - 25.0) / 70.0, 0, 1)
    # despill: el verde que sobra en los bordes, fuera
    im[..., 1] = np.minimum(g, np.maximum(r, b) + 6)
    duro = (a > 0.5).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(duro, 8)
    k = 0
    for i in np.argsort(-st[1:, cv2.CC_STAT_AREA]) + 1:
        x, y, w, h, area = st[i]
        if area < 1500:
            continue
        m = 12
        x0, y0 = max(0, x - m), max(0, y - m)
        x1, y1 = min(im.shape[1], x + w + m), min(im.shape[0], y + h + m)
        cerca = cv2.dilate((lab[y0:y1, x0:x1] == i).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
        alfa = np.where(cerca, a[y0:y1, x0:x1], 0)
        rgba = np.dstack([np.clip(im[y0:y1, x0:x1], 0, 255).astype(np.uint8), (alfa * 255).astype(np.uint8)])
        cv2.imencode(".png", rgba)[1].tofile(os.path.join(destino, "%s_%d.png" % (prefijo, k)))
        print("%s_%d" % (prefijo, k), rgba.shape)
        k += 1


if __name__ == "__main__":
    if len(sys.argv) >= 4:
        main(sys.argv[1], sys.argv[2], sys.argv[3])
    else:
        main()
