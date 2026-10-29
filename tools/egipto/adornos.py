"""LOS ADORNOS DEL RECORRIDO DE PIEDRA (2026-10-28): las hojas del usuario sobre
croma verde (Downloads/elementos_egipto, copiadas en
raw/master_builder/referencias/egipto_adornos/): plantas, enredaderas que
cuelgan, arena amontonada, atrezzo y lo de primer plano. Recortadas y separadas
como las piezas de piedra (piezas.py), con dos diferencias:

- las hojas SON verdes: el croma se quita por lo cerca que esta cada pixel del
  verde puro del fondo (verde muy por encima de rojo y azul, y muy claro), no
  por ser verde; y el verde de los filos solo se quita en los filos;
- lo de primer plano (kit_delante) va mas oscuro y algo mas frio: esta en la
  sombra, entre la camara y el peregrino.

Salida: assets/egipto/acto1/adornos/<nombre>.png y adornos.json (tamanos); con
--hoja, una hoja de contactos con el nombre de cada pieza (para elegir).

Uso: python -I tools/egipto/adornos.py [--copiar] [--hoja[=ruta.png]]
"""
import json
import os
import shutil
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, AQUI)
import piezas  # noqa: E402  (leer, guardar, luz, recortar, separar)

PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ORIGEN = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_adornos")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "adornos")
DESCARGAS = os.path.join(os.path.expanduser("~"), "Downloads", "elementos_egipto")

NOMBRES = {
    "Colección de vegetación desértica antigua.png": "plantas_a",
    "Lámina de vegetación y ruinas desérticas.png": "plantas_b",
    "Hoja de recursos de enredaderas colgantes.png": "colgantes_a",
    "Hoja de recursos_ lianas y ruinas de piedra.png": "colgantes_b",
    "Hoja de recursos del desierto en ruinas.png": "arena_a",
    "Hoja de recursos_ dunas y ruinas del desierto.png": "arena_b",
    "Atrezzo egipcio sobre fondo verde croma.png": "atrezzo_a",
    "Hoja de accesorios del antiguo Egipto.png": "atrezzo_b",
    "Atrezzo del oasis en verde croma.png": "delante_a",
    "Elementos de Oasis y Ruinas en Pantalla Verde.png": "delante_b",
    "Ruinas egipcias y vegetación sobre fondo verde.png": "delante_c",
    # las dunas que entierran la base del templo (2026-10-28, ChatGPT; de
    # Downloads, no de elementos_egipto: copiadas a mano)
    "Hoja de sprites de dunas desérticas.png": "arena_dunas_a",
    "Hoja de sprites de dunas desérticas (1).png": "arena_dunas_b",
}

# las hojas con los objetos muy juntos: junta mas fina al separar
JUNTA = {"atrezzo_a": 1, "atrezzo_b": 1}

# los braseros (su llama pintada fuera: sin_llama)
BRASEROS = {"atrezzo_a_0", "atrezzo_b_4"}

# las enredaderas cuelgan de su propio trozo de repisa: fuera la piedra (las
# filas de arriba, hasta y; medido a ojo) y el corte, difuminado. Cuelgan del
# canto de las repisas del recorrido (recorrido.py, ADORNOS)
CORTE = {"colgantes_b_0": 120, "colgantes_b_1": 120, "colgantes_b_2": 100, "colgantes_b_3": 50,
         "colgantes_a_0": 123, "colgantes_a_2": 118, "colgantes_a_8": 100}
DIFUMINA = 16

CROMA = np.array([12.0, 248.0, 2.0], np.float32)   # (b, g, r) del fondo, medido

# lo de primer plano: en sombra (Lab: L y b)
DELANTE = {"dL": -38.0, "db": -8.0, "croma": 0.8}


