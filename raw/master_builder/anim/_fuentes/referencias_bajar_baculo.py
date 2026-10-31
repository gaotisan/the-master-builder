"""Referencias para BAJAR CON EL BACULO EN LA MANO (2026-10-31; prompt_bajar_escalon_baculo.txt
y prompt_bajar_saltito_baculo.txt; Flow, fotogramas a video). Empiezan y acaban en el
reposo con el baston en la mano del juego (giro_mano.reposo_mano, garra VACIA: la
bola la pone el juego):
  referencia_escalon_baculo_inicio.png  encima de un escalon, junto a su filo (16:9)
  referencia_escalon_baculo_fin.png     abajo, un paso mas alla del pie del escalon
  referencia_saltito_baculo_inicio.png  encima del muro de bajar (1,15 del alto), junto al filo (9:16)
  referencia_saltito_baculo_fin.png     abajo, donde cae con el saltito
Alturas: el escalon mide 0,40 del alto del peregrino (250 px de master = ~125 del juego,
en medio de los escalones de Egipto, 53-182); el muro, el de prompt_bajar_saltando.txt
(721 de master = ~360 del juego, en medio de 183-492). El muro es el de
referencias_trepar_bajar.py (su funcion muro, sacada de alli sin ejecutar el resto).
La punta del baston (delante del pie) queda dentro del filo arriba.
  python referencias_bajar_baculo.py [carpeta de salida; por defecto esta]"""
import ast
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import Delaunay

AQUI = os.path.dirname(os.path.abspath(__file__))
BASTON = os.path.join(os.path.dirname(AQUI), 'baston')
SALIDA = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else AQUI
sys.path.insert(0, AQUI)
sys.path.insert(0, BASTON)
import referencias_empujar as E               # noqa: E402

os.chdir(BASTON)
import giro_mano as G                         # noqa: E402

# la funcion muro() de referencias_trepar_bajar.py, sin ejecutar el script
fuente = open(os.path.join(AQUI, 'referencias_trepar_bajar.py'), encoding='utf-8').read()
nodo = next(n for n in ast.parse(fuente).body if isinstance(n, ast.FunctionDef) and n.name == 'muro')
ns = {'np': np, 'Image': Image, 'ImageDraw': ImageDraw, 'Delaunay': Delaunay, 'SS': 3}
exec(ast.get_source_segment(fuente, nodo), ns)
muro = ns['muro']

rep, H, PIE_Y, _, _, _, _ = E.peregrino()
con = G.reposo_mano()[0]                      # 720x584 RGBA, el reposo con el baston en la mano
op = con[..., 3] > 128
ys, xs = np.where(op)
assert ys.max() == PIE_Y, (ys.max(), PIE_Y)
pies = np.where(op[PIE_Y - 25:PIE_Y + 1, :400].any(0))[0]
TALON, PUNTA = pies.min(), pies.max()
abajo = np.where(op[PIE_Y - 25:PIE_Y + 1, 400:].any(0))[0] + 400
PUNTA_B = abajo.max()                         # la punta del baston, en el suelo
ARRIBA_FIG = ys.min()                         # lo mas alto (la garra o la capucha)
celda = Image.fromarray(con)
print('alto %d, talon %d, punta del pie %d, punta del baston %d, arriba %d' % (H, TALON, PUNTA, PUNTA_B, ARRIBA_FIG))

MARGEN = round(0.06 * H)                      # de la punta del baston al filo, arriba


def lienzo(ancho, alto, img_muro, xm, ym, x0, y0, nombre):
    lien = Image.new('RGBA', (ancho, alto), E.VERDE)
    lien.alpha_composite(img_muro, (max(xm, 0), ym), (max(-xm, 0), 0))
    lien.alpha_composite(celda, (x0, y0))
    lien.convert('RGB').save(os.path.join(SALIDA, nombre))
    print('%-38s talon x %d, pies en y %d, arriba %d' % (nombre, x0 + TALON, y0 + PIE_Y, y0 + ARRIBA_FIG))


# 1. ESCALON (16:9): el escalon a la izquierda, el filo en BORDE_E
ANCHO, ALTO, SUELO = 1920, 1080, 1040
HE = round(0.40 * H)
BORDE_E = 860
esc = muro(BORDE_E, HE, semilla=21).transpose(Image.FLIP_LEFT_RIGHT)
ARRIBA_E = SUELO - HE + 1
BAJA_E = round(0.30 * H)                      # del pie del escalon al talon, al acabar (un paso)
lienzo(ANCHO, ALTO, esc, 0, ARRIBA_E, BORDE_E - MARGEN - PUNTA_B, ARRIBA_E - 1 - PIE_Y, 'referencia_escalon_baculo_inicio.png')
lienzo(ANCHO, ALTO, esc, 0, ARRIBA_E, BORDE_E + BAJA_E - TALON, SUELO - PIE_Y, 'referencia_escalon_baculo_fin.png')
print('escalon %dx%d, arriba en %d, filo en %d' % (BORDE_E, HE, ARRIBA_E, BORDE_E))

# 2. SALTITO DE UN MURO (9:16): el de bajar de un saltito (mismo alto, misma semilla)
ANCHO, ALTO, SUELO = 1080, 1920, 1880
HM, WM, BORDE_B = round(1.15 * H), 600, 540
m = muro(WM, HM).transpose(Image.FLIP_LEFT_RIGHT)
ARRIBA_M = SUELO - HM + 1
CAE = round(0.35 * H)                         # del pie del muro al talon, abajo (como el saltito sin baston)
lienzo(ANCHO, ALTO, m, BORDE_B - WM, ARRIBA_M, BORDE_B - MARGEN - PUNTA_B, ARRIBA_M - 1 - PIE_Y, 'referencia_saltito_baculo_inicio.png')
lienzo(ANCHO, ALTO, m, BORDE_B - WM, ARRIBA_M, BORDE_B + CAE - TALON, SUELO - PIE_Y, 'referencia_saltito_baculo_fin.png')
print('muro %dx%d, arriba en %d, filo en %d' % (WM, HM, ARRIBA_M, BORDE_B))
