"""EL TEMPLO DEL CORTEJO (2026-10-29): el templo de los videos del usuario
(procesion con el sarcofago, el barco que atraca y se va remando) en la orilla
de enfrente, en lugar del templo de la torre de la tira del medio.

  raw/master_builder/referencias/egipto_templo_video/
      secuencia.mp4  los tres videos unidos (sin la piedra del muelle)
      primero.png    su primer fotograma, sin comprimir
      ultimo.png     el ultimo (el templo sin barco y sin gente)
      cantos_original.wav  el audio del primer video (los canticos del cortejo)
      barco.png      el barco suelto (--recortar-barco, una vez), con barco.json

El video va sobre croma y se recorta en el juego (templo_rio.gdshader), el
fotograma quieto igual que el video; se corta en la linea del agua del video y
el reflejo lo pone el juego, del mismo dibujo, como los de la orilla.

Escribe assets/egipto/acto1/templo/ (primero.png, ultimo.png, secuencia.ogv,
cantos.ogg y templo.json) y quita el templo viejo de la orilla (medio_orilla_0.png: la piedra
que asomaria, y su reflejo). Se pasa despues de capas.py (que lo llama).
EL BARCO (2026-10-29): en el video sale por el borde derecho y se corta. Desde
el fotograma RELEVO sigue un barco suelto (TemploRio, la textura barco.png) que
va rio abajo, y el video a partir de ahi lo lleva borrado: a la derecha de la
gente, el templo vacio (su ultimo fotograma), encajado en cada fotograma.

Uso: python tools/egipto/templo_rio.py [--vista carpeta] [--cantos (solo los canticos)]
     [--recortar-barco (rembg: el barco del video a raw, una vez)]
"""
import json
import os
import subprocess
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ORIGEN = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_templo_video")
CAPAS = os.path.join(PROYECTO, "assets", "egipto", "acto1", "capas")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "templo")
RES = "res://assets/egipto/acto1/templo/"
FFMPEG = os.path.join(os.path.dirname(os.path.dirname(PROYECTO)), "tools", "ffmpeg", "bin", "ffmpeg.exe")

# ---- el video (px del video, 1280x720)
CORTE = 634          # la linea del agua del muelle (lo de debajo es su agua: fuera)
ARRIBA = 58          # por encima de lo mas alto del pilono (y 72); 576 filas, multiplo de 16 (Theora)
# el video en el juego: entero (1280 de ancho). A 0,5 (640) se veia blando junto a
# la orilla al agrandarlo (el usuario: "resolucion entera y unos 1,4")
REDUCE = 1.0
# las medidas hechas a mano a 640 de ancho (los shaders: reflejo, suavizado,
# espuma) van en px de la textura por este factor (templo.json "px")
PX = REDUCE / 0.5
# calidad del Theora (0-10): a 9 el video entero pasaba de 100 MB (el limite de
# GitHub por archivo)
CALIDAD = 8
X_PILONO = 780       # el centro del pilono alto
# ---- en la orilla de enfrente (px de la tira cosida, medio_orilla_0.png)
PALMERAS = 0.52      # px de la orilla por px del video con las palmeras del video como las de la orilla
# MAS GRANDE (2026-10-29, el usuario: "se ve muy poquito el detalle de los hombres
# funebres"): probado en el juego a 1,4 y a 1,7, desde el centro de su base; a 1,7
# sus palmeras tapan media nave de detras; en el juego, a 1,7 se notaban demasiado
# los defectos: 1,4.
AGRANDAR = 1.4
ESCALA = PALMERAS * AGRANDAR
X_TORRE = 975        # el centro de la torre del templo viejo: ahi va el pilono
Y_AGUA = 840         # la linea del agua de la orilla junto a la torre
# lo que se quita del templo viejo, donde el nuevo no lo tapa: la torre (remate,
# capitel y cuerpo) y la casa de su derecha, a mano (por el color no: la piedra
# en sombra y el remate gris se quedaban)
VIEJO = [
    [(966, 465), (1024, 465), (1024, 532), (1042, 532), (1042, 600), (1046, 600), (1046, 845),
     (900, 845), (900, 595), (944, 595), (944, 532), (966, 532)],
    [(1036, 695), (1155, 695), (1155, 845), (1036, 845)],
]
ZONA = (880, 1170, 440, Y_AGUA + 4)  # x0, x1, y0, y1 (donde se mide la piedra vieja)
# y su reflejo: el agua de debajo, con la de su izquierda
AGUA = (885, 1165, Y_AGUA + 2, 1290)
FUNDIDO = 24
# cuanto del color de la orilla se le da (1 = todo: quedaba gris y apagado junto
# a la piedra al sol de la orilla; 0 = el del video: naranja, un pegote)
FUERZA = 0.6
# el velo de la calima (templo_rio.gdshader): las sombras del templo iban mucho
# mas oscuras que las de la orilla pintada (L del 5 %: 22 frente a 32) y con el
# doble de contraste; mezclado un poco hacia el aire de lejos caen donde las de
# la orilla. Medido en el juego, 2026-10-29 (una curva por canal lo ponia rosado)
VELO_COLOR = [172, 194, 186]
VELO = 0.18
# y un pelin mas naranja y oscura la piedra al sol (el usuario: "demasiado
# amarillo"; medido: tono 82-87 grados frente a 73-77 de la orilla), por canal
# sobre el grado
CALOR = [0.985, 0.935, 0.94]
# LOS TRES VIDEOS (procesion, barco que atraca, barco que se va) tienen cada uno
# su color: la piedra del templo a 72, 76 y 80 grados de tono y cada vez menos
# saturada; saltaba en los empalmes y el templo del final quedaba amarillo y
# apagado. Los dos ultimos, con la luz y el color del primero (en Lab, medido en
# la piedra del templo); el grado se mide en el primero.
TRAMOS = [(0, 200), (200, 440), (440, 680)]
PIEDRA = [(700, 860, 90, 300), (430, 560, 250, 330)]   # px del video: pilono y fachada


