"""EL FRENTE DEL ALTAR CON EL ESCARABAJO (2026-10-29; el usuario: "lo que habia
que hacer era sustituir el halcon o ave que habia en el altar por el
escarabajo", "ajustala en tamano y color"). La placa del escarabajo alado
(placa_escarabajo_0, de adornos.py) encajada en el hueco del frente del altar
(el del halcon, en la imagen del templo), tapandolo:
  - el tamano: el del hueco (RECUADRO, en el templo HD); la placa es mas
    cuadrada (1,43 frente a 2,1): se estira a lo ancho sobre todo por las alas
    (CENTRO, el escarabajo y el sol, casi sin estirar);
  - el color: la piedra de la placa a la del hueco (su luz y su tono, del
    mismo templo), con su luz de arriba abajo; la pintura (verde y roja) se
    queda, algo gastada (PINTURA), para que se lea como la pista.
Nada pintado: todo sale de la placa y del templo.

adornos.py lo llama al acabar (se guarda con los adornos: frente_escarabajo.png).
Uso suelto: python -I tools/egipto/frente_escarabajo.py [--ver carpeta]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ACTO = os.path.join(PROYECTO, "assets", "egipto", "acto1")
TEMPLO_HD = os.path.join(ACTO, "piezas_hd", "templo_terrazas.png")
HD = 2.0                                 # (piezas_hd/hd.json: el templo HD, al doble)
RECUADRO = (2926, 298, 3228, 442)        # el hueco del halcon en el templo HD (x0, y0, x1, y1)
CENTRO = (440, 800)                      # en la placa (su imagen): el sol, el escarabajo y sus patas
ESTIRA_CENTRO = 1.1                      # lo que se estira lo del centro (lo demas, lo que haga falta)
PINTURA = 0.75                           # lo que queda del color de la pintura (sobre el de la piedra)
GRANO_TONO = 0.6                         # lo que queda de las manchas de color de la piedra de la placa
LUZ_SIGMA = 25.0                         # px HD: la luz del hueco (sin el dibujo del halcon)


def _estirar(p, ancho, centro):
    """p a lo ancho 'ancho' (en px de p): lo de centro casi igual, las alas mas."""
    h, w = p.shape[:2]
    x = np.arange(w, dtype=np.float32)
    # cuanto ocupa cada columna de la placa: 1 en el centro, g fuera (suave)
    filo = 40.0
    dentro = np.clip((x - centro[0]) / filo + 0.5, 0, 1) * np.clip((centro[1] - x) / filo + 0.5, 0, 1)
    dentro = dentro * dentro * (3 - 2 * dentro)
    fuera = (1 - dentro).sum()
    g = (ancho - ESTIRA_CENTRO * dentro.sum()) / fuera
    dens = ESTIRA_CENTRO * dentro + g * (1 - dentro)
    destino = np.concatenate([[0.0], np.cumsum(dens)])      # x en el resultado de cada borde de columna
    xs = np.interp(np.arange(int(round(ancho)), dtype=np.float32) + 0.5, destino, np.arange(w + 1)) - 0.5
    mx = np.tile(xs.astype(np.float32), (h, 1))
    my = np.tile(np.arange(h, dtype=np.float32)[:, None], (1, mx.shape[1]))
    return cv2.remap(p, mx, my, cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def _pintura(lab):
    """Lo pintado de la placa (0..1): lo verde y lo rojo, lejos del tono de la piedra."""
    a = lab[..., 1] - 128.0
    b = lab[..., 2] - 128.0
    verde = np.clip((-a - 2.0) / 8.0, 0, 1)
    rojo = np.clip((a - b * 0.9 - 2.0) / 8.0, 0, 1)
    return np.maximum(verde, rojo)


def hacer(ruta_placa):
    placa = cv2.imread(ruta_placa, cv2.IMREAD_UNCHANGED)
    ys, xs = np.where(placa[..., 3] > 128)
    placa = placa[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    x0, y0, x1, y1 = RECUADRO
    W, H = x1 - x0, y1 - y0
    # el tamano: alto el del hueco, ancho estirado por las alas
    k = H / placa.shape[0]
    centro = (CENTRO[0] - xs.min(), CENTRO[1] - xs.min())
    # (el grano: la piedra de la placa es aspera y la del templo lisa, pintada;
    # se alisa sin perder el relieve ni el filo de la pintura)
    rgb = placa[..., :3]
    for _ in range(2):
        rgb = cv2.bilateralFilter(rgb, 9, 30, 6)
    placa = np.dstack([rgb, placa[..., 3]])
    p = _estirar(placa, W / k, centro)
    p = cv2.resize(p, (W, H), interpolation=cv2.INTER_AREA)
    # el color: la piedra del hueco del templo
    t = cv2.imread(TEMPLO_HD, cv2.IMREAD_UNCHANGED)[y0:y1, x0:x1]
    tl = cv2.cvtColor(t[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    lab = cv2.cvtColor(p[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    pint = _pintura(lab)
    piedra = (pint < 0.1) & (p[..., 3] > 200)
    out = lab.copy()
    for c in range(3):
        mp = np.median(lab[..., c][piedra])
        mt = np.median(tl[..., c])
        if c == 0:
            # la luz: su mediana y su contraste (lo de en medio, sin las rayas)
            sp = np.subtract(*np.percentile(lab[..., 0][piedra], [75, 25]))
            st = np.subtract(*np.percentile(tl[..., 0], [75, 25]))
            out[..., 0] = mt + (lab[..., 0] - mp) * (st / max(sp, 1e-3))
        else:
            # el tono: la piedra al del templo; la pintura, algo gastada
            out[..., c] = mt + (lab[..., c] - mp) * (pint * PINTURA + (1 - pint) * GRANO_TONO)
    # la luz del hueco (de arriba abajo, la sombra del borde de encima): lo
    # suave de la luz del templo, sin el dibujo del halcon
    luz = cv2.GaussianBlur(tl[..., 0], (0, 0), LUZ_SIGMA)
    out[..., 0] += luz - luz.mean()
    p[..., :3] = cv2.cvtColor(np.clip(out, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return p


def escala():
    """La escala del adorno (sus px son los del templo HD)."""
    return 1.8 / HD


def main():
    ruta = os.path.join(ACTO, "adornos", "placa_escarabajo_0.png")
    p = hacer(ruta)
    cv2.imwrite(os.path.join(ACTO, "adornos", "frente_escarabajo.png"), p)
    print("frente_escarabajo:", p.shape[1], "x", p.shape[0])
    if "--ver" in sys.argv:
        carpeta = sys.argv[sys.argv.index("--ver") + 1]
        t = cv2.imread(TEMPLO_HD, cv2.IMREAD_UNCHANGED)
        x0, y0, x1, y1 = RECUADRO
        m = 60
        c = t[y0 - m:y1 + m, x0 - m:x1 + m].copy()
        antes = c[..., :3].copy()
        a = p[..., 3:] / 255.0
        zona = c[m:m + p.shape[0], m:m + p.shape[1], :3].astype(np.float32)
        c[m:m + p.shape[0], m:m + p.shape[1], :3] = (p[..., :3] * a + zona * (1 - a)).astype(np.uint8)
        v = np.vstack([antes, c[..., :3]])
        cv2.imwrite(os.path.join(carpeta, "frente_escarabajo.png"), cv2.resize(v, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC))


if __name__ == "__main__":
    main()
