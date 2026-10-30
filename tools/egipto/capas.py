"""LAS CAPAS DEL ACTO I, de tiras generadas por separado (2026-10-26):

  lejos   raw/master_builder/referencias/egipto_lejos/tira_NN.png: cielo,
          ciudad y rio (sin la orilla de palmeras). Sale en dos capas: el cielo
          (casi quieto) y la ciudad con el agua.
  medio   (cuando este) la orilla de palmeras con su reflejo, y la arena.

COSER: cada extension se coloca sobre la anterior por SIFT (similitud), y en
el solape se corta por la costura de menor diferencia (programacion dinamica,
de arriba abajo) con un fundido estrecho, en vez de fundir a medias: donde las
dos imagenes no casan exactamente, el corte pasa por donde menos se nota.

Nada se pinta: recortes, rellenos de lo de alrededor y fundidos.

Escribe assets/egipto/acto1/capas/ (trozos y capas.json, que el nivel carga
ademas de la tira: las capas de aqui quitan las de la tira que nombran).
Uso: python tools/egipto/capas.py [--vista carpeta] [--solo-filas]
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, AQUI)
import tira as T  # noqa: E402  (rellenar, limpiar_borde, planos)

PROYECTO = os.path.dirname(os.path.dirname(AQUI))
REFS = os.path.join(PROYECTO, "raw", "master_builder", "referencias")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "capas")
RES = "res://assets/egipto/acto1/capas/"

# (la 7 y la 8: el final del acto, donde el rio tuerce hacia aqui para cruzarlo)
LEJOS = {"carpeta": "egipto_lejos", "usar": [0, 1, 2, 3, 4, 5, 6, 7]}
# UNA SOLA ESCALA Y UNA SOLA REFERENCIA PARA TODAS LAS CAPAS: con la camara en
# reposo (la de arranque) el conjunto es la imagen tal cual; solo al moverse se
# separan los planos. (Con escalas y alturas distintas por capa "no cuadraba
# nada": la orilla flotaba lejos de la ciudad.)
# (2026-10-27: 1.2 y no la 1.9 de la tira vieja: con 1.9 el peregrino salia
# como la maleza de la playa; mundo mas pequeno y camara mas cerca, mismo encuadre)
ESCALA = 1.2
ESCALA_LEJOS = ESCALA
X0 = -800.0
Y_BORDE_JUEGO = -150.0  # donde queda el borde de la playa de la imagen (lo tapa la arena)
EXTRA_ARRIBA = 600      # cielo alargado por arriba
EXTRA_AGUA = 1100       # agua alargada por abajo (con la camara alta, se ve mas)
FUNDIDO = 14            # px de fundido a cada lado de la costura
TROZO = 2048


def leer(ruta):
    return cv2.imdecode(np.fromfile(ruta, np.uint8), cv2.IMREAD_COLOR)


def guardar(nombre, img):
    cv2.imencode(".png", img)[1].tofile(os.path.join(DESTINO, nombre + ".png"))


def transformacion(a, b):
    """La similitud que lleva b sobre a (SIFT a media resolucion)."""
    e = 0.5
    ga = cv2.cvtColor(cv2.resize(a, None, fx=e, fy=e), cv2.COLOR_BGR2GRAY)
    gb = cv2.cvtColor(cv2.resize(b, None, fx=e, fy=e), cv2.COLOR_BGR2GRAY)
    s = cv2.SIFT_create()
    ka, da = s.detectAndCompute(ga, None)
    kb, db = s.detectAndCompute(gb, None)
    m = cv2.BFMatcher().knnMatch(da, db, k=2)
    g = [p for p, q in m if p.distance < 0.7 * q.distance]
    pa = np.float32([ka[p.queryIdx].pt for p in g]) / e
    pb = np.float32([kb[p.trainIdx].pt for p in g]) / e
    H, inl = cv2.estimateAffinePartial2D(pb, pa, method=cv2.RANSAC, ransacReprojThreshold=4)
    print("  solape: %d puntos, escala %.4f, dx %.0f, dy %.1f" % (inl.sum(), np.hypot(H[0, 0], H[1, 0]), H[0, 2], H[1, 2]))
    return np.vstack([H, [0, 0, 1]])


def costura(dif):
    """El camino vertical (una x por fila) de menor coste acumulado en dif (h, w)."""
    h, w = dif.shape
    acum = dif.copy()
    de = np.zeros((h, w), np.int8)
    for y in range(1, h):
        prev = acum[y - 1]
        izq = np.r_[np.inf, prev[:-1]]
        der = np.r_[prev[1:], np.inf]
        opciones = np.stack([izq, prev, der])
        k = np.argmin(opciones, 0)
        acum[y] += opciones[k, np.arange(w)]
        de[y] = k - 1
    xs = np.zeros(h, int)
    xs[-1] = int(np.argmin(acum[-1]))
    for y in range(h - 1, 0, -1):
        xs[y - 1] = np.clip(xs[y] + de[y, xs[y]], 0, w - 1)
    return xs


def coser(ims):
    Ts = [np.eye(3)]
    for a, b in zip(ims, ims[1:]):
        Ts.append(Ts[-1] @ transformacion(a, b))
    H = ims[0].shape[0]
    W = int(max(t[0, 2] + t[0, 0] * im.shape[1] for t, im in zip(Ts, ims))) + 2
    lienzo = np.zeros((H, W, 3), np.uint8)
    lleno = np.zeros((H, W), bool)
    for k, (im, t) in enumerate(zip(ims, Ts)):
        nuevo = cv2.warpAffine(im, t[:2], (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
        valido = cv2.warpAffine(np.full(im.shape[:2], 255, np.uint8), t[:2], (W, H), flags=cv2.INTER_NEAREST) > 0
        valido = cv2.erode(valido.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        if k == 0:
            lienzo[valido] = nuevo[valido]
            lleno |= valido
            continue
        # (columnas con casi todas las filas en las dos: con un dy de medio pixel
        # la primera o la ultima fila no estan)
        cols = np.where((valido & lleno).mean(0) > 0.97)[0]
        x0, x1 = int(cols.min()), int(cols.max()) + 1
        # (que la costura no pegue a los bordes del solape)
        m = min(120, (x1 - x0) // 6)
        a = lienzo[:, x0 + m:x1 - m].astype(np.float32)
        b = nuevo[:, x0 + m:x1 - m].astype(np.float32)
        dif = np.abs(a - b).sum(2)
        dif = cv2.GaussianBlur(dif, (0, 0), 2.0)
        xs = costura(dif) + x0 + m
        print("  costura en x %d-%d (solape %d-%d), diferencia media %.1f" % (xs.min(), xs.max(), x0, x1,
              float(dif[np.arange(H), xs - x0 - m].mean())))
        # peso del nuevo: 0 a la izquierda de la costura, 1 a la derecha, fundido
        X = np.arange(W)[None, :]
        r = np.clip((X - xs[:, None] + FUNDIDO) / (2.0 * FUNDIDO), 0, 1)
        r = np.where(valido, r, 0)
        r = np.where(lleno, r, valido.astype(np.float32))
        lienzo = (lienzo * (1 - r[..., None]) + nuevo * r[..., None]).astype(np.uint8)
        lleno |= valido
    # sin columnas vacias al final
    cols = np.where(lleno.mean(0) > 0.97)[0]
    lienzo, lleno = lienzo[:, :cols.max() + 1], lleno[:, :cols.max() + 1]
    # lo que quede sin imagen arriba o abajo (una extension algo desplazada en
    # vertical), con la primera o la ultima fila que si tiene
    for x in np.where(~lleno.all(0))[0]:
        ys = np.where(lleno[:, x])[0]
        if len(ys):
            lienzo[:ys[0], x] = lienzo[ys[0], x]
            lienzo[ys[-1] + 1:, x] = lienzo[ys[-1], x]
    return lienzo


def borde_playa(T_):
    """La fila del borde de la playa por columna: desde abajo, la primera tanda
    de 8 filas de agua clara (azul, luminosa y saturada: ni las sombras de la
    arena, oscuras, ni la arena cuentan), suave."""
    hsv = cv2.cvtColor(T_, cv2.COLOR_BGR2HSV).astype(int)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    agua = (h >= 88) & (h <= 135) & (s > 35) & (v > 145)
    H = agua.shape[0]
    run = cv2.erode(agua.astype(np.uint8), np.ones((8, 1), np.uint8)) > 0
    run[:int(H * 0.5)] = False
    hay = run.any(0)
    bajo = np.where(hay, H - 1 - np.argmax(run[::-1], 0) + 4, H * 0.85).astype(np.float32)
    bajo = cv2.medianBlur(bajo.reshape(1, -1), 5).ravel()
    return cv2.GaussianBlur(bajo.reshape(1, -1), (0, 0), 20).ravel()


def linea_cielo(img, desde):
    """La linea (fila por columna) por encima de todo lo que no es cielo:
    ciudad, piramides, montanas. Lo que tiene algo de detalle, desde arriba; un
    percentil bajo en una ventana ancha (sin picos de aristas del cielo) y
    suave. Por encima solo hay cielo."""
    H, W = img.shape[:2]
    e = 0.5
    p = cv2.resize(img, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
    g = cv2.cvtColor(p, cv2.COLOR_BGR2GRAY).astype(np.float32)
    hf = cv2.GaussianBlur(np.abs(g - cv2.GaussianBlur(g, (0, 0), 1.5)), (0, 0), 2.0)
    run = cv2.erode((hf > 1.6).astype(np.uint8), np.ones((5, 1), np.uint8)) > 0
    hp, wp = run.shape
    d0 = int(desde * e)
    top = np.full(wp, hp * 0.7, np.float32)
    for x in range(wp):
        ys = np.where(run[d0:, x])[0]
        if len(ys):
            top[x] = ys[0] + d0
    from scipy.ndimage import percentile_filter
    top = percentile_filter(top, 20, size=151)
    top = cv2.GaussianBlur(top.reshape(1, -1).astype(np.float32), (0, 0), 40).ravel()
    return cv2.resize(top.reshape(1, -1), (W, 1), interpolation=cv2.INTER_LINEAR).ravel() / e


def silueta(img, desde, lin):
    """La silueta de lo que no es cielo (montanas, piramides, ciudad) por
    columna, para que la lluvia de naves se pierda justo detras (2026-10-27).
    Por color (Lab, medido): las montanas son rosadas (a > 16), malva (a > 9
    con b no mucho mayor) o, en sombra, mas oscuras que el cielo (L < 160, la
    cara en sombra de la piramide es azulada); el cielo naranja tiene a ~11
    pero b ~35 y es muy claro (con a > 11 a secas la linea se iba al cielo junto
    a la piramide y las naves desaparecian antes de tiempo). Los saltos de color
    no valian: las nubes facetadas tambien los tienen."""
    H, W = img.shape[:2]
    lab = cv2.cvtColor(cv2.GaussianBlur(img, (0, 0), 1.5), cv2.COLOR_BGR2LAB).astype(np.int32)
    L, a, b = lab[..., 0], lab[..., 1] - 128, lab[..., 2] - 128
    monte = (a > 16) | ((L < 160) & (a > -4)) | ((a > 9) & (b < a + 8) & (L < 200))
    monte = cv2.erode(monte.astype(np.uint8), np.ones((4, 1), np.uint8)) > 0
    top = np.full(W, float(H), np.float32)
    y_ini = np.clip(lin.astype(int) - 80, desde, H - 1)
    for x in range(W):
        ys = np.where(monte[y_ini[x]:, x])[0]
        if len(ys):
            top[x] = ys[0] + y_ini[x]
    from scipy.ndimage import median_filter
    return median_filter(top, size=7)


def agua_hacia_abajo(img, borde, n):
    """Quita la playa: por debajo de 'borde' (menos un margen), el agua de las
    filas de justo encima repetida en espejo y algo mas oscura, y luego n filas
    mas de lo mismo."""
    H, W = img.shape[:2]
    # donde la playa se tuerce (el final: el rio que gira para cruzarlo) no se
    # quita: se alarga lo que hay (la arena, en espejo)
    raro = np.abs(borde - np.median(borde)) > 60
    borde = np.where(raro, H - 1, borde)
    lin = np.clip(borde - 12, H * 0.5, H - 2).astype(int)
    out = np.zeros((H + n, W, 3), np.float32)
    out[:H] = img
    yy = np.arange(H + n)[:, None]
    # espejo de la franja de agua de encima (ida y vuelta)
    banda = 40
    d = yy - lin[None, :]
    k = np.mod(d, 2 * banda)
    src = np.where(k < banda, lin[None, :] - 1 - k, lin[None, :] - 2 * banda + k)
    src = np.clip(src, 0, H - 1)
    xs = np.arange(W)[None, :].repeat(H + n, 0)
    ref = img[src, xs].astype(np.float32)
    ref = cv2.GaussianBlur(ref, (0, 0), sigmaX=6, sigmaY=1.5)
    prof = np.clip(d / 900.0, 0, 1)[..., None]
    ref *= (1 - 0.18 * prof)
    m = cv2.GaussianBlur((d >= 0).astype(np.float32), (0, 0), 3.0)[..., None]
    return np.clip(out * (1 - m) + ref * m, 0, 255).astype(np.uint8)


def rellenar_filas(img, hueco):
    """Lo de detras de la ciudad en el cielo: cada fila, con el cielo de esa
    misma fila a los lados (el cielo cambia en vertical, no en horizontal), y
    las filas sin cielo, con la de encima; suavizado a lo ancho."""
    out = img.astype(np.float32).copy()
    H, W = hueco.shape
    xs = np.arange(W)
    prev = None
    for y in range(H):
        m = hueco[y]
        if not m.any():
            prev = out[y]
            continue
        if (~m).sum() > W * 0.03:
            for c in range(3):
                out[y, m, c] = np.interp(xs[m], xs[~m], out[y, ~m, c])
        elif prev is not None:
            out[y, m] = prev[m]
        prev = out[y]
    suave = cv2.GaussianBlur(out, (0, 0), sigmaX=40, sigmaY=3)
    mm = cv2.GaussianBlur(hueco.astype(np.float32), (0, 0), 4)[..., None]
    return np.clip(out * (1 - mm) + suave * mm, 0, 255).astype(np.uint8)


def trocear(nombre, img, y_juego0, escala):
    out = []
    for k, c in enumerate(range(0, img.shape[1], TROZO)):
        n = "%s_%d" % (nombre, k)
        guardar(n, img[:, c:c + TROZO])
        t = {"tex": RES + n + ".png", "x": X0 + c * escala, "y": y_juego0}
        f = filas_con_algo(img[:, c:c + TROZO])
        if f:
            t["filas"] = f
        out.append(t)
    return out


# LAS FILAS CON ALGO (2026-10-29, rendimiento): de cada trozo con transparencia,
# de la primera a la ultima fila que no es del todo transparente (con MARGEN_FILAS
# de mas, por el filtro); el juego dibuja solo eso (region): las filas vacias
# (la mitad de la arena, un 38 % de la orilla) costaban igual en la GPU.
MARGEN_FILAS = 4


def filas_con_algo(img):
    if img.ndim < 3 or img.shape[2] < 4:
        return None
    filas = np.nonzero(img[..., 3].max(1) > 0)[0]
    if len(filas) == 0:
        return None
    y0 = max(int(filas[0]) - MARGEN_FILAS, 0)
    y1 = min(int(filas[-1]) + 1 + MARGEN_FILAS, img.shape[0])
    if (y1 - y0) > img.shape[0] * 0.95:
        return None
    return [y0, y1]


def solo_filas():
    """Pone las filas en el capas.json que ya hay, de sus PNG (sin rehacer las capas)."""
    ruta = os.path.join(DESTINO, "capas.json")
    datos = json.load(open(ruta, encoding="utf-8"))
    for c in datos["capas"]:
        for t in c["trozos"]:
            png = os.path.join(DESTINO, os.path.basename(t["tex"]))
            f = filas_con_algo(cv2.imread(png, cv2.IMREAD_UNCHANGED))
            if f:
                t["filas"] = f
            else:
                t.pop("filas", None)
        print(c["nombre"], [t.get("filas") for t in c["trozos"]][:3])
    json.dump(datos, open(ruta, "w", encoding="utf-8"), indent=1)


def lejos(vista):
    d = os.path.join(REFS, LEJOS["carpeta"])
    ims = [leer(os.path.join(d, "tira_%02d.png" % i)) for i in LEJOS["usar"]]
    print("lejos: cosiendo", len(ims))
    L = coser(ims)
    print("lejos", L.shape)
    borde = borde_playa(L)
    L2 = agua_hacia_abajo(L, borde, EXTRA_AGUA)
    L2 = T.alargar_arriba(L2, EXTRA_ARRIBA)
    H2 = L2.shape[0]
    # la otra orilla (para la calima y para separar el cielo)
    hsv = cv2.cvtColor(L, cv2.COLOR_BGR2HSV).astype(int)
    agua = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 135) & (hsv[..., 1] > 30) & (hsv[..., 2] > 100)
    filas = agua[:, ::8].mean(1)
    # (el agua es la franja azul seguida que llega hasta abajo: el cielo azul de
    # arriba tambien pasaba y el agua "empezaba" en el cielo, con brillos en el)
    no_agua = np.where(filas[:int(np.median(borde))] <= 0.5)[0]
    agua_y0 = int(no_agua.max()) + 1 if len(no_agua) else 0
    costa = T.linea_orilla_lejana(L, agua_y0, int(np.median(borde))) + EXTRA_ARRIBA
    # cielo y ciudad: corte suave por encima de todo lo que no es cielo (la
    # ciudad se lleva el cielo de entre sus edificios: un degradado liso, que al
    # moverse a otra velocidad no se nota), y el cielo, por debajo del corte,
    # con el cielo de justo encima alargado hacia abajo
    lin = linea_cielo(L2, EXTRA_ARRIBA) - 40
    H2_ = L2.shape[0]
    Y = np.arange(H2_)[:, None]
    a_c = np.clip((Y - lin[None, :]) / 140.0, 0, 1)
    ciudad = np.dstack([L2, (a_c * 255).astype(np.uint8)])
    li = np.clip(lin.astype(int) - 8, 1, H2_ - 1)
    xs = np.arange(L2.shape[1])
    cielo = L2.copy()
    fila = L2[li, xs].astype(np.float32)
    fila = cv2.GaussianBlur(fila.reshape(1, -1, 3), (0, 0), sigmaX=160, sigmaY=0).reshape(-1, 3)
    debajo = Y >= li[None, :]
    cielo = np.where(debajo[..., None], fila[None, :, :], cielo.astype(np.float32))
    m = cv2.GaussianBlur(debajo.astype(np.float32), (0, 0), 6)[..., None]
    cielo = np.clip(L2 * (1 - m) + cielo * m, 0, 255).astype(np.uint8)
    # la silueta (para la lluvia de naves), cada 8 px, en px de juego de la capa
    global SILUETA
    sil = silueta(L2, EXTRA_ARRIBA, lin)[::8]
    y_l2 = (-EXTRA_ARRIBA - T.Y_PISA) * ESCALA_LEJOS - T.PLANTA
    SILUETA = {"x0": X0, "paso": 8 * ESCALA_LEJOS,
               "y": [round(float(v) * ESCALA_LEJOS + y_l2, 1) for v in sil]}
    # el aire: la ciudad, lejana, algo del color del cielo del horizonte
    global HORIZONTE
    HORIZONTE = color_horizonte(cielo, lin)
    ciudad = aire(igualar_luz(ciudad, **LUZ_CIUDAD), HORIZONTE, AIRE_CIUDAD)
    yb = float(np.median(borde)) + EXTRA_ARRIBA          # fila del borde de la playa en L2
    # la fila 0 de L2 es la -EXTRA_ARRIBA de la imagen; la fila Y_PISA de la imagen es y = 0
    y0 = (-EXTRA_ARRIBA - T.Y_PISA) * ESCALA_LEJOS - T.PLANTA
    # (paralaje contenido, 2026-10-27: con 0.25 / 0.45 / 1.0 los planos se
    # deslizaban mucho unos sobre otros y se leian como cartones pegados)
    capas = [
        {"nombre": "cielo", "p": 0.12, "py": 0.08, "escala": ESCALA_LEJOS, "deriva": -6.0,
         "trozos": trocear("lejos_cielo", cielo, y0, ESCALA_LEJOS)},
        {"nombre": "ciudad", "p": 0.40, "py": 0.25, "escala": ESCALA_LEJOS,
         "agua": [(agua_y0 + EXTRA_ARRIBA) / H2, 1.0], "costa": (agua_y0 + EXTRA_ARRIBA) / H2,
         "trozos": trocear("lejos_ciudad", ciudad, y0, ESCALA_LEJOS)},
    ]
    if vista:
        for nombre, img in (("cielo", cielo), ("ciudad", ciudad)):
            v = img.astype(np.float32)
            if v.shape[2] == 4:
                a3 = v[..., 3:4] / 255.0
                v = v[..., :3] * a3 + np.array([255, 0, 255], np.float32) * (1 - a3)
            cv2.imencode(".jpg", cv2.resize(v.astype(np.uint8), None, fx=0.12, fy=0.12))[1].tofile(
                os.path.join(vista, "lejos_%s.jpg" % nombre))
        cv2.imencode(".jpg", cv2.resize(L, None, fx=0.12, fy=0.12))[1].tofile(os.path.join(vista, "lejos_cosida.jpg"))
    # (el ancho en px de juego a la escala de la tira, como en tira.json: x1 = x0 + ancho * escala_capa / escala)
    return capas, float(L.shape[1] * ESCALA)


MEDIO = {"carpeta": "egipto_medio", "usar": [0, 1, 2, 3, 4, 5, 6, 7]}
ESCALA_MEDIO = ESCALA
REFLEJO = 300           # px (imagen) del reflejo de la orilla que se queda, fundiendose
BORDE_CIELO = 6.0       # gradiente (gris por px) que ya es contorno: el cielo no lo cruza
TROZO_CIELO = 150       # px: un trozo liso de color de cielo asi de grande es cielo
FRANJA_CIELO = 12.0     # px junto al cielo donde se mide la transparencia (las puntas de las hojas)


def mascara_orilla(img, y_agua):
    """La orilla de enfrente contra su cielo (2026-10-27, tercera version: "quita
    esos colores solo donde corresponde, en las palmeras, no en lo demas").
    Hay muros y columnas casi del color del cielo, asi que el color no basta:
      - el cielo es lo de color de cielo unido al borde de arriba SIN cruzar un
        contorno (los muros y las columnas tienen su raya; el cielo es liso);
      - y los huecos de cielo entre las hojas: lo de color de cielo rodeado de hoja;
      - la transparencia fina solo en una franja de pocos px junto a ese cielo
        (alli se quita el cielo mezclado, I = a*F + (1-a)*S); lo demas, opaco
        aunque sea crema.
    Devuelve el bgra de la orilla. y_agua: la linea del agua por columna."""
    from scipy.ndimage import grey_dilation
    H, W = img.shape[:2]
    Yf = np.arange(H)[:, None]
    arriba = Yf < y_agua[None, :] - 4
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    hh, ss, vv = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    # color de cielo: crema, blanquecino o azul claro (las ruinas al sol, mas saturadas)
    color_cielo = (((vv >= 200) & (ss < 110)) | ((hh >= 85) & (hh <= 125) & (vv > 150))) & arriba
    # los contornos: el cielo es un degradado liso
    g = cv2.GaussianBlur(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 1.0)
    borde = cv2.magnitude(cv2.Sobel(g, cv2.CV_32F, 1, 0), cv2.Sobel(g, cv2.CV_32F, 0, 1)) > BORDE_CIELO
    borde = cv2.dilate(borde.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    liso_cielo = color_cielo & ~borde
    libre = (color_cielo & ~borde).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(libre, 4)
    # (unido al borde de arriba, o un trozo liso grande: el cielo de entre los
    # troncos queda encerrado por las copas; los muros y columnas, con su raya,
    # no dan trozos grandes)
    arriba_del_todo = np.unique(lab[:int(H * 0.12)])
    vale = st[:, cv2.CC_STAT_AREA] >= TROZO_CIELO
    vale[0] = False
    # (los trozos encerrados y los huecos, no pegados al agua: alli eran brillos
    # del agua y la raya clara de la orilla, que agujereaban los arbustos; la
    # linea del agua medida cae hasta ~130 px por debajo de la orilla)
    lejos_agua = Yf < y_agua[None, :] - 170
    cielo = vale[lab] & lejos_agua
    top = np.zeros(n, bool)
    top[arriba_del_todo] = True
    top[0] = False
    cielo |= top[lab]
    del lab
    # las piedras claras al sol (s 117-187): nunca cielo
    ruina = (ss > 112) & (hh >= 4) & (hh <= 24) & (vv > 110)
    ruina = cv2.morphologyEx(ruina.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    ruina = cv2.morphologyEx(ruina, cv2.MORPH_OPEN, np.ones((13, 13), np.uint8)) > 0
    # los huecos entre las hojas: color de cielo (sin mirar contornos: son
    # pequenos) rodeado sobre todo de palmera (hojas y troncos: ni cielo ni
    # ruina; una columna clara toca el cielo y no pasa)
    hoja = ~cielo & ~ruina
    n2_, lab2, st2, _ = cv2.connectedComponentsWithStats((color_cielo & ~cielo).astype(np.uint8), 8)
    anillo_lab = grey_dilation(lab2, size=(5, 5))
    anillo = (anillo_lab > 0) & (lab2 == 0)
    tot = np.bincount(anillo_lab[anillo], minlength=n2_)
    de_hoja = np.bincount(anillo_lab[anillo & hoja], minlength=n2_)
    area2 = st2[:, cv2.CC_STAT_AREA]
    hueco = (de_hoja > 0.6 * np.maximum(tot, 1)) & (area2 >= 4) & (area2 < 4000)
    hueco[0] = False
    cielo |= hueco[lab2] & lejos_agua
    del lab2, anillo_lab
    cielo &= ~ruina
    # ---- el recorte fino: en cada punto, el color del cielo de detras (S, del
    # cielo de alrededor) y el de la hoja o la piedra de delante (F, de lo seguro
    # de alrededor); la transparencia es cuanto del camino de S a F lleva el pixel
    # (la transparencia fina solo cerca de hoja oscura: las puntas de las palmas;
    # junto a una columna clara no hay hoja y no se le comen los bordes)
    # (hoja: oscura, verde, o dorada por el sol; el rayado pardo de las columnas
    # claras es de tono 12-16 y menos saturado, las hojas y troncos dorados de 17
    # en adelante y s ~185: medido en la tira)
    oscuro = (((vv < 150) & (hh >= 17)) | ((hh >= 25) & (hh <= 95) & (vv < 210))
              | ((hh >= 17) & (ss > 160) & (vv < 230)))
    cerca_hoja = cv2.dilate(oscuro.astype(np.uint8), np.ones((21, 21), np.uint8)) > 0
    A = np.ones((H, W), np.float32)
    Fo = img.astype(np.float32).copy()
    TROZO, M_ = 2048, 160
    for c0 in range(0, W, TROZO):
        a0, a1 = max(0, c0 - M_), min(W, c0 + TROZO + M_)
        I = img[:, a0:a1].astype(np.float32)
        ci = cielo[:, a0:a1].copy()
        cc = color_cielo[:, a0:a1]
        # (el cielo se paraba a 2-3 px del contorno, por el filtro de bordes, y
        # quedaba un filo crema: crece hasta 3 px por lo que tiene su color justo)
        for _ in range(3):
            Sk = _media_cercana(I, ci, (3, 12, 50))
            dS = np.linalg.norm(I - Sk, axis=2)
            ci |= cc & (dS < 7) & (cv2.dilate(ci.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)
        ci &= ~ruina[:, a0:a1]
        dist = cv2.distanceTransform((~ci).astype(np.uint8), cv2.DIST_L2, 3)
        Sk = _media_cercana(I, ci, (3, 12, 50))
        dS = np.linalg.norm(I - Sk, axis=2)
        ch = cerca_hoja[:, a0:a1]
        # (los bolsillos crema de dentro de las copas: lisos y del color del cielo
        # de al lado; tambien se miden, aunque esten lejos del cielo detectado)
        bolsillo = liso_cielo[:, a0:a1] & (dS < 25) & ch & ~ci
        # (y los trozos crema pequenos junto a las hojas, aunque no sean lisos: el
        # filo de las hojas los raya; una columna o un muro claro es un trozo grande)
        cand = (cc & (dS < 22) & ch & ~ci).astype(np.uint8)
        nb, lb, sb, _ = cv2.connectedComponentsWithStats(cand, 8)
        peq = sb[:, cv2.CC_STAT_AREA] < 400
        peq[0] = False
        bolsillo |= peq[lb]
        franja = (((dist > 0) & (dist <= FRANJA_CIELO)) | bolsillo) & ch
        # lo seguro de delante: fuera de la franja, o muy lejos del color del
        # cielo (2026-10-27: con 45 el filo de las hojas, mezcla de hoja y crema,
        # contaba como hoja y quedaba un contorno amarillo)
        seguro = (~ci & ~franja) | (franja & (dS > 100))
        Fk = _media_cercana(I, seguro, (1.5, 5, 18))
        FS = Fk - Sk
        n2 = np.maximum((FS * FS).sum(2), 1.0)
        a = np.clip(((I - Sk) * FS).sum(2) / n2, 0, 1)
        # (donde lo de delante casi tiene el color del cielo no se puede medir: opaco)
        a = np.where(n2 < 15 ** 2, 1.0, a)
        a = np.clip((a - 0.1) / 0.8, 0, 1)
        a[seguro] = 1.0
        a[ci] = 0.0
        # el color sin el cielo mezclado; en lo muy transparente, el de la hoja de al lado
        F = np.clip((I - (1 - a[..., None]) * Sk) / np.maximum(a[..., None], 0.05), 0, 255)
        t = np.clip((a - 0.3) / 0.4, 0, 1)[..., None]
        F = Fk * (1 - t) + F * t
        F = np.where(seguro[..., None], I, F)
        b0 = c0 - a0
        A[:, c0:c0 + TROZO] = a[:, b0:b0 + TROZO]
        Fo[:, c0:c0 + TROZO] = F[:, b0:b0 + TROZO]
    # solo lo unido a la orilla (sin motas sueltas en el cielo)
    duro = (A > 0.35).astype(np.uint8)
    n, labl, st, _ = cv2.connectedComponentsWithStats(duro, 8)
    base = np.unique(labl[~arriba])
    unido = cv2.dilate(np.isin(labl, base[base > 0]).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    A = np.where(unido, A, 0.0)
    rampa = 1.0 - np.clip((Yf - y_agua[None, :] - REFLEJO * 0.4) / (REFLEJO * 0.6), 0, 1)
    A = A * rampa
    return np.dstack([Fo.astype(np.uint8), (A * 255).astype(np.uint8)])


# LA LUZ DE LA ORILLA (2026-10-27, "parecen 3 pegotes"): la tira media salio de
# imagenes con el cielo crema dorado y queda mucho mas amarilla y oscura que la
# ciudad del fondo (Lab b 153 contra 135, L 97 contra 150): se le quita casi todo
# el amarillo de mas y se aclara un poco (mas cerca, puede ser algo mas oscura)
# (2026-10-29: a la mitad, "hemos perdido detalle en lo amarillo"; antes
# dL 12, db -11, contraste 0.8 y aire 0.12; ciudad dL 8, db -8, contraste 0.62, aire 0.28)
# (y 2026-10-29, "calidos, no naranjas": menos croma y menos rojo, la piedra
# color arena; el relieve, el de la bruma a la mitad)
LUZ_ORILLA = {"dL": 6.0, "db": -5.0, "da": -2.0, "contraste": 0.9, "croma": 0.85}
# EL AIRE: lo lejano se mezcla con el color del cielo del horizonte
AIRE_CIUDAD = 0.16
AIRE_ORILLA = 0.08
# EL ESCALONADO DE LOS PLANOS (2026-10-27, comparado con las composiciones que
# gustan: lejos palido, plano y algo frio, contraste ~27; delante oscuro y con
# contraste ~65. Aqui estaba al reves: la ciudad con 45 y la playa, lo mas
# cercano, la mas plana (31) y la mas naranja)
LUZ_CIUDAD = {"dL": 6.0, "db": 0.0, "da": -4.0, "contraste": 0.8, "croma": 0.75}
# (2026-10-29, el usuario: la arena "tan naranja", rosada, y la piedra amarilla,
# "parecen suelos distintos"; medido: arena a 58-64 grados de tono en Lab, la
# piedra 72-75 y la banda media 77-79. Antes db -10, da -2: se le quitaba el
# amarillo y quedaba teja. Ahora menos rojo y algo mas de amarillo: la arena a
# ~69, de la familia de la piedra y algo mas calida que ella, maqueta A)
LUZ_ARENA = {"dL": -10.0, "db": -8.5, "da": -5.0, "contraste": 1.35}
HORIZONTE = None        # (lo pone lejos(): el color del aire)
SILUETA = None          # (lo pone lejos(): la silueta de montanas y ciudad, para la lluvia)
CALIMA_ORILLA = 0.12
FILA_ORILLA = 830.0     # (lo pone sin_raya_orilla(): la fila del agua de la orilla de enfrente)
LINEA_ORILLA = None     # (y por columna)
# las naves: (donde se posa en px de la primera imagen del fondo), hacia donde
# se va, y como empieza (una llega al poco, otra despega pronto)
NAVES = [((1430, 420), -1.0, "posada", 12.0, 60.0), ((1565, 414), 1.0, "posada", 45.0, 60.0),
         ((1765, 413), 1.0, "fuera", 6.0, 60.0),
         # (y en los edificios iguales del principio, mas lejos: mas pequenas)
         ((330, 528), 1.0, "posada", 70.0, 44.0)]
# (2026-10-30: quitada la pequena que llegaba a la azotea junto a la piramide
# pequena, detras del templo del cortejo: "ya no pinta nada")


def igualar_luz(bgra, dL=0.0, da=0.0, db=0.0, contraste=1.0, croma=1.0):
    """Corrige la luz de una capa recortada en Lab (solo el color, el alfa igual);
    croma < 1 apaga el color hacia el gris."""
    lab = cv2.cvtColor(bgra[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    m = bgra[..., 3] > 128
    media = lab[m].mean(0) if m.any() else lab.reshape(-1, 3).mean(0)
    lab[..., 0] = (lab[..., 0] - media[0]) * contraste + media[0] + dL
    lab[..., 1] = 128.0 + (lab[..., 1] - 128.0) * croma + da
    lab[..., 2] = 128.0 + (lab[..., 2] - 128.0) * croma + db
    out = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([out, bgra[..., 3]])


def aire(bgra, color_bgr, k):
    """Mezcla el color con el del aire (el cielo del horizonte) en la proporcion k."""
    c = bgra[..., :3].astype(np.float32) * (1 - k) + np.array(color_bgr, np.float32) * k
    return np.dstack([np.clip(c, 0, 255).astype(np.uint8), bgra[..., 3]])


def color_horizonte(cielo, lin):
    """El color del cielo justo por encima de lo mas alto de la ciudad."""
    y1 = int(np.percentile(lin, 10))
    return cielo[max(0, y1 - 300):y1, :, :3].reshape(-1, 3).mean(0)


def limpiar_filos(o, img, ancho=3.0):
    """Ultima pasada sobre el recorte (2026-10-27, "siguen teniendo amarillo"):
    en el filo de lo opaco (a <= ancho px de lo transparente) se vuelve a medir
    cuanto es hoja y cuanto cielo, con el cielo real de al lado (de la imagen,
    donde ya es transparente) y la hoja de dentro; el filo crema se vuelve
    transparente y lo que queda, sin el cielo mezclado. Donde la hoja y el cielo
    se parecen (muros y columnas claras) no se toca. Revisar con revisar_orilla.py."""
    A = o[..., 3].astype(np.float32) / 255
    Fo = o[..., :3].astype(np.float32)
    H, W = A.shape
    # los bolsillos de cielo encerrados en la vegetacion (no tocan lo transparente):
    # lisos, del color crema del cielo y rodeados casi del todo de hoja
    # (del color del cielo real de esa zona, el de lo ya transparente alrededor:
    # en la segunda mitad de la tira el cielo es mas amarillo y saturado)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    hh, vv = hsv[..., 0], hsv[..., 2]
    If = img.astype(np.float32)
    Sz = np.zeros_like(If)
    for c0 in range(0, W, 2048):
        a0, a1 = max(0, c0 - 300), min(W, c0 + 2048 + 300)
        s_ = _media_cercana(If[:, a0:a1], A[:, a0:a1] < 0.1, (10, 40, 120))
        Sz[:, c0:c0 + 2048] = s_[:, c0 - a0:c0 - a0 + 2048]
    dist_cielo = np.linalg.norm(If - Sz, axis=2)
    crema = (dist_cielo < 32) & (A > 0.5) & (vv > 150)
    # (hoja: verde, o muy oscura y no parda; las sombras de los muros son pardas)
    hoja = (((hh >= 25) & (hh <= 95) & (vv < 200)) | ((vv < 110) & ((hh < 5) | (hh > 22)))) & ~crema
    transp_ = A < 0.1
    n, lab, st, _ = cv2.connectedComponentsWithStats(crema.astype(np.uint8), 8)
    if n > 1:
        from scipy.ndimage import grey_dilation
        anillo_lab = grey_dilation(lab, size=(7, 7))
        anillo = (anillo_lab > 0) & (lab == 0)
        tot = np.bincount(anillo_lab[anillo], minlength=n)
        de_hoja = np.bincount(anillo_lab[anillo & hoja], minlength=n)
        de_cielo = np.bincount(anillo_lab[anillo & transp_], minlength=n)
        area = st[:, cv2.CC_STAT_AREA]
        # (rodeado de hoja, o de hoja y del cielo ya quitado, con bastante hoja)
        tot1 = np.maximum(tot, 1)
        # (o pequeno, muy del color del cielo y rodeado de cualquier cosa solida:
        # entre hojas doradas por el sol, que no cuentan como hoja; un muro o una
        # columna son trozos mayores)
        d_media = np.bincount(lab.ravel(), dist_cielo.ravel(), minlength=n) / np.maximum(area, 1)
        solido = np.bincount(anillo_lab[anillo & ~transp_ & ~crema], minlength=n)
        bolsa = ((((de_hoja > 0.7 * tot1) | ((de_hoja > 0.35 * tot1) & (de_hoja + de_cielo > 0.9 * tot1)))
                  & (area < 3000))
                 | ((area < 600) & (d_media < 20) & (solido > 0.6 * tot1))
                 | ((area < 3000) & (d_media < 12) & (solido > 0.6 * tot1))) & (area >= 6)
        bolsa[0] = False
        quitar = cv2.dilate(bolsa[lab].astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        A[quitar & crema] = 0.0
        print("  bolsillos de cielo en la vegetacion: %d" % int(bolsa.sum()))
    TROZO, M_ = 2048, 64
    for c0 in range(0, W, TROZO):
        a0, a1 = max(0, c0 - M_), min(W, c0 + TROZO + M_)
        a = A[:, a0:a1]
        I = img[:, a0:a1].astype(np.float32)
        transp = a < 0.1
        d = cv2.distanceTransform((~transp).astype(np.uint8), cv2.DIST_L2, 3)
        filo = (a > 0.1) & (d <= ancho)
        dentro = (a > 0.95) & (d > ancho + 1)
        Sk = _media_cercana(I, transp, (2, 6, 20))
        Fk = _media_cercana(I, dentro, (2, 6, 20))
        FS = Fk - Sk
        n2 = (FS * FS).sum(2)
        t = np.clip(((I - Sk) * FS).sum(2) / np.maximum(n2, 1), 0, 1)
        t = np.clip((t - 0.08) / 0.84, 0, 1)
        vale = filo & (n2 > 50 ** 2)
        nuevo_a = np.where(vale, np.minimum(a, t), a)
        F = np.clip((I - (1 - nuevo_a[..., None]) * Sk) / np.maximum(nuevo_a[..., None], 0.05), 0, 255)
        k = np.clip((nuevo_a - 0.3) / 0.4, 0, 1)[..., None]
        F = Fk * (1 - k) + F * k
        b0 = c0 - a0
        sl = slice(b0, b0 + TROZO)
        v = vale[:, sl]
        A[:, c0:c0 + TROZO] = np.where(v, nuevo_a[:, sl], A[:, c0:c0 + TROZO])
        Fo[:, c0:c0 + TROZO] = np.where(v[..., None], F[:, sl], Fo[:, c0:c0 + TROZO])
    return np.dstack([np.clip(Fo, 0, 255).astype(np.uint8), (A * 255).astype(np.uint8)])


VIENTO_ALTO = 260.0      # px por encima del agua en que las copas ya se mecen del todo


def mascara_viento(orilla, img, y_agua):
    """Cuanto se mece cada punto de la orilla (2026-10-27): la vegetacion (verde,
    oscura o dorada por el sol, no la piedra clara), mas cuanto mas alta sobre
    el agua, ensanchada un poco para que se mueva tambien el aire de alrededor
    de las copas (si no, la copa se recortaria contra su hueco). En gris."""
    H, W = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    hh, ss, vv = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    veg = ((hh >= 25) & (hh <= 95)) | ((vv < 110) & ((hh < 5) | (hh > 16))) | ((hh >= 17) & (ss > 160))
    veg &= orilla[..., 3] > 128
    veg = cv2.morphologyEx(veg.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    veg = cv2.dilate(veg, np.ones((9, 9), np.uint8)).astype(np.float32)
    veg = cv2.GaussianBlur(veg, (0, 0), 4)
    Y = np.arange(H)[:, None].astype(np.float32)
    alto = np.clip((y_agua[None, :] - Y) / VIENTO_ALTO, 0, 1)
    m = veg * alto * alto
    return (np.clip(m, 0, 1) * 255).astype(np.uint8)


def tapar_agua(orilla, img, linea, y_orilla):
    """Por debajo de la linea de la orilla todo es reflejo: nada transparente
    (2026-10-27: trozos de agua azul del reflejo pasaban por cielo y quedaban
    huecos, "marcas que rompen el reflejo"). El color, el de la imagen; el alfa,
    solo la rampa con la que el reflejo se funde con el agua del fondo."""
    H, W = img.shape[:2]
    Y = np.arange(H)[:, None].astype(np.float32)
    debajo = Y > linea[None, :] + 6
    rampa = 1.0 - np.clip((Y - y_orilla[None, :] - REFLEJO * 0.4) / (REFLEJO * 0.6), 0, 1)
    out = orilla.copy()
    out[..., :3] = np.where(debajo[..., None], img, orilla[..., :3])
    out[..., 3] = np.where(debajo, (rampa * 255).astype(np.uint8), orilla[..., 3])
    return out


def _media_cercana(I, m, sigmas):
    """El color medio de los puntos de la mascara m alrededor de cada punto,
    el de mas cerca primero (si no hay cerca, de mas lejos)."""
    mf = m.astype(np.float32)
    est = np.zeros_like(I)
    falta = np.ones(m.shape, bool)
    for sg in sigmas:
        num = cv2.GaussianBlur(I * mf[..., None], (0, 0), sg)
        den = cv2.GaussianBlur(mf, (0, 0), sg)
        ok = falta & (den > 0.02)
        est[ok] = num[ok] / den[ok][:, None]
        falta &= ~ok
    est[falta] = I[falta]
    return est


def linea_agua_medio(img):
    """La linea del agua de la orilla de enfrente, por columna: lo mas alto de
    la franja de agua azul (que no sean reflejos calidos), en la mitad de abajo."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(int)
    agua = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 135) & (hsv[..., 1] > 35) & (hsv[..., 2] > 140)
    H = agua.shape[0]
    run = cv2.erode(agua.astype(np.uint8), np.ones((10, 1), np.uint8)) > 0
    # (el agua, por debajo de la orilla: mas arriba, el cielo azul tambien
    # parecia agua y la linea subia hasta el cielo)
    run[:int(H * 0.6)] = False
    top = np.where(run.any(0), np.argmax(run, 0), H * 0.7).astype(np.float32)
    # (bajo los reflejos calidos el azul empieza mas abajo: la orilla es lo mas alto en una ventana ancha)
    from scipy.ndimage import percentile_filter
    top = percentile_filter(top, 10, size=301)
    return cv2.GaussianBlur(top.reshape(1, -1), (0, 0), 40).ravel()


