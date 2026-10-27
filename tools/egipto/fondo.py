"""EL FONDO DEL ACTO I, sacado de las referencias (2026-10-25).

De las imagenes 17, 19 y 18 (las de horizonte a la misma altura: la ciudad
acaba hacia los 600 px), sin su primer plano (franjas.py), dos capas para el
paralaje:
  lejos  cielo, ciudad y piramides (opaca): lo del Nilo y las palmeras se
         quita y se rellena con lo de alrededor (inpaint), porque va en:
  medio  el Nilo, los juncos y las palmeras de cada imagen (con alfa: GrabCut
         sembrado por alturas y por el verde)
Cada capa es una tira cosida de las tres imagenes con fundidos largos. Y los
barcos (faluchos) de la imagen del ribazo al amanecer, sueltos, para que
naveguen por el agua de la capa media.

Nada se pinta: recortes, rellenos de lo de alrededor y fundidos.

Escribe assets/egipto/acto1/fondo/ (lejos.png, medio.png, barco_N.png) y
fondo.json. Uso: python tools/egipto/fondo.py [--vista ruta.jpg]
"""
import json
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from grado import graduar  # noqa: E402

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
REFS = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_primer_plano")
FRANJAS = os.path.join(AQUI, "_kit", "franjas")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "fondo")
RES = "res://assets/egipto/acto1/fondo/"

ORDEN = [17, 19, 18]
CIELO_EXTRA = 600
LINEA_AGUA = 60         # la orilla del agua en calma, por debajo de donde empieza el agua       # lo que se alarga el cielo por arriba
SOLAPE = 900            # fundido entre dos imagenes (px de la imagen)
# por imagen (resolucion completa): donde acaba la ciudad (empieza el verde) y
# donde empieza el agua
BASE = {17: 620, 18: 600, 19: 600}
AGUA = {17: 750, 18: 870, 19: 700}
# restos del primer plano que la franja no cogio (se quitan como el primer plano)
QUITAR = {18: [(1700, 640, 2220, 1160)], 17: [(1980, 690, 2220, 1000)]}
# los barcos de la imagen del ribazo (2048 x 2048): cajas x0, y0, x1, y1
BARCOS = {
    "barco_vela_blanca": (1190, 1080, 1305, 1290),
    "barco_lejano_a": (1680, 1150, 1730, 1240),
    "barco_lejano_b": (1950, 1150, 1995, 1300),
    "barco_vela_oscura": (1000, 940, 1170, 1320),
}


def leer(ruta, flags=cv2.IMREAD_COLOR):
    return cv2.imdecode(np.fromfile(ruta, np.uint8), flags)


def rellenar(im, hueco):
    """Rellena 'hueco' (bool) con lo de alrededor: inpaint a 1/4 y suavizado."""
    h, w = im.shape[:2]
    e = 0.25
    peq = cv2.resize(im, (int(w * e), int(h * e)), interpolation=cv2.INTER_AREA)
    hp = cv2.resize(hueco.astype(np.uint8) * 255, (peq.shape[1], peq.shape[0]), interpolation=cv2.INTER_NEAREST)
    hp = cv2.dilate(hp, np.ones((3, 3), np.uint8))
    rel = cv2.inpaint(peq, hp, 9, cv2.INPAINT_TELEA)
    rel = cv2.GaussianBlur(rel, (0, 0), 2.0)
    grande = cv2.resize(rel, (w, h), interpolation=cv2.INTER_CUBIC)
    m = cv2.GaussianBlur(hueco.astype(np.float32), (0, 0), 3.0)[..., None]
    return (im * (1 - m) + grande * m).astype(np.uint8)


def reflejar(im, hueco, linea):
    """Agua en calma desde la linea (horizontal) hacia abajo: el reflejo de lo de
    encima (juncos, orilla), borroso en vertical, mas oscuro y azulado hacia
    abajo. Lo del hueco (el primer plano) que quede por encima de la linea se
    rellena con lo de alrededor."""
    H, W = hueco.shape
    yy = np.arange(H)[:, None]
    h2 = cv2.dilate(hueco.astype(np.uint8), np.ones((31, 31), np.uint8)) > 0
    im = rellenar(im, h2 | (yy > linea + 40))
    src = np.clip(2 * linea - np.arange(H) - 1, 0, H - 1)
    ref = im[src].astype(np.float32)
    ref = cv2.GaussianBlur(ref, (0, 0), sigmaX=2.0, sigmaY=6.0)
    prof = np.clip((yy - linea) / 600.0, 0, 1)[..., None]
    tinte = np.array([0.97, 0.9, 0.8], np.float32)             # BGR: hacia el azul del agua
    agua = ref * tinte * (0.88 - 0.3 * prof)
    # la orilla: una linea de luz fina
    debajo = (yy >= linea).astype(np.float32) * np.ones((1, W), np.float32)
    m = cv2.GaussianBlur(debajo, (0, 0), 2.0)[..., None]
    out = im * (1 - m) + agua * m
    out[linea:linea + 2] = out[linea:linea + 2] * 0.85 + 255 * 0.15 * np.array([0.95, 0.97, 1.0])
    return np.clip(out, 0, 255).astype(np.uint8)