def leer(ruta, flags=cv2.IMREAD_COLOR):
    return cv2.imdecode(np.fromfile(ruta, np.uint8), flags)


def guardar(ruta, img):
    cv2.imencode(".png", img)[1].tofile(ruta)


def alfa(bgr):
    """Lo que no es croma (lo mismo que templo_rio.gdshader)."""
    f = bgr.astype(np.float32)
    verde = f[..., 1] - np.maximum(f[..., 2], f[..., 0])
    return 1.0 - np.clip((verde - 25.0) / 70.0, 0, 1)


def a_orilla(img_video, forma):
    """Lo del video (recortado de ARRIBA a CORTE) llevado a px de la orilla."""
    e = ESCALA
    # (el pilono en la torre vieja a su tamano de palmeras, y agrandado desde el
    # centro del video)
    x0 = X_TORRE - X_PILONO * PALMERAS - 640 * (e - PALMERAS)
    y0 = Y_AGUA - (CORTE - ARRIBA) * e
    M = np.float32([[e, 0, x0], [0, e, y0]])
    return cv2.warpAffine(img_video, M, (forma[1], forma[0]), flags=cv2.INTER_AREA), (x0, y0)


def piedra(bgr):
    """La piedra arenisca (ni hojas, ni cielo, ni agua), tambien la apagada."""
    f = bgr.astype(np.float32)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    return (r >= b + 8) & (r >= g - 4) & (r + g + b > 300)


def lab(bgr):
    return cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB).reshape(-1, 3).astype(np.float32)


def grado(video, orilla):
    """La piedra del video con la luz y el color de la de la orilla (media y
    contraste en Lab, de la franja de casas sobre el agua, sin el templo viejo),
    llevado a una matriz de color RGB (3x4) ajustada sobre todo lo del video.
    (Por canal en RGB no apagaba el color: quedaba mas naranja que la orilla.)"""
    a = alfa(video) > 0.9
    mv = a & piedra(video)
    banda = orilla[Y_AGUA - 320:Y_AGUA - 5, 300:1900]
    mo = (banda[..., 3] > 240) & piedra(banda[..., :3])
    xs = np.arange(300, 1900)
    mo[:, (xs >= ZONA[0] - 40) & (xs < ZONA[1] + 40)] = False
    lv, lo = lab(video[mv][None]), lab(banda[..., :3][mo][None])
    mul = lo.std(0) / lv.std(0)
    add = lo.mean(0) - lv.mean(0) * mul
    todo = video[a][None]
    destino = np.clip(lab(todo) * mul + add, 0, 255).astype(np.uint8)
    destino = cv2.cvtColor(destino[None], cv2.COLOR_LAB2BGR)[0].astype(np.float32) / 255.0
    origen = todo[0].astype(np.float32) / 255.0
    X = np.c_[origen[:, ::-1], np.ones(len(origen))]
    A = np.linalg.lstsq(X, destino[:, ::-1], rcond=None)[0].T
    A = np.c_[np.eye(3), np.zeros(3)] * (1 - FUERZA) + A * FUERZA
    # (RGB; filas = canal de salida, la ultima columna lo que se suma)
    A = A * np.array(CALOR)[:, None]
    return np.round(A, 4).tolist()


def quitar_viejo(orilla, nuevo_alfa):
    """El templo viejo fuera donde el nuevo no lo tapa, y su reflejo."""
    viejo = np.zeros(orilla.shape[:2], np.uint8)
    cv2.fillPoly(viejo, [np.int32(p) for p in VIEJO], 1)
    asoma = (viejo > 0) & (nuevo_alfa < 0.6)
    orilla[..., 3] = np.where(asoma, 0, orilla[..., 3])
    # el agua: la de la izquierda, fundida por los lados
    x0, x1, y0, y1 = AGUA
    w = x1 - x0
    fuente = orilla[y0:y1, x0 - w:x0].astype(np.float32)
    destino = orilla[y0:y1, x0:x1].astype(np.float32)
    k = np.minimum(np.arange(w), np.arange(w)[::-1]) / float(FUNDIDO)
    k = np.clip(k, 0, 1)[None, :, None]
    orilla[y0:y1, x0:x1] = (fuente * k + destino * (1 - k)).astype(np.uint8)


def _lab(bgr):
    return cv2.cvtColor(bgr.astype(np.float32) / 255.0, cv2.COLOR_BGR2LAB)


def medir_tramos():
    """Por tramo, media y desviacion en Lab de la piedra al sol del templo."""
    cap = cv2.VideoCapture(os.path.join(ORIGEN, "secuencia.mp4"))
    muestras = [[] for _ in TRAMOS]
    k = 0
    while True:
        ok, f = cap.read()
        if not ok:
            break
        if k % 10 == 0:
            i = next(j for j, (a, b) in enumerate(TRAMOS) if a <= k < b)
            lab = _lab(f)
            for x0, x1, y0, y1 in PIEDRA:
                z = lab[y0:y1, x0:x1].reshape(-1, 3)
                muestras[i].append(z[(z[:, 2] > 8) & (z[:, 0] > 40)])
        k += 1
    est = [np.vstack(m) for m in muestras]
    ref = est[0]
    # (mul, add) por tramo: el tramo con la media y el contraste del primero
    return [(ref.std(0) / e.std(0), ref.mean(0) - e.mean(0) * ref.std(0) / e.std(0)) for e in est]