def sin_raya_orilla(img):
    """Quita la raya azul clara que Midjourney pinta donde el agua toca la orilla
    de enfrente (2026-10-27: "no tiene sentido, se ve la separacion"): una linea
    de pocos px, azul y mas clara que lo de encima y lo de debajo, muy larga;
    se rellena desde arriba y desde abajo."""
    H = img.shape[0]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.int32)
    v = hsv[..., 2]
    # (azul, o casi blanca: en algunos tramos la raya es blanquecina)
    azul = ((hsv[..., 0] >= 88) & (hsv[..., 0] <= 128) & (hsv[..., 1] > 30)) | (hsv[..., 1] < 50)
    arriba = np.roll(v, 5, axis=0)
    abajo = np.roll(v, -5, axis=0)
    raya = azul & (v > arriba + 18) & (v > abajo + 6)
    raya[:int(H * 0.35)] = False
    # (la orilla va por el 50 %; mas abajo son brillos del agua, que se quedan)
    raya[int(H * 0.6):] = False
    # solo lo muy largo en horizontal (no los brillos sueltos del agua; por
    # componentes no valia: la raya se toca con ellos)
    m = cv2.morphologyEx(raya.astype(np.uint8), cv2.MORPH_OPEN, np.ones((1, 41), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((1, 61), np.uint8))
    # segunda pasada (quedaban trozos cortos y mas tenues): a la altura por la
    # que va la raya, lo claro y fino aunque sea corto
    W = img.shape[1]
    ys, xs = np.nonzero(m)
    fila = np.full(W, np.nan, np.float32)
    if len(xs):
        # (lo mas alto de cada columna: mas abajo salen tambien brillos largos del
        # agua y con la media la altura se iba 200 px por debajo de la orilla)
        alto = np.full(W, H, np.int64)
        np.minimum.at(alto, xs, ys)
        ok = alto < H
        fila[ok] = alto[ok]
        cols = np.arange(W)
        fila = np.interp(cols, cols[ok], fila[ok]).astype(np.float32)
        from scipy.ndimage import median_filter
        fila = median_filter(fila, size=201)
        Y = np.arange(H)[:, None]
        banda = np.abs(Y - fila[None, :]) <= 12
        arriba4 = np.roll(v, 4, axis=0)
        abajo4 = np.roll(v, -4, axis=0)
        corta = azul & banda & (v > np.maximum(arriba4, abajo4) + 8)
        # (y la raya azul fina entre calidos: las cañas encima y el reflejo
        # dorado debajo; alli no es mas clara, solo azul)
        az = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 128) & (hsv[..., 1] > 40) & (v > 70)
        corta |= banda & az & ~np.roll(az, 5, axis=0) & ~np.roll(az, -6, axis=0)
        corta = cv2.morphologyEx(corta.astype(np.uint8), cv2.MORPH_OPEN, np.ones((1, 9), np.uint8))
        m = m | corta
        global FILA_ORILLA, LINEA_ORILLA
        FILA_ORILLA = float(np.median(fila))
        LINEA_ORILLA = fila.copy()
    m = cv2.dilate(m, np.ones((5, 5), np.uint8))
    print("  raya de la orilla: %d px" % int(m.sum()))
    return cv2.inpaint(img, m, 4, cv2.INPAINT_TELEA)


