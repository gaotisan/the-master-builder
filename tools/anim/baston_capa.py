"""EL BASTON SIGUE A LA CAPA (2026-10-30, Egipto; el usuario, de la caida cuando
te tiras corriendo: "la capa trasera se separa del cuerpo... deja entrever el
baculo", "no es coherente con que el baculo este cogido a esa capa en dos puntos
arriba y abajo"). En salto_correr 30-42 la tunica de atras sube como una vela y
la vara de baston_seguimiento.json colgaba recta y entera debajo (hasta 241 px
de madera suelta entre la capa y las piernas).

Aqui, con el pivote donde estaba (la presilla de arriba, en la espalda), el
baston se gira hacia atras (giro mayor: la punta de abajo hacia la espalda) lo
justo para quedar dentro de la capa: por cada fotograma, el giro mas cercano al
de siempre con la madera mas larga dentro de la silueta (encogida lo que mide la
madera de ancho); suavizado, y entrando y saliendo poco a poco. Lo que aun asome
por abajo se recorta (corte, como en baston_caida.py).
Filas como baston_caida.json: [x, y, giro, visible (0 detras), corte].

Salida: assets/characters/baston/baston_capa.json (baston.gd la usa en lugar de
baston_seguimiento.json para esas animaciones).
Uso (desde el proyecto): python -I tools/anim/baston_capa.py [--ver carpeta]
"""
import json
import math
import os
import re
import sys

import cv2
import numpy as np

TRES = "resources/characters/peregrino_frames_limpio.tres"
SEGUIMIENTO = "assets/characters/baston/baston_seguimiento.json"
SALIDA = "assets/characters/baston/baston_capa.json"
# animacion: (primer y ultimo fotograma donde puede seguir a la capa)
TRAMOS = {"salto_correr": (22, 48)}
GIRO_MAX = 1.3      # lo mas que se va hacia atras (rad) sobre el de siempre
PIVOTE = 40         # px de la punta de arriba de la textura al pivote
CERCA = 0.0015      # lo que cuesta cada rad de giro, por px de madera ganada
SUAVE = 5

t = open(TRES, encoding="utf-8").read()
ext = dict((i, p) for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t))
sub = {}
for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)'
                     r'\s*region = Rect2\(([^)]*)\)(?:\s*margin = Rect2\(([^)]*)\))?', t):
    mg = [int(round(float(v))) for v in m.group(4).split(",")] if m.group(4) else [0, 0, 0, 0]
    sub[m.group(1)] = (ext[m.group(2)], [int(round(float(v))) for v in m.group(3).split(",")], mg)
cache = {}


def frames(name):
    i = t.find('"name": &"%s"' % name)
    j = t.rfind('"frames": [', 0, i)
    return re.findall(r'SubResource\("([^"]+)"\)', t[j:i])


def img(sid):
    p, r, mg = sub[sid]
    if p not in cache:
        cache[p] = cv2.imread(p, -1)
    x, y, w, h = r
    o = np.zeros((h + mg[3], w + mg[2], 4), np.uint8)
    o[mg[1]:mg[1] + h, mg[0]:mg[0] + w] = cache[p][y:y + h, x:x + w]
    return o


def dentro(a, x, y, rot, largo):
    """Madera seguida dentro de la silueta desde el pivote hacia abajo (px).
    (el giro es horario: hacia abajo por el baston es (-sin, cos))"""
    H, W = a.shape
    cx, cy = W / 2, H / 2
    ultimo = 0
    entro = False
    for L in range(0, largo):
        px = int(round(cx + x - L * math.sin(rot)))
        py = int(round(cy + y + L * math.cos(rot)))
        if 0 <= px < W and 0 <= py < H and a[py, px]:
            entro = True
            ultimo = L
        elif entro:
            break
    return ultimo


def main():
    S = json.load(open(SEGUIMIENTO, encoding="utf-8"))
    B = cv2.imread("assets/characters/baston/baston.png", -1)
    largo = B.shape[0] - PIVOTE
    datos = {}
    for n, (i0, i1) in TRAMOS.items():
        fr = frames(n)
        filas = S[n]
        sil = [cv2.erode((img(s)[..., 3] > 100).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0 for s in fr]
        extra = np.zeros(len(fr))
        for i in range(i0, i1 + 1):
            x, y, r = filas[i][:3]
            mejor, mejor_d = -1e9, 0.0
            for d in np.linspace(0, GIRO_MAX, 66):
                v = dentro(sil[i], x, y, r + d, largo) - CERCA * largo * d * 100
                if v > mejor:
                    mejor, mejor_d = v, d
            extra[i] = mejor_d
        # suavizado, sin salirse del tramo
        k = SUAVE // 2
        pad = np.pad(extra, k, mode="edge")
        extra = np.array([pad[i:i + SUAVE].mean() for i in range(len(extra))])
        extra[:i0] = 0
        extra[i1 + 1:] = 0
        rows = []
        for i, f in enumerate(filas):
            x, y, r = f[:3]
            r = r + float(extra[i])
            c = 1.0
            if i0 <= i <= i1:
                L = dentro(sil[i], x, y, r, largo)
                c = round(min((PIVOTE + max(L - 14, 0)) / B.shape[0], 1.0), 3)
            rows.append([round(float(x), 2), round(float(y), 2), round(r, 4), 0, c])
        # (el corte tambien suave: que la vara no crezca y mengue a saltos)
        cs = np.array([q[4] for q in rows])
        pad = np.pad(cs, 1, mode="edge")
        cs = np.minimum(cs, np.array([pad[i:i + 3].mean() for i in range(len(cs))]))
        for q, c in zip(rows, cs):
            q[4] = round(float(c), 3)
        datos[n] = rows
        print(n, [(i, round(float(extra[i]), 2), rows[i][4]) for i in range(i0, i1 + 1)])
        if "--ver" in sys.argv:
            ver(sys.argv[sys.argv.index("--ver") + 1], n, fr, rows, B)
    json.dump(datos, open(SALIDA, "w", encoding="utf-8"))


def ver(carpeta, n, fr, rows, B):
    bh, bw = B.shape[:2]
    out = []
    for i, s in enumerate(fr):
        p = img(s)
        H, W = p.shape[:2]
        x, y, r, _, c = rows[i]
        Bc = B.copy()
        Bc[int(c * bh):, :, 3] = 0
        M = cv2.getRotationMatrix2D((bw / 2, PIVOTE), -math.degrees(r), 1.0)
        M[0, 2] += W / 2 + x - bw / 2
        M[1, 2] += H / 2 + y - PIVOTE
        capa = cv2.warpAffine(Bc, M, (W, H), borderValue=(0, 0, 0, 0))
        a = capa[..., 3:] / 255.0
        o = capa[..., :3] * a + 200 * (1 - a)
        b = p[..., 3:] / 255.0
        out.append((p[..., :3] * b + o * (1 - b)).astype(np.uint8))
    cv2.imwrite(os.path.join(carpeta, "c_%s.png" % n), np.hstack(out))


if __name__ == "__main__":
    main()
