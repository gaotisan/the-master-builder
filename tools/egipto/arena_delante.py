"""LA ARENA DE DELANTE, DEL MISMO SUELO QUE LA DE DETRAS (2026-10-29; el usuario:
"hay una linea rara donde se une las piedras con la arena... parece que son
suelos distintos"). La franja de delante (medio_arena_delante_N, la que tapa el
pie de las piezas) es lo de abajo de la imagen de la playa: mas rosada, fria y
oscura que la arena de detras, con las sombras azules de las palmeras (la raya
oscura bajo su borde). Aqui se rehace de medio_arena_N (como capas.py: lo de
debajo de Y_CORTE, con su rampa de alfa) y:
  - el color: arriba, el de la arena de justo encima de la costura (que casen
    al juntarse); hacia abajo se deja algo de lo suyo (lo cercano, algo mas
    oscuro, ABAJO_QUEDA);
  - las sombras azules de palmera, a sombra de arena: su azul al color de la
    arena y su luz, a medio camino de la de alrededor (tambien en la arena de
    detras, medio_arena_N, que se reescribe: limpiar_azul).
Nada pintado: el color y la luz salen de la misma imagen.

capas.py lo llama al acabar. Uso suelto: python -I tools/egipto/arena_delante.py [--ver carpeta]
"""
import glob
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, AQUI)
import tira as T  # noqa: E402

PROYECTO = os.path.dirname(os.path.dirname(AQUI))
CAPAS = os.path.join(PROYECTO, "assets", "egipto", "acto1", "capas")
Y_CORTE = T.Y_PISA + 22      # (capas.py: medio(), y_corte)
RAMPA = 26.0
ENCIMA = (120, 20)           # filas por encima de la costura de donde se toma el color
ABAJO_QUEDA = 0.35           # lo que se deja del cambio de luz abajo del todo (el color, entero)
AZUL_DESDE = 3.0             # b de Lab por debajo del de la arena donde empieza a ser sombra azul
AZUL_HASTA = 12.0
LISO = 7.0                   # desviacion de la luz (Lab, 9 x 9) por encima de la cual es detalle, no sombra


def leer(r):
    return cv2.imread(r, cv2.IMREAD_UNCHANGED)


def _media_cercana(v, m, sigma):
    num = cv2.GaussianBlur(v * m, (0, 0), sigma)
    den = cv2.GaussianBlur(m, (0, 0), sigma)
    return np.where(den > 1e-3, num / np.maximum(den, 1e-3), v)


SUAVE_X = 300.0              # px: lo que se suaviza la correccion a lo largo (sin costuras entre trozos)
TOPE = 14.0                  # lo mas que se mueve cada canal de Lab


def _por_columnas(v, m, sigma):
    """La media por columna de v donde m, suavizada a lo largo (sigma px)."""
    num = cv2.GaussianBlur((v * m).sum(0, keepdims=True), (0, 0), sigmaX=sigma, sigmaY=0.01)
    den = cv2.GaussianBlur(m.sum(0, keepdims=True), (0, 0), sigmaX=sigma, sigmaY=0.01)
    return (num / np.maximum(den, 1e-3))[0]


