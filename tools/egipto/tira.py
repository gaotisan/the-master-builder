"""LA TIRA DEL ACTO I (2026-10-25): las extensiones encadenadas de Midjourney
(raw/master_builder/referencias/egipto_tira/tira_NN.png, cada una con la mitad
izquierda repitiendo la derecha de la anterior) cosidas en un solo paisaje, y
separado en dos capas por profundidad:

  paisaje  el Nilo, las islas, las ruinas de la otra orilla, la ciudad y el
           cielo (opaca, con paralaje); bajo su orilla, el reflejo del agua
           (lo tapa la arena, pero el paralaje deja ver algo del borde)
  arena    la orilla de arena de delante, con lo que esta plantado en ella
           (juncos, piedras, ruinas sobre las dunas): se mueve con el juego.
           Las piezas del recorrido van encima. Y una copia de su parte de
           abajo (arena_delante) que va por delante de las piezas, para que
           su pie quede metido en la arena.

Los solapes se miden (SIFT) y se funden; la orilla se busca por el color de la
arena; lo plantado en ella, con GrabCut. Nada se pinta: recortes, fundidos y el
reflejo del agua de la propia imagen.

Escribe assets/egipto/acto1/tira/ (trozos de 2048 de ancho y tira.json).
Uso: python tools/egipto/tira.py [--vista ruta.jpg]
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ORIGEN = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_tira2")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "tira")
RES = "res://assets/egipto/acto1/tira/"

USAR = [0, 1, 2, 3, 4, 5]
ESCALA = 1.9            # px de juego por px de imagen (la arena)
ESCALA_PAISAJE = 1.3    # el paisaje, mas pequeno: mas cielo y la ciudad lejos
Y_PISA = 1460           # la linea de la arena (en la imagen) donde se pisa: y = 0 del juego
X0 = -800.0             # donde empieza la tira en el juego
PLANTA = 6.5
EXTRA_ABAJO = 700       # arena alargada por abajo (px de imagen)
EXTRA_ARRIBA = 600      # cielo alargado por arriba
TROZO = 2048


def leer(ruta):
    return cv2.imdecode(np.fromfile(ruta, np.uint8), cv2.IMREAD_COLOR)


def guardar(nombre, img):
    cv2.imencode(".png", img)[1].tofile(os.path.join(DESTINO, nombre + ".png"))


def transformacion(a, b):
    """La transformacion (2x3, similitud) que lleva b sobre a, por SIFT a media
    resolucion: las extensiones puras salen con escala 1; las retocadas con
    Paint pueden venir algo escaladas o desplazadas."""
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
    esc = float(np.hypot(H[0, 0], H[1, 0]))
    print("  solape: %d puntos, escala %.4f, dx %.1f, dy %.1f" % (inl.sum(), esc, H[0, 2], H[1, 2]))
    return np.vstack([H, [0, 0, 1]])


def coser(ims):
    """Cada imagen llevada a la primera (encadenando las transformaciones) y
    fundidas en el centro de cada solape."""
    Ts = [np.eye(3)]
    for a, b in zip(ims, ims[1:]):
        Ts.append(Ts[-1] @ transformacion(a, b))
    H = ims[0].shape[0]
    W = int(max(T[0, 2] + T[0, 0] * im.shape[1] for T, im in zip(Ts, ims))) + 1
    acum = np.zeros((H, W, 3), np.float32)
    peso = np.zeros((H, W), np.float32)
    xs = [T[0, 2] for T in Ts]
    for k, (im, T) in enumerate(zip(ims, Ts)):
        h, w = im.shape[:2]
        r = np.ones(w, np.float32)
        esc = T[0, 0]
        if k > 0:
            sol = int((xs[k - 1] + Ts[k - 1][0, 0] * ims[k - 1].shape[1] - xs[k]) / esc)
            f = min(400, sol)
            c0 = (sol - f) // 2
            r[:c0] = 0
            r[c0:c0 + f] = np.linspace(0, 1, f)
        if k < len(ims) - 1:
            sol = int((xs[k] + esc * w - xs[k + 1]) / esc)
            f = min(400, sol)
            c0 = w - sol + (sol - f) // 2
            r[c0:c0 + f] = np.minimum(r[c0:c0 + f], np.linspace(1, 0, f))
            r[c0 + f:] = 0
        M = T[:2]
        # (con el borde repetido: si viene algo mas pequena, no deja filas negras)
        warped = cv2.warpAffine(im.astype(np.float32), M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        rr = cv2.warpAffine(np.repeat(r[None, :], h, 0), M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
        # el peso, extendido en vertical (las filas que faltan arriba o abajo)
        col = rr.max(0)
        rr = np.maximum(rr, np.where(rr.sum(0) > 0, 0, 0)[None, :])
        rr[:, :] = np.maximum(rr, col[None, :] * 0)
        rr = np.where(rr > 0, rr, col[None, :])
        acum += warped * rr[..., None]
        peso += rr
    return np.clip(acum / np.maximum(peso, 1e-4)[..., None], 0, 255).astype(np.uint8)


def separar(im):
    """Mascara (float 0..1) de la arena de delante y lo plantado en ella, y la
    orilla (y por columna) para el reflejo."""
    H, W = im.shape[:2]
    e = 0.5
    p = cv2.resize(im, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
    hsv = cv2.cvtColor(p, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    # (el agua es clara y algo saturada; las sombras largas de la arena son
    # azuladas pero oscuras y apagadas: cuentan como arena)
    agua = (h >= 88) & (h <= 128) & (s > 45) & (v > 140)
    sombra = (v < 135) & (h >= 25) & (h <= 115)
    arena = ((h >= 6) & (h <= 26) & (s > 55) & (v > 60)) | sombra
    agua = cv2.morphologyEx(agua.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)) > 0
    hp, wp = p.shape[:2]
    # la arena de delante: de abajo hacia arriba mientras sea arena (tolera
    # huecos cortos: piedras, sombras, juncos pequenos)
    top = np.full(wp, hp, int)
    for x in range(wp):
        y = hp - 1
        hueco = 0
        ult = hp
        while y > hp * 0.3:
            if arena[y, x] and not agua[y, x]:
                ult = y
                hueco = 0
            else:
                hueco += 1
                if hueco > 18 or agua[y, x]:
                    break
            y -= 1
        top[x] = ult
    top = cv2.medianBlur(top.astype(np.float32).reshape(1, -1), 5).ravel()
    top = cv2.erode(top.reshape(1, -1), np.ones((1, 9), np.uint8)).ravel()
    yy = np.arange(hp)[:, None]
    seguro = yy > top[None, :] + 6
    # GrabCut en una banda por encima: lo plantado en la arena (juncos, piedras,
    # ruinas sobre las dunas) va con ella; el agua, la ciudad y el cielo, no
    m = np.full((hp, wp), cv2.GC_BGD, np.uint8)
    banda = (yy > top[None, :] - 190) & ~seguro
    m[banda] = cv2.GC_PR_BGD
    cerca = banda & ~agua & ((s > 60) | (v < 115))
    m[cerca] = cv2.GC_PR_FGD
    m[seguro] = cv2.GC_FGD
    m[agua & ~seguro] = cv2.GC_BGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(p, m, None, bgd, fgd, 5, cv2.GC_INIT_WITH_MASK)
    fg = np.isin(m, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    # solo lo que toca la arena de delante (sin islas sueltas en el agua)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    base = lab[hp - 1]
    quedan = set(int(b) for b in base if b > 0)
    fg = np.isin(lab, list(quedan)).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    a = cv2.resize(fg.astype(np.float32), (W, H), interpolation=cv2.INTER_LINEAR)
    a = cv2.GaussianBlur(a, (0, 0), 1.2)
    # la linea del agua: lo mas bajo del rio en cada columna; donde no hay rio
    # (la duna llega a la otra orilla), interpolada entre los lados
    fondo = np.full(wp, np.nan)
    for x in range(wp):
        ys = np.where(agua[int(hp * 0.3):int(Y_PISA * e), x])[0]
        if len(ys):
            fondo[x] = ys.max() + int(hp * 0.3)
    ok = ~np.isnan(fondo)
    fondo = np.interp(np.arange(wp), np.where(ok)[0], fondo[ok])
    # (lo mas bajo en una ventana ancha: tras la duna el agua que se ve esta mas
    # arriba; la orilla de verdad es la de los lados) y muy suave
    fondo = cv2.dilate(fondo.reshape(1, -1).astype(np.float32), np.ones((1, 751), np.uint8)).ravel()
    fondo = cv2.GaussianBlur(fondo.reshape(1, -1), (0, 0), 120).ravel()
    linea = cv2.resize(fondo.reshape(1, -1), (W, 1), interpolation=cv2.INTER_LINEAR).ravel() / e
    return np.clip(a, 0, 1), linea


def rellenar(im, hueco):
    """Rellena 'hueco' con lo de alrededor (inpaint a 1/4, suavizado)."""
    h, w = im.shape[:2]
    e = 0.25
    peq = cv2.resize(im, (int(w * e), int(h * e)), interpolation=cv2.INTER_AREA)
    hp = cv2.resize(hueco.astype(np.uint8) * 255, (peq.shape[1], peq.shape[0]), interpolation=cv2.INTER_NEAREST)
    hp = cv2.dilate(hp, np.ones((3, 3), np.uint8))
    rel = cv2.GaussianBlur(cv2.inpaint(peq, hp, 9, cv2.INPAINT_TELEA), (0, 0), 2.0)
    grande = cv2.resize(rel, (w, h), interpolation=cv2.INTER_CUBIC)
    m = cv2.GaussianBlur(hueco.astype(np.float32), (0, 0), 3.0)[..., None]
    return (im * (1 - m) + grande * m).astype(np.uint8)


def reflejar_bajo(im, linea, arena):
    """El paisaje detras de la arena: lo que tapaba la arena por encima de la
    linea del agua (ruinas de la duna), relleno con lo de alrededor; y bajo esa
    linea, el reflejo de lo de encima, como agua en calma."""
    H, W = im.shape[:2]
    lin = np.clip(linea, H * 0.35, H - 2).astype(int)
    yy = np.arange(H)[:, None]
    tapado = (cv2.dilate((arena > 0.3).astype(np.uint8), np.ones((15, 15), np.uint8)) > 0) & (yy < lin[None, :])
    # (lo de bajo la linea tambien se rellena: si no, el relleno cogia el color
    # de la arena de abajo)
    # lo tapado que cae en el agua (juncos de la orilla), por filas: el agua en
    # calma es horizontal, asi que cada fila se rellena con lo de sus lados (el
    # inpaint dejaba juncos fantasma emborronados)
    im = im.copy()
    xs_ = np.arange(W)
    for y in range(H):
        m = tapado[y]
        if m.any() and not m.all():
            for ch in range(3):
                im[y, m, ch] = np.interp(xs_[m], xs_[~m], im[y, ~m, ch]).astype(np.uint8)
    im = rellenar(im, yy >= lin[None, :])
    src = np.clip(2 * lin[None, :] - yy - 1, 0, H - 1)
    xs = np.arange(W)[None, :].repeat(H, 0)
    ref = cv2.GaussianBlur(im[src, xs].astype(np.float32), (0, 0), sigmaX=2.0, sigmaY=6.0) * 0.86
    debajo = cv2.GaussianBlur((yy >= lin[None, :]).astype(np.float32), (0, 0), 3.0)[..., None]
    return np.clip(im * (1 - debajo) + ref * debajo, 0, 255).astype(np.uint8)


def alargar_abajo(img, n):
    """Las ultimas filas, difuminadas, hacia abajo (mas suelo de arena)."""
    # (el color de la arena iluminada, no la media: las sombras azules la volvian gris)
    col = np.percentile(img[-150:].astype(np.float32), 75, axis=0)
    col = cv2.GaussianBlur(col.reshape(1, -1, img.shape[2]), (0, 0), sigmaX=60, sigmaY=0).reshape(-1, img.shape[2])
    y = np.linspace(0, 1, n)[:, None, None]
    ext = np.repeat(col[None], n, axis=0)
    ext[..., :3] *= (1 - 0.12 * y)
    if img.shape[2] == 4:
        ext[..., 3] = 255
    out = np.vstack([img.astype(np.float32), ext])
    f = 50
    r = np.linspace(0, 1, f)[:, None, None]
    out[img.shape[0] - f:img.shape[0]] = out[img.shape[0] - f:img.shape[0]] * (1 - r) + col[None] * r
    return np.clip(out, 0, 255).astype(np.uint8)


def alargar_arriba(img, n):
    est = img[:60]
    arriba = cv2.resize(est, (img.shape[1], n), interpolation=cv2.INTER_LINEAR)
    # (muy difuminado a lo ancho: cada imagen trae un tono de cielo y estirado
    # dejaba una frontera vertical)
    arriba = cv2.GaussianBlur(arriba, (0, 0), sigmaX=220, sigmaY=30)
    out = np.vstack([arriba, img]).astype(np.float32)
    f = 120
    r = np.linspace(0, 1, f)[:, None, None]
    out[n:n + f] = arriba[-1:].astype(np.float32) * (1 - r) + out[n:n + f] * r
    return np.clip(out, 0, 255).astype(np.uint8)


def trocear(nombre, img, y0_img, escala=ESCALA, y_casa=None):
    """Trozos de TROZO px de ancho; devuelve [{tex, x, y}] en px de juego. Con
    otra escala, la fila y_casa de la imagen queda donde quedaria a ESCALA (la
    linea del agua: el paisaje casa con la arena ahi)."""
    out = []
    yc = Y_PISA if y_casa is None else y_casa
    base = (yc - Y_PISA) * ESCALA - PLANTA              # y del juego de la fila y_casa
    for k, c in enumerate(range(0, img.shape[1], TROZO)):
        n = "%s_%d" % (nombre, k)
        guardar(n, img[:, c:c + TROZO])
        out.append({"tex": RES + n + ".png", "x": X0 + c * escala, "y": base + (y0_img - yc) * escala})
    return out


def linea_orilla_lejana(T, y0, y1):
    """La otra orilla: por columna, la primera fila de agua (de arriba abajo)
    entre y0-60 e y1; mediana ancha (los reflejos la hacen saltar)."""
    hsv = cv2.cvtColor(T, cv2.COLOR_BGR2HSV).astype(int)
    agua = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 128) & (hsv[..., 1] > 45) & (hsv[..., 2] > 140)
    H, W = agua.shape
    a0 = max(0, y0 - 60)
    sub = agua[a0:y1]
    # que haya agua en 6 filas seguidas (no un reflejo suelto)
    k = cv2.erode(sub.astype(np.uint8), np.ones((6, 1), np.uint8)) > 0
    hay = k.any(0)
    top = np.where(hay, k.argmax(0) + a0, y0).astype(np.float32)
    top = cv2.medianBlur(top.reshape(1, -1), 5).ravel()
    top = cv2.GaussianBlur(top.reshape(1, -1), (0, 0), 30).ravel()
    return top


def limpiar_borde(rgba, r=2.0):
    """El borde de un recorte con el color de su interior (sin halo del fondo)."""
    a = rgba[..., 3].astype(np.float32) / 255.0
    dentro = (a > 0.95).astype(np.float32)
    c = rgba[..., :3].astype(np.float32)
    num = cv2.GaussianBlur(c * dentro[..., None], (0, 0), r)
    den = cv2.GaussianBlur(dentro, (0, 0), r)[..., None]
    interior = np.where(den > 1e-3, num / np.maximum(den, 1e-3), c)
    borde = ((a > 0.0) & (a <= 0.95))[..., None]
    rgba[..., :3] = np.clip(np.where(borde, interior, c), 0, 255).astype(np.uint8)
    return rgba


def planos(pais, costa):
    """Separa el paisaje (ya alargado) en dos planos: el cielo (opaco) y la
    ciudad con las montanas, las piramides, la otra orilla y el rio. (Separar
    tambien la otra orilla: sus palmeras se confunden con los reflejos, y el rio
    no puede ir a otra velocidad que la ciudad sin que se despeguen los
    reflejos.) costa: la otra orilla por columna, en filas de pais."""
    H, W = pais.shape[:2]
    e = 0.25
    p = cv2.resize(pais, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
    hp, wp = p.shape[:2]
    yy = np.arange(hp)[:, None]
    cs = cv2.resize(costa.reshape(1, -1).astype(np.float32), (wp, 1)).ravel() * e
    # --- el cielo: GrabCut con el cielo de arriba seguro y lo de la orilla abajo seguro
    m = np.full((hp, wp), cv2.GC_PR_BGD, np.uint8)
    lab = cv2.cvtColor(p, cv2.COLOR_BGR2LAB).astype(np.float32)
    ref = cv2.GaussianBlur(lab, (0, 0), 25)
    # (cada columna comparada con el cielo de su altura: el cielo es un degradado suave)
    top_ref = lab[:int(hp * 0.25)].mean(0)
    liso = cv2.GaussianBlur(np.abs(cv2.Laplacian(cv2.cvtColor(p, cv2.COLOR_BGR2GRAY), cv2.CV_32F)), (0, 0), 2)
    m[(liso < 3.0) & (yy < cs[None, :] - 40)] = cv2.GC_PR_FGD
    m[:int((EXTRA_ARRIBA + 120) * e)] = cv2.GC_FGD
    m[yy > cs[None, :] - 25] = cv2.GC_BGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(p, m, None, bgd, fgd, 5, cv2.GC_INIT_WITH_MASK)
    cielo = np.isin(m, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    # el cielo, conectado con lo de arriba (no huecos de cielo sueltos en la ciudad)
    n, labs, st, _ = cv2.connectedComponentsWithStats(cielo, 4)
    arriba = set(int(v) for v in labs[0] if v > 0)
    cielo = np.isin(labs, list(arriba)).astype(np.uint8)
    # a tamano completo, con el borde suave
    a_cielo = cv2.resize(cielo.astype(np.float32), (W, H), interpolation=cv2.INTER_LINEAR)
    a_cielo = np.clip(cv2.GaussianBlur(a_cielo, (0, 0), 1.2), 0, 1)
    Y = np.arange(H)[:, None]
    # --- capa cielo (opaca): lo de la ciudad, relleno con el cielo de encima
    # (con el borde de la ciudad dentro: si no, su contorno quedaba en el cielo y
    # se veia como una linea al desplazarse las capas)
    hueco = cv2.dilate((a_cielo < 0.97).astype(np.uint8), np.ones((15, 15), np.uint8)) > 0
    cielo_img = rellenar(pais, hueco & (Y > EXTRA_ARRIBA))
    # --- capa ciudad, con el rio y sus reflejos (van juntos: el reflejo de cada
    # edificio queda siempre debajo de el)
    ciudad = limpiar_borde(np.dstack([pais, ((1.0 - a_cielo) * 255).astype(np.uint8)]))
    return cielo_img, ciudad


def main():
    os.makedirs(DESTINO, exist_ok=True)
    for f in os.listdir(DESTINO):
        if f.endswith(".png"):
            os.remove(os.path.join(DESTINO, f))
    ims = [leer(os.path.join(ORIGEN, "tira_%02d.png" % i)) for i in USAR]
    print("cosiendo", len(ims))
    T = coser(ims)
    print("tira", T.shape)
    a, orilla = separar(T)
    # paisaje: opaco, sin la arena (reflejo del agua bajo la orilla), con mas cielo
    pais = reflejar_bajo(T, orilla, a)
    pais = alargar_arriba(pais, EXTRA_ARRIBA)
    # y por abajo, mas agua (con la camara alta, la arena baja mas que el paisaje)
    pais = alargar_abajo(pais, 1100)
    # arena: con alfa, alargada por abajo
    arena = np.dstack([T, (a * 255).astype(np.uint8)])
    arena = alargar_abajo(arena, EXTRA_ABAJO)
    # arena de delante: la misma, desde algo por debajo de donde se pisa
    delante = arena.copy()
    y_corte = Y_PISA + 22
    rampa = np.clip((np.arange(delante.shape[0]) - y_corte) / 26.0, 0, 1)[:, None]
    delante[..., 3] = (delante[..., 3] * rampa).astype(np.uint8)
    delante = delante[y_corte:]
    # la franja del agua (filas de la imagen): de la otra orilla a la cercana
    hsv = cv2.cvtColor(T, cv2.COLOR_BGR2HSV).astype(int)
    agua = (hsv[..., 0] >= 88) & (hsv[..., 0] <= 128) & (hsv[..., 1] > 45) & (hsv[..., 2] > 140)
    filas = agua[:, ::8].mean(1)
    ys = np.where(filas > 0.5)[0]
    agua_y0, agua_y1 = (int(ys.min()), int(ys.max())) if len(ys) else (int(T.shape[0] * 0.6), int(T.shape[0] * 0.8))
    print("agua de la fila %d a la %d" % (agua_y0, agua_y1))
    costa = linea_orilla_lejana(T, agua_y0, agua_y1) + EXTRA_ARRIBA
    cielo, ciudad = planos(pais, costa)
    H2 = float(pais.shape[0])
    yc = int(np.median(orilla))
    def capa(nombre, img, p, py, extra=None):
        c = {"nombre": nombre, "p": p, "py": py, "escala": ESCALA_PAISAJE,
             "trozos": trocear(nombre, img, -EXTRA_ARRIBA, ESCALA_PAISAJE, yc)}
        c.update(extra or {})
        return c
    datos = {
        "escala": ESCALA,
        "y_pisa": Y_PISA,
        "ancho": T.shape[1] * ESCALA,
        "x0": X0,
        "capas": [
            capa("cielo", cielo, 0.1, 0.05, {"deriva": -6.0}),
            capa("ciudad", ciudad, 0.45, 0.22, {
                "agua": [(agua_y0 + EXTRA_ARRIBA) / H2, (agua_y1 + EXTRA_ARRIBA) / H2],
                "costa": (agua_y0 + EXTRA_ARRIBA) / H2}),
            {"nombre": "arena", "p": 1.0, "py": 1.0, "trozos": trocear("arena", arena, 0)},
            {"nombre": "arena_delante", "p": 1.0, "py": 1.0, "delante": True,
             "trozos": trocear("arena_delante", delante, y_corte)},
        ],
    }
    json.dump(datos, open(os.path.join(DESTINO, "tira.json"), "w", encoding="utf-8"), indent=1)
    print("capas escritas; ancho en el juego %.0f (de %.0f a %.0f)" % (datos["ancho"], X0, X0 + datos["ancho"]))
    if "--vista" in sys.argv:
        r = sys.argv[sys.argv.index("--vista") + 1]
        v = T.copy()
        mag = np.zeros_like(v)
        mag[:] = (255, 0, 255)
        aa = a[..., None]
        v2 = (v * aa + mag * (1 - aa) * 0.5 + v * (1 - aa) * 0.5).astype(np.uint8)
        cv2.line(v2, (0, Y_PISA), (v2.shape[1], Y_PISA), (0, 0, 255), 3)
        cv2.imencode(".jpg", cv2.resize(v2, None, fx=0.2, fy=0.2))[1].tofile(r)
        for nombre, img in (("cielo", cielo), ("ciudad", ciudad)):
            v = img.astype(np.float32)
            if v.shape[2] == 4:
                a3 = v[..., 3:4] / 255.0
                v = v[..., :3] * a3 + np.array([255, 0, 255], np.float32) * (1 - a3)
            cv2.imencode(".jpg", cv2.resize(v.astype(np.uint8), None, fx=0.15, fy=0.15))[1].tofile(
                r.replace(".jpg", "_%s.jpg" % nombre))


if __name__ == "__main__":
    main()
