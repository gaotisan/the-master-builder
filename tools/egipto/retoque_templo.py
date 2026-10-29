"""EL RETOQUE DEL TEMPLO DE LAS TERRAZAS (2026-10-29): las alturas de lo que se
trepa, a la medida de las dos trepadas que hay (sin videos nuevos; el usuario:
"tendriamos que ajustarlo con los videos actuales, como si tengo que retocar el
templo"). Con las manos en el borde, la trepada mediana vale de 155 a 190 px de
juego y la alta de 300 a 420; lo de 53 a 150 se sube de un salto. Antes, cuatro
caras caian entre 220 y 250 (ni una ni otra: manos en el aire o dentro de la
piedra).

Se sube (px de la imagen, 1744 x 837; en el juego, x1,8):
  - el puente, 33: la losa y lo de debajo suben; las columnas y el machon se
    alargan repitiendo un trozo de su fuste (de 647 a 680)
    -> puente a la losa 221 -> 162 (mediana), escalon bajo al puente 247 -> 306
       (alta), plinto al puente 337 -> 396 (alta), puente al pilar 158 -> 99 (salto)
  - el remate del pilar alto, 23: se alarga su fuste (de 397 a 420)
    -> losa al remate 131 -> 172 (mediana), remate a la repisa 148 -> 107 (salto)
  - el altar, 38: se le repite la cornisa con su friso (de 112 a 150): un remate
    doble (en la base no: las bases de los obeliscos le tapan las esquinas)
    -> subida al mirador 239 -> 307 (alta)

Y sin escalones de 16 a 60 px (andando el nodo se deslizaba y parecia levitar):
  - el plinto, 15 hacia arriba (una hilada mas): del plinto a la pasarela 45 -> 72
  - la repisa suelta, 10 hacia abajo: de ella a la grande 50 -> 68

Nada pintado: todo son trozos de la misma imagen movidos o repetidos. Se hace
en las dos: la de piezas/ (la de recorrido.py --ver) y la escalada de piezas_hd/
(la del juego, x2). Lo de recorrido.py (CAJAS, ADORNOS, BANDADA) ya esta con las
alturas nuevas.

    python tools/egipto/retoque_templo.py

Parte siempre de las copias sin retocar (raw/.../egipto_piezas/_sin_retoque); si
la imagen de assets no es la que dejo este script (se rehizo con piezas.py o
escalar_piezas.py), esa pasa a ser la copia sin retocar. Despues: Godot --import.
"""
import os, json, hashlib, shutil
import numpy as np
import cv2

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.abspath(os.path.join(AQUI, "..", ".."))
PIEZA = "templo_terrazas"
IMAGENES = {  # carpeta -> escala respecto a la imagen medida
    os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas"): 1,
    os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas_hd"): 2,
}
COPIAS = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_piezas", "_sin_retoque")
HUELLAS = os.path.join(COPIAS, "retocadas.json")

# [x0, x1, ya, c, d, fundido]: en las columnas x0..x1, lo de las filas ya..c
# sube d; la franja de c-d a c se queda tambien donde estaba (se repite: el
# hueco que deja lo que sube). ya: por encima de lo que sube (lo de arriba de
# ya no se toca). fundido: filas en que lo que sube pasa poco a poco a la franja
# que se repite (en los fustes, sin el se veia la costura).
SUBIDAS = [
    # el puente: la losa empieza en 547 (en 140-149, contra el pilar, justo ahi:
    # por encima esta la esquina del pilar, que no se mueve)
    [140, 149, 547, 680, 33, 6],
    [149, 525, 535, 680, 33, 6],
    # (a la derecha del machon, bajo la losa solo hay cielo hasta el bloque de
    # 640: se repite cielo)
    [525, 546, 535, 630, 33, 0],
    # el remate del pilar alto (por encima, la repisa suelta acaba en 325). Lo
    # que se repite, por debajo de las manchas de sombra del remate (repetidas
    # salia una banda oscura): en la cara de la luz, de 429 a 452; en la de la
    # sombra (hasta 755, su arista; debajo esta la losa), de 401 a 424
    [705, 755, 350, 424, 23, 4],
    [755, 849, 350, 452, 23, 4],
    # el altar: entre los obeliscos (en 1640 empieza el de la derecha); la
    # cornisa con su friso, repetida tal cual (fundida se emborronaba)
    [1400, 1639, 40, 150, 38, 0],
    # EL PLINTO (2026-10-29, sin escalones de 16 a 60 px: andando se veia levitar):
    # su cara de arriba sube una hilada, tapando las basas del pilar y de la
    # columna (como encastradas); repite el bloque de 760 a 775 (antes de la junta)
    [0, 221, 737, 775, 15, 4],
]