def separar(i):
    im = leer(os.path.join(REFS, "ref_%02d.png" % i))
    H, W = im.shape[:2]
    pp = leer(os.path.join(FRANJAS, "r%02d.png" % i), cv2.IMREAD_UNCHANGED)[..., 3] > 60
    pp = cv2.dilate(pp.astype(np.uint8), np.ones((15, 15), np.uint8)) > 0
    # QUITAR: se tapa clonando lo de su izquierda (palmeras y juncos), fundido
    for x0, y0, x1, y1 in QUITAR.get(i, []):
        w = x1 - x0
        sx = max(0, x0 - w - 60)
        trozo = im[y0:y1, sx:sx + w].astype(np.float32)
        r = np.ones((y1 - y0, w), np.float32)
        f = 60
        r[:, :f] *= np.linspace(0, 1, f)[None, :]
        r[:, -f:] *= np.linspace(1, 0, f)[None, :]
        r[:f, :] *= np.linspace(0, 1, f)[:, None]
        r = r[..., None]
        im[y0:y1, x0:x1] = (im[y0:y1, x0:x1] * (1 - r) + trozo * r).astype(np.uint8)
        pp[y0:y1, x0:x1] &= False
    hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    verde = (h >= 25) & (h <= 95) & (s > 55) & (v < 190)
    yy = np.arange(H)[:, None] * np.ones((1, W), int)
    base, agua = BASE[i], AGUA[i]
    m = np.full((H, W), cv2.GC_PR_BGD, np.uint8)
    m[(yy > base - 260) & verde] = cv2.GC_PR_FGD
    m[(yy < base - 140) & ~verde] = cv2.GC_BGD
    m[yy < base - 330] = cv2.GC_BGD
    m[yy > agua + 20] = cv2.GC_FGD
    m[pp] = cv2.GC_FGD
    e = 0.5
    ims = cv2.resize(im, None, fx=e, fy=e, interpolation=cv2.INTER_AREA)
    ms = cv2.resize(m, (ims.shape[1], ims.shape[0]), interpolation=cv2.INTER_NEAREST)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(ims, ms, None, bgd, fgd, 5, cv2.GC_INIT_WITH_MASK)
    medio = np.isin(ms, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    medio = cv2.resize(medio, (W, H), interpolation=cv2.INTER_LINEAR)
    medio = cv2.morphologyEx(medio, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    alfa = cv2.GaussianBlur(medio.astype(np.float32), (0, 0), 1.2)
    # medio: la imagen sin el primer plano; lo de debajo, el reflejo en el agua
    # de lo que hay encima (cada columna, desde donde empezaba el primer plano)
    rgb_medio = reflejar(im, pp, AGUA[i] + LINEA_AGUA)
    # lejos: sin el primer plano
    # (solo el primer plano: lo del medio se queda tambien aqui; con el paralaje
    # se ve como mas palmeras detras, y no como neblina rellenada)
    hueco = pp
    rgb_lejos = rellenar(im, hueco)
    return rgb_lejos, np.dstack([rgb_medio, (alfa * 255).astype(np.uint8)])


def coser(trozos, opaca):
    """Une las imagenes de izquierda a derecha con fundidos de SOLAPE px."""
    H = trozos[0].shape[0]
    W = sum(t.shape[1] for t in trozos) - SOLAPE * (len(trozos) - 1)
    c = 3 if opaca else 4
    acum = np.zeros((H, W, c), np.float32)
    peso = np.zeros((H, W, 1), np.float32)
    x = 0
    for k, t in enumerate(trozos):
        w = t.shape[1]
        r = np.ones(w, np.float32)
        if k > 0:
            r[:SOLAPE] = np.linspace(0, 1, SOLAPE)
        if k < len(trozos) - 1:
            r[-SOLAPE:] = np.minimum(r[-SOLAPE:], np.linspace(1, 0, SOLAPE))
        r = (r * r * (3 - 2 * r))[None, :, None]           # suave
        tt = t.astype(np.float32)
        if not opaca:
            # premultiplicado: el alfa se funde con el color
            tt[..., :3] *= tt[..., 3:4] / 255.0
        acum[:, x:x + w] += tt * r
        peso[:, x:x + w] += r
        x += w - SOLAPE
    out = acum / np.maximum(peso, 1e-4)
    if not opaca:
        a = out[..., 3:4] / 255.0
        out[..., :3] = np.where(a > 1e-3, out[..., :3] / np.maximum(a, 1e-3), 0)
    return np.clip(out, 0, 255).astype(np.uint8)


def barcos():
    import glob
    f = glob.glob(os.path.join(os.path.expanduser("~"), "Downloads", "gaotisan_ancient_Egyptian_riverbank_at_dawn*"))
    copia = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_primer_plano", "ribazo_barcos.png")
    if f and not os.path.exists(copia):
        import shutil
        shutil.copy2(f[0], copia)
    im = leer(copia)
    out = []
    for nombre, (x0, y0, x1, y1) in BARCOS.items():
        m = 14
        X0, Y0, X1, Y1 = max(0, x0 - m), max(0, y0 - m), min(im.shape[1], x1 + m), min(im.shape[0], y1 + m)
        sub = im[Y0:Y1, X0:X1].copy()
        mask = np.full(sub.shape[:2], cv2.GC_BGD, np.uint8)
        mask[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0] = cv2.GC_PR_FGD
        bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
        try:
            cv2.grabCut(sub, mask, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
        except cv2.error:
            continue
        fg = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
        n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
        if n > 1:
            k = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
            fg = (lab == k).astype(np.uint8)
        a = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 0.8)
        rgba = np.dstack([sub, (a * 255).astype(np.uint8)])
        ys, xs = np.where(fg > 0)
        if len(ys) == 0:
            continue
        rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        cv2.imencode(".png", rgba)[1].tofile(os.path.join(DESTINO, nombre + ".png"))
        out.append({"tex": RES + nombre + ".png", "w": int(rgba.shape[1]), "h": int(rgba.shape[0])})
    return out


def main():
    os.makedirs(DESTINO, exist_ok=True)
    lejos, medio = [], []
    tramos = []
    x = 0
    for i in ORDEN:
        l, m = separar(i)
        lejos.append(l)
        medio.append(m)
        tramos.append({"ref": i, "x0": x, "x1": x + l.shape[1], "agua": AGUA[i] + CIELO_EXTRA, "base": BASE[i] + CIELO_EXTRA})
        x += l.shape[1] - SOLAPE
        print("separada", i)
    L = coser(lejos, True)
    M = coser(medio, False)
    # el cielo, alargado por arriba (sus primeras filas estiradas: es un degradado)
    extra = CIELO_EXTRA
    arriba = cv2.resize(L[:40], (L.shape[1], extra), interpolation=cv2.INTER_LINEAR)
    arriba = cv2.GaussianBlur(arriba, (0, 0), sigmaX=6, sigmaY=20)
    L = np.vstack([arriba, L])
    # el cielo de arriba, con las pinceladas de las imagenes de estilo (no
    # estirado): la franja de cielo limpia de estilo_1, en espejo a lo ancho, con el
    # color de lo de arriba de nuestra imagen, fundida en ella
    est = leer(os.path.join(REFS, "estilo_1.png"))[0:150]
    est = cv2.resize(est, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
    fila = []
    k = 0
    while sum(f.shape[1] for f in fila) < L.shape[1]:
        fila.append(est if k % 2 == 0 else est[:, ::-1])
        k += 1
    cielo = np.hstack(fila)[:, :L.shape[1]]
    cielo = cv2.resize(cielo, (L.shape[1], extra + 200), interpolation=cv2.INTER_LINEAR).astype(np.float32)
    # mismo color medio que la parte de arriba de nuestra imagen
    ref_m = L[extra:extra + 80].reshape(-1, 3).astype(np.float32).mean(0)
    cielo += (ref_m - cielo[-80:].reshape(-1, 3).mean(0))
    L = L.astype(np.float32)
    L[:extra] = cielo[:extra]
    f = 200
    r = np.linspace(0, 1, f)[:, None, None]
    L[extra:extra + f] = cielo[extra:extra + f] * (1 - r) + L[extra:extra + f] * r
    L = np.clip(L, 0, 255).astype(np.uint8)
    M = np.vstack([np.zeros((extra, M.shape[1], 4), np.uint8), M])
    L = graduar(L, "lejos")
    M = graduar(M, "medio")
    cv2.imencode(".png", L)[1].tofile(os.path.join(DESTINO, "lejos.png"))
    cv2.imencode(".png", M)[1].tofile(os.path.join(DESTINO, "medio.png"))
    bs = barcos()
    datos = {
        "alto": int(L.shape[0]),
        "cielo_extra": CIELO_EXTRA,
        "capas": [
            {"nombre": "lejos", "tex": RES + "lejos.png", "ancho": int(L.shape[1]), "paralaje": 0.12, "paralaje_y": 0.04},
            {"nombre": "medio", "tex": RES + "medio.png", "ancho": int(M.shape[1]), "paralaje": 0.34, "paralaje_y": 0.12},
        ],
        "tramos": tramos,
        "barcos": bs,
    }
    json.dump(datos, open(os.path.join(DESTINO, "fondo.json"), "w", encoding="utf-8"), indent=1)
    print("lejos", L.shape, "medio", M.shape, "barcos", len(bs))
    if "--vista" in sys.argv:
        r = sys.argv[sys.argv.index("--vista") + 1]
        v = L.astype(np.float32)
        a = M[..., 3:4] / 255.0
        v = v * (1 - a) + M[..., :3] * a
        cv2.imencode(".jpg", cv2.resize(v.astype(np.uint8), None, fx=0.25, fy=0.25))[1].tofile(r)
        mm = M.copy()
        mm[M[..., 3] < 128, :3] = (255, 0, 255)
        cv2.imencode(".jpg", cv2.resize(mm[..., :3], None, fx=0.25, fy=0.25))[1].tofile(r.replace(".jpg", "_medio.jpg"))


if __name__ == "__main__":
    main()