def igualar(bgr, k, tramos):
    """El fotograma k con el color del primer video."""
    i = next(j for j, (a, b) in enumerate(TRAMOS) if a <= k < b)
    if i == 0:
        return bgr
    mul, add = tramos[i]
    lab = _lab(bgr) * mul + add
    return np.clip(cv2.cvtColor(lab, cv2.COLOR_LAB2BGR) * 255.0 + 0.5, 0, 255).astype(np.uint8)


def recortar(bgr):
    r = bgr[ARRIBA:CORTE]
    return cv2.resize(r, None, fx=REDUCE, fy=REDUCE, interpolation=cv2.INTER_AREA)


# ---- el barco (px del video)
RELEVO = 556         # el ultimo fotograma del video con el barco: luego, el suelto
PROA = 548           # (en el 556 la punta de la proa ya se sale del video: la de aqui)
# el video lleva su barco unos fotogramas mas, debajo del suelto (que ya esta
# encima): con el video entero, en el juego el barco desaparecia un instante en el
# relevo (el fotograma que se ve va un poco por delante de stream_position)
SOLAPE = 3
# el barco suelto, un poco mas metido en el agua (el usuario: "para que lo que se
# vea por debajo sea mas uniforme"): px del video que se hunde, poco a poco tras
# el relevo (TemploRio)
HUNDIR = 8
HUECO_MAX = 60       # px del hueco mas grande que se rellena en el remero de atras
RECORTE = (760, 380, 1280, 650)    # x0, y0, x1, y1 donde se busca el barco
POR_FOTOGRAMA = 4.87 # px que avanza (seguido con subpixel del 526 al 556; luego el video da un salto)
BANDA = (790, 395)   # desde aqui (x, y) el video lleva el barco borrado (la gente, a la izquierda)
FUNDIDO_BANDA = 16
CANVAS_BARCO = (760, 380, 1320, 650)  # el barco suelto: px del video (la proa pasa del borde)
# EL REMO (2026-10-29, el usuario: "tener el barco remando para que se mueva y no
# solo desplazarse"): los fotogramas REMO..RELEVO del video, con el barco quieto
# (seguido con subpixel) y recortado; en el juego, adelante y atras (un golpe de
# remo: en el video no llega a repetirse). Lo rigido (casco, sarcofago, vela y el
# remero de delante, que apenas se mueve) con la silueta del barco.png (BiRefNet);
# el remero de atras y su remo, por diferencia con el templo vacio encajado.
REMO = 526
ZONAS_REMO = [(840, 1000, 466, 600), (850, 916, 600, 628)]  # px del video en el RELEVO
# LA ESPUMA (2026-10-29, el usuario: "que se vea un poco mas como se levanta
# agua ... me da igual si lo sacas del video o no"): la del video es tan tenue
# que recortada no se veia; la pinta el juego (barco_espuma.gdshader). Aqui solo
# donde: la popa (donde empieza el casco), la proa y donde el remo entra en el
# agua (px del video en el RELEVO), y en que fotogramas del remo salpica.
ESPUMA_X = {"popa": 905, "proa": 1272, "remo": 895}
SALPICA = (546, 556)
# LOS RETOQUES A MANO (el usuario, en GIMP): barco_retoque/NN.png, a tamano del
# video, con transparencia. Lo que se borre o se pinte ahi se queda aunque esto se
# vuelva a pasar (se compara con _auto/, lo que salio sin tocar). Lo que se cambie
# en el ultimo (el del relevo) fuera del remero de atras vale para todos.
RETOQUE = os.path.join(ORIGEN, "barco_retoque")
PROA_DESDE = 1262    # x del video desde donde manda la proa del PROA


def recortar_barco():
    """El barco del RELEVO sin fondo (BiRefNet), con la punta de la proa del
    PROA corrida lo que ha avanzado. A raw (barco.png + barco.json)."""
    from PIL import Image
    from rembg import new_session, remove
    sesion = new_session("birefnet-general")
    cap = cv2.VideoCapture(os.path.join(ORIGEN, "secuencia.mp4"))
    fot = {}
    k = 0
    while k <= RELEVO:
        ok, f = cap.read()
        if not ok:
            break
        if k in (RELEVO, PROA):
            fot[k] = f
        k += 1
    x0, y0, x1, y1 = RECORTE
    sin = {}
    for k, f in fot.items():
        img = Image.fromarray(cv2.cvtColor(f[y0:y1, x0:x1], cv2.COLOR_BGR2RGB))
        sin[k] = cv2.cvtColor(np.array(remove(img, session=sesion)), cv2.COLOR_RGBA2BGRA)
    cx0, cy0, cx1, cy1 = CANVAS_BARCO
    lienzo = np.zeros((cy1 - cy0, cx1 - cx0, 4), np.uint8)
    lienzo[y0 - cy0:y1 - cy0, x0 - cx0:x1 - cx0] = sin[RELEVO]
    # la proa: la del PROA, corrida lo que avanza (y 1 px abajo, medido)
    dx = int(round(POR_FOTOGRAMA * (RELEVO - PROA)))
    proa = np.zeros_like(lienzo)
    proa[y0 - cy0 + 1:y1 - cy0, x0 - cx0 + dx:x1 - cx0 + dx] = sin[PROA][:y1 - y0 - 1]
    xs = np.arange(lienzo.shape[1]) + cx0
    k = np.clip((xs - PROA_DESDE) / 8.0, 0, 1)[None, :, None]
    lienzo = (lienzo * (1 - k) + proa * k).astype(np.uint8)
    guardar(os.path.join(ORIGEN, "barco.png"), lienzo)
    json.dump({"x": cx0, "y": cy0, "fotograma": RELEVO}, open(os.path.join(ORIGEN, "barco.json"), "w"), indent=1)