# [x0, x1, y0, y1, d, xm]: lo de las filas y0..y1 (columnas x0..x1) baja d; lo
# que deja arriba, transparente (cielo detras), salvo desde xm: ahi hay un muro
# encima y se alarga hacia abajo con sus propias filas.
BAJADAS = [
    # LA REPISA SUELTA (con la grande quedaba un escalon de 50): 10 (con 15 se
    # apoyaba en el remate del pilar alto, recien subido). Su extremo (hasta
    # 926) sale de debajo del muro, que acaba en 275: el muro baja con ella
    [805, 926, 272, 318, 10, 905],
]


def huella(ruta):
    return hashlib.sha1(open(ruta, "rb").read()).hexdigest()


def retocar(img, e):
    out = img.copy()
    for x0, x1, ya, c, d, fundido in SUBIDAS:
        x0, x1, ya, c, d = x0 * e, x1 * e, ya * e, c * e, d * e
        out[ya - d:c - d, x0:x1] = img[ya:c, x0:x1]
        if fundido == 0:
            continue
        # la costura: las ultimas filas de lo que sube pasan poco a poco a la
        # franja que se repite
        k = fundido * e
        w = np.linspace(0.0, 1.0, k + 2)[1:-1].reshape(-1, 1, 1)
        arriba = img[c - k:c, x0:x1].astype(np.float32)
        abajo = img[c - d - k:c - d, x0:x1].astype(np.float32)
        out[c - d - k:c - d, x0:x1] = np.round(arriba * (1.0 - w) + abajo * w).astype(img.dtype)
    for x0, x1, y0, y1, d, xm in BAJADAS:
        x0, x1, y0, y1, d, xm = x0 * e, x1 * e, y0 * e, y1 * e, d * e, xm * e
        out[y0:y1, x0:x1] = 0
        out[y0:y0 + d, xm:x1] = img[y0 - d:y0, xm:x1]
        # (por encima de lo que haya debajo: el remate del pilar asoma ahi)
        src = img[y0:y1, x0:x1].astype(np.float32)
        dst = out[y0 + d:y1 + d, x0:x1].astype(np.float32)
        a_s = src[..., 3:4] / 255.0
        a_d = dst[..., 3:4] / 255.0
        a_o = a_s + a_d * (1.0 - a_s)
        rgb = (src[..., :3] * a_s + dst[..., :3] * a_d * (1.0 - a_s)) / np.maximum(a_o, 1e-6)
        out[y0 + d:y1 + d, x0:x1] = np.dstack([rgb, a_o * 255.0]).round().astype(img.dtype)
    return out


def main():
    os.makedirs(COPIAS, exist_ok=True)
    huellas = json.load(open(HUELLAS)) if os.path.exists(HUELLAS) else {}
    for carpeta, e in IMAGENES.items():
        ruta = os.path.join(carpeta, PIEZA + ".png")
        nombre = os.path.basename(carpeta)
        copia = os.path.join(COPIAS, "%s_%s.png" % (PIEZA, nombre))
        if not os.path.exists(copia) or huellas.get(nombre) != huella(ruta):
            shutil.copyfile(ruta, copia)
            print("copia sin retocar:", copia)
        img = cv2.imread(copia, cv2.IMREAD_UNCHANGED)
        cv2.imwrite(ruta, retocar(img, e))
        huellas[nombre] = huella(ruta)
        print("retocada:", ruta)
    json.dump(huellas, open(HUELLAS, "w"), indent=1)


if __name__ == "__main__":
    main()
