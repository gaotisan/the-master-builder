"""EL PLANO MEDIO, recortado de las referencias (2026-10-25): palmeras y juncos
que ya estan en las imagenes, sueltos (GrabCut con una caja por pieza; el cielo
y el agua azules, fondo seguro). Guarda _kit/medio/<nombre>.png recortado a lo
que tiene alfa y una hoja de contactos para revisarlos.

Nada se pinta: solo se recorta.

Uso: python tools/egipto/medio.py [hoja.jpg]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
KIT = os.path.join(AQUI, "_kit", "medio")
REFS = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
                    "raw", "master_builder", "referencias", "egipto_primer_plano")


def ruta_ref(i):
    """La referencia i (indice en el orden alfabetico de la carpeta original de
    Descargas): copiada en el proyecto como ref_<i>.png."""
    return os.path.join(REFS, "ref_%02d.png" % i)

# nombre: (referencia, caja a MEDIA resolucion x0, y0, x1, y1, corte de abajo: lo que
# queda por debajo no se usa, va detras del primer plano)
PIEZAS = {
    # nombre: (referencia, caja, fraccion de alto que se queda desde arriba)
    "palmera_20a": (20, (840, 200, 1035, 600), 0.6),
    "palmera_20b": (20, (995, 330, 1135, 545), 1.0),
    "palmera_20c": (20, (722, 305, 858, 470), 0.74),
}


def leer(i):
    return cv2.imdecode(np.fromfile(ruta_ref(i), np.uint8), cv2.IMREAD_COLOR)


def recortar(im, caja):
    e = im.shape[1] / 1456.0
    x0, y0, x1, y1 = [int(v * e) for v in caja]
    m = 12
    X0, Y0 = max(0, x0 - m), max(0, y0 - m)
    X1, Y1 = min(im.shape[1], x1 + m), min(im.shape[0], y1 + m)
    sub = im[Y0:Y1, X0:X1]
    mask = np.full(sub.shape[:2], cv2.GC_BGD, np.uint8)
    mask[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0] = cv2.GC_PR_FGD
    hsv = cv2.cvtColor(sub, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    # cielo y agua (azules o muy claros y sin color): fondo seguro
    fondo = ((h >= 85) & (h <= 130) & (v > 100)) | ((s < 45) & (v > 170))
    # y la piedra clara del primer plano (lo que asoma de los muros)
    piedra = (h >= 8) & (h <= 28) & (s > 50) & (v > 140)
    mask[fondo | piedra] = cv2.GC_BGD
    # verde oscuro de las copas y tronco pardo oscuro: primer plano seguro
    verde = (h >= 30) & (h <= 85) & (s > 70) & (v < 150)
    mask[verde & (mask != cv2.GC_BGD)] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    try:
        cv2.grabCut(sub, mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    except cv2.error:
        pass
    fg = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        grande = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
        # la pieza principal y lo que este pegado (frondas sueltas grandes)
        keep = np.zeros_like(fg)
        for k in range(1, n):
            if k == grande or st[k, cv2.CC_STAT_AREA] > 0.08 * st[grande, cv2.CC_STAT_AREA]:
                keep[lab == k] = 1
        fg = keep
    a = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 0.7)
    rgba = np.dstack([sub, (np.clip(a, 0, 1) * 255).astype(np.uint8)])
    ys, xs = np.where(fg > 0)
    if len(ys):
        rgba = rgba[max(0, ys.min() - 2):ys.max() + 3, max(0, xs.min() - 2):xs.max() + 3]
    return rgba


def main():
    os.makedirs(KIT, exist_ok=True)
    piezas = []
    for nombre, (i, caja, queda) in PIEZAS.items():
        r = recortar(leer(i), caja)
        r = r[:max(1, int(r.shape[0] * queda))]
        cv2.imencode(".png", r)[1].tofile(os.path.join(KIT, nombre + ".png"))
        piezas.append((nombre, r))
    if len(sys.argv) > 1:
        celda = 420
        cols = 5
        filas = (len(piezas) + cols - 1) // cols
        hoja = np.full((filas * celda, cols * celda, 3), (200, 0, 200), np.uint8)
        for k, (nombre, r) in enumerate(piezas):
            e = min((celda - 20) / r.shape[1], (celda - 40) / r.shape[0])
            im = cv2.resize(r, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
            a = im[..., 3:4] / 255.0
            y, x = (k // cols) * celda + 30, (k % cols) * celda + 10
            z = hoja[y:y + im.shape[0], x:x + im.shape[1]]
            hoja[y:y + im.shape[0], x:x + im.shape[1]] = (im[..., :3] * a + z * (1 - a)).astype(np.uint8)
            cv2.putText(hoja, nombre, ((k % cols) * celda + 8, (k // cols) * celda + 22), cv2.FONT_HERSHEY_SIMPLEX,
                        0.6, (255, 255, 255), 2)
        cv2.imencode(".jpg", hoja)[1].tofile(sys.argv[1])
    print("medio", len(piezas))


if __name__ == "__main__":
    main()
