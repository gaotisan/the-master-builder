"""EL VERDE QUE QUEDA EN UNA HOJA DE SPRITES (2026-10-29; el usuario, en la
caida de Egipto: "justo cuando se esta levantando del golpe... entre ese brazo
y el torso hay zonas que no son transparentes, hay sprites que si y sprites que
no"). Son restos del croma verde del video, encerrados entre el brazo y el
cuerpo (en levantarse, los 35, 40, 42 y 44-48 con 200-400 px; los de al lado,
limpios: parpadeaba). Aqui: lo verde (tono de verde, saturado, mas verde que
rojo y azul), transparente; su filo (1-2 px de mezcla con la tunica), sin el
verde (g no pasa de lo mayor de r y b) y medio transparente. La tunica, la
capucha, la barba y la piel no tienen verde.

Cambia la hoja en su sitio (la de antes, en raw/respaldo_hojas/, fuera de
lo que importa Godot).
Uso (desde el proyecto): python -I tools/anim/quitar_verde_hoja.py hoja.png [...] [--ver carpeta] [--solo-ver]
"""
import os
import shutil
import sys

import cv2
import numpy as np


def mascara(bgra):
    a = bgra[..., 3] > 0
    hsv = cv2.cvtColor(bgra[..., :3], cv2.COLOR_BGR2HSV).astype(int)
    f = bgra[..., :3].astype(int)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    verde = a & (hsv[..., 0] >= 40) & (hsv[..., 0] <= 90) & (hsv[..., 1] > 50) & (g > r + 8) & (g >= b)
    # (motas sueltas de 1-2 px: tambien, son del croma)
    # el filo: lo que toca lo verde y aun tira a verde
    cerca = cv2.dilate(verde.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    filo = cerca & ~verde & a & (g > np.maximum(r, b))
    return verde, filo


def limpiar(bgra):
    verde, filo = mascara(bgra)
    o = bgra.copy()
    o[..., 3][verde] = 0
    f = o[..., :3].astype(int)
    tope = np.maximum(f[..., 0], f[..., 2])
    g = np.where(filo, np.minimum(f[..., 1], tope), f[..., 1])
    o[..., 1] = g.astype(np.uint8)
    o[..., 3] = np.where(filo, (o[..., 3] * 0.6).astype(np.uint8), o[..., 3])
    return o, int(verde.sum()), int(filo.sum())


def sobre(bgra, color=(255, 0, 255)):
    a = bgra[..., 3:] / 255.0
    return (bgra[..., :3] * a + np.array(color) * (1 - a)).astype(np.uint8)


def main():
    hojas = [a for a in sys.argv[1:] if a.lower().endswith(".png")]
    carpeta = sys.argv[sys.argv.index("--ver") + 1] if "--ver" in sys.argv else None
    for ruta in hojas:
        im = cv2.imread(ruta, -1)
        o, nv, nf = limpiar(im)
        print(ruta, "verde quitado: %d px, filo: %d px" % (nv, nf))
        if carpeta:
            verde, _ = mascara(im)
            ys, xs = np.nonzero(verde)
            if len(xs):
                # el trozo con mas verde, antes y despues
                cy, cx = int(np.median(ys)), int(np.median(xs))
                y0, x0 = max(cy - 150, 0), max(cx - 150, 0)
                a_ = sobre(im[y0:y0 + 300, x0:x0 + 300])
                d_ = sobre(o[y0:y0 + 300, x0:x0 + 300])
                cv2.imwrite(os.path.join(carpeta, "verde_" + os.path.basename(ruta)), np.hstack([a_, d_]))
        if "--solo-ver" in sys.argv:
            continue
        os.makedirs(os.path.join("raw", "respaldo_hojas"), exist_ok=True)
        antes = os.path.join("raw", "respaldo_hojas", os.path.basename(ruta))
        if not os.path.exists(antes):
            shutil.copy2(ruta, antes)
        cv2.imwrite(ruta, o)


if __name__ == "__main__":
    main()
