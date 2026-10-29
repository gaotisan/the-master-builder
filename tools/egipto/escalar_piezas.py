"""LAS PIEZAS DEL RECORRIDO, ESCALADAS (2026-10-28, el usuario: "escala el templo
y vamos a usarlo ya escalado"; el de las terrazas se estiraba 1,8 en el juego y se
veia blando). Real-ESRGAN (x4plus-anime: es dibujo de tonos planos) a 4x y bajado
al factor de cada una; recorrido.py usa la escalada si esta (con su escala
dividida por el factor: las cajas siguen medidas en la original).

Como tools/anim/escalar_hoja.py: el color con el fondo rellenado del borde hacia
fuera (sin halo oscuro) y el alfa aparte; con trozos pequenos, y el resultado se
comprueba contra la original trozo a trozo (la Quadro, caliente, devuelve trozos
en negro sin error): si sale mal, se repite en la grafica integrada.

EL TONO (el usuario: "el tono de la piedra [de la losa] me gusta mas, no tan
naranja como el del templo"): las dos tienen la misma media, pero el templo
varia el doble en croma (sus caras al sol, muy naranjas); se lleva su a y su b
hacia los de la losa (TONO), sin tocar la luz.

EL GRANO: el modelo anime alisa la piedra (queda algo plastificada); se le
devuelve GRANO del detalle fino de la original (su luz, ampliada sin mas).

Salida: assets/egipto/acto1/piezas_hd/<pieza>.png y hd.json ({pieza: factor}).
Lo que sale del modelo se guarda en piezas_hd/_crudo/ (fuera del juego: .gdignore)
y se reutiliza (en la integrada el templo tarda minutos); --rehacer lo repite.
El escalador: engine/realesrgan (fuera del proyecto, junto a Godot).

Uso: python -I tools/egipto/escalar_piezas.py
"""
import json
import os
import shutil
import subprocess
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "anim"))
from escalar_hoja import rellenar  # noqa: E402

PROYECTO = os.path.dirname(os.path.dirname(AQUI))
PIEZAS = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas")
SALIDA = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas_hd")
EXE = os.path.normpath(os.path.join(PROYECTO, "..", "..", "engine", "realesrgan", "realesrgan-ncnn-vulkan.exe"))
TRABAJO = os.path.join(os.environ.get("TEMP", "."), "escalar_piezas")

# pieza -> factor (sobre la imagen recortada): el templo, a lo que se ve en el
# juego (1,8) y algo mas; la losa va a escala 1
FACTOR = {"templo_terrazas": 2.0, "kit_pilares_1": 1.5}
# el tono de la losa para el templo: [pieza, a, b, cuanto se acerca la variacion]
TONO = {"templo_terrazas": ("kit_pilares_1", 0.6)}
GRANO = 0.5
MARGEN = 16
TROZO = 128
BLOQUE = 32


def leer(n):
    return cv2.imread(os.path.join(PIEZAS, n + ".png"), cv2.IMREAD_UNCHANGED)


