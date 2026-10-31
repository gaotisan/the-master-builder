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
  - (el altar ya NO: se le repetia la cornisa con su friso para subirlo 38 y que
    la subida al mirador fuera la alta; 2026-10-30, el usuario: "esos dos frisos
    en el altar no vienen a cuento, lo suyo es tener solo uno". Se sube por la
    base del obelisco: recorrido.py)

Y sin escalones de 16 a 60 px (andando el nodo se deslizaba y parecia levitar):
  - el plinto, 15 hacia arriba (una hilada mas): del plinto a la pasarela 45 -> 72
  - la repisa suelta, 10 hacia abajo: de ella a la grande 50 -> 68

EL CAMINO DEL PRINCIPIO (2026-10-30, el usuario: "deberia pasar por c001, c003,
c004 y de ahi para arriba"; se paraba en el bloque bajo, debajo del puente, y
trepaba al puente a traves de el):
  - el bloque bajo, 40 hacia abajo (se queda en su hilada de arriba, sobre la
    pasarela): debajo del puente ya cabe de pie (248 -> 317 px) y de la pasarela
    se sube de un salto (135 -> 67)
  - EL BLOQUE GEMELO: el mismo bloque bajo repetido a la derecha del bloque de
    encima, el camino de vuelta (de la pasarela a ese bloque no se subia: 225)

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
    # EL BLOQUE BAJO: su hilada de arriba (de la cara de arriba, 685, a la junta,
    # 722) baja 40 hasta casi la pasarela y tapa la de abajo; lo que deja, de lo
    # de encima (el machon del puente, el cielo y el lado del bloque de encima,
    # alargados)
    [452, 576, 685, 722, 40, 452],
]

# [x0, x1, y0, y1]: cielo (transparente), tras las bajadas
CIELOS = [
    # entre el machon del puente y el bloque de encima: lo oscuro de detras del
    # bloque bajo se quedaba flotando, dos veces (lo de su sitio y lo alargado)
    [522, 540, 676, 721],
]

# [x0, x1, y0, y1, dx]: lo de x0..x1, y0..y1 (ya retocado) repetido dx a la
# derecha, encima de lo que haya
REPETIDOS = [
    # EL BLOQUE GEMELO: el bloque bajo (ya bajado) a la derecha del de encima,
    # contra el muro
    [456, 576, 725, 765, 314],
]

# Como SUBIDAS, pero al final, sobre lo ya retocado (con las coordenadas de la
# imagen de assets: lo de debajo ya bajado, el bloque gemelo puesto...)
SUBIDAS_TRAS = [
    # EL BLOQUE DE ENCIMA (c004), 16 (2026-10-31, el usuario: "naturalmente pasas
    # al 4 y del cuatro al puente parece que si se puede"; la primera trepada,
    # obligada): del bloque bajo al de encima 158 -> 187 (ya no llega de un
    # salto: se trepa) y del de encima al puente 216 -> 187 (la misma trepada,
    # pegado al filo). Sube desde su cara de arriba (634: lo de encima, el pie del
    # fuste de la losa y del pilar, no se mueve, queda detras), y se repite la
    # franja lisa de su hilada de abajo (735-751), sobre su zocalo (con la de los
    # churretes de arriba quedaba una raya; el montoncito de arena de encima
    # tambien desde 634: desde mas arriba subia con el un trozo del muro de
    # detras, un parche claro). El vuelo de la derecha de la losa, solo ella:
    # debajo, el muro de su derecha (RELLENOS_TRAS). (Lo de su izquierda, el
    # remate y las piedrecitas, se quita: CIELOS_TRAS)
    [575, 765, 634, 751, 16, 4],
    [765, 780, 634, 672, 16, 0],
    # EL SALIENTE ALTO de los tres de encima de la pasarela (2026-10-31, el usuario:
    # "quiero que se puedan usar tb aunque no lleven a ningun sitio"), 13: del de
    # abajo se trepa (277 -> 300, la alta). La repisa y sus churretes, de debajo
    # de la junta de encima (427: si no, subia con ella y quedaba una raya) a la
    # de debajo (500: no se descuadra con el muro de los lados)
    [1100, 1228, 428, 490, 13, 4],
]

# [x0, x1, y0, y1, dx]: tras SUBIDAS_TRAS, lo de x0..x1, y0..y1 con lo de dx a la
# derecha (el muro que queda a la vista)
RELLENOS_TRAS = [
    [765, 780, 656, 672, 15],
]

# [x0, x1, y0, y1]: cielo, tras lo anterior
CIELOS_TRAS = [
    # EL REMATE DE LA IZQUIERDA DEL BLOQUE DE ENCIMA y la columna de piedrecitas
    # de debajo (2026-10-31, el usuario: "esos arreglos se ven raros"): la
    # columna salio de alargar ese lado al bajar el bloque bajo (BAJADAS) y al
    # subir el de encima; el remate quedaba suelto debajo del final del puente.
    # Hasta la cara de arriba del bloque bajo (728)
    [524, 576, 590, 728],          # (desde 524: a la izquierda, el canto del pilar del puente)
]

# [x0, xa, x1, y0, y1]: lo de xa..x1 estirado a x0..x1 (en x), filas y0..y1
ESTIRADOS_TRAS = [
    # EL BLOQUE DE ENCIMA, 12 mas a la izquierda (sin el remate, su cara quedaba
    # a 68 px de juego del puente: no se trepaba de uno a otro): su cara de lado,
    # en sombra, y el principio de la de frente, hasta su primera junta (636), de
    # la cara de arriba de su losa a la pasarela; tapa el final del bloque bajo
    [564, 576, 636, 620, 767],
]