def sin_croma(bgr):
    """Alfa por la distancia al croma: el fondo es verde puro y claro (g ~248,
    r y b ~0-20); una hoja, aunque sea verde, tiene rojo y es mas oscura."""
    f = bgr.astype(np.float32)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    # cuanto se parece al croma: verde sobre lo demas, y claro
    verde = g - np.maximum(r, b)
    k = np.clip((verde - 70.0) / (200.0 - 70.0), 0.0, 1.0) * np.clip((g - 120.0) / (230.0 - 120.0), 0.0, 1.0)
    a = 1.0 - k
    a = np.where(a < 0.06, 0.0, a)
    # motas sueltas fuera
    duro = (a > 0.5).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(duro, 8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 25:
            a[lab == i] = 0.0
    # la mezcla con el croma, sin el croma
    semi = (a > 0.05) & (a < 0.98)
    for c in range(3):
        ch = f[..., c]
        ch[semi] = np.clip((ch[semi] - (1.0 - a[semi]) * CROMA[c]) / a[semi], 0, 255)
    # el verde que quede en los filos (solo en los filos: las hojas se quedan)
    filo = cv2.dilate((a < 0.5).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    tope = np.maximum(f[..., 0], f[..., 2]) * 1.15 + 10.0
    f[..., 1] = np.where(filo, np.minimum(f[..., 1], tope), f[..., 1])
    return np.dstack([np.clip(f, 0, 255).astype(np.uint8), (a * 255).astype(np.uint8)])


def separar(bgra, junta=7):
    """Las piezas de la hoja: grupos de lo macizo (juntando lo que esta a menos
    de junta px), y lo pequeno suelto (piedrecillas, hojas caidas, la arena del
    pie) con el grupo grande mas cercano. En estas hojas las piezas casi se
    tocan por el suelo: con la junta grande de piezas.py salian filas enteras."""
    duro = (bgra[..., 3] > 160).astype(np.uint8)
    junto = cv2.dilate(duro, np.ones((junta, junta), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(junto, 8)
    grandes = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= 4000]
    if not grandes:
        return []
    # cada pixel con algo, del grande mas cercano (la distancia a cada grande)
    dist = []
    for i in grandes:
        fuera = (lab != i).astype(np.uint8)
        dist.append(cv2.distanceTransform(fuera, cv2.DIST_L2, 3))
    cual = np.argmin(np.stack(dist), axis=0)
    algo = bgra[..., 3] > 0
    piezas = []
    for k, i in enumerate(grandes):
        m = algo & (cual == k)
        ys, xs = np.nonzero(m)
        p = bgra.copy()
        p[..., 3] = np.where(m, p[..., 3], 0)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        piezas.append((y0, x0, y1 - y0, p[y0:y1, x0:x1]))
    # por filas, de izquierda a derecha (una fila: lo que acaba a la misma altura)
    piezas.sort(key=lambda t: (t[0] + t[2], t[1]))
    filas = []
    for t in piezas:
        if filas and abs((t[0] + t[2]) - (filas[-1][0][0] + filas[-1][0][2])) < 0.3 * t[2]:
            filas[-1].append(t)
        else:
            filas.append([t])
    out = []
    for f in filas:
        out += [t[3] for t in sorted(f, key=lambda t: t[1])]
    return out


def sin_llama(bgra):
    """Un brasero sin su llama pintada (la llama va por codigo y se mueve): fuera
    lo que esta por encima del borde del cuenco (la primera fila, de arriba
    abajo, que es casi entera de metal oscuro y ancha)."""
    a = bgra[..., 3] > 160
    lum = bgra[..., :3].astype(np.float32).mean(2)
    oscuro = a & (lum < 120)
    ancho = a.sum(1).max()
    for y in range(bgra.shape[0]):
        if oscuro[y].sum() > 0.5 * ancho:
            bgra = bgra.copy()
            bgra[:y, :, 3] = 0
            return piezas.recortar(bgra), y
    return bgra, 0


# A LA PALETA DEL TEMPLO (2026-10-28, el usuario: "quedan ahi pegadas"): las
# hojas de MJ vienen mucho mas saturadas y contrastadas que la piedra del
# templo; la arena, mas amarilla y clara que la de la playa.
#   arena: al color de la arena seca de la playa (medio_arena, junto a la linea
#   del suelo: Lab medido), con su sombreado algo suavizado
#   lo demas: menos croma y menos contraste (verde polvoriento, barro apagado)
ARENA = {"L": 170.0, "a": 141.6, "b": 152.5, "kL": 0.75, "kab": 0.45}
APAGAR = {"plantas": (0.72, 0.88), "colgantes": (0.74, 0.9), "atrezzo": (0.66, 0.86)}


def armonizar(bgra, nombre):
    lab = cv2.cvtColor(bgra[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    sel = bgra[..., 3] > 128
    if not sel.any():
        return bgra
    m = lab[sel].mean(0)
    if nombre.startswith("arena"):
        lab[..., 0] = ARENA["L"] + (lab[..., 0] - m[0]) * ARENA["kL"]
        lab[..., 1] = ARENA["a"] + (lab[..., 1] - m[1]) * ARENA["kab"]
        lab[..., 2] = ARENA["b"] + (lab[..., 2] - m[2]) * ARENA["kab"]
    else:
        croma, contraste = APAGAR.get(nombre.split("_")[0], (1.0, 1.0))
        lab[..., 0] = m[0] + (lab[..., 0] - m[0]) * contraste
        lab[..., 1] = 128.0 + (lab[..., 1] - 128.0) * croma
        lab[..., 2] = 128.0 + (lab[..., 2] - 128.0) * croma
    bgr = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([bgr, bgra[..., 3]])


def filas(p):
    """Recortada solo por arriba y por abajo (el ancho se queda: la parte de
    arriba y la de abajo de una enredadera, alineadas)."""
    ys = np.nonzero(p[..., 3].max(1) > 8)[0]
    return p[ys.min():ys.max() + 1] if len(ys) else p


def piedra_arriba(p):
    """La primera fila (de arriba abajo) que es piedra en buena parte."""
    f = p.astype(np.int32)
    b, g, r, a = f[..., 0], f[..., 1], f[..., 2], f[..., 3]
    piedra = (a > 160) & (r > g + 10) & (r > 120)
    fr = piedra.sum(1) / p.shape[1]
    ys = np.nonzero(fr > 0.12)[0]
    return int(ys[0]) if len(ys) else 0


def en_sombra(bgra):
    lab = cv2.cvtColor(bgra[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    lab[..., 0] += DELANTE["dL"]
    lab[..., 1] = 128.0 + (lab[..., 1] - 128.0) * DELANTE["croma"]
    lab[..., 2] = 128.0 + (lab[..., 2] - 128.0) * DELANTE["croma"] + DELANTE["db"]
    bgr = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([bgr, bgra[..., 3]])


def main():
    if "--copiar" in sys.argv:
        os.makedirs(ORIGEN, exist_ok=True)
        for f in NOMBRES:
            shutil.copy2(os.path.join(DESCARGAS, f), os.path.join(ORIGEN, f))
    os.makedirs(DESTINO, exist_ok=True)
    datos = {}
    colgar = {}
    for f, nombre in NOMBRES.items():
        img = armonizar(piezas.luz(sin_croma(piezas.leer(os.path.join(ORIGEN, f)))), nombre)
        if nombre.startswith("delante"):
            img = en_sombra(img)
        for i, p in enumerate(separar(img, JUNTA.get(nombre, 7))):
            p = piezas.recortar(p)
            n = "%s_%d" % (nombre, i)
            if n in BRASEROS:
                p, _ = sin_llama(p)
            if n in CORTE:
                # lo de arriba (las hojas sobre su trozo de repisa) va aparte: se
                # pone detras del templo, con su piedra tapada por la repisa de
                # la que cuelga, y asoman las hojas por encima
                arriba = p[:CORTE[n]].copy()
                piezas.guardar(os.path.join(DESTINO, n + "_arriba.png"), arriba)
                datos[n + "_arriba"] = [arriba.shape[1], arriba.shape[0]]
                colgar[n] = {"piedra": piedra_arriba(arriba), "corte": CORTE[n]}
                p = p[CORTE[n]:].copy()
                k = np.clip(np.arange(p.shape[0], dtype=np.float32) / DIFUMINA, 0.0, 1.0)
                p[..., 3] = (p[..., 3] * k[:, None]).astype(np.uint8)
                p = filas(p)
            piezas.guardar(os.path.join(DESTINO, n + ".png"), p)
            datos[n] = [p.shape[1], p.shape[0]]
        print(nombre, sum(1 for k in datos if k.startswith(nombre + "_")))
    datos["_colgar"] = colgar
    json.dump(datos, open(os.path.join(DESTINO, "adornos.json"), "w", encoding="utf-8"), indent=1)
    del datos["_colgar"]
    for a in sys.argv[1:]:
        if a.startswith("--hoja"):
            hoja(datos, a.split("=", 1)[1] if "=" in a else None)


def hoja(datos, ruta):
    """Todas las piezas sobre gris medio (se ve el filo) con su nombre."""
    celda = 260
    cols = 8
    nombres = sorted(datos)
    filas = (len(nombres) + cols - 1) // cols
    img = np.full((filas * (celda + 22), cols * celda, 3), 110, np.uint8)
    for i, n in enumerate(nombres):
        p = cv2.imread(os.path.join(DESTINO, n + ".png"), cv2.IMREAD_UNCHANGED)
        e = min((celda - 8) / p.shape[1], (celda - 8) / p.shape[0])
        p = cv2.resize(p, (max(1, int(p.shape[1] * e)), max(1, int(p.shape[0] * e))), interpolation=cv2.INTER_AREA)
        X = (i % cols) * celda + (celda - p.shape[1]) // 2
        Y = (i // cols) * (celda + 22) + (celda - p.shape[0])
        a = p[..., 3:] / 255.0
        sub = img[Y:Y + p.shape[0], X:X + p.shape[1]].astype(np.float32)
        img[Y:Y + p.shape[0], X:X + p.shape[1]] = (p[..., :3] * a + sub * (1 - a)).astype(np.uint8)
        cv2.putText(img, n, ((i % cols) * celda + 4, (i // cols) * (celda + 22) + celda + 16),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    ruta = ruta or os.path.join(os.environ.get("TEMP", "."), "adornos_hoja.png")
    cv2.imwrite(ruta, img)
    print("hoja:", ruta)


if __name__ == "__main__":
    main()
