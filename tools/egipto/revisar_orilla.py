"""REVISAR EL RECORTE DE LA ORILLA (2026-10-27): busca restos de cielo (crema o
amarillo) pegados a las palmeras, trozo a trozo de toda la tira, y saca hojas de
contacto de los peores para mirarlos: original | recorte sobre azul | sobre oscuro,
con los restos marcados en rojo.

Un resto es un pixel opaco del borde (a <= 3 px de lo transparente) cuyo color
cae entre el del cielo de al lado y el de la hoja de dentro: mezcla de los dos.

Uso: python tools/egipto/revisar_orilla.py [carpeta_salida] [--original tira_media.npy]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, AQUI)
import capas as C  # noqa: E402

TESELA = 200
FILAS = (380, 880)
# hasta donde llega la camara en la orilla (paralaje 0.55, fin de la playa): mas
# alla estan las dunas del final, macizas y casi del color del cielo
HASTA_X = 10300


def piezas(carpeta, nombre="medio_orilla"):
    out, k = [], 0
    while os.path.exists(os.path.join(carpeta, "%s_%d.png" % (nombre, k))):
        out.append(cv2.imread(os.path.join(carpeta, "%s_%d.png" % (nombre, k)), cv2.IMREAD_UNCHANGED))
        k += 1
    return np.hstack(out)


def restos(o, original=None):
    """Mascara de los restos de cielo en el borde de lo opaco (y, con la imagen
    cosida original, los bolsillos opacos del color del cielo de esa zona)."""
    A = o[..., 3].astype(np.float32) / 255
    I = o[..., :3].astype(np.float32)
    transp = A < 0.1
    d = cv2.distanceTransform((~transp).astype(np.uint8), cv2.DIST_L2, 3)
    borde = (A > 0.5) & (d <= 3)
    dentro = (A > 0.95) & (d > 4)
    # el cielo de detras ya no esta en el recorte: el de la imagen cosida si hay,
    # si no, el crema tipico de la tira
    S = np.array([170, 226, 250], np.float32)
    F = C._media_cercana(I, dentro, (3, 8, 20))
    FS = F - S
    n2 = (FS * FS).sum(2)
    t = ((I - S) * FS).sum(2) / np.maximum(n2, 1)
    # mezcla: entre cielo y hoja (t lejos de 1), con hoja bien distinta del cielo
    mezcla = borde & (n2 > 60 ** 2) & (t < 0.75)
    hsv = cv2.cvtColor(o[..., :3], cv2.COLOR_BGR2HSV)
    crema = (hsv[..., 0] >= 12) & (hsv[..., 0] <= 34) & (hsv[..., 1] < 150) & (hsv[..., 2] > 150)
    if original is None:
        return mezcla & crema
    # los bolsillos: opaco, y en la imagen original del color del cielo de esa
    # zona (el de la imagen donde el recorte ya es transparente)
    Io = original.astype(np.float32)
    Sz = np.zeros_like(Io)
    W = Io.shape[1]
    for c0 in range(0, W, 2048):
        a0, a1 = max(0, c0 - 300), min(W, c0 + 2048 + 300)
        s_ = C._media_cercana(Io[:, a0:a1], transp[:, a0:a1], (10, 40, 120))
        Sz[:, c0:c0 + 2048] = s_[:, c0 - a0:c0 - a0 + 2048]
    bolsillo = (A > 0.5) & (np.linalg.norm(Io - Sz, axis=2) < 14)
    bolsillo = cv2.morphologyEx(bolsillo.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)) > 0
    return (mezcla & crema) | bolsillo


def main():
    sal = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.join(AQUI, "_revision")
    os.makedirs(sal, exist_ok=True)
    o = piezas(C.DESTINO)
    # (--original tira.npy: la tira media cosida, para buscar tambien bolsillos)
    original = np.load(sys.argv[sys.argv.index("--original") + 1]) if "--original" in sys.argv else None
    r = restos(o, original)
    r[:FILAS[0]] = False
    r[FILAS[1]:] = False
    r[:, HASTA_X:] = False
    H, W = r.shape
    cuenta = []
    for x in range(0, W, TESELA):
        for y in range(FILAS[0], FILAS[1], TESELA):
            cuenta.append((int(r[y:y + TESELA, x:x + TESELA].sum()), x, y))
    cuenta.sort(reverse=True)
    total = int(r.sum())
    print("restos en toda la tira: %d px; teselas con mas de 20: %d" % (total, sum(1 for c in cuenta if c[0] > 20)))
    for c in cuenta[:12]:
        print("  x %5d y %4d: %d" % (c[1], c[2], c[0]))
    A = o[..., 3:4].astype(np.float32) / 255
    azul = (o[..., :3] * A + np.array([230, 170, 90]) * (1 - A)).astype(np.uint8)
    oscuro = (o[..., :3] * A + np.array([60, 50, 45]) * (1 - A)).astype(np.uint8)
    marca = azul.copy()
    marca[r] = (0, 0, 255)
    hojas = []
    for n, x, y in cuenta[:24]:
        sl = (slice(y, y + TESELA), slice(x, x + TESELA))
        fila = np.hstack([azul[sl], oscuro[sl], marca[sl]])
        fila = cv2.resize(fila, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_NEAREST)
        cv2.putText(fila, "x%d y%d  %d" % (x, y, n), (6, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2)
        hojas.append(fila)
    for k in range(0, len(hojas), 4):
        cv2.imwrite(os.path.join(sal, "peores_%d.png" % (k // 4)), np.vstack(hojas[k:k + 4]))
    np.save(os.path.join(sal, "restos.npy"), r)


if __name__ == "__main__":
    main()
