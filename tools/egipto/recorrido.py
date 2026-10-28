"""EL RECORRIDO DE PIEDRA DEL ACTO I (2026-10-28): las piezas del usuario
(piezas.py) colocadas sobre la arena de la playa, y lo que se pisa (cajas).

Las cajas son el suelo de verdad: rectangulos macizos con su cara de arriba y su
cara de abajo (en px de juego, alturas sobre la arena). Pueden quedar unas
sobre otras (repisas): lo que esta por encima de la cabeza no estorba, se pasa
por debajo (acciones_egipto.gd). Se miden en la imagen de cada pieza (px de la
pieza, y hacia abajo) y se llevan al juego con su escala y su sitio. Las
columnas y los muros del fondo de las fachadas no son cajas: se pasa por
delante.

Salida: assets/egipto/acto1/recorrido.json; con --ver, una vista del recorrido
(piezas, cajas, el peregrino a escala) en el scratchpad o donde diga --ver=ruta.

Uso: python -I tools/egipto/recorrido.py [--ver[=ruta.png]]
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
PIEZAS = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas")
RES = "res://assets/egipto/acto1/piezas/"
SALIDA = os.path.join(PROYECTO, "assets", "egipto", "acto1", "recorrido.json")

ALTO_PEREGRINO = 305.0   # px de juego, de los pies a la capucha (medido en la playa)

# Lo que se pisa de cada pieza: [x0, x1, y de arriba, y de abajo] en px de su
# imagen (y hacia abajo); abajo None = hasta el pie de la pieza (macizo).
CAJAS = {
    # EL TEMPLO DE LAS TERRAZAS: el zigzag hasta el mirador. Medido en su
    # imagen (1744 x 837): la pasarela de abajo, el bloque bajo y el de encima,
    # el puente (con su dintel), el pilar de la izquierda, la losa sobre las
    # columnas, el pilar alto, las repisas de la derecha, el escalon, el bloque
    # de arriba, la terraza de los obeliscos y el altar.
    "templo_terrazas": [
        [0, 240, 740, None],        # la base de la izquierda
        [240, 1160, 765, None],     # la pasarela
        [1160, 1744, 725, None],    # la base de la derecha
        [450, 570, 690, None],      # S3: el bloque bajo
        [565, 775, 640, None],      # S4: el bloque de encima
        # S2: el puente (dintel), hasta donde empieza la losa: por encima del
        # bloque bajo no se pisa (no habria sitio para la cabeza)
        # (y desde 300: de la base de la izquierda se baja a la pasarela, y desde
        # alli el puente queda por encima de la cabeza; solo se sube desde el
        # bloque bajo, volviendo hacia la izquierda: el zigzag)
        [300, 500, 553, 585],
        # S1: lo alto del pilar de la izquierda (se pasa por delante del fuste:
        # si no, tapaba la entrada)
        [5, 170, 465, 500],
        [500, 750, 430, 462],       # S5: la losa sobre las columnas
        [712, 842, 357, 640],       # S6: el pilar alto (sobre S4)
        [805, 920, 275, 305],       # S8: la repisa suelta
        [905, 1140, 247, 280],      # S9: la repisa grande
        [1037, 1100, 200, 247],     # S13: el escalon
        [1100, 1268, 165, 247],     # S12: el bloque de arriba
        [1245, 1744, 245, 280],     # S14: la terraza de los obeliscos
        [1408, 1632, 112, 245],     # el altar (lo mas alto: el mirador)
    ],
}

# Las piezas colocadas: [pieza, x de su izquierda (juego), escala, hundida (px
# de juego que quedan bajo la arena), volteada]
# EL TEMPLO DE LAS TERRAZAS, desde el borde izquierdo de la primera pantalla
# (2026-10-28, el usuario: el peregrino aparecera por ahi, por una puerta estelar
# que aun tiene que hacer; -800 es donde empieza la playa y para la camara)
X_TEMPLO = -800.0
COLOCADAS = [
    ["templo_terrazas", X_TEMPLO, 1.8, 85.0, False],
]

MARCAS = {
    # donde aparece el peregrino: en la pasarela, bajo el puente (entre los
    # pilares, donde puede ir la puerta)
    "inicio": [X_TEMPLO + 330.0 * 1.8, None],
    # hasta donde se puede ir a la izquierda (el borde de la base)
    "limite_izq": [X_TEMPLO + 40.0, None],
    # donde se ve el templo de la franja media (lo alto del altar)
    "mirador": [X_TEMPLO + 1520.0 * 1.8, None],
}


# Las palomas posadas (pajaro_posado.gd: se espantan al acercarse el peregrino):
# [x de juego, altura sobre la arena, hacia donde miran]
PAJAROS = [
    [X_TEMPLO + 85.0 * 1.8, 584.0, 1.0],      # en lo alto del pilar de la izquierda
    [X_TEMPLO + 460.0 * 1.8, 426.0, -1.0],    # en el puente
    [X_TEMPLO + 700.0 * 1.8, 648.0, 1.0],     # en la losa sobre las columnas
    [X_TEMPLO + 1700.0 * 1.8, 981.0, -1.0],   # en la terraza de los obeliscos, dos
    [X_TEMPLO + 1675.0 * 1.8, 981.0, 1.0],
]


def cajas_de(pieza, x, escala, hundida, volteada, tam):
    w, h = tam
    out = []
    for x0, x1, ya, yb in CAJAS.get(pieza, []):
        if volteada:
            x0, x1 = w - x1, w - x0
        arriba = (h - ya) * escala - hundida
        abajo = 0.0 if yb is None else (h - yb) * escala - hundida
        out.append({"x0": round(x + x0 * escala, 1), "x1": round(x + x1 * escala, 1),
                    "arriba": round(arriba, 1), "abajo": round(max(abajo, 0.0), 1),
                    "pieza": pieza})
    return out


def main():
    tam = json.load(open(os.path.join(PIEZAS, "piezas.json"), encoding="utf-8"))
    sprites, cajas = [], []
    for pieza, x, escala, hundida, volteada in COLOCADAS:
        w, h = tam[pieza]
        sprites.append({"tex": RES + pieza + ".png", "x": x, "abajo": -hundida, "escala": escala,
                        "flip": volteada, "ancho": round(w * escala, 1), "alto": round(h * escala, 1)})
        cajas += cajas_de(pieza, x, escala, hundida, volteada, (w, h))
    for i, c in enumerate(cajas):
        c["nombre"] = "c%03d" % i
    marcas = {k: v[0] for k, v in MARCAS.items()}
    pajaros = [{"x": round(x, 1), "h": h, "sentido": s} for x, h, s in PAJAROS]
    datos = {"sprites": sprites, "cajas": cajas, "marcas": marcas, "pajaros": pajaros}
    json.dump(datos, open(SALIDA, "w", encoding="utf-8"), indent=1)
    print("%d piezas, %d cajas -> %s" % (len(sprites), len(cajas), SALIDA))
    for a in sys.argv[1:]:
        if a.startswith("--ver"):
            ver(datos, a.split("=", 1)[1] if "=" in a else None)


def ver(datos, ruta):
    """La vista: la arena, las piezas, las cajas (verde: lo de arriba, rojo: el
    canto) y un peregrino de ALTO_PEREGRINO en cada caja."""
    e = 0.35
    x0 = min(s["x"] for s in datos["sprites"]) - 800
    x1 = max(s["x"] + s["ancho"] for s in datos["sprites"]) + 400
    alto = max(s["alto"] for s in datos["sprites"]) + 300
    W, H = int((x1 - x0) * e), int((alto + 200) * e)
    suelo = int(alto * e)
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = (215, 205, 185)
    img[suelo:] = (150, 175, 205)
    for s in datos["sprites"]:
        p = cv2.imread(os.path.join(PIEZAS, os.path.basename(s["tex"])), cv2.IMREAD_UNCHANGED)
        if s["flip"]:
            p = p[:, ::-1]
        w, h = int(s["ancho"] * e), int(s["alto"] * e)
        p = cv2.resize(p, (w, h), interpolation=cv2.INTER_AREA)
        X = int((s["x"] - x0) * e)
        Y = int(suelo - (s["abajo"] + s["alto"]) * e)
        ys, xs = slice(max(Y, 0), min(Y + h, H)), slice(max(X, 0), min(X + w, W))
        sub = p[ys.start - Y:ys.stop - Y, xs.start - X:xs.stop - X].astype(np.float32)
        a = sub[..., 3:] / 255.0
        img[ys, xs] = (sub[..., :3] * a + img[ys, xs] * (1 - a)).astype(np.uint8)
    # la arena por delante del pie de las piezas (lo hundido)
    img[suelo:] = (150, 175, 205)
    for c in datos["cajas"]:
        X0, X1 = int((c["x0"] - x0) * e), int((c["x1"] - x0) * e)
        ya, yb = int(suelo - c["arriba"] * e), int(suelo - c["abajo"] * e)
        cv2.rectangle(img, (X0, ya), (X1, yb), (40, 40, 200), 1)
        cv2.line(img, (X0, ya), (X1, ya), (40, 200, 40), 2)
        cv2.putText(img, "%d" % c["arriba"], (X0 + 2, ya - 3), cv2.FONT_HERSHEY_SIMPLEX, 0.35, (20, 20, 20), 1)
        # el peregrino en medio de la caja
        px = (X0 + X1) // 2
        cv2.rectangle(img, (px - 5, ya - int(ALTO_PEREGRINO * e)), (px + 5, ya), (90, 60, 40), -1)
    ruta = ruta or os.path.join(os.environ.get("TEMP", "."), "recorrido_vista.png")
    cv2.imwrite(ruta, img)
    print("vista:", ruta)


if __name__ == "__main__":
    main()