# LA PALA (2026-10-29, el usuario: "recompon la pala en los 30 y dejala bien"):
# la diferencia con el templo vacio la sacaba mellada (donde la madera se parece a
# la piedra de detras) y con agua y postes pegados. Se rehace con forma: el eje del
# remo, buscado en cada fotograma como una cresta (distinto a los dos lados),
# empezando por el del ultimo; la cana, una banda fina a lo largo; la pala, lo que
# hay alrededor del eje abajo, cerrado. Los px son los del video (el remo esta
# ahi: solo fallaba la mascara). A la izquierda de la popa no queda nada mas.
REMO_Y = (175.0, 225.0)          # el eje: su x a estas dos alturas (px del lienzo)
REMO_EJE = (202.8, 136.7)        # en el ultimo
REMO_CANA = 1.9                  # media anchura de la cana
REMO_PALA = 7                    # media anchura de la banda de la pala
REMO_LIBRE = 145                 # a la izquierda de la popa (x del lienzo)
REMO_CANA_DESDE = 185            # la cana se repasa por debajo de las manos


def ejes_remo(lienzos):
    """El eje del remo en cada lienzo, del ultimo hacia atras: (x en REMO_Y[0],
    x en REMO_Y[1])."""
    y1, y2 = REMO_Y
    im = [cv2.GaussianBlur(l[..., :3].astype(np.float32), (0, 0), 0.7) for l in lienzos]

    def toma(m, x, y):
        return cv2.remap(m, x.astype(np.float32), y.astype(np.float32), cv2.INTER_LINEAR)

    def cresta(m, a, b):
        ys = np.linspace(178, 215, 60)[None, :]
        xs = a + (b - a) * (ys - y1) / (y2 - y1)
        d = np.array([b - a, y2 - y1]) / np.hypot(b - a, y2 - y1)
        c = toma(m, xs, ys)
        lados = [toma(m, xs + sg * d[1] * 3.5, ys - sg * d[0] * 3.5) for sg in (1, -1)]
        return np.minimum(*[np.abs(c - l).sum(-1) for l in lados]).mean()
    ejes = [None] * len(lienzos)
    a, b = REMO_EJE
    pasos = np.arange(-4, 4.01, 0.5)
    for i in range(len(lienzos) - 1, -1, -1):
        _, a, b = max((cresta(im[i], a + da, b + db), a + da, b + db) for da in pasos for db in pasos)
        ejes[i] = (a, b)
    return ejes