def tono(p, ref, k):
    """a y b de p hacia la media y la variacion de ref (la luz, L, igual)."""
    def lab(x):
        return cv2.cvtColor(x[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    lp, lr = lab(p), lab(ref)
    mp, mr = p[..., 3] > 200, ref[..., 3] > 200
    for c in (1, 2):
        sp, sr = lp[..., c][mp].std(), lr[..., c][mr].std()
        f = 1.0 + k * (sr / sp - 1.0)
        lp[..., c] = lr[..., c][mr].mean() + (lp[..., c] - lp[..., c][mp].mean()) * f
    bgr = cv2.cvtColor(np.clip(lp, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([bgr, p[..., 3]])


def bien(hecha, orig):
    """La escalada, devuelta a su tamano, se parece a la original trozo a trozo."""
    h, w = orig.shape[:2]
    v = cv2.resize(hecha, (w, h), interpolation=cv2.INTER_AREA).astype(np.float32)
    o = orig.astype(np.float32)
    malos = 0
    for by in range(0, h, BLOQUE):
        for bx in range(0, w, BLOQUE):
            ob, vb = o[by:by + BLOQUE, bx:bx + BLOQUE], v[by:by + BLOQUE, bx:bx + BLOQUE]
            mb = ob[..., 3] > 200
            if float(np.abs(vb[..., 3] - ob[..., 3]).mean()) > 60:
                malos += 1
            elif mb.sum() > 40 and float(np.abs(vb[..., :3] - ob[..., :3])[mb].mean()) > 45:
                malos += 1
    return malos


def escalar(p, factor, gpu):
    c = cv2.copyMakeBorder(p, MARGEN, MARGEN, MARGEN, MARGEN, cv2.BORDER_CONSTANT, value=(0, 0, 0, 0))
    al = c[..., 3].astype(np.float32) / 255.0
    for d in ("rgb", "alfa", "rgb4", "alfa4"):
        shutil.rmtree(os.path.join(TRABAJO, d), ignore_errors=True)
        os.makedirs(os.path.join(TRABAJO, d))
    cv2.imwrite(os.path.join(TRABAJO, "rgb", "p.png"),
                np.clip(rellenar(c[..., :3].astype(np.float32), al), 0, 255).astype(np.uint8))
    cv2.imwrite(os.path.join(TRABAJO, "alfa", "p.png"), cv2.merge([c[..., 3]] * 3))
    for d in ("rgb", "alfa"):
        subprocess.run([EXE, "-i", os.path.join(TRABAJO, d), "-o", os.path.join(TRABAJO, d + "4"),
                        "-n", "realesrgan-x4plus-anime", "-s", "4", "-t", str(TROZO), "-g", str(gpu),
                        "-m", os.path.join(os.path.dirname(EXE), "models")],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    H, W = c.shape[:2]
    W2, H2 = round(W * factor), round(H * factor)
    rgb = cv2.resize(cv2.imread(os.path.join(TRABAJO, "rgb4", "p.png")), (W2, H2), interpolation=cv2.INTER_AREA)
    a = cv2.resize(cv2.imread(os.path.join(TRABAJO, "alfa4", "p.png"))[..., 1], (W2, H2), interpolation=cv2.INTER_AREA)
    m = round(MARGEN * factor)
    return np.dstack([rgb, a])[m:H2 - m, m:W2 - m]


def grano(hecha, p, k):
    """Devuelve a la luz de la escalada el detalle fino de la original."""
    up = cv2.resize(p, (hecha.shape[1], hecha.shape[0]), interpolation=cv2.INTER_CUBIC)
    lu = cv2.cvtColor(up[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)[..., 0]
    det = lu - cv2.GaussianBlur(lu, (0, 0), 2.0)
    lh = cv2.cvtColor(hecha[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    lh[..., 0] += k * det
    bgr = cv2.cvtColor(np.clip(lh, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([bgr, hecha[..., 3]])


def main():
    crudo = os.path.join(SALIDA, "_crudo")
    os.makedirs(crudo, exist_ok=True)
    open(os.path.join(crudo, ".gdignore"), "w").close()
    hd = {}
    for n, factor in FACTOR.items():
        p = leer(n)
        if n in TONO:
            ref, k = TONO[n]
            p = tono(p, leer(ref), k)
        guardada = os.path.join(crudo, n + ".png")
        if os.path.exists(guardada) and "--rehacer" not in sys.argv:
            hecha = cv2.imread(guardada, cv2.IMREAD_UNCHANGED)
        else:
            for gpu in (1, 0, 0):
                hecha = escalar(p, factor, gpu)
                malos = bien(hecha, p)
                print("%s x%.1f gpu %d: %d trozos mal" % (n, factor, gpu, malos), flush=True)
                if malos == 0:
                    break
            cv2.imwrite(guardada, hecha)
        cv2.imwrite(os.path.join(SALIDA, n + ".png"), grano(hecha, p, GRANO))
        hd[n] = factor
    json.dump(hd, open(os.path.join(SALIDA, "hd.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
