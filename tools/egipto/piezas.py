"""LAS PIEZAS DE PIEDRA DEL RECORRIDO (2026-10-28): las imagenes del usuario sobre
croma verde (Downloads/piezas_piedra, copiadas en
raw/master_builder/referencias/egipto_piezas/) recortadas, sin el verde en los
filos, con la luz de la playa, y los kits (hojas con varias piezas) separados en
piezas sueltas.

Salida: assets/egipto/acto1/piezas/<nombre>.png (recortadas a lo que hay) y
piezas.json con el tamano de cada una. El recorrido (recorrido.py) las coloca.

Uso: python -I tools/egipto/piezas.py [--copiar]
  --copiar: copia antes las imagenes de Downloads/piezas_piedra a raw/.
"""
import json
import os
import shutil
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
ORIGEN = os.path.join(PROYECTO, "raw", "master_builder", "referencias", "egipto_piezas")
DESTINO = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas")
DESCARGAS = os.path.join(os.path.expanduser("~"), "Downloads", "piezas_piedra")

# nombre corto de cada imagen (el orden de la carpeta del usuario); las de "kit"
# se separan en piezas sueltas (kit_<n>_<i>, de izquierda a derecha y de arriba abajo)
NOMBRES = {
    "Arco de arenisca sobre fondo verde.png": "arco_bajo",
    "Columna de piedra arenisca egipcia.png": "bloque_grande",
    "Columna egipcia de loto en piedra arenisca.png": "columna_loto",
    "Hoja de bloques de piedra en verde croma.png": "kit_pilares",
    "Hoja de recursos de ruinas desérticas.png": "kit_ruinas",
    "Kit de ruinas egipcias estilizadas.png": "kit_egipcio",
    "Muro de piedra antiguo sobre fondo verde.png": "muro_puerta",
    "Muro de piedra arenisca estilizado-2.png": "muro_largo",
    "Obelisco egipcio con jeroglíficos sobre verde croma.png": "obelisco",
    "Obelisco y columna egipcios estilizados.png": "kit_obelisco",
    "Pasadizo rocoso de arenisca.png": "pasadizo",
    "Plataforma de arenisca sobre fondo verde.png": "plataforma_alta",
    "Plataforma de piedra agrietada en verde croma (1).png": "plataforma_baja",
    "Plataforma rocosa de arenisca desértica.png": "plataforma_rocosa",
    "Portal egipcio en ruinas sobre fondo verde croma.png": "portal_caido",
    "Puente egipcio antiguo en ruinas-1.png": "puente_dintel",
    "Puente egipcio antiguo sobre fondo verde-3.png": "puente_arcos",
    "Puente egipcio de piedra tallada.png": "puente_corto",
    "Ruinas de piedra arenisca en plataforma.png": "ruina_mesa",
    "Ruinas de piedra del desierto.png": "ruina_torre",
    "Ruinas de piedra egipcias sobre fondo verde.png": "kit_muro_portico",
    "Ruinas de piedra en el desierto.png": "ruina_escalera",
    "Ruinas de piedra sobre fondo verde (1).png": "ruina_base_rocosa",
    "Ruinas de piedra sobre fondo verde.png": "gradas",
    "Ruinas de piedra sobre plataforma unerquicklich.png": "ruina_escalinata",
    "Ruinas de templo de arena en plataformas.png": "templo_pisos",
    # (2026-10-28: el mismo templo repintado por ChatGPT, algo mas gastado,
    # alineado sobre el original: "Ruinas antiguas de templo de arenisca
    # (ChatGPT).png" -> ECC afin, la silueta casa al 97 %; se recorta como el
    # original, RECORTE, para que sus cajas sigan valiendo)
    "Ruinas de templo egipcio, desgastado (alineado).png": "templo_terrazas",
    "Ruinas egipcias bajo el sol cálido.png": "templo_rampa",
    "Ruinas egipcias bajo un sol alado.png": "portico_caido",
    "Templo egipcio de piedra en ruinas.png": "templo_escalinata",
}
# (las "(1)" y "-2"/"-3" repetidas son la misma imagen: se usa una)

# el recorte de una pieza fijo (y0, y1, x0, x1 en su imagen): la del original,
# cuando se cambia por otra version alineada
RECORTE = {"templo_terrazas": (13, 850, 21, 1765)}

# la luz de la playa (como LUZ_ARENA de capas.py, algo menos): el naranja
# saturado de las imagenes, hacia la caliza palida del acto
SOMBRA_FRIA = 12.0   # cuanto azul (b de Lab) se llevan las sombras mas hondas
LUZ_CALIDA = 4.0     # y cuanto amarillo las luces
LUZ = {"dL": -6.0, "da": -2.0, "db": -6.0, "croma": 0.86, "contraste": 1.08}


def leer(ruta):
    return cv2.imdecode(np.fromfile(ruta, np.uint8), cv2.IMREAD_COLOR)


def guardar(ruta, img):
    ok, buf = cv2.imencode(".png", img)
    buf.tofile(ruta)


