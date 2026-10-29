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
ARRIBA = 58          # por encima de lo mas alto del pilono (y 72); 576 filas -> 288, multiplo de 16 (Theora)
REDUCE = 0.5         # el video en el juego, a 640 de ancho: a la escala a la que se ve
X_PILONO = 780       # el centro del pilono alto
# ---- en la orilla de enfrente (px de la tira cosida, medio_orilla_0.png)
ESCALA = 0.52        # px de la orilla por px del video (las palmeras del video, como las de la orilla)
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
    x0 = X_TORRE - X_PILONO * e
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


def recortar(bgr):
    r = bgr[ARRIBA:CORTE]
    return cv2.resize(r, None, fx=REDUCE, fy=REDUCE, interpolation=cv2.INTER_AREA)


# ---- el barco (px del video)
RELEVO = 556         # el ultimo fotograma del video con el barco: luego, el suelto
PROA = 548           # (en el 556 la punta de la proa ya se sale del video: la de aqui)
RECORTE = (760, 380, 1280, 650)    # x0, y0, x1, y1 donde se busca el barco
POR_FOTOGRAMA = 4.71 # px que avanza (medido del 536 al 564; luego el video da un salto)
BANDA = (790, 395)   # desde aqui (x, y) el video lleva el barco borrado (la gente, a la izquierda)
FUNDIDO_BANDA = 16
CANVAS_BARCO = (760, 380, 1320, 650)  # el barco suelto: px del video (la proa pasa del borde)
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


def video(destino, ult):
    # (todo fotogramas clave: con los intermedios de este libtheora, el Theora de
    # Godot 4.6 sacaba bloques de colores en casi todo el video; 31 MB)
    alto = CORTE - ARRIBA
    ancho, alto_r = int(1280 * REDUCE), int(alto * REDUCE)
    ff = subprocess.Popen([FFMPEG, "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24",
                           "-s", "%dx%d" % (ancho, alto_r), "-r", "24", "-i", "-",
                           "-c:v", "libtheora", "-q:v", "9", "-g:v", "1", destino], stdin=subprocess.PIPE)
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
        if k > RELEVO:
            f = sin_barco(f, ult, ult_gris, mascara, peso)
        ff.stdin.write(np.ascontiguousarray(recortar(f)).tobytes())
        k += 1
    ff.stdin.close()
    if ff.wait():
        raise RuntimeError("ffmpeg")


def barco(destino):
    """El barco suelto para el juego: a la escala del video del juego y cortado
    en la linea del agua, como el templo. Devuelve lo que va en templo.json."""
    b = leer(os.path.join(ORIGEN, "barco.png"), cv2.IMREAD_UNCHANGED)
    d = json.load(open(os.path.join(ORIGEN, "barco.json"), encoding="utf-8"))
    b = b[:CORTE - d["y"]]
    # (premultiplicado al reducir: sin orla oscura)
    f = b.astype(np.float32)
    a = f[..., 3:] / 255.0
    f[..., :3] *= a
    r = cv2.resize(f, None, fx=REDUCE, fy=REDUCE, interpolation=cv2.INTER_AREA)
    ar = np.maximum(r[..., 3:] / 255.0, 1e-6)
    r[..., :3] = np.where(r[..., 3:] > 0.5, r[..., :3] / ar, 0)
    guardar(destino, np.clip(r, 0, 255).astype(np.uint8))
    return {
        "textura": RES + "barco.png",
        # px de la textura del templo (la del video del juego)
        "x": round(d["x"] * REDUCE, 2), "y": round((d["y"] - ARRIBA) * REDUCE, 2),
        "desde": d["fotograma"] / 24.0,
        "velocidad": round(POR_FOTOGRAMA * 24.0 * REDUCE, 2),
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

    guardar(os.path.join(DESTINO, "primero.png"), recortar(primero))
    guardar(os.path.join(DESTINO, "ultimo.png"), recortar(ultimo))
    video(os.path.join(DESTINO, "secuencia.ogv"), ultimo)
    cantos(os.path.join(DESTINO, "cantos.ogg"))
    datos_barco = barco(os.path.join(DESTINO, "barco.png"))
    # en el juego: px de la orilla -> coordenadas de su capa
    datos = {
        "capa": "orilla",
        "x": round(float(t0["x"]) + xi * ec, 1),
        "y": round(float(t0["y"]) + yi * ec, 1),
        # (unidades del juego por px de la textura)
        "escala": round(ESCALA / REDUCE * ec, 4),
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