# [x, y, r]: la esquina de arriba a la izquierda en (x, y), redondeada con radio
# r (lo estirado acababa en esquina viva; las de la piedra son romas)
ESQUINAS_TRAS = [
    [564, 620, 5],
]

# [x0, x1, y0, y1, dx, xb, yb]: lo de x0..x1, y0..y1 (ya retocado) corrido dx a
# la derecha; antes, todo eso a cielo (si no, la pieza de su sitio asomaba por
# las esquinas redondeadas de lo corrido: un corte recto), y lo que tapa, salvo lo
# de debajo de yb desde xb (el borde de arriba del capitel), que se queda debajo
CORRIDOS = [
    # LA PUNTA DE LA LOSA (2026-10-31, el usuario: de c004 a la losa "en teoria no
    # debe poder escalar", mejor al puente): la punta izquierda de la losa
    # (500-545) tapaba el extremo del puente (hasta 540), 58 px por encima: no se
    # podia subir al puente sin meter la cabeza en ella. Corrida 57: acaba a ras
    # del capitel de su columna (que empieza en 556; con 45 asomaba un munon de
    # losa sobre el cielo, "queda feisimo ese pegotillo") y en la junta de 630
    [496, 573, 418, 464, 57, 556, 461],
]


def huella(ruta):
    return hashlib.sha1(open(ruta, "rb").read()).hexdigest()


def subir(out, img, subidas, e):
    for x0, x1, ya, c, d, fundido in subidas:
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


def retocar(img, e):
    out = img.copy()
    subir(out, img, SUBIDAS, e)
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
    for x0, x1, y0, y1 in CIELOS:
        out[y0 * e:y1 * e, x0 * e:x1 * e] = 0
    for x0, x1, y0, y1, dx in REPETIDOS:
        x0, x1, y0, y1, dx = x0 * e, x1 * e, y0 * e, y1 * e, dx * e
        src = out[y0:y1, x0:x1].astype(np.float32)
        dst = out[y0:y1, x0 + dx:x1 + dx].astype(np.float32)
        a_s = src[..., 3:4] / 255.0
        a_d = dst[..., 3:4] / 255.0
        a_o = a_s + a_d * (1.0 - a_s)
        rgb = (src[..., :3] * a_s + dst[..., :3] * a_d * (1.0 - a_s)) / np.maximum(a_o, 1e-6)
        out[y0:y1, x0 + dx:x1 + dx] = np.dstack([rgb, a_o * 255.0]).round().astype(img.dtype)
    subir(out, out.copy(), SUBIDAS_TRAS, e)
    for x0, x1, y0, y1, dx in RELLENOS_TRAS:
        x0, x1, y0, y1, dx = x0 * e, x1 * e, y0 * e, y1 * e, dx * e
        out[y0:y1, x0:x1] = out[y0:y1, x0 + dx:x1 + dx]
    for x0, x1, y0, y1 in CIELOS_TRAS:
        out[y0 * e:y1 * e, x0 * e:x1 * e] = 0
    for x0, xa, x1, y0, y1 in ESTIRADOS_TRAS:
        x0, xa, x1, y0, y1 = x0 * e, xa * e, x1 * e, y0 * e, y1 * e
        trozo = out[y0:y1, xa:x1].copy()
        out[y0:y1, x0:x1] = cv2.resize(trozo, (x1 - x0, y1 - y0), interpolation=cv2.INTER_CUBIC)
    for x, y, r in ESQUINAS_TRAS:
        x, y, r = x * e, y * e, r * e
        yy, xx = np.mgrid[0:r, 0:r].astype(np.float32) + 0.5
        dentro = np.clip(r - np.hypot(r - xx, r - yy) + 0.5, 0.0, 1.0)
        a = out[y:y + r, x:x + r, 3].astype(np.float32)
        out[y:y + r, x:x + r, 3] = np.round(a * dentro).astype(out.dtype)
    for x0, x1, y0, y1, dx, xb, yb in CORRIDOS:
        x0, x1, y0, y1, dx, xb, yb = x0 * e, x1 * e, y0 * e, y1 * e, dx * e, xb * e, yb * e
        src = out[y0:y1, x0:x1].astype(np.float32)
        antes = out[yb:y1, xb:x1 + dx].astype(np.float32)
        # (y donde va, tambien: si no, por encima de lo corrido asomaba el borde
        # de arriba de la pieza de antes, una franja clara con su extremo recto)
        out[y0:y1, x0:x1 + dx] = 0
        dst = out[y0:y1, x0 + dx:x1 + dx].astype(np.float32)
        a_s = src[..., 3:4] / 255.0
        a_d = dst[..., 3:4] / 255.0
        a_o = a_s + a_d * (1.0 - a_s)
        rgb = (src[..., :3] * a_s + dst[..., :3] * a_d * (1.0 - a_s)) / np.maximum(a_o, 1e-6)
        out[y0:y1, x0 + dx:x1 + dx] = np.dstack([rgb, a_o * 255.0]).round().astype(img.dtype)
        src = out[yb:y1, xb:x1 + dx].astype(np.float32)
        a_s = src[..., 3:4] / 255.0
        a_d = antes[..., 3:4] / 255.0
        a_o = a_s + a_d * (1.0 - a_s)
        rgb = (src[..., :3] * a_s + antes[..., :3] * a_d * (1.0 - a_s)) / np.maximum(a_o, 1e-6)
        out[yb:y1, xb:x1 + dx] = np.dstack([rgb, a_o * 255.0]).round().astype(img.dtype)
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