def medio(vista):
    d = os.path.join(REFS, MEDIO["carpeta"])
    ims = [leer(os.path.join(d, "tira_%02d.png" % i)) for i in MEDIO["usar"]]
    print("medio: cosiendo", len(ims))
    M = coser(ims)
    print("medio", M.shape)
    M = sin_raya_orilla(M)
    # ---- la orilla de enfrente (con su reflejo), contra el cielo liso
    agua_top = linea_agua_medio(M)
    # (la linea del agua: la orilla esta justo encima del primer azul; los reflejos de
    # las palmeras quedan debajo de la orilla y van con ella)
    # (la frontera de lo que se recorta: justo encima del agua azul; con -260 en
    # algunos tramos quedaba por encima de los troncos y el cielo crema de entre
    # ellos se daba por opaco)
    y_orilla = agua_top - 40
    orilla = mascara_orilla(M, y_orilla)
    orilla = limpiar_filos(orilla, M)
    # (con la linea de la raya de la orilla: la del agua azul cae mas abajo)
    linea = LINEA_ORILLA if LINEA_ORILLA is not None else agua_top - 130
    orilla = tapar_agua(orilla, M, linea, y_orilla)
    trocear("medio_orilla_viento", mascara_viento(orilla, M, linea), 0, ESCALA_MEDIO)
    orilla = igualar_luz(orilla, **LUZ_ORILLA)
    if HORIZONTE is not None:
        orilla = aire(orilla, HORIZONTE, AIRE_ORILLA)
    borde = borde_playa(M)
    yb = float(np.median(borde))
    y0 = (0 - T.Y_PISA) * ESCALA_MEDIO - T.PLANTA
    # ---- la arena de delante (con lo plantado en ella), a la escala del juego
    a, _ = T.separar(M)
    arena = igualar_luz(np.dstack([M, (a * 255).astype(np.uint8)]), **LUZ_ARENA)
    arena = T.alargar_abajo(arena, T.EXTRA_ABAJO)
    delante = arena.copy()
    y_corte = T.Y_PISA + 22
    rampa = np.clip((np.arange(delante.shape[0]) - y_corte) / 26.0, 0, 1)[:, None]
    delante[..., 3] = (delante[..., 3] * rampa).astype(np.uint8)
    delante = delante[y_corte:]
    e = ESCALA

    def tr(nombre, img, y0_img):
        return trocear(nombre, img, (y0_img - T.Y_PISA) * e - T.PLANTA, e)
    capas = [
        # (la calima en su base, la del agua: mas suave que la de la ciudad)
        {"nombre": "orilla", "p": 0.55, "py": 0.32, "escala": ESCALA_MEDIO,
         "costa": FILA_ORILLA / M.shape[0], "calima": CALIMA_ORILLA, "calima_alto": 300.0,
         "viento": True, "trozos": trocear("medio_orilla", orilla, y0, ESCALA_MEDIO)},
        {"nombre": "arena", "p": 1.0, "py": 1.0, "trozos": tr("medio_arena", arena, 0)},
        {"nombre": "arena_delante", "p": 1.0, "py": 1.0, "delante": True,
         "trozos": tr("medio_arena_delante", delante, y_corte)},
    ]
    if vista:
        v = orilla.astype(np.float32)
        a3 = v[..., 3:4] / 255.0
        v = v[..., :3] * a3 + np.array([255, 0, 255], np.float32) * (1 - a3)
        cv2.imencode(".jpg", cv2.resize(v.astype(np.uint8), None, fx=0.15, fy=0.15))[1].tofile(
            os.path.join(vista, "medio_orilla.jpg"))
        cv2.imencode(".jpg", cv2.resize(M, None, fx=0.15, fy=0.15))[1].tofile(os.path.join(vista, "medio_cosida.jpg"))
    return capas


