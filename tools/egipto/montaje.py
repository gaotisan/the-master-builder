"""EGIPTO, ACTO I: el nivel montado con las referencias (2026-10-25).

NADA SE PINTA: todo son recortes del primer plano de las imagenes del usuario
(franjas.py, familia B: 17-21) a la misma escala (ESCALA: los escalones de las
imagenes quedan al ~12 % de la altura del peregrino y los muros caen en las
alturas de trepar), colocados en fila y alguno recompuesto (el paso bajo: una
viga sobre dos pilares). Lo que se pisa sale del perfil de la piedra de lo
dibujado (o de una linea a mano donde se anda por delante, como la arena de la
llegada), asi que la colision coincide con el dibujo.

Escribe en assets/egipto/acto1/: nivel.json (lo que leen las acciones y el
nivel), arte.json (los sprites), tex/*.png y objetos/*.png; y una vista previa
del montaje con las colisiones (--vista ruta.jpg).

Uso: python tools/egipto/montaje.py [--vista ruta.jpg]
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
FRANJAS = os.path.join(AQUI, "_kit", "franjas")
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1")
TEX = os.path.join(DESTINO, "tex")
OBJ = os.path.join(DESTINO, "objetos")
RES = "res://assets/egipto/acto1/"

ESCALA = 0.77
SOLAPE = 60             # lo que se solapan (fundidas) dos piezas seguidas
PLANTA = 6.5            # los pies pintan 6,5 px por encima del nodo (acciones_perfil.gd)
FONDO_DEBAJO = 900      # lo que se alarga hacia abajo cada franja (su pie, repetido y en sombra)

_cache = {}
REFS = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
                    "raw", "master_builder", "referencias", "egipto_primer_plano")


def ruta_ref(i):
    """La referencia i (indice en el orden alfabetico de la carpeta original de
    Descargas): copiada en el proyecto como ref_<i>.png."""
    return os.path.join(REFS, "ref_%02d.png" % i)


def original(i, rec):
    """Un trozo de la imagen original (con su fondo): para lo de dentro de
    huecos y pasos, que en la franja recortada no queda."""
    im = cv2.imdecode(np.fromfile(ruta_ref(i), np.uint8), cv2.IMREAD_COLOR)
    x0, x1, y0, y1 = rec
    c = im[y0:y1, x0:x1]
    return np.dstack([c, np.full(c.shape[:2], 255, np.uint8)])


def franja(i):
    if i not in _cache:
        im = cv2.imdecode(np.fromfile(os.path.join(FRANJAS, "r%02d.png" % i), np.uint8), cv2.IMREAD_UNCHANGED)
        _cache[i] = im
    return _cache[i]


def perfil_piedra(rgba):
    """y (en la imagen) de lo mas alto de piedra en cada columna (H si no hay)."""
    a = rgba[..., 3] > 128
    hsv = cv2.cvtColor(rgba[..., :3], cv2.COLOR_BGR2HSV)
    p = a & (hsv[..., 0] >= 8) & (hsv[..., 0] <= 28) & (hsv[..., 1] > 60) & (hsv[..., 2] > 90)
    p = cv2.morphologyEx(p.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)) > 0
    H = p.shape[0]
    hay = p.any(0)
    top = np.where(hay, p.argmax(0), H)
    return top


# ---- las piezas ------------------------------------------------------------------
# Cada pieza: franja, recorte (x0, x1, y0, y1 en la imagen, resolucion completa),
# la y de la imagen que hace de 'ancla' y la altura del juego a la que va, y
# como se pisa: "perfil" (la piedra dibujada), una lista de [x0, x1, y] en la
# imagen (a mano), o nada (decorado). Se ponen en fila de izquierda a derecha.
# Alturas del juego: 0 = el camino del patio (el mas bajo, donde se empuja y se tira).

PIEZAS = [
    # 1. LA LLEGADA: la explanada de arena (r21); se anda por la arena, los
    #    muros quedan detras
    {"f": 21, "rec": (0, 2912, 380, 1560), "ancla": 1450, "h": 297, "pisa": [[0, 2912, 1450]], "nombre": "llegada",
     "pie_de": (18, (40, 1000, 1050, 1420))},
    # 2. LA ZANJA: 200 px de hueco (se salta corriendo); fondo a 200 por debajo
    {"hueco": 200, "fondo_h": 97, "nombre": "zanja"},
    # 3. CORRER: el muro largo de r18 (las torres, decorado)
    {"f": 18, "rec": (0, 2912, 600, 1632), "ancla": 1035, "h": 297, "pisa": [[0, 2912, 1035]], "nombre": "muro_largo",
     "paso_bajo": {"desde": 1500, "largo": 520, "libre": 215}},
    # 4. r17, de la izquierda al camino: muro, escaleras que bajan
    {"f": 17, "rec": (0, 1076, 600, 1632), "ancla": 1011, "h": 297, "pisa": "perfil", "nombre": "escaleras"},
    # 5. TREPAR (a la altura del pecho) y los bloques que suben, hasta el pilar
    {"f": 17, "rec": (1076, 2317, 600, 1632), "ancla": 1376, "h": 0, "pisa": "perfil", "nombre": "bloques"},
    # 6. EL PATIO, a la medida: el sillar alto encajado contra la pared de la
    #    izquierda (se llega por encima); tirar, pasar por encima, empujar dos
    #    veces hasta la estructura alta: 183 + 226 + 2 x 201,77 + 1 = 813,5
    {"f": 18, "rec": (600, 1180, 1000, 1632), "ancla": 1035, "h": 0, "pisa": [[0, 580, 1035]], "nombre": "patio_0"},
    {"f": 19, "rec": (547, 1180, 1100, 1632), "ancla": 1202, "h": 0, "pisa": [[0, 633, 1202]], "nombre": "patio_1"},
    # 7. TREPAR CON LO COLOCADO: la estructura alta de r17 (639 sobre el camino)
    {"f": 17, "rec": (2317, 2912, 520, 1632), "ancla": 1376, "h": 0, "pisa": "perfil", "nombre": "estructura_alta"},
    # 8. HACIA LA CANTERA: r19 (de su muro de la izquierda en adelante)
    {"f": 19, "rec": (132, 2912, 700, 1632), "ancla": 928, "h": 340, "pisa": "perfil", "nombre": "ruinas"},
    # 9. EL FOSO: 360 px (salto corriendo, a tiempo)
    {"hueco": 360, "fondo_h": 140, "nombre": "foso"},
    # 10. r20 hasta el final
    {"f": 20, "rec": (0, 2912, 700, 1632), "ancla": 1205, "h": 446, "pisa": "perfil", "nombre": "final"},
]

# Los objetos que se mueven y la losa, recortados de las franjas
OBJETOS = {
    # el sillar alto (de la argolla): el pilar de r20
    "sillar_argolla": {"f": 20, "rec": (207, 445, 953, 1390)},
}

sprites = []


def poner(tex, x, y, capa="detras", z=-10, flip=False, escala=1.0, tinte=None, viento=0.0, ancla="arriba_izq"):
    sprites.append({"tex": RES + "tex/" + tex + ".png", "x": round(float(x), 1), "y": round(float(y), 1), "capa": capa,
                    "z": int(z), "flip": bool(flip), "escala": round(float(escala), 4), "viento": viento, "tinte": tinte,
                    "ancla": ancla})


def guardar(ruta, rgba):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    cv2.imencode(".png", rgba)[1].tofile(ruta)


def recorte(f, rec, flip=False):
    x0, x1, y0, y1 = rec
    im = franja(f)[y0:y1, x0:x1].copy()
    if flip:
        im = im[:, ::-1].copy()
    return im


def escalar(im):
    return cv2.resize(im, None, fx=ESCALA, fy=ESCALA, interpolation=cv2.INTER_AREA)


def con_pie_de(im, alto_extra, fuente):
    """Alarga una pieza hacia abajo con otro paramento (fuente: (franja, recorte))
    repetido, en penumbra: la explanada de la llegada, sobre un muro de terraza."""
    h, w = im.shape[:2]
    pared = escalar(recorte(*fuente))
    pared[..., 3] = 255
    while pared.shape[1] < w:
        pared = np.hstack([pared, pared[:, ::-1]])
    pared = pared[:, :w]
    out = np.zeros((h + alto_extra, w, 4), np.uint8)
    out[:h] = im
    y = h
    while y < h + alto_extra:
        n = min(pared.shape[0], h + alto_extra - y)
        out[y:y + n] = pared[:n]
        y += n
    sombra = (0.35 + 0.4 * np.clip((np.arange(h + alto_extra) - h) / 600.0, 0, 1.0))[:, None]
    sombra[:h] = 0
    out[..., :3] = (out[..., :3] * (1 - sombra[..., None])).astype(np.uint8)
    return out


def con_pie(im, alto_extra):
    """Alarga una pieza hacia abajo con su propio pie: la franja de abajo (las
    plantas del pie del muro) repetida, volteada en horizontal una si y otra no
    (sin espejo vertical: parecia un reflejo en el agua), y fundida a negro."""
    h, w = im.shape[:2]
    banda = im[max(0, h - 160):].copy()
    out = np.zeros((h + alto_extra, w, 4), np.uint8)
    out[:h] = im
    y = h
    k = 0
    while y < h + alto_extra:
        t = banda[:, ::-1] if k % 2 == 0 else banda
        n = min(t.shape[0], h + alto_extra - y)
        out[y:y + n] = t[:n]
        out[y:y + n, :, 3] = 255
        y += n
        k += 1
    sombra = 0.6 * np.clip((np.arange(h + alto_extra) - h + 40) / 420.0, 0, 1.0)[:, None] ** 0.7
    out[..., :3] = (out[..., :3] * (1 - sombra[..., None])).astype(np.uint8)
    return out


def fundir_bordes(im, lados=(True, True, True, False), ancho=40):
    """Funde a transparente los bordes de un relleno rectangular (izq, der, arriba, abajo)."""
    h, w = im.shape[:2]
    a = np.ones((h, w), np.float32)
    rx = np.clip(np.arange(w) / ancho, 0, 1)
    ry = np.clip(np.arange(h) / ancho, 0, 1)
    if lados[0]:
        a *= rx[None, :]
    if lados[1]:
        a *= rx[::-1][None, :]
    if lados[2]:
        a *= ry[:, None]
    if lados[3]:
        a *= ry[::-1][:, None]
    im[..., 3] = (im[..., 3] * a).astype(np.uint8)
    return im


def montar():
    """Coloca las piezas en fila; devuelve el terreno (alturas por x del juego)."""
    os.makedirs(TEX, exist_ok=True)
    for f in os.listdir(TEX):
        if f.endswith(".png"):
            os.remove(os.path.join(TEX, f))
    x = 0.0
    alto = {}                          # x del juego (entero) -> altura
    techos = []
    zonas = {}
    bloques_extra = []
    pegada = False
    for p in PIEZAS:
        nombre = p["nombre"]
        if "hueco" in p:
            pegada = False
            w = p["hueco"]
            zonas[nombre] = (x, x + w)
            for xx in range(int(x), int(x + w)):
                alto[xx] = p["fondo_h"]
            x += w
            continue
        if p.get("paso_bajo") is True:
            w = p["largo"]
            zonas[nombre] = (x, x + w)
            s = p["suelo"]
            ims = con_pie(escalar(recorte(s["f"], s["rec"])), FONDO_DEBAJO)
            ims = cv2.resize(ims, (int(w) + 2, ims.shape[0]), interpolation=cv2.INTER_AREA)
            guardar(os.path.join(TEX, "pieza_suelo_paso.png"), ims)
            poner("pieza_suelo_paso", x - 1, -(s["ancla"] - s["rec"][2]) * ESCALA - PLANTA, z=-10)
            techos.append({"x0": x, "x1": x + w, "libre": float(p["libre"]), "nombre": nombre})
            for xx in range(int(x), int(x + w)):
                alto[xx] = 0.0
            x += w
            continue
        if isinstance(p.get("paso_bajo"), dict):
            pb = p["paso_bajo"]
            techos.append({"x0": x + pb["desde"], "x1": x + pb["desde"] + pb["largo"], "libre": float(pb["libre"]),
                           "suelo_h": float(p["h"]), "nombre": "paso_bajo"})
        im = recorte(p["f"], p["rec"], p.get("flip", False))
        ims = escalar(im)
        ims = con_pie_de(ims, FONDO_DEBAJO, p["pie_de"]) if "pie_de" in p else con_pie(ims, FONDO_DEBAJO)
        w = ims.shape[1]
        # COSTURAS: si va pegada a otra pieza, la solapa SOLAPE px y se funde en ella
        if pegada:
            x -= SOLAPE
            ims = fundir_bordes(ims, (True, False, False, False), SOLAPE)
        # la y del juego de lo de arriba del recorte: el ancla va a -h (+ los pies)
        y_rec = -p["h"] - (p["ancla"] - p["rec"][2]) * ESCALA - PLANTA
        tex = "pieza_%s" % nombre
        guardar(os.path.join(TEX, tex + ".png"), ims)
        poner(tex, x, y_rec, z=-10)
        zonas[nombre] = (x, x + w)
        # lo que se pisa
        if p["pisa"] == "perfil":
            top = perfil_piedra(im)                    # en la imagen recortada (sin escalar)
            for xx in range(w):
                xi = min(im.shape[1] - 1, int(xx / ESCALA))
                ty = top[xi] + p["rec"][2]
                if ty >= p["rec"][3] - 2:
                    continue
                alto[int(x) + xx] = p["h"] + (p["ancla"] - ty) * ESCALA
        elif isinstance(p["pisa"], list):
            for a0, a1, ay in p["pisa"]:
                for xx in range(int(a0 * ESCALA), int(a1 * ESCALA)):
                    if 0 <= xx < w:
                        alto[int(x) + xx] = p["h"] + (p["ancla"] - ay) * ESCALA
        x += w
        pegada = True
    return alto, techos, zonas, x


def suavizar(alto, x_fin):
    """Del perfil por columnas a tramos: rellena las hendiduras estrechas (las
    plantas entre bloques) y junta lo que casi no cambia."""
    xs = np.arange(int(x_fin))
    h = np.array([alto.get(int(v), np.nan) for v in xs], np.float64)
    # huecos sin dato (bordes de recorte): lo de al lado
    for i in range(len(h)):
        if np.isnan(h[i]):
            h[i] = h[i - 1] if i > 0 and not np.isnan(h[i - 1]) else 0.0
    # cuantizar a 2 px y quitar el ruido de un pixel
    h = np.round(h / 2.0) * 2.0
    h = cv2.medianBlur(h.astype(np.float32).reshape(1, -1), 5).ravel().astype(np.float64)
    tramos = []
    i0 = 0
    for i in range(1, len(h) + 1):
        if i == len(h) or abs(h[i] - h[i0]) > 6:
            tramos.append([float(i0), float(i), float(np.median(h[i0:i]))])
            i0 = i
    # hendiduras de menos de 90 px mas bajas que los dos lados: a la altura del mas bajo de ellos
    cambio = True
    while cambio:
        cambio = False
        for k in range(1, len(tramos) - 1):
            a, b, c = tramos[k - 1], tramos[k], tramos[k + 1]
            if b[1] - b[0] < 90 and b[2] < a[2] - 10 and b[2] < c[2] - 10:
                b[2] = min(a[2], c[2])
                cambio = True
        # juntar vecinos iguales
        j = []
        for t in tramos:
            if j and abs(j[-1][2] - t[2]) <= 6:
                j[-1][1] = t[1]
            else:
                j.append(list(t))
        tramos = j
    # tramos de menos de 60 px (un canto, medio peldano): con un vecino (antes
    # el mas alto), si despues todo sigue siendo subible y bajable
    def vale(d):
        # (con margen_altura 0,36 en acciones_egipto.gd las dos trepas se solapan:
        # todo sube hasta 492 y todo baja hasta 492)
        return d <= 492 if d > 0 else -d <= 492

    cambio = True
    while cambio:
        cambio = False
        for k, tr in enumerate(tramos):
            if tr[1] - tr[0] >= 60 or len(tramos) < 3 or k == 0 or k == len(tramos) - 1:
                continue
            izq, der = tramos[k - 1], tramos[k + 1]
            for v in sorted((izq, der), key=lambda q: -q[2]):
                otro = der if v is izq else izq
                d = (v[2] - otro[2]) if v is der else (otro[2] - v[2])
                if vale(d):
                    if v is izq:
                        izq[1] = tr[1]
                    else:
                        der[0] = tr[0]
                    del tramos[k]
                    cambio = True
                    break
            if cambio:
                break
    return tramos


def comprobar(tramos, techos):
    """Avisa de lo que el peregrino no puede subir o bajar: escalon <= 52 se
    anda; saltando sube hasta 175; trepa de 110 a 492 (las dos trepas, con el
    margen de acciones_egipto.gd); baja hasta 492. Y de los tramos tan estrechos
    que no se puede estar encima (menos de 30 px)."""
    malos = []
    for a, b in zip(tramos, tramos[1:]):
        d = b[2] - a[2]
        if d > 492:
            malos.append("x %.0f: sube %.0f (no se trepa)" % (b[0], d))
        elif -d > 492:
            malos.append("x %.0f: baja %.0f (no se baja)" % (b[0], -d))
    for t in tramos[1:-1]:
        if t[1] - t[0] < 30:
            malos.append("x %.0f: tramo de %.0f px" % (t[0], t[1] - t[0]))
    for m in malos:
        print("  AVISO", m)
    return malos


def objetos():
    os.makedirs(OBJ, exist_ok=True)
    tam = {}
    for n, o in OBJETOS.items():
        im = escalar(recorte(o["f"], o["rec"]))
        guardar(os.path.join(OBJ, n + ".png"), im)
        tam[n] = (im.shape[1], im.shape[0])
    return tam


def paso_bajo(techo):
    """El paso bajo, recompuesto: una seccion de muro de r18 (con su cornisa) de
    viga, sobre dos pilares de r21 cortados a la altura libre."""
    x0, x1, libre = techo["x0"], techo["x1"], techo["libre"]
    y_suelo = -techo.get("suelo_h", 0.0) - PLANTA
    viga = escalar(recorte(18, (1180, 1900, 1018, 1190)))
    vw, vh = viga.shape[1], viga.shape[0]
    # que cubra el paso y apoye en los pilares
    largo = int(x1 - x0 + 160)
    if vw < largo:
        viga = cv2.resize(viga, (largo, vh), interpolation=cv2.INTER_AREA)
    guardar(os.path.join(TEX, "viga_paso.png"), viga)
    pilar = escalar(recorte(20, (207, 445, 953, 1390)))
    # cortado a la altura libre (desde abajo)
    ph = int(libre + PLANTA)
    pilar = pilar[max(0, pilar.shape[0] - ph):]
    guardar(os.path.join(TEX, "pilar_paso.png"), pilar)
    pw = pilar.shape[1]
    poner("pilar_paso", x0 - pw + 30, y_suelo - pilar.shape[0] + 6, z=-9)
    poner("pilar_paso", x1 - 30, y_suelo - pilar.shape[0] + 6, z=-9, flip=True)
    poner("viga_paso", x0 - 80, y_suelo - libre - vh + 4, z=-8)
    # lo de dentro del paso: la sombra bajo el puente de r19 (verdes oscuros)
    dentro = original(19, (600, 890, 1340, 1560))
    dentro = cv2.resize(dentro, (int(x1 - x0 + 40), int(libre + 10)), interpolation=cv2.INTER_AREA)
    dentro[..., :3] = (dentro[..., :3] * 0.42).astype(np.uint8)
    dentro = fundir_bordes(dentro, (True, True, True, False), 50)
    guardar(os.path.join(TEX, "dentro_paso.png"), dentro)
    poner("dentro_paso", x0 - 20, y_suelo - libre - 6, z=-11)


def hueco(nombre, x0, x1, fondo_h):
    """El fondo de una zanja: un murete de piedra (un trozo de muro de r18 con su
    cornisa) a la altura del fondo; por encima se ve el Nilo del fondo."""
    w = int(x1 - x0) + 40
    murete = escalar(recorte(18, (1213, 1747, 1000, 1632)))
    while murete.shape[1] < w:
        murete = np.hstack([murete, murete[:, ::-1]])
    murete = con_pie(murete[:, :w], FONDO_DEBAJO)
    murete[..., :3] = (murete[..., :3] * 0.72).astype(np.uint8)      # en sombra, entre los dos muros
    murete = fundir_bordes(murete, (True, True, False, False), 20)
    guardar(os.path.join(TEX, "hueco_%s.png" % nombre), murete)
    poner("hueco_%s" % nombre, x0 - 20, -fondo_h - (1035 - 1000) * ESCALA - PLANTA, z=-12)


def vista(ruta, tramos, techos, x_fin, bloques):
    """El montaje entero a 1/8 con lo que se pisa en rojo."""
    e = 1 / 8.0
    W = int(x_fin * e) + 20
    y_min, y_max = -1800, 700
    H = int((y_max - y_min) * e)
    can = np.full((H, W, 3), (205, 190, 170), np.uint8)
    for s in sprites:
        im = cv2.imdecode(np.fromfile(os.path.join(TEX, os.path.basename(s["tex"])), np.uint8), cv2.IMREAD_UNCHANGED)
        if s["flip"]:
            im = im[:, ::-1]
        im = cv2.resize(im, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
        x, y = int(s["x"] * e), int((s["y"] - y_min) * e)
        h, w = im.shape[:2]
        x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
        if x1 <= x0 or y1 <= y0:
            continue
        a = im[y0 - y:y1 - y, x0 - x:x1 - x, 3:4] / 255.0
        can[y0:y1, x0:x1] = (im[y0 - y:y1 - y, x0 - x:x1 - x, :3] * a + can[y0:y1, x0:x1] * (1 - a)).astype(np.uint8)
    for t in tramos:
        y = int((-t[2] - y_min) * e)
        cv2.line(can, (int(t[0] * e), y), (int(t[1] * e), y), (0, 0, 255), 1)
    for t in techos:
        y = int((-t["libre"] - y_min) * e)
        cv2.line(can, (int(t["x0"] * e), y), (int(t["x1"] * e), y), (255, 0, 0), 1)
    for b in bloques:
        cv2.rectangle(can, (int(b["x0"] * e), int((-b["alto"] - y_min) * e)),
                      (int((b["x0"] + b["ancho"]) * e), int((0 - y_min) * e)), (0, 255, 255), 1)
    cv2.imencode(".jpg", can, [cv2.IMWRITE_JPEG_QUALITY, 88])[1].tofile(ruta)


MEDIO = os.path.join(AQUI, "_kit", "medio")


def plano_medio(tramos, x_fin, rng):
    """Las palmeras de las imagenes (medio.py) detras del camino, con paralaje:
    el pie, tapado por el primer plano."""
    palmeras = sorted(f for f in os.listdir(MEDIO) if f.startswith("palmera_") and f.endswith(".png"))
    if not palmeras:
        return
    texs = []
    for f in palmeras:
        im = cv2.imdecode(np.fromfile(os.path.join(MEDIO, f), np.uint8), cv2.IMREAD_UNCHANGED)
        im = escalar(im) if im.shape[0] > 500 else im
        n = "medio_" + f[:-4]
        guardar(os.path.join(TEX, n + ".png"), im)
        texs.append((n, im.shape[1], im.shape[0]))

    def alto_en(x):
        for t in tramos:
            if t[0] <= x < t[1]:
                return t[2]
        return 0.0

    x = 300.0
    while x < x_fin - 200:
        n, w, h = texs[int(rng.integers(len(texs)))]
        e = rng.uniform(1.0, 1.45)
        base = -alto_en(x) + rng.uniform(60, 200)
        k = rng.uniform(1.05, 1.2)
        poner(n, x, base + 60, capa="trasera", z=-30, flip=bool(rng.random() < 0.5), escala=e,
              tinte=[k, k, k * 0.96, 1.0], viento=0.2, ancla="base")
        if rng.random() < 0.45:
            n2, w2, h2 = texs[int(rng.integers(len(texs)))]
            poner(n2, x + rng.uniform(140, 320), base + rng.uniform(-30, 60), capa="trasera", z=-31,
                  flip=bool(rng.random() < 0.5), escala=e * rng.uniform(0.7, 0.9),
                  tinte=[k * 0.85, k * 0.85, k * 0.82, 1.0], viento=0.2, ancla="base")
        x += rng.uniform(650, 1350)


def primer_termino(x_fin, rng, tramos):
    """Vegetacion oscura que pasa por delante, abajo: las plantas (solo lo
    verde) del pie de las franjas 17, 18 y 20, mas grandes y en sombra, con
    paralaje."""
    fuentes = [(17, (0, 2912, 1330, 1632)), (18, (0, 2912, 1250, 1632)), (20, (0, 2912, 1330, 1632))]
    texs = []
    for k, (f, rec) in enumerate(fuentes):
        im = recorte(f, rec)
        # solo lo que es planta (no la piedra del pie del muro)
        hsv = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2HSV)
        planta = (hsv[..., 0] >= 30) & (hsv[..., 0] <= 100) & (hsv[..., 1] > 40) & (hsv[..., 2] > 25)
        planta = cv2.morphologyEx(planta.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        # sin hojitas sueltas: solo las matas grandes
        n_, lab, st, _ = cv2.connectedComponentsWithStats(planta, 8)
        grandes = np.zeros_like(planta)
        for k_ in range(1, n_):
            if st[k_, cv2.CC_STAT_AREA] > 1500:
                grandes[lab == k_] = 1
        planta = grandes > 0
        a = im[..., 3].astype(np.float32)
        a[~planta] = 0
        a = cv2.GaussianBlur(a, (0, 0), 1.0)
        # y que se funda hacia abajo con lo de debajo (se alarga en sombra)
        im[..., 3] = np.clip(a, 0, 255).astype(np.uint8)
        im = escalar(im)
        n = "frente_%d" % k
        guardar(os.path.join(TEX, n + ".png"), im)
        texs.append((n, im.shape[1], im.shape[0]))
    def alto_en(x):
        for t in tramos:
            if t[0] <= x < t[1]:
                return t[2]
        return tramos[-1][2] if x >= tramos[-1][1] else tramos[0][2]

    x = 2100.0                  # (en la explanada de la llegada, nada: se ve la arena)
    while x < x_fin + 600:
        n, w, h = texs[int(rng.integers(len(texs)))]
        e = rng.uniform(1.5, 1.9)
        k = rng.uniform(0.22, 0.32)
        # sigue el terreno (lo mas bajo de alrededor): siempre tapa el pie de lo que hay
        suelo = min(alto_en(x + d) for d in (-300, 0, 300, 600))
        # la copa, siempre por debajo de lo que se pisa
        poner(n, x, -suelo + h * e + rng.uniform(40, 130), capa="frente", z=30, flip=bool(rng.random() < 0.5), escala=e,
              tinte=[k, k * 1.08, k * 0.95, 1.0], ancla="base")
        x += w * e * rng.uniform(0.55, 0.8)


PASO = [0.0, 0.0]


def camara(zonas):
    """Los encuadres por tramo: [x, zoom, alto del encuadre sobre los pies]."""
    z = zonas
    c = [
        [0, 0.86, 260],                                    # la llegada: algo abierto
        [900, 0.98, 200],
        [z["zanja"][0] - 300, 0.94, 200],
        [z["muro_largo"][0] + 400, 0.9, 200],              # correr: algo mas abierto
        [PASO[0] - 400, 0.98, 190],
        [PASO[0] + 60, 1.1, 150],                          # el paso bajo: cerrado
        [PASO[1] - 60, 1.1, 150],
        [PASO[1] + 400, 0.96, 200],
        [z["escaleras"][0] + 300, 1.0, 210],
        [z["bloques"][0] + 300, 1.0, 240],                 # los bloques que suben
        [z["bloques"][1] - 100, 0.96, 240],
        [z["patio_0"][0] - 200, 0.98, 240],                # el patio
        [z["patio_1"][1] - 100, 0.88, 320],                # la estructura alta: hay que ver arriba
        [z["estructura_alta"][0] + 250, 0.78, 300],        # el mirador
        [z["ruinas"][0] + 300, 0.96, 220],
        [z["foso"][0] - 200, 0.9, 200],
        [z["final"][0] + 300, 0.96, 220],
        [z["final"][1] - 700, 0.8, 340],                   # la losa
    ]
    return c


def main():
    alto, techos, zonas, x_fin = montar()
    tam = objetos()
    tramos = suavizar(alto, x_fin)
    comprobar(tramos, techos)
    for t in techos:
        paso_bajo(t)
        PASO[0], PASO[1] = t["x0"], t["x1"]
    for n in ("zanja", "foso"):
        z = zonas[n]
        p = [q for q in PIEZAS if q["nombre"] == n][0]
        hueco(n, z[0], z[1], p["fondo_h"])
    # el patio: el sillar alto (argolla) encajado contra la pared de la izquierda
    wa, ha = tam["sillar_argolla"]
    L = zonas["patio_0"][0]
    cara_alta = zonas["estructura_alta"][0]
    print("  patio: pared %.0f, estructura %.0f (falta %.1f, ideal 813.5)" % (L, cara_alta, cara_alta - L))
    bloques = [
        {"nombre": "sillar_argolla", "x0": L + 0.5, "ancho": float(wa), "alto": float(ha),
         "empuje": "empujar_v2", "accion": "tirar", "trepable": True},
    ]
    # la losa: provisional (no hay cantera en las referencias): el pilar alto de r21
    losa_im = escalar(recorte(21, (720, 960, 470, 1432)))
    guardar(os.path.join(OBJ, "losa.png"), losa_im)
    z_fin = zonas["final"]
    terreno = []
    for k, t in enumerate(tramos):
        if t[0] >= z_fin[1] - 200:
            break
        terreno.append({"x0": t[0], "x1": t[1], "h": round(t[2], 1), "nombre": "t%03d" % k})
    losa_x = z_fin[1] - 420.0
    # la losa sobre lo que haya alli
    h_losa = max(t["h"] for t in terreno if t["x0"] <= losa_x <= t["x1"]) if terreno else 0
    terreno = [t for t in terreno if t["x0"] < losa_x]
    if terreno:
        terreno[-1]["x1"] = losa_x + losa_im.shape[1]
    datos = {
        "suelo": 0.0,
        "limites": [200.0, losa_x - 160.0],
        "terreno": terreno,
        "techos": techos,
        "bloques": bloques,
        "losa": {"x0": losa_x, "ancho": float(losa_im.shape[1]), "alto": float(losa_im.shape[0]), "base": h_losa},
        "marcas": {"inicio": 260.0, "contemplar": 1100.0,
                   "mirador": zonas["estructura_alta"][0] + 250.0, "cantera": zonas["final"][0]},
        "zonas": {k: [round(v[0], 1), round(v[1], 1)] for k, v in zonas.items()},
        "camara": camara(zonas),
    }
    rng = np.random.default_rng(1981)
    plano_medio(tramos, x_fin, rng)
    primer_termino(x_fin, rng, tramos)
    json.dump(datos, open(os.path.join(DESTINO, "nivel.json"), "w", encoding="utf-8"), indent=1)
    json.dump({"paralaje": {"trasera": 0.93, "detras": 1.0, "delante": 1.0, "frente": 1.18}, "sprites": sprites},
              open(os.path.join(DESTINO, "arte.json"), "w", encoding="utf-8"), indent=0)
    print("largo %.0f, tramos %d, sprites %d" % (x_fin, len(terreno), len(sprites)))
    for k, v in zonas.items():
        print("  %-16s %7.0f %7.0f" % (k, v[0], v[1]))
    if "--vista" in sys.argv:
        vista(sys.argv[sys.argv.index("--vista") + 1], tramos, techos, x_fin, bloques)


if __name__ == "__main__":
    main()