def rehacer_remo(lienzo, alfa, eje):
    """La alfa con el remo rehecho sobre su eje."""
    alto, ancho = alfa.shape
    y1, y2 = REMO_Y
    a, b = eje
    yy, xx = np.mgrid[0:alto, 0:ancho].astype(np.float32)
    d = np.array([b - a, y2 - y1]) / np.hypot(b - a, y2 - y1)
    # distancia al eje
    dist = np.abs((xx - a) * d[1] - (yy - y1) * d[0])
    cana = np.clip(REMO_CANA + 0.5 - dist, 0, 1)
    cana[yy < REMO_CANA_DESDE] = 0
    # la pala: lo que habia cerca del eje, abajo, cerrado y sin huecos
    banda = (dist <= REMO_PALA) & (yy >= 205)
    pala = ((alfa > 128) & banda).astype(np.uint8)
    pala = cv2.morphologyEx(pala, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    lleno = pala.copy()
    cv2.floodFill(lleno, np.zeros((alto + 2, ancho + 2), np.uint8), (0, 0), 1)
    pala = (pala | (lleno == 0)) & banda
    # (solo lo que toca el eje)
    n, lab = cv2.connectedComponents(pala.astype(np.uint8))
    toca = set(np.unique(lab[(dist < 1.0) & (pala > 0)])) - {0}
    pala = np.isin(lab, list(toca)).astype(np.float32)
    pala = cv2.GaussianBlur(pala, (0, 0), 0.6)
    remo = np.maximum(cana, pala)
    nueva = np.maximum(alfa.astype(np.float32), remo * 255)
    libre = xx < REMO_LIBRE
    nueva[libre] = remo[libre] * 255
    return nueva.astype(np.uint8)


def seguir_retoque():
    """Lo que el usuario borro a mano en el ultimo (el del RELEVO), llevado a los
    demas en barco_retoque/: lo quieto, en el mismo sitio; lo del remero de atras
    y su remo, siguiendolo hacia atras fotograma a fotograma (flujo optico sobre
    el lienzo entero de _auto/). Solo quita: lo que el usuario ya borro en cada
    uno se queda. (--seguir-retoque; despues, pasar main otra vez)"""
    d = json.load(open(os.path.join(ORIGEN, "barco.json"), encoding="utf-8"))
    ox, oy = d["x"], d["y"]
    n = RELEVO - REMO + 1
    auto = [leer(os.path.join(RETOQUE, "_auto", "%02d.png" % i), cv2.IMREAD_UNCHANGED) for i in range(n)]
    ultimo = leer(os.path.join(RETOQUE, "%02d.png" % (n - 1)), cv2.IMREAD_UNCHANGED)
    alto, ancho = ultimo.shape[:2]
    movil = np.zeros((alto, ancho), np.float32)
    for x0, x1, y0, y1 in ZONAS_REMO:
        movil[max(0, y0 - oy):y1 - oy, x0 - ox:x1 - ox] = 1
    movil = cv2.dilate(movil, np.ones((15, 15), np.uint8))
    quita = np.clip((auto[-1][..., 3].astype(np.float32) - ultimo[..., 3]) / 255.0, 0, 1)
    quieto = quita * (1 - movil)
    sigue = quita * movil
    ejes = ejes_remo(auto)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    gris = [cv2.cvtColor(a[..., :3], cv2.COLOR_BGR2GRAY) for a in auto]
    yy, xx = np.mgrid[0:alto, 0:ancho].astype(np.float32)
    alfas = [None] * (n - 1) + [ultimo[..., 3]]
    for i in range(n - 2, -1, -1):
        fl = dis.calc(gris[i], gris[i + 1], None)
        fv = dis.calc(gris[i + 1], gris[i], None)
        mx, my = xx + fl[..., 0], yy + fl[..., 1]
        sigue = cv2.remap(sigue, mx, my, cv2.INTER_LINEAR)
        # solo donde el flujo es de fiar: ida y vuelta al mismo sitio y el mismo
        # color (el remo, fino y rapido, se llevaba los borrados del fondo)
        vuelta = cv2.remap(fv, mx, my, cv2.INTER_LINEAR) + fl
        sig = cv2.remap(auto[i + 1][..., :3].astype(np.float32), mx, my, cv2.INTER_LINEAR)
        color = np.abs(sig - auto[i][..., :3]).max(2)
        sigue *= (np.hypot(vuelta[..., 0], vuelta[..., 1]) < 1.0) & (color < 30)
        # (sin que se emborrone de uno en otro)
        sigue = np.clip((sigue - 0.5) * 2 + 0.5, 0, 1) * movil
        u = leer(os.path.join(RETOQUE, "%02d.png" % i), cv2.IMREAD_UNCHANGED)
        q = np.maximum(quieto, sigue)
        alfas[i] = np.minimum(u[..., 3], (auto[i][..., 3] * (1 - q)).astype(np.uint8))
    # SIN PARPADEO (el usuario: "se ven los pixeles que parpadean ... cosas que
    # estan y no estan"): en el remero, cada px como la mediana de su fotograma y
    # los de al lado (lo que sale en uno solo, fuera; el borde, quieto)
    for i in range(n - 1):
        tres = np.stack([alfas[max(0, i - 1)], alfas[i], alfas[i + 1]])
        quieta = np.median(tres, 0).astype(np.uint8)
        u = leer(os.path.join(RETOQUE, "%02d.png" % i), cv2.IMREAD_UNCHANGED)
        u[..., 3] = np.where(movil > 0, quieta, alfas[i])
        u[..., 3] = rehacer_remo(auto[i], u[..., 3], ejes[i])
        guardar(os.path.join(RETOQUE, "%02d.png" % i), u)
    print("retoque del", n - 1, "llevado a los", n - 1, "de antes")


def sin_barco(f, ult, ult_gris, mascara, peso):
    """El fotograma con la banda del barco del templo vacio, encajado (el video
    se mueve unos px: afin medida fuera de la banda)."""
    g = cv2.GaussianBlur(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 1.5)
    w = np.eye(2, 3, dtype=np.float32)
    try:
        _, w = cv2.findTransformECC(g, ult_gris, w, cv2.MOTION_AFFINE,
                                    (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 80, 1e-5), mascara, 1)
    except cv2.error:
        pass
    placa = cv2.warpAffine(ult, w, (f.shape[1], f.shape[0]), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                           borderMode=cv2.BORDER_REFLECT)
    return (f * (1 - peso) + placa * peso).astype(np.uint8)


def video(destino, ult, tramos):
    # (todo fotogramas clave: con los intermedios de este libtheora, el Theora de
    # Godot 4.6 sacaba bloques de colores en casi todo el video; 31 MB)
    alto = CORTE - ARRIBA
    ancho, alto_r = int(1280 * REDUCE), int(alto * REDUCE)
    ff = subprocess.Popen([FFMPEG, "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24",
                           "-s", "%dx%d" % (ancho, alto_r), "-r", "24", "-i", "-",
                           "-c:v", "libtheora", "-q:v", str(CALIDAD), "-g:v", "1", destino], stdin=subprocess.PIPE)
    ult_gris = cv2.GaussianBlur(cv2.cvtColor(ult, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 1.5)
    bx, by = BANDA
    mascara = np.zeros(ult.shape[:2], np.uint8)
    mascara[230:640, 560:] = 1
    mascara[by - 10:640, bx - 10:] = 0
    yy, xx = np.mgrid[0:ult.shape[0], 0:ult.shape[1]]
    peso = (np.clip((xx - bx) / FUNDIDO_BANDA + 0.5, 0, 1) * np.clip((yy - by) / FUNDIDO_BANDA + 0.5, 0, 1))[..., None]
    cap = cv2.VideoCapture(os.path.join(ORIGEN, "secuencia.mp4"))
    k = 0
    while True:
        ok, f = cap.read()
        if not ok:
            break
        if k > RELEVO + SOLAPE:
            f = sin_barco(f, ult, ult_gris, mascara, peso)
        f = igualar(f, k, tramos)
        ff.stdin.write(np.ascontiguousarray(recortar(f)).tobytes())
        k += 1
    ff.stdin.close()
    if ff.wait():
        raise RuntimeError("ffmpeg")


def seguir_barco(f, plantilla, mascara):
    """Lo que se ha corrido el barco respecto al RELEVO (casco y sarcofago),
    con subpixel."""
    x0, y0 = 880, 585
    zona = f[y0 - 14:y0 + plantilla.shape[0] + 14, 600:1280]
    r = cv2.matchTemplate(zona, plantilla, cv2.TM_SQDIFF, mask=mascara)
    _, _, (lx, ly), _ = cv2.minMaxLoc(r)

    def sub(a, b, c):
        d = a - 2 * b + c
        return 0.0 if d == 0 else 0.5 * (a - c) / d
    sx = sub(r[ly, lx - 1], r[ly, lx], r[ly, lx + 1]) if 0 < lx < r.shape[1] - 1 else 0.0
    sy = sub(r[ly - 1, lx], r[ly, lx], r[ly + 1, lx]) if 0 < ly < r.shape[0] - 1 else 0.0
    return lx + sx + 600 - x0, ly + sy - 14


def barco(carpeta, ult, tramos):
    """El barco suelto para el juego: un PNG por fotograma del remo, a la escala
    del video del juego y cortado en la linea del agua, como el templo. Devuelve
    lo que va en templo.json."""
    b = leer(os.path.join(ORIGEN, "barco.png"), cv2.IMREAD_UNCHANGED)
    d = json.load(open(os.path.join(ORIGEN, "barco.json"), encoding="utf-8"))
    ox, oy = d["x"], d["y"]
    alto, ancho = b.shape[:2]
    base = b[..., 3].astype(np.float32) / 255.0
    movil = np.zeros((alto, ancho), np.float32)
    for x0, x1, y0, y1 in ZONAS_REMO:
        movil[y0 - oy:y1 - oy, x0 - ox:x1 - ox] = 1
    rigido = base * (1 - movil)
    zona_m = cv2.dilate(movil, np.ones((15, 15), np.uint8))
    plantilla = b[585 - oy:634 - oy, 880 - ox:1240 - ox, :3]
    mascara_p = (b[585 - oy:634 - oy, 880 - ox:1240 - ox, 3] > 220).astype(np.uint8)
    ult_gris = cv2.GaussianBlur(cv2.cvtColor(ult, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 1.5)
    os.makedirs(carpeta, exist_ok=True)
    for viejo in os.listdir(carpeta):
        if viejo.endswith(".png"):
            os.remove(os.path.join(carpeta, viejo))
    os.makedirs(os.path.join(RETOQUE, "_auto"), exist_ok=True)

    def retocado(nombre):
        u, a = os.path.join(RETOQUE, nombre), os.path.join(RETOQUE, "_auto", nombre)
        if not (os.path.exists(u) and os.path.exists(a)):
            return None
        ua = leer(u, cv2.IMREAD_UNCHANGED)[..., 3].astype(np.float32)
        aa = leer(a, cv2.IMREAD_UNCHANGED)[..., 3].astype(np.float32)
        return ua, np.abs(ua - aa) > 8
    r_ultimo = retocado("%02d.png" % (RELEVO - REMO))
    para_todos = None
    if r_ultimo is not None:
        para_todos = (r_ultimo[0], r_ultimo[1] & (movil[:CORTE - oy] == 0))

    cap = cv2.VideoCapture(os.path.join(ORIGEN, "secuencia.mp4"))
    k = 0
    rutas = []
    while k <= RELEVO:
        ok, f = cap.read()
        if not ok:
            break
        if k < REMO:
            k += 1
            continue
        dx, dy = seguir_barco(f, plantilla, mascara_p)
        # el templo vacio encajado, fuera del barco y de la gente
        mb = np.zeros(f.shape[:2], np.uint8)
        xa, xb = ox + int(dx), min(f.shape[1], ox + int(dx) + ancho)
        mb[oy:oy + alto, xa:xb] = base[:, :xb - xa] > 0.3
        mb = cv2.dilate(mb, np.ones((41, 41), np.uint8))
        mascara = np.zeros(f.shape[:2], np.uint8)
        mascara[200:650, 780:] = 1
        mascara[mb > 0] = 0
        g = cv2.GaussianBlur(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 1.5)
        w = np.eye(2, 3, dtype=np.float32)
        try:
            _, w = cv2.findTransformECC(g, ult_gris, w, cv2.MOTION_AFFINE,
                                        (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 80, 1e-5), mascara, 1)
        except cv2.error:
            pass
        placa = cv2.warpAffine(ult, w, (f.shape[1], f.shape[0]), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                               borderMode=cv2.BORDER_REFLECT)
        # al lienzo del barco, quieto
        M = np.float32([[1, 0, -dx - ox], [0, 1, -dy - oy]])
        fs = cv2.warpAffine(f, M, (ancho, alto), borderMode=cv2.BORDER_REPLICATE).astype(np.float32)
        ps = cv2.warpAffine(placa, M, (ancho, alto), borderMode=cv2.BORDER_REPLICATE).astype(np.float32)
        dif = np.abs(cv2.GaussianBlur(fs, (0, 0), 0.8) - cv2.GaussianBlur(ps, (0, 0), 0.8)).max(2)
        a = np.clip((dif - 16) / 26, 0, 1)
        # donde detras hay croma, lo que no es verde
        verde_detras = (ps[..., 1] - np.maximum(ps[..., 0], ps[..., 2])) > 40
        ak = 1 - np.clip(((fs[..., 1] - np.maximum(fs[..., 0], fs[..., 2])) - 25) / 70, 0, 1)
        a = np.where(verde_detras, ak, a)
        # (ni hojas de palmera)
        a[(fs[..., 1] > fs[..., 2] - 2) & (fs[..., 1] > fs[..., 0] + 10)] = 0
        a *= zona_m
        # los huecos dentro de la silueta del remero (ropa clara sobre piedra clara)
        sil = cv2.morphologyEx((a > 0.3).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
        lleno = sil.copy()
        cv2.floodFill(lleno, np.zeros((alto + 2, ancho + 2), np.uint8), (0, 0), 1)
        # (solo los pequenos: cuando el remo cruza, la pared que queda encerrada
        # entre el remo, las piernas y la popa se llenaba entera)
        n, lab, st, _ = cv2.connectedComponentsWithStats(((lleno == 0) & (sil == 0)).astype(np.uint8))
        huecos = np.isin(lab, [c for c in range(1, n) if st[c, 4] <= HUECO_MAX])
        a = np.maximum(a, (sil | huecos).astype(np.float32) * zona_m)
        al = np.maximum(rigido, a)
        # solo lo pegado al barco
        n, lab, st, _ = cv2.connectedComponentsWithStats((al > 0.4).astype(np.uint8))
        grande = 1 + np.argmax(st[1:, 4])
        al *= cv2.dilate((lab == grande).astype(np.uint8), np.ones((3, 3), np.uint8))
        # lo rigido, siempre con los px del RELEVO (el barco.png): con los de cada
        # fotograma, el fondo que se ve a traves de la vela (clara) corria por ella
        # y parecia semitransparente
        r = (rigido * (1 - zona_m))[..., None]
        fs = fs * (1 - r) + b[..., :3].astype(np.float32) * r
        rgba = np.dstack([fs, al * 255])
        # lo que cae fuera del video (la proa): la del barco.png
        fuera = (np.arange(ancho) + ox + dx) >= f.shape[1] - 1
        rgba[:, fuera] = b[:, fuera]
        rgba = rgba[:CORTE - oy]
        rgba[..., :3] = igualar(np.clip(rgba[..., :3], 0, 255).astype(np.uint8), k, tramos)
        nombre = "%02d.png" % (k - REMO)
        # los retoques a mano
        auto = np.clip(rgba, 0, 255).astype(np.uint8)
        r_k = retocado(nombre)
        if para_todos is not None:
            rgba[..., 3] = np.where(para_todos[1], para_todos[0], rgba[..., 3])
        if r_k is not None:
            rgba[..., 3] = np.where(r_k[1], r_k[0], rgba[..., 3])
        guardar(os.path.join(RETOQUE, "_auto", nombre), auto)
        if not os.path.exists(os.path.join(RETOQUE, nombre)):
            guardar(os.path.join(RETOQUE, nombre), auto)
        # (premultiplicado al reducir: sin orla oscura)
        rgba[..., :3] *= rgba[..., 3:] / 255.0
        r = cv2.resize(rgba, None, fx=REDUCE, fy=REDUCE, interpolation=cv2.INTER_AREA)
        ar = np.maximum(r[..., 3:] / 255.0, 1e-6)
        r[..., :3] = np.where(r[..., 3:] > 0.5, r[..., :3] / ar, 0)
        guardar(os.path.join(carpeta, nombre), np.clip(r, 0, 255).astype(np.uint8))
        rutas.append(RES + "barco/" + nombre)
        k += 1
    return {
        # (el ultimo es el del RELEVO; en el juego van adelante y atras desde el)
        "fotogramas": rutas,
        "fps": 24,
        # px de la textura del templo (la del video del juego)
        "x": round(ox * REDUCE, 2), "y": round((oy - ARRIBA) * REDUCE, 2),
        "desde": d["fotograma"] / 24.0,
        "velocidad": round(POR_FOTOGRAMA * 24.0 * REDUCE, 2),
        "hundir": round(HUNDIR * REDUCE, 2),
        # px de la textura del barco; "linea": la del agua (su borde de abajo)
        "espuma": {**{c: round((x - ox) * REDUCE, 2) for c, x in ESPUMA_X.items()},
                   "linea": round((CORTE - oy) * REDUCE, 2),
                   "salpica": [SALPICA[0] - REMO, SALPICA[1] - REMO]},
    }


# ---- los canticos (2026-10-29, el usuario: "de fondo, que se escuchen poco
# porque estan lejos, pero que se escuchen hasta que se meten"): el audio del
# primer video (10 s) a la vez que el video, y para llegar al final, otra vez
# desde otro punto con un fundido (s del audio original, s del video)
TROZOS = [(0.0, 0.0), (1.0, 9.0), (2.0, 17.0), (1.5, 24.0)]
TROZO_FIN = 9.8      # s del audio original hasta donde se usa cada vez
CRUCE = 0.8          # s del fundido entre trozos
SE_METEN = (25.5, 27.8)  # s del video: la gente entra al templo (fotogramas ~612-667): se apagan
LEJOS_HZ = 1500      # sin los agudos: lejos (2200 sonaba cerca)
ECO = 0.4            # lo que suena del eco (la orilla de enfrente)
CANTOS_DB = -20.0    # dBFS de media del fichero (el volumen en el juego, aparte)


def cantos(destino):
    import soundfile as sf
    from scipy import signal
    x, sr = sf.read(os.path.join(ORIGEN, "cantos_original.wav"), dtype="float64")
    largo = int(SE_METEN[1] * sr) + sr // 4
    y = np.zeros((largo, x.shape[1]))
    n = int(CRUCE * sr)
    for k, (desde, en) in enumerate(TROZOS):
        t = x[int(desde * sr):int(TROZO_FIN * sr)].copy()
        if k > 0:
            t[:n] *= np.sin(np.linspace(0, np.pi / 2, n))[:, None]
        if k < len(TROZOS) - 1:
            t[-n:] *= np.cos(np.linspace(0, np.pi / 2, n))[:, None]
        i = int(en * sr)
        t = t[:max(0, largo - i)]
        y[i:i + len(t)] += t
    # lejos: casi mono, sin agudos y con algo de eco
    m = y.mean(1, keepdims=True)
    y = m * 0.7 + y * 0.3
    y = signal.sosfilt(signal.butter(2, LEJOS_HZ, fs=sr, output="sos"), y, axis=0)
    rng = np.random.default_rng(7)
    ir = rng.standard_normal(int(0.9 * sr)) * np.exp(-np.arange(int(0.9 * sr)) / (0.22 * sr))
    ir[:int(0.03 * sr)] = 0
    ir /= np.sqrt((ir ** 2).sum())
    eco = signal.fftconvolve(y, ir[:, None], axes=0)[:len(y)]
    y = y * (1 - ECO) + eco * ECO
    # y se apagan cuando se meten
    a, b = int(SE_METEN[0] * sr), int(SE_METEN[1] * sr)
    y[a:b] *= np.cos(np.linspace(0, np.pi / 2, b - a))[:, None] ** 2
    y[b:] = 0
    y *= 10 ** (CANTOS_DB / 20) / np.sqrt((y[sr:a] ** 2).mean())
    y = np.clip(y, -0.98, 0.98)
    tmp = destino + ".tmp.wav"
    sf.write(tmp, y, sr, subtype="PCM_24")
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", destino], check=True)
    os.remove(tmp)


def main():
    if "--cantos" in sys.argv:
        cantos(os.path.join(DESTINO, "cantos.ogg"))
        return
    if "--recortar-barco" in sys.argv:
        recortar_barco()
        return
    if "--seguir-retoque" in sys.argv:
        seguir_retoque()
        return
    vista = sys.argv[sys.argv.index("--vista") + 1] if "--vista" in sys.argv else None
    os.makedirs(DESTINO, exist_ok=True)
    primero = leer(os.path.join(ORIGEN, "primero.png"))
    ultimo = leer(os.path.join(ORIGEN, "ultimo.png"))
    ruta_orilla = os.path.join(CAPAS, "medio_orilla_0.png")
    orilla = leer(ruta_orilla, cv2.IMREAD_UNCHANGED)
    datos_capas = json.load(open(os.path.join(CAPAS, "capas.json"), encoding="utf-8"))
    capa = next(c for c in datos_capas["capas"] if c["nombre"] == "orilla")
    t0 = capa["trozos"][0]
    ec = float(capa.get("escala", datos_capas["escala"]))

    g = grado(primero[ARRIBA:CORTE], orilla)
    print("grado", g)

    # lo que el nuevo tapa siempre (el primero y el ultimo: el barco solo tapa mas)
    a = np.minimum(alfa(primero[ARRIBA:CORTE]), alfa(ultimo[ARRIBA:CORTE]))
    nuevo_alfa, (xi, yi) = a_orilla(a, orilla.shape)
    quitar_viejo(orilla, nuevo_alfa)
    guardar(ruta_orilla, orilla)

    tramos = medir_tramos()
    for i, (mul, add) in enumerate(tramos):
        print("tramo", i, "Lab x", np.round(mul, 3), "+", np.round(add, 3))
    guardar(os.path.join(DESTINO, "primero.png"), recortar(primero))
    guardar(os.path.join(DESTINO, "ultimo.png"), recortar(igualar(ultimo, TRAMOS[-1][1] - 1, tramos)))
    video(os.path.join(DESTINO, "secuencia.ogv"), ultimo, tramos)
    cantos(os.path.join(DESTINO, "cantos.ogg"))
    datos_barco = barco(os.path.join(DESTINO, "barco"), ultimo, tramos)
    # en el juego: px de la orilla -> coordenadas de su capa
    datos = {
        "capa": "orilla",
        "x": round(float(t0["x"]) + xi * ec, 1),
        "y": round(float(t0["y"]) + yi * ec, 1),
        # (unidades del juego por px de la textura)
        "escala": round(ESCALA / REDUCE * ec, 4),
        "px": PX,
        "primero": RES + "primero.png",
        "ultimo": RES + "ultimo.png",
        "video": RES + "secuencia.ogv",
        "cantos": RES + "cantos.ogg",
        "barco": datos_barco,
        "grado": g,
        "velo": {"color": VELO_COLOR, "cuanto": VELO},
    }
    json.dump(datos, open(os.path.join(DESTINO, "templo.json"), "w", encoding="utf-8"), indent=1)
    print("templo en", datos["x"], datos["y"], "escala", datos["escala"])
    if vista:
        # la orilla con el templo nuevo encima (sin el grado), sobre magenta
        o = orilla.astype(np.float32)
        v = o[..., :3] * (o[..., 3:] / 255.0) + np.array([255, 0, 255]) * (1 - o[..., 3:] / 255.0)
        p, _ = a_orilla(primero[ARRIBA:CORTE].astype(np.float32), orilla.shape)
        pa, _ = a_orilla(alfa(primero[ARRIBA:CORTE]), orilla.shape)
        v = p * pa[..., None] + v * (1 - pa[..., None])
        guardar(os.path.join(vista, "templo_orilla.png"), v[300:1400, 400:1600].astype(np.uint8))
        o2 = o[..., :3] * (o[..., 3:] / 255.0) + np.array([255, 0, 255]) * (1 - o[..., 3:] / 255.0)
        guardar(os.path.join(vista, "orilla_sin_viejo.png"), o2[300:1400, 400:1600].astype(np.uint8))


if __name__ == "__main__":
    main()