def sin_croma(bgr):
    """Alfa por lo verde que es cada pixel (verde menos lo mayor de rojo y azul),
    y el verde quitado de los filos."""
    f = bgr.astype(np.float32)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    verde = g - np.maximum(r, b)
    # el croma es ~(0, 255, 0): verde > 150; la piedra, naranja: verde < 0
    a = np.clip((120.0 - verde) / (120.0 - 30.0), 0.0, 1.0)
    # lo que cae dentro del croma del todo, fuera (motas sueltas)
    duro = (a > 0.5).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(duro, 8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 60:
            a[lab == i] = 0.0
    # lo que era mezcla con el croma, sin el croma: color = (c - (1-a)*croma)/a
    croma = np.array([20.0, 250.0, 20.0], np.float32)
    semi = (a > 0.05) & (a < 0.98)
    for k in range(3):
        c = f[..., k]
        c[semi] = np.clip((c[semi] - (1.0 - a[semi]) * croma[k]) / a[semi], 0, 255)
    # y el verde que quede en los filos: g no pasa de lo mayor de r y b (la
    # piedra no es verde)
    f[..., 1] = np.minimum(f[..., 1], np.maximum(f[..., 0], f[..., 2]) * 0.98 + 2.0)
    out = np.dstack([np.clip(f, 0, 255).astype(np.uint8), (a * 255).astype(np.uint8)])
    return out


def luz(bgra):
    lab = cv2.cvtColor(bgra[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    sel = bgra[..., 3] > 128
    if sel.any():
        m = lab[sel].mean(0)
    else:
        m = lab.reshape(-1, 3).mean(0)
    lab[..., 0] = m[0] + (lab[..., 0] - m[0]) * LUZ["contraste"] + LUZ["dL"]
    for k, dk in ((1, "da"), (2, "db")):
        lab[..., k] = 128.0 + (lab[..., k] - 128.0) * LUZ["croma"] + LUZ[dk]
    # las sombras, frias como las del fondo (el cielo las llena de azul) y las
    # luces, un punto mas calidas: si no, la sombra de la piedra salia marron
    # y la pieza no parecia del mismo sitio
    t = np.clip((m[0] - lab[..., 0]) / 70.0, -1.0, 1.0)
    lab[..., 2] -= np.where(t > 0, t * SOMBRA_FRIA, t * LUZ_CALIDA)
    lab[..., 1] -= np.where(t > 0, t * 2.0, 0.0)
    bgr = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return np.dstack([bgr, bgra[..., 3]])


def recortar(bgra, margen=2):
    ys, xs = np.nonzero(bgra[..., 3] > 8)
    if len(xs) == 0:
        return bgra
    y0, y1 = max(ys.min() - margen, 0), min(ys.max() + margen + 1, bgra.shape[0])
    x0, x1 = max(xs.min() - margen, 0), min(xs.max() + margen + 1, bgra.shape[1])
    return bgra[y0:y1, x0:x1]


def separar(bgra):
    """Las piezas de un kit: grupos de lo opaco (juntando lo que esta a menos de
    25 px: los cascotes al pie de cada pieza van con ella)."""
    duro = (bgra[..., 3] > 100).astype(np.uint8)
    junto = cv2.dilate(duro, np.ones((25, 25), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(junto, 8)
    piezas = []
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 3000:
            continue
        x, y, w, h = st[i, :4]
        m = (lab == i)
        p = bgra.copy()
        p[..., 3] = np.where(m, p[..., 3], 0)
        p = p[y:y + h, x:x + w]
        piezas.append((y, x, h, p))
    # por filas (de arriba abajo, una fila = lo que empieza a menos de media pieza)
    piezas.sort(key=lambda t: (t[0] + t[2] // 2, t[1]))
    filas = []
    for t in piezas:
        if filas and abs((t[0] + t[2] / 2) - (filas[-1][0][0] + filas[-1][0][2] / 2)) < t[2] * 0.5:
            filas[-1].append(t)
        else:
            filas.append([t])
    out = []
    for f in filas:
        out += [t[3] for t in sorted(f, key=lambda t: t[1])]
    return out


def main():
    if "--copiar" in sys.argv:
        os.makedirs(ORIGEN, exist_ok=True)
        for f in NOMBRES:
            shutil.copy2(os.path.join(DESCARGAS, f), os.path.join(ORIGEN, f))
    os.makedirs(DESTINO, exist_ok=True)
    datos = {}
    for f, nombre in NOMBRES.items():
        img = luz(sin_croma(leer(os.path.join(ORIGEN, f))))
        if nombre.startswith("kit_"):
            for i, p in enumerate(separar(img)):
                p = recortar(p)
                n = "%s_%d" % (nombre, i)
                guardar(os.path.join(DESTINO, n + ".png"), p)
                datos[n] = [p.shape[1], p.shape[0]]
        else:
            if nombre in RECORTE:
                y0, y1, x0, x1 = RECORTE[nombre]
                p = img[y0:y1, x0:x1]
            else:
                p = recortar(img)
            guardar(os.path.join(DESTINO, nombre + ".png"), p)
            datos[nombre] = [p.shape[1], p.shape[0]]
        print(nombre)
    json.dump(datos, open(os.path.join(DESTINO, "piezas.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
