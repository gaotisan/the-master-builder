"""EL PRIMER PLANO DE LAS REFERENCIAS, separado del fondo (2026-10-25).

De cada imagen de la familia B (17-21: las upscale --ar 91:51 coherentes entre
si) saca la piedra y las plantas del primer plano, sin el cielo, la ciudad, el
agua ni los juncos del fondo, con GrabCut sembrado a mano: lo de arriba es fondo
seguro, lo de debajo del camino es primer plano seguro, y las cajas de PISTAS
dicen donde hay estructura (primer plano probable). Guarda _kit/franjas/rNN.png
(RGBA a resolucion completa) y una vista sobre magenta para revisar el borde.

Nada se pinta: solo se recorta.

Uso: python tools/egipto/franjas.py [indices...]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
KIT = os.path.join(AQUI, "_kit", "franjas")
REFS = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
                    "raw", "master_builder", "referencias", "egipto_primer_plano")


def ruta_ref(i):
    """La referencia i (indice en el orden alfabetico de la carpeta original de
    Descargas): copiada en el proyecto como ref_<i>.png."""
    return os.path.join(REFS, "ref_%02d.png" % i)

# por imagen (coordenadas a MEDIA resolucion, 1456 x 816):
#   cielo: por encima, fondo seguro
#   seguro: por debajo, primer plano seguro (el frente del camino y lo de abajo)
#   cajas: estructuras y plantas del primer plano (probable)
#   fondo: cajas de fondo seguro entre estructuras (agua, juncos lejanos)
PISTAS = {
    17: {"cielo": 270, "seguro": 712,
         "cajas": [(0, 445, 220, 712), (200, 585, 360, 712), (470, 575, 690, 712), (675, 500, 900, 712),
                   (850, 360, 1100, 712), (1030, 420, 1160, 712), (1060, 590, 1300, 712), (1155, 275, 1400, 712),
                   (1300, 455, 1456, 712), (1390, 320, 1456, 600), (730, 440, 860, 520)],
         "fondo": [(230, 470, 530, 580), (0, 330, 1000, 440)]},
    18: {"cielo": 380, "seguro": 640,
         "cajas": [(0, 470, 1456, 640), (410, 460, 545, 530), (905, 380, 1060, 530), (1245, 470, 1310, 525),
                   (155, 470, 250, 520), (520, 445, 600, 520)],
         "fondo": [(0, 380, 1456, 455)]},
    19: {"cielo": 380, "seguro": 660,
         "cajas": [(0, 395, 320, 660), (575, 455, 890, 660), (860, 550, 1130, 660), (1085, 455, 1290, 660),
                   (1200, 390, 1456, 660), (1360, 380, 1440, 470), (55, 395, 130, 520)],
         "fondo": [(330, 440, 560, 590), (1140, 500, 1200, 560)]},
    20: {"cielo": 410, "seguro": 700,
         "cajas": [(0, 470, 560, 700), (590, 415, 1080, 700), (1060, 610, 1260, 700), (1330, 535, 1456, 700),
                   (720, 300, 1040, 520), (990, 330, 1130, 610), (300, 545, 650, 690)],
         "fondo": [(220, 490, 540, 560), (1120, 520, 1330, 600)]},
    21: {"cielo": 230, "seguro": 728,
         "cajas": [(0, 500, 480, 728), (355, 238, 485, 728), (460, 565, 820, 728), (690, 465, 820, 728),
                   (880, 495, 1110, 728), (1040, 615, 1456, 728)],
         "fondo": [(490, 460, 690, 560), (820, 470, 880, 600), (1110, 470, 1456, 610)]},
}


def leer(i):
    return cv2.imdecode(np.fromfile(ruta_ref(i), np.uint8), cv2.IMREAD_COLOR)


def separar(i):
    im = leer(i)
    H, W = im.shape[:2]
    pis = PISTAS[i]
    e = W / 1456.0
    m = np.full((H, W), cv2.GC_PR_BGD, np.uint8)
    for x0, y0, x1, y1 in pis["cajas"]:
        m[int(y0 * e):int(y1 * e), int(x0 * e):int(x1 * e)] = cv2.GC_PR_FGD
    for x0, y0, x1, y1 in pis["fondo"]:
        m[int(y0 * e):int(y1 * e), int(x0 * e):int(x1 * e)] = cv2.GC_BGD
    m[:int(pis["cielo"] * e)] = cv2.GC_BGD
    m[int(pis["seguro"] * e):] = cv2.GC_FGD
    # el agua y el cielo azul, fondo seguro por color (salvo en lo seguro)
    hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
    azul = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 125) & (hsv[..., 2] > 90)
    azul[int(pis["seguro"] * e):] = False
    m[azul & (m != cv2.GC_FGD)] = cv2.GC_BGD
    # GrabCut a media resolucion (rapido) y luego el borde fino a la completa
    s = 0.5
    ims = cv2.resize(im, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
    ms = cv2.resize(m, (ims.shape[1], ims.shape[0]), interpolation=cv2.INTER_NEAREST)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(ims, ms, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = np.isin(ms, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    fg = cv2.resize(fg, (W, H), interpolation=cv2.INTER_NEAREST)
    # refinado a resolucion completa en una franja alrededor del borde
    borde = cv2.dilate(fg, np.ones((9, 9), np.uint8)) - cv2.erode(fg, np.ones((9, 9), np.uint8))
    m2 = np.where(fg > 0, cv2.GC_FGD, cv2.GC_BGD).astype(np.uint8)
    m2[(borde > 0) & (fg > 0)] = cv2.GC_PR_FGD
    m2[(borde > 0) & (fg == 0)] = cv2.GC_PR_BGD
    try:
        cv2.grabCut(im, m2, None, bgd, fgd, 2, cv2.GC_INIT_WITH_MASK)
    except cv2.error:
        pass
    fg = np.isin(m2, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    # sin islas sueltas de fondo
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    for k in range(1, n):
        if st[k, cv2.CC_STAT_AREA] < 600:
            fg[lab == k] = 0
    alfa = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 0.7)
    return im, np.clip(alfa, 0, 1)


def main():
    os.makedirs(KIT, exist_ok=True)
    idx = [int(a) for a in sys.argv[1:]] or sorted(PISTAS)
    for i in idx:
        im, a = separar(i)
        rgba = np.dstack([im, (a * 255).astype(np.uint8)])
        cv2.imencode(".png", rgba)[1].tofile(os.path.join(KIT, "r%02d.png" % i))
        mag = np.zeros_like(im)
        mag[:] = (255, 0, 255)
        vista = (im * a[..., None] + mag * (1 - a[..., None])).astype(np.uint8)
        vista = cv2.resize(vista, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
        cv2.imencode(".jpg", vista, [cv2.IMWRITE_JPEG_QUALITY, 88])[1].tofile(os.path.join(KIT, "vista_r%02d.jpg" % i))
        print("franja", i)


if __name__ == "__main__":
    main()