def rehacer(arena):
    """arena: la tira entera de la arena (todos los trozos juntos)."""
    d = arena[Y_CORTE:].copy()
    H = d.shape[0]
    rampa = np.clip(np.arange(H) / RAMPA, 0, 1)[:, None]
    d[..., 3] = (d[..., 3] * rampa).astype(np.uint8)
    lab = cv2.cvtColor(d[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    ref = cv2.cvtColor(arena[Y_CORTE - ENCIMA[0]:Y_CORTE - ENCIMA[1], :, :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    # la arena de referencia por columna, sin sus sombras azules (lo mas amarillo
    # de cada zona: b por encima de su mediana local)
    rb = ref[..., 2]
    med_b = _por_columnas(rb, np.ones_like(rb), SUAVE_X)
    sel_r = (rb >= med_b[None, :]).astype(np.float32)
    objetivo = np.stack([_por_columnas(ref[..., k], sel_r, SUAVE_X) for k in range(3)], 1)   # (W, 3)
    # las sombras azules de delante
    azul = np.clip((objetivo[None, :, 2] - lab[..., 2] - AZUL_DESDE) / (AZUL_HASTA - AZUL_DESDE), 0, 1)
    # (filo blando: las sombras grandes de la imagen tienen el borde duro y, ya
    # sin el azul, quedaba una cuna marron recortada)
    azul = cv2.GaussianBlur(azul, (0, 0), 4.0)
    limpio = (azul < 0.05).astype(np.float32)
    L_alrededor = _media_cercana(lab[..., 0], limpio, 60.0)
    lab[..., 0] += azul * (L_alrededor - lab[..., 0]) * 0.85
    for k in (1, 2):
        lab[..., k] += azul * (objetivo[None, :, k] - lab[..., k])
    # el color hacia el de la arena de encima, por columna (de lo de arriba de la franja)
    arriba = lab[: H // 3]
    m = limpio[: H // 3]
    actual = np.stack([_por_columnas(arriba[..., k], m, SUAVE_X) for k in range(3)], 1)
    dif = np.clip(objetivo - actual, -TOPE, TOPE)
    y = np.linspace(0, 1, H)[:, None]
    k_luz = 1.0 - (1.0 - ABAJO_QUEDA) * y
    lab[..., 0] += dif[None, :, 0] * k_luz
    lab[..., 1] += dif[None, :, 1]
    lab[..., 2] += dif[None, :, 2]
    d[..., :3] = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return d, dif


def limpiar_azul(arena):
    """LA ARENA DE DETRAS, SIN LAS SOMBRAS AZULES DE PALMERA (2026-10-29): las
    que se veian entre las piedras (el shader solo las limpiaba en una franja a
    la altura del suelo). Lo azul respecto a la arena de alrededor (su b de Lab
    por debajo del de lo cercano), a sombra de arena: el color de la arena de al
    lado y la luz a medio camino. Solo en lo opaco (el filo con el agua, igual:
    si no, un halo color arena en la orilla). Se puede pasar dos veces: sin
    azul no cambia nada."""
    d = arena.copy()
    lab = cv2.cvtColor(d[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    opaco = (d[..., 3] > 230).astype(np.float32)
    b = lab[..., 2]
    # la arena de alrededor: lo que no queda por debajo de la media de la zona
    media = cv2.blur(b * opaco, (201, 61)) / np.maximum(cv2.blur(opaco, (201, 61)), 1e-3)
    m0 = ((b >= media - 1.0) * opaco).astype(np.float32)
    b_ref = _media_cercana(b, m0, 40.0)
    a_ref = _media_cercana(lab[..., 1], m0, 40.0)
    azul = np.clip((b_ref - b - AZUL_DESDE) / (AZUL_HASTA - AZUL_DESDE), 0, 1) * opaco
    # (solo lo liso: las matas de hierba plantadas en la arena tambien tienen
    # azules, pero con mucho detalle; una sombra es lisa. Por la desviacion de
    # la luz en 9 x 9, y lo que crece de lo descartado, fuera tambien)
    L = lab[..., 0]
    m1 = cv2.blur(L, (9, 9))
    desv = np.sqrt(np.maximum(cv2.blur(L * L, (9, 9)) - m1 * m1, 0))
    detalle = (desv > LISO).astype(np.uint8)
    # (las matas: manchas gruesas de detalle; los filos de una raya de sombra
    # fina tambien dan detalle, pero se van con la apertura)
    detalle = cv2.morphologyEx(detalle, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    detalle = cv2.morphologyEx(detalle, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
    detalle = cv2.dilate(detalle, np.ones((15, 15), np.uint8))
    azul *= 1.0 - detalle.astype(np.float32)
    azul = cv2.GaussianBlur(azul, (0, 0), 4.0) * opaco
    limpio = (azul < 0.05).astype(np.float32) * opaco
    L_alrededor = _media_cercana(lab[..., 0], limpio, 60.0)
    lab[..., 0] += azul * (L_alrededor - lab[..., 0]) * 0.85
    lab[..., 1] += azul * (a_ref - lab[..., 1])
    lab[..., 2] += azul * (b_ref - lab[..., 2])
    d[..., :3] = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return d, float((azul > 0.5).mean())


def main():
    carpeta = sys.argv[sys.argv.index("--ver") + 1] if "--ver" in sys.argv else None
    rutas = [r for r in glob.glob(os.path.join(CAPAS, "medio_arena_*.png"))
             if os.path.basename(r)[len("medio_arena_"):-4].isdigit()]
    rutas.sort(key=lambda r: int(os.path.basename(r)[len("medio_arena_"):-4]))
    trozos = [leer(r) for r in rutas]
    anchos = [t.shape[1] for t in trozos]
    arena, cuanto = limpiar_azul(np.hstack(trozos))
    print("arena de detras: %.1f %% era sombra azul" % (cuanto * 100))
    x = 0
    for r, w in zip(rutas, anchos):
        cv2.imwrite(r, arena[:, x:x + w])
        x += w
    d, dif = rehacer(arena)
    x = 0
    for r, w in zip(rutas, anchos):
        n = os.path.basename(r)[len("medio_arena_"):-4]
        p = d[:, x:x + w]
        cv2.imwrite(os.path.join(CAPAS, "medio_arena_delante_%s.png" % n), p)
        print("medio_arena_delante_%s: cambio Lab medio %s" % (n, dif[x:x + w].mean(0).round(1)))
        if carpeta:
            a = p[..., 3:] / 255.0
            v = (p[..., :3] * a + 255 * (1 - a)).astype(np.uint8)
            cv2.imwrite(os.path.join(carpeta, "delante_%s.jpg" % n), cv2.resize(v[:400], None, fx=0.5, fy=0.5))
        x += w


if __name__ == "__main__":
    main()