def main():
    if "--solo-filas" in sys.argv:
        solo_filas()
        return
    os.makedirs(DESTINO, exist_ok=True)
    for f in os.listdir(DESTINO):
        if f.endswith(".png"):
            os.remove(os.path.join(DESTINO, f))
    vista = sys.argv[sys.argv.index("--vista") + 1] if "--vista" in sys.argv else None
    capas, ancho = lejos(vista)
    quita = ["cielo", "ciudad"]
    if os.path.isdir(os.path.join(REFS, MEDIO["carpeta"])):
        capas += medio(vista)
        quita += ["arena", "arena_delante"]
    datos = {"escala": ESCALA, "x0": X0, "ancho": ancho, "quita": quita, "capas": capas}
    if SILUETA:
        datos["silueta"] = SILUETA
    # los barcos (tools/egipto/barcos.py): en su capa, justo delante de la orilla
    # de enfrente, por el agua de entre ella y nuestra playa
    e = ESCALA
    # (2026-10-27: eran demasiados y uno pasaba pegado a la playa; pocos, lejos,
    # pequenos y lentos; 2026-10-30: junto al barco del cortejo del templo
    # "parecen de papel": mas grandes, cada uno en su carril, sin cruzarse)
    datos["barcos"] = {"tras": "orilla", "cuantos": 3, "prof": [0.0, 0.4], "alto": [220.0, 440.0],
                       "carriles": [0.04, 0.2, 0.36],
                       "rapidez": [4.0, 9.0], "p": 0.68, "py": 0.42, "y0": (930 - T.Y_PISA) * e, "y1": (1330 - T.Y_PISA) * e,
                       "x0": X0, "x1": 17000.0}
    # las naves (2026-10-27, un guino del usuario): en las azoteas planas de los
    # pilonos gemelos de la ciudad del fondo (px de la primera imagen del fondo:
    # el primero de x 1340 a 1630, el segundo de 1675 a 1840, arriba en y ~414)
    def en_ciudad(x, y):
        return X0 + x * ESCALA_LEJOS, (y - T.Y_PISA) * ESCALA_LEJOS - T.PLANTA
    datos["naves"] = []
    for (x, y), sentido, estado, espera, ancho_n in NAVES:
        px, py = en_ciudad(x, y)
        # (las mas pequenas, mas lejos: mas aire)
        datos["naves"].append({"capa": "ciudad", "x": round(px, 1), "y": round(py, 1), "ancho": ancho_n,
                               "aire": 0.28 if ancho_n >= 60.0 else 0.36,
                               "sentido": sentido, "estado": estado, "espera": espera})
    # donde se acaba la arena (la playa no puede seguir mas alla)
    for c in capas:
        if c["nombre"] == "arena":
            tr = c["trozos"][-1]
            w = cv2.imread(os.path.join(DESTINO, os.path.basename(tr["tex"])), cv2.IMREAD_UNCHANGED).shape[1]
            datos["fin_suelo"] = round(tr["x"] + w * ESCALA, 1)
    json.dump(datos, open(os.path.join(DESTINO, "capas.json"), "w", encoding="utf-8"), indent=1)
    # la arena de delante, del mismo suelo que la de detras (arena_delante.py)
    if os.path.isdir(os.path.join(REFS, MEDIO["carpeta"])):
        import arena_delante
        arena_delante.main()
    # el templo del cortejo en la orilla (templo_rio.py): quita el de la torre
    if os.path.isdir(os.path.join(REFS, "egipto_templo_video")):
        import templo_rio
        templo_rio.main()
    print("capas escritas")


if __name__ == "__main__":
    main()
