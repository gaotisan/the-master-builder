"""EL RECORRIDO DE PIEDRA DEL ACTO I (2026-10-28): las piezas del usuario
(piezas.py) colocadas sobre la arena de la playa, y lo que se pisa (cajas).

Las cajas son el suelo de verdad: rectangulos macizos con su cara de arriba y su
cara de abajo (en px de juego, alturas sobre la arena). Pueden quedar unas
sobre otras (repisas): lo que esta por encima de la cabeza no estorba, se pasa
por debajo (acciones_egipto.gd). Se miden en la imagen de cada pieza (px de la
pieza, y hacia abajo) y se llevan al juego con su escala y su sitio. Las
columnas y los muros del fondo de las fachadas no son cajas: se pasa por
delante.

Salida: assets/egipto/acto1/recorrido.json; con --ver, una vista del recorrido
(piezas, cajas, el peregrino a escala) en el scratchpad o donde diga --ver=ruta.

Uso: python -I tools/egipto/recorrido.py [--ver[=ruta.png]]
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
PIEZAS = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas")
RES = "res://assets/egipto/acto1/piezas/"
# las escaladas (escalar_piezas.py): {pieza: factor}; se usan en su lugar, con la
# escala dividida por el factor (las cajas siguen medidas en la original)
HD = os.path.join(PROYECTO, "assets", "egipto", "acto1", "piezas_hd")
RES_HD = "res://assets/egipto/acto1/piezas_hd/"
ADORNOS_DIR = os.path.join(PROYECTO, "assets", "egipto", "acto1", "adornos")
RES_ADORNOS = "res://assets/egipto/acto1/adornos/"
SALIDA = os.path.join(PROYECTO, "assets", "egipto", "acto1", "recorrido.json")

ALTO_PEREGRINO = 305.0   # px de juego, de los pies a la capucha (medido en la playa)

# Lo que se pisa de cada pieza: [x0, x1, y de arriba, y de abajo] en px de su
# imagen (y hacia abajo); abajo None = hasta el pie de la pieza (macizo).
CAJAS = {
    # EL TEMPLO DE LAS TERRAZAS: el zigzag hasta el mirador. Medido en su
    # imagen (1744 x 837): la pasarela de abajo, el bloque bajo y el de encima,
    # el puente (con su dintel), el pilar de la izquierda, la losa sobre las
    # columnas, el pilar alto, las repisas de la derecha, el escalon, el bloque
    # de arriba, la terraza de los obeliscos y el altar.
    "templo_terrazas": [
        [0, 240, 725, None],        # la base de la izquierda (el plinto; 15 mas arriba, retoque_templo.py)
        [240, 1160, 765, None],     # la pasarela
        [1160, 1744, 725, None],    # la base de la derecha
        # S3: el bloque bajo (2026-10-30: 38 mas abajo, retoque_templo.py: debajo
        # del puente no cabia de pie y trepaba al puente a traves de el)
        [450, 570, 728, None],
        # S4: el bloque de encima (hasta su borde: se pasa por delante del pilar
        # alto). 16 mas arriba (2026-10-31, retoque_templo.py SUBIDAS_TRAS): del
        # bloque bajo se trepa (187, ya no se salta: la primera trepada, obligada)
        # y de su filo izquierdo se trepa al puente (187): lo que se ve. Su cara
        # izquierda en 564 (sin el remate de antes, que quedaba suelto bajo el
        # final del puente: retoque_templo.py CIELOS_TRAS y ESTIRADOS_TRAS)
        [564, 775, 624, None],
        # S2: el puente, la losa entera (2026-10-28, el usuario: estaba corto por
        # los dos lados): hasta su final a la derecha, y a la izquierda hasta el
        # remate del pilar (170; mas alla la losa se mete bajo el remate: si se
        # aterrizaba ahi al trepar, el remate estorbaba). De la base de la
        # izquierda se trepa al puente; del puente, al pilar
        # (2026-10-29: 33 mas arriba, retoque_templo.py)
        # Se sube desde el filo izquierdo del bloque de encima (trepada mediana:
        # la rendija entre los dos, 49 px, no es un borde; acciones_egipto.gd
        # _nivel). (2026-10-31: de un dia se subio por su canto derecho desde el
        # bloque bajo, como ARISTA; el usuario: "no es nada intuitivo")
        # Y se baja por el mismo sitio (2026-10-31, el usuario: "subo de c004 a
        # c005 y luego no puedo bajar"): andando hacia el filo derecho, el saltito
        # de bajar al bloque de encima (bajada; acciones_egipto.gd _bajada_en)
        [170, 538, 520, 552, {"bajada": 1}],
        # S1: lo alto del pilar de la izquierda (se pasa por delante del fuste:
        # si no, tapaba la entrada)
        [5, 170, 465, 500],
        # S5: la losa sobre las columnas, hasta donde nace el fuste del pilar
        # alto (722; la losa sigue por delante hasta 750). Su punta izquierda va
        # corrida 57 (retoque_templo.py CORRIDOS), a ras de su capitel, para dejar
        # libre el extremo del puente (la rendija de 538 a 556 entre los dos no es
        # un borde por el que caer: acciones_egipto.gd _nivel). Se sube del puente
        # (mediana o salto). Por debajo, sobre el bloque de encima (ya subido),
        # quedan 292: se pasa por delante (su columna esta detras del bloque),
        # la capucha roza su canto de abajo (despeje 290, no 310). Su canto derecho ya no
        # se trepa desde el bloque de encima (2026-10-30 a 31; el usuario: "por
        # ahi en teoria no debe poder escalar": es la cara del pilar alto)
        [556, 722, 430, 462, {"despeje": 290}],
        # S6: lo alto del pilar alto (su remate); el fuste no estorba: por el
        # bloque de encima se pasa por delante (2026-10-28, el usuario: el bloque
        # se quedaba corto por la derecha)
        [712, 842, 334, 377],       # (23 mas arriba, retoque_templo.py)
        [805, 920, 285, 315],       # S8: la repisa suelta (10 mas abajo, retoque_templo.py)
        # S9: la repisa grande. Por debajo, en la punta del saliente alto (abajo),
        # se le deja rozar la capucha (254)
        [905, 1140, 247, 280, {"despeje": 250}],
        [1037, 1100, 200, 247],     # S13: el escalon
        [1100, 1268, 165, 247],     # S12: el bloque de arriba
        [1245, 1744, 245, 280],     # S14: la terraza de los obeliscos
        # el altar (lo mas alto: el mirador). Con su altura de la imagen
        # (2026-10-30, el usuario: sin la cornisa repetida, "lo suyo es tener
        # solo un friso"): se sube desde el peldanito pegado a el (desde 1420, el
        # canto de su costado: el peldanito, entero hasta ahi; con 1408 era tan
        # estrecho que el salto no caia encima)
        [1420, 1632, 112, 245],
        # (lo de 2026-10-30, al final: los nombres de lo de antes no cambian)
        # EL BLOQUE GEMELO a la derecha del bloque de encima (retoque_templo.py):
        # el camino de vuelta, de la pasarela al bloque de encima
        [772, 890, 728, None],
        # EL PELDANITO PEGADO AL ALTAR: la piedra con luz entre la base del obelisco
        # de la izquierda y el altar (2026-10-31, el usuario: "se ven como dos
        # piedras"; que la base del obelisco "se vea que no se puede subir, de
        # fondo" y solo se pise este). La base, hecha un solo peldano
        # (retoque_templo.py UN_PELDANO: las piezas sueltas eran "un pegote en toda
        # regla", "se notan las costuras") y a la sombra (A_LA_SOMBRA), no se pisa.
        # De la terraza, un salto (67); de el al altar, la trepada mediana (173; o
        # un salto andando). Con el mismo margen sobre su canto (212,5) que tenia la
        # base. La base del obelisco de la derecha tampoco se pisa (fondo; se queda
        # en la lista para no cambiar los nombres de las demas)
        [1391, 1420, 208, 245],
        [1632, 1708, 210, 245, {"fondo": True}],
        # LOS TRES SALIENTES de encima de la pasarela, junto al bloque gemelo
        # (2026-10-31, el usuario: "quiero que se puedan usar tb aunque no lleven a
        # ningun sitio"). Con "al_final": sus nombres, despues de los de todas las
        # piezas (los de antes no cambian). Se sube al del medio desde el bloque
        # gemelo (la alta, saltando junto a su canto izquierdo: arista); de el se
        # baja al de abajo; del de abajo, al del medio de un salto o al alto con la
        # alta (retoque_templo.py lo sube 13); del alto se baja a la base de la
        # derecha. No llevan a la terraza: entre el alto y ella quedan 38, mas que
        # una rendija.
        #   el del medio, desde donde acaba el remate del pilar alto, que le queda
        #   encima (842). De el no se trepa al remate (313, la alta): era un atajo
        #   que se saltaba media subida (sin_trepar, acciones_egipto.gd)
        [842, 1042, 508, 535, {"arista": -1, "sin_trepar": True, "al_final": True}],
        #   el de abajo, hasta donde empieza el alto (por debajo no cabe de pie); por
        #   debajo, en la pasarela, se pasa (268: por delante, como ya se pasaba), y
        #   no es techo para el salto (si no, de la pasarela a la base derecha solo
        #   se saltaba pegado a ella)
        [1042, 1102, 588, 616, {"despeje": 250, "sin_techo": True, "al_final": True}],
        #   el alto, hasta 38 de la terraza
        [1102, 1216, 421, 448, {"al_final": True}],
    ],
    # LA LOSA DE LA IZQUIERDA (2026-10-28, el usuario: "para evitar que el
    # personaje vaya hacia atras, pon una losa vertical grande"): maciza de
    # arriba abajo, mas alta de lo que se trepa (no se sube ni se salta)
    "kit_pilares_1": [
        [20, 450, 0, None],
        # (el hueco del peldano suelto del altar, quitado: un fondo para que los
        # nombres de las de despues no cambien)
        [0, 1, 0, 1, {"fondo": True}],
    ],
    # LAS RUINAS DE LA DERECHA (2026-10-31, Downloads/segundo puzzle egipto, "Ruinas
    # de templo"): un muro alto al que solo se llega por la losa que saca el altar
    # (mecanismo_altar.gd). La columna (la losa se apoya en su capitel), la cornisa
    # del muro alto y el muro bajo largo hasta el final. El hueco de la puerta del
    # muro bajo no se alcanza (la columna lo tapa por la izquierda y el muro, 463,
    # por la derecha): macizo. Desde la arena nada se sube (917 / 463); se baja:
    # capitel -> cornisa 115, cornisa -> muro bajo 340, muro bajo -> arena 463.
    # La cara de arriba, 5 px bajo lo que asoma (la luz del canto)
    "muro_columnas": [
        # el capitel de la columna (en el se apoya la losa). Su zocalo, el bloque de
        # la base, sobresale hasta 2: desde la arena se para antes de el (2026-10-31,
        # el usuario: se quedaba "muy metido")
        [18, 222, 8, None, {"zocalo": 2}],
        [222, 640, 78, None],       # la cornisa del muro alto
        [640, 1890, 285, None],     # el muro bajo largo (con la puerta, macizo)
    ],
}

# Las piezas colocadas: [pieza, x de su izquierda (juego), escala, hundida (px
# de juego que quedan bajo la arena), volteada]
# EL TEMPLO DE LAS TERRAZAS, en la primera pantalla (el usuario: el peregrino
# aparecera por ahi, por una puerta estelar que aun tiene que hacer). Primero
# pegado al borde izquierdo (-800: donde empieza la playa y para la camara);
# luego (2026-10-28) un poco a la derecha: que el peregrino empiece abajo del
# todo, en la arena, antes del templo; y mas (2026-10-28) para la caida del
# cielo en el monton de arena: tumbado ocupa de -170 a +160 px del peregrino,
# y la camara no pasa de -800 (si no, quedaba medio cuerpo fuera de pantalla)
X_TEMPLO = -120.0
COLOCADAS = [
    ["templo_terrazas", X_TEMPLO, 1.8, 85.0, False],
    # (despues del templo: las cajas del templo siguen siendo c000-c014)
    ["kit_pilares_1", -1010.0, 1.0, 85.0, False],
]

# EL ALTAR Y LA LOSA (2026-10-31, mecanismo_altar.gd): despues del video, de pie en
# el altar (c014) baja HUNDIR px y la losa larga sale por la derecha del voladizo
# de la terraza (c013, su cara de arriba y su grueso: 980,6 y 63) hasta el capitel
# de la columna de las ruinas; al bajarse del altar vuelve a meterse.
#   El altar, recortado del templo (px de templo_terrazas.png, la de piezas/): la
#   losa de arriba y el cuerpo, hasta el peldano corrido de los obeliscos (226; al
#   bajar se mete detras de el)
#   Solo baja la tapa (2026-10-31, el usuario: "la parte de arriba ... podria
#   bajar?"): la losa de arriba, por delante del templo, sobre el cuerpo del
#   altar (que se queda, con la placa del escarabajo). Antes, el altar entero:
#   [[1402, 106, 1638, 134], [1406, 134, 1631, 226]]
ALTAR_RECTS = [[1402, 106, 1638, 134]]
SOLO_TAPA = True
HUNDIR = 30.0
#   La losa: escala para que su grueso (113 px de la pieza) sea el del voladizo;
#   su cara de arriba (CARA_LOSA px de la pieza) a ras de la terraza; sale de su
#   canto derecho, con OCULTO px por detras de el (no se ve el corte)
TERRAZA_X1 = X_TEMPLO + 1744 * 1.8
TERRAZA_ARRIBA = (837 - 245) * 1.8 - 85.0
ESC_LOSA = 0.56
CARA_LOSA = 10.0
OCULTO_LOSA = 20.0
#   Las ruinas: a la escala (y hundidas) a la que su capitel queda justo debajo de
#   la losa; la columna, a HUECO_RUINAS de la terraza (lo que la losa cruza); la
#   punta de la losa, PUNTA_EN_CAPITEL dentro del capitel (lo que hay que recoger
#   para que deje de llegar: el tiempo de cruzar)
ESC_RUINAS = 1.64
HUECO_RUINAS = 790.0
PUNTA_EN_CAPITEL = 250.0
ALTO_RUINAS = 577.0
HUNDIDA_RUINAS = (ALTO_RUINAS - 8.0) * ESC_RUINAS - (TERRAZA_ARRIBA - (116.0 - CARA_LOSA) * ESC_LOSA) + 4.0
X_RUINAS = TERRAZA_X1 + HUECO_RUINAS - 18.0 * ESC_RUINAS
LARGO_LOSA = HUECO_RUINAS + PUNTA_EN_CAPITEL
COLOCADAS.append(["muro_columnas", X_RUINAS, ESC_RUINAS, HUNDIDA_RUINAS, False])


def en_ruinas(x, y):
    """Un punto de la imagen de las ruinas, en px de la imagen del templo (donde
    se miden los adornos)."""
    X = X_RUINAS + x * ESC_RUINAS
    alto = (ALTO_RUINAS - y) * ESC_RUINAS - HUNDIDA_RUINAS
    return (X - X_TEMPLO) / 1.8, 837.0 - (alto + 85.0) / 1.8

# Por delante de todo lo del recorrido (z): la losa tapa el monton de arena de
# la caida, que se mete bajo ella (si no, sus piedras quedaban a los pies del
# peregrino, "irreal")
Z = {"kit_pilares_1": 10}

MARCAS = {
    # donde aparece el peregrino: abajo del todo, en la arena, antes del templo
    # (cae del cielo ahi, en el monton de arena: egipto_acto1.gd, MONTON)
    "inicio": [-330.0, None],
    # hasta donde se puede ir a la izquierda (el borde de la playa: la camara
    # para en -800)
    "limite_izq": [-760.0, None],
    # donde se ve el templo de la franja media (lo alto del altar)
    "mirador": [X_TEMPLO + 1520.0 * 1.8, None],
}


# Las palomas posadas (pajaro_posado.gd: se espantan al acercarse el peregrino):
# [x de juego, altura sobre la arena, hacia donde miran]
# (2026-10-29: las del pilar de la izquierda y el puente, quitadas: ahi va la
# bandada, que se posa en el puente y mas alla)
PAJAROS = [
    [X_TEMPLO + 700.0 * 1.8, 648.0, 1.0],     # en la losa sobre las columnas
    [X_TEMPLO + 1700.0 * 1.8, 981.0, -1.0],   # en la terraza de los obeliscos, dos
    [X_TEMPLO + 1675.0 * 1.8, 981.0, 1.0],
    # en las ruinas de la derecha: una en la cornisa, dos en el muro bajo
    [X_RUINAS + 470.0 * ESC_RUINAS, (ALTO_RUINAS - 78.0) * ESC_RUINAS - HUNDIDA_RUINAS, -1.0],
    [X_RUINAS + 1180.0 * ESC_RUINAS, (ALTO_RUINAS - 285.0) * ESC_RUINAS - HUNDIDA_RUINAS, -1.0],
    [X_RUINAS + 1215.0 * ESC_RUINAS, (ALTO_RUINAS - 285.0) * ESC_RUINAS - HUNDIDA_RUINAS, 1.0],
]

# LA BANDADA DE LA CAIDA (bandada.gd, 2026-10-29): palomas comiendo a la derecha
# de donde cae el peregrino; con el golpe salen volando, unas se van y otras se
# posan mas alla en el templo.
#   tramos: [x0, x1, altura sobre la arena, cuantas] donde comen: el escalon al
#     pie del pilar de la izquierda y la arena bajo el puente
#   posaderos: [x0, x1, altura] donde se posan: el puente (lo de la derecha), la
#     losa sobre las columnas y las repisas que suben
BANDADA = {
    "tramos": [
        [X_TEMPLO + 70.0 * 1.8, X_TEMPLO + 225.0 * 1.8, 116.6, 5],
        [X_TEMPLO + 250.0 * 1.8, X_TEMPLO + 370.0 * 1.8, 45.0, 7],
    ],
    "posaderos": [
        [X_TEMPLO + 360.0 * 1.8, X_TEMPLO + 530.0 * 1.8, 485.6],
        [X_TEMPLO + 590.0 * 1.8, X_TEMPLO + 665.0 * 1.8, 648.0],
        [X_TEMPLO + 735.0 * 1.8, X_TEMPLO + 830.0 * 1.8, 820.4],
        [X_TEMPLO + 815.0 * 1.8, X_TEMPLO + 900.0 * 1.8, 909.0],
    ],
}


# LOS ADORNOS (adornos.py, de las hojas del usuario del 2026-10-28): plantas en
# lo alto de las repisas, enredaderas colgando de sus cantos, atrezzo, arena
# amontonada. Medidos en la imagen del templo (como sus cajas): [adorno, ancla,
# x, y, escala (de la imagen del adorno a px de juego), volteado, vaiven, opciones]
#   ancla "pie": el pie del adorno en (x, y) (lo apoyado: plantas, atrezzo, arena)
#   ancla "techo": lo de arriba en (x, y) (lo que cuelga del canto de una repisa)
#   vaiven: lo que se mece con el aire (px de la imagen del adorno; 0 quieto)
#   opciones:
#     detras: por detras del templo, hundido "hunde" px (de la imagen del
#       templo) bajo la cara de arriba: la piedra le tapa el pie y solo asoma lo
#       de arriba, como si naciera de la repisa (puesto encima, con su montoncito
#       de piedras de otro estilo, quedaba pegado)
#     hunde (sin detras, en la arena): la arena de delante le tapa el pie
#     repisa: la cara de arriba de la repisa de la que cuelga una enredadera: sus
#       hojas de arriba (adornos.py, _arriba) van detras y asoman por encima
#     sombra: sombra de contacto en la piedra (lo apoyado delante)
#     luz: la suya, fija (lo que ya trae la luz del sitio puesta)
# Lo que va delante de la piedra toma la luz del sitio (lo que tiene detras en
# la imagen del templo: en la sombra de un muro, mas oscuro).
# (2026-10-28, el usuario: fuera la palmera, el gato y el brasero, "no pegan en
# las ruinas"; y la arena, como estaba, no funcionaba)
ARENA_Y = 837.0 - 85.0 / 1.8      # la linea de la arena en la imagen del templo
DELANTE_PEREGRINO = 5             # z: por encima del peregrino (0) y de su baculo (hasta 3)
ADORNOS = [
    # enredaderas: del puente, del pilar, de la losa, de las repisas y de la terraza
    ["colgantes_b_3", "techo", 252, 549, 0.38, False, 10, {"repisa": 520}],
    ["colgantes_a_2", "techo", 482, 549, 0.53, True, 8, {"repisa": 520}],
    ["colgantes_a_0", "techo", 62, 497, 0.47, False, 8, {"repisa": 465}],
    ["colgantes_b_0", "techo", 577, 459, 0.53, False, 10, {"repisa": 430}],
    ["colgantes_b_1", "techo", 842, 312, 0.5, True, 10, {"repisa": 285}],
    ["colgantes_a_8", "techo", 985, 277, 0.62, False, 8, {"repisa": 247}],
    ["colgantes_b_2", "techo", 1060, 612, 0.5, False, 10, {"repisa": 585}],
    ["colgantes_b_0", "techo", 1292, 279, 0.62, True, 10, {"repisa": 245}],
    ["colgantes_a_2", "techo", 1700, 279, 0.6, False, 8, {"repisa": 245}],
    # matas que nacen en lo alto de las repisas (junto a las enredaderas: que
    # parezca que crece ahi y se descuelga)
    ["plantas_a_0", "pie", 45, 465, 0.32, False, 6, {"detras": True, "hunde": 14}],
    ["plantas_b_6", "pie", 590, 430, 0.36, True, 6, {"detras": True, "hunde": 16}],
    ["plantas_b_5", "pie", 668, 430, 0.3, False, 5, {"detras": True, "hunde": 14}],
    ["plantas_a_7", "pie", 800, 334, 0.42, False, 4, {"detras": True, "hunde": 12}],
    ["plantas_a_0", "pie", 940, 247, 0.3, True, 6, {"detras": True, "hunde": 14}],
    ["plantas_a_2", "pie", 1288, 245, 0.32, False, 4, {"detras": True, "hunde": 14}],
    ["plantas_b_6", "pie", 1722, 245, 0.3, False, 6, {"detras": True, "hunde": 14}],
    # arena acumulada en los rincones (contra el bloque, por detras: el bloque
    # la tapa por un lado y la cara de la pasarela por abajo)
    # (donde se ve: en el hueco de la puerta oscura, contra sus dos lados; bajo
    # el puente, contra el escalon de la base; en el bloque, contra el pilar)
    ["arena_b_5", "pie", 965, 765, 0.55, True, 0, {"detras": True, "hunde": 5}],
    ["arena_a_3", "pie", 1078, 765, 0.5, False, 0, {"detras": True, "hunde": 5}],
    ["arena_b_5", "pie", 262, 765, 0.45, True, 0, {"detras": True, "hunde": 5}],
    ["arena_a_3", "pie", 690, 640, 0.55, True, 0, {"detras": True, "hunde": 4}],
    # en la arena de la playa: hundido, la arena de delante les tapa el pie
    # (a la izquierda, nada: alli ira la puerta estelar)
    # LAS DUNAS QUE ENTIERRAN LA BASE (2026-10-28, de ChatGPT; el usuario: la base
    # cortaba la arena en una linea recta, "pegado"): por delante del templo y
    # por detras del peregrino (no le tapan las piernas), hundidas bajo el borde
    # de la arena de delante (no se ve su pie recto)
    ["arena_dunas_b_0", "pie", 640, ARENA_Y, 1.1, False, 0, {"hunde": 10}],
    ["arena_dunas_a_0", "pie", 1420, ARENA_Y, 1.0, True, 0, {"hunde": 10}],
    # (2026-10-31, el usuario: fuera la de 1850, en la esquina de la base de la
    # derecha: con su canto recto tapaba el escalon)
    ["arena_dunas_b_5", "pie", 1110, ARENA_Y, 0.9, False, 0, {"hunde": 8}],
    # (lo plantado en la arena de la playa, por DELANTE del peregrino: esta a la
    # altura de sus pies o mas cerca; detras, la piedra de jeroglificos le
    # quedaba atravesada por los pies; 2026-10-30, el usuario: "deberian quedar
    # por delante de el")
    # (2026-10-31, el usuario: fuera la de la esquina de la base de la derecha,
    # plantas_a_5 en 1748: tapaba el escalon y no se veia que habia que saltar)
    ["plantas_a_0", "pie", 222, ARENA_Y, 0.3, True, 6, {"hunde": 20, "z": DELANTE_PEREGRINO}],
    ["plantas_b_1", "pie", 1885, ARENA_Y, 0.5, False, 5, {"hunde": 24, "z": DELANTE_PEREGRINO}],
    ["atrezzo_a_6", "pie", 2010, ARENA_Y, 0.55, False, 0, {"hunde": 16, "z": DELANTE_PEREGRINO}],
    # LA ESTELA, abajo a la izquierda, al pie de la losa (2026-10-28, el usuario:
    # "una piedra con jeroglificos de gran tamano"; sin plantas en la losa:
    # "mejor sin plantas"); por delante de la losa (z)
    ["atrezzo_b_3", "pie", -335, ARENA_Y, 1.15, False, 0, {"hunde": 14, "z": 11}],
    # vasijas en la piedra, con su sombra
    # (la de la pasarela, pasado el bloque gemelo: antes estaba donde el)
    ["atrezzo_a_1", "pie", 905, 768, 0.4, False, 0, {"sombra": True}],
    ["atrezzo_a_3", "pie", 1222, 728, 0.4, False, 0, {"sombra": True}],
    ["atrezzo_a_2", "pie", 1495, 728, 0.38, True, 0, {"sombra": True}],
    # EL ESCARABAJO EN EL FRENTE DEL ALTAR, en lugar del halcon (2026-10-29, el
    # usuario: "que sea el escarabajo del simbolo que buscamos y sea una pista
    # para ponerse ahi"; "sustituir el halcon... por el escarabajo"): la placa
    # encajada en su hueco, con la luz y el color del hueco ya puestos
    # (frente_escarabajo.py: sus px son los del templo HD, de ahi la escala; y
    # la luz, la de lo que no se pisa del templo: pie_piedra.gdshader, fondo
    # 0,86 por su frio)
    ["frente_escarabajo", "pie", 1538.5, 221, 0.9, False, 0, {"luz": 0.84}],
]
# LOS DE LAS RUINAS DE LA DERECHA (2026-10-31): medidos en su imagen (en_ruinas los
# lleva a la del templo). Las dunas que les entierran la base (como al templo: si
# no, la base corta la arena en recto), una enredadera de la cornisa y otra del
# muro bajo, matas que asoman por detras de lo alto. [adorno, ancla, x, y, escala,
# volteado, vaiven, opciones]; "repisa", tambien en px de las ruinas
ARENA_RUINAS = ALTO_RUINAS - HUNDIDA_RUINAS / ESC_RUINAS
for n, ancla, x, y, e, flip, vaiven, op in [
    ["arena_dunas_b_1", "pie", 330, ARENA_RUINAS, 1.0, False, 0, {"hunde": 10}],
    ["arena_dunas_a_1", "pie", 1050, ARENA_RUINAS, 1.0, True, 0, {"hunde": 10}],
    ["arena_dunas_b_3", "pie", 1760, ARENA_RUINAS, 0.75, False, 0, {"hunde": 10}],
    ["colgantes_b_2", "techo", 470, 121, 0.5, False, 10, {"repisa": 76, "luz": 0.9}],
    ["colgantes_a_8", "techo", 1480, 340, 0.55, True, 8, {"repisa": 283, "luz": 0.9}],
    ["plantas_b_5", "pie", 330, 78, 0.3, False, 5, {"detras": True, "hunde": 14}],
    ["plantas_a_7", "pie", 1250, 283, 0.4, True, 4, {"detras": True, "hunde": 12}],
    ["plantas_a_2", "pie", 1760, 283, 0.3, False, 4, {"detras": True, "hunde": 14}],
]:
    xt, yt = en_ruinas(x, y)
    if "repisa" in op:
        op = dict(op, repisa=en_ruinas(x, op["repisa"])[1])
    ADORNOS.append([n, ancla, xt, yt, e, flip, vaiven, op])


def _luz_templo():
    """La luminancia de la imagen del templo (L de Lab, nan donde no hay piedra)
    y la de la piedra al sol (para comparar)."""
    t = cv2.imread(os.path.join(PIEZAS, "templo_terrazas.png"), cv2.IMREAD_UNCHANGED)
    L = cv2.cvtColor(t[..., :3], cv2.COLOR_BGR2LAB)[..., 0].astype(np.float32)
    L[t[..., 3] < 200] = np.nan
    return L, float(np.nanpercentile(L, 85))


def luz_en(L, sol, x0, x1, y0, y1, nada=0.86, fuerza=0.85):
    """Lo que se oscurece lo que esta delante de esa parte del templo."""
    h, w = L.shape
    x0, x1 = int(max(x0, 0)), int(min(x1, w))
    y0, y1 = int(max(y0, 0)), int(min(y1, h))
    if x1 <= x0 or y1 <= y0:
        return 1.0
    r = L[y0:y1, x0:x1]
    if np.isnan(r).all():
        return nada
    k = float(np.nanmedian(r)) / sol
    return round(float(np.clip(1.0 - fuerza * (1.0 - k), 0.55, 1.0)), 3)


def adornos_de(tam):
    L, sol = _luz_templo()
    colgar = tam.get("_colgar", {})
    out = []
    for n, ancla, x, y, e, flip, vaiven, op in ADORNOS:
        w, h = tam[n]
        X = X_TEMPLO + x * 1.8
        y_hunde = y + op.get("hunde", 0)
        alto_y = (837.0 - y_hunde) * 1.8 - 85.0
        abajo = alto_y if ancla == "pie" else alto_y - h * e
        # (la huella en la imagen del templo: para la luz)
        xi0, xi1 = x - w * e / 3.6, x + w * e / 3.6
        if ancla == "pie":
            yi0, yi1 = y - h * e / 1.8 * 0.5, y
        else:
            yi0, yi1 = y, y + h * e / 1.8
        # (lo apoyado, menos: esta mas cerca que el muro, no le cae toda su sombra)
        luz = op["luz"] if "luz" in op else 1.0 if op.get("detras") or op.get("hunde") else             luz_en(L, sol, xi0, xi1, yi0, yi1, fuerza=0.85 if ancla == "techo" else 0.55)
        d = {"tex": RES_ADORNOS + n + ".png", "x": round(X - w * e * 0.5, 1),
             "abajo": round(abajo, 1), "escala": e, "flip": flip,
             "ancho": round(w * e, 1), "alto": round(h * e, 1),
             "ancla": ancla, "vaiven": vaiven, "nombre": n, "luz": luz,
             "detras": bool(op.get("detras")), "sombra": bool(op.get("sombra"))}
        if "z" in op:
            d["z"] = op["z"]
        out.append(d)
        if "repisa" in op and n in colgar:
            # sus hojas de arriba, detras: la fila donde empieza su trozo de
            # piedra, a la altura de la cara de arriba de la repisa; y solo
            # hasta la de abajo (lo de mas abajo lo pone la enredadera)
            wa, ha = tam[n + "_arriba"]
            piedra = colgar[n]["piedra"]
            cara = (y - op["repisa"]) * 1.8
            filas = int(min(ha, piedra + cara / e))
            arriba = (837.0 - op["repisa"]) * 1.8 - 85.0 + piedra * e - 3.0
            out.append({"tex": RES_ADORNOS + n + "_arriba.png", "x": d["x"],
                        "abajo": round(arriba - filas * e, 1), "escala": e, "flip": flip,
                        "ancho": round(wa * e, 1), "alto": round(filas * e, 1), "filas": filas,
                        "ancla": "pie", "vaiven": vaiven * 0.4, "nombre": n + "_arriba", "luz": 1.0,
                        "detras": True, "sombra": False})
    return out


# EL PRIMER PLANO: entre la camara y el peregrino, en sombra, con mas paralaje
# (se va antes de la pantalla) y por abajo (al subir, se hunde): [adorno, x de
# juego (donde esta con la camara encima), escala, volteado]
DELANTE = [
    # (pasado el templo: delante del recorrido estorbaba, y al principio tapaba
    # donde aparece el peregrino; sin las de la hoja cortada por arriba, como la
    # palmera delante_b_0: se veia el corte; ni donde se cae de la terraza:
    # tapaba al peregrino al tocar la arena)
    # (sin delante_a_5: tambien cortada en recto por la derecha, 2026-10-29; el
    # usuario: "ya veremos, mas adelante iran mas ruinas de templos")
    # (sin delante_a_4: sus palmas venian cortadas en recto por el borde de la hoja)
    ["delante_c_2", 6260.0, 1.05, False],
]


def cajas_de(pieza, x, escala, hundida, volteada, tam):
    w, h = tam
    out = []
    for x0, x1, ya, yb, *op in CAJAS.get(pieza, []):
        op = op[0] if op else {}
        if volteada:
            x0, x1 = w - x1, w - x0
        arriba = (h - ya) * escala - hundida
        abajo = 0.0 if yb is None else (h - yb) * escala - hundida
        c = {"x0": round(x + x0 * escala, 1), "x1": round(x + x1 * escala, 1),
             "arriba": round(arriba, 1), "abajo": round(max(abajo, 0.0), 1),
             "pieza": pieza}
        if "arista" in op:
            c["arista"] = -op["arista"] if volteada else op["arista"]
        if "despeje" in op:
            c["despeje"] = op["despeje"]
        if "bajada" in op:
            c["bajada"] = -op["bajada"] if volteada else op["bajada"]
        if op.get("fondo"):
            c["fondo"] = True
        if "zocalo" in op:
            c["zocalo"] = round(x + (w - op["zocalo"] if volteada else op["zocalo"]) * escala, 1)
        if op.get("al_final"):
            c["al_final"] = True
        if op.get("sin_trepar"):
            c["sin_trepar"] = True
        if op.get("sin_techo"):
            c["sin_techo"] = True
        out.append(c)
    return out


def main():
    tam = json.load(open(os.path.join(PIEZAS, "piezas.json"), encoding="utf-8"))
    hd = {}
    if os.path.exists(os.path.join(HD, "hd.json")):
        hd = json.load(open(os.path.join(HD, "hd.json"), encoding="utf-8"))
    sprites, cajas = [], []
    for pieza, x, escala, hundida, volteada in COLOCADAS:
        w, h = tam[pieza]
        f = float(hd.get(pieza, 1.0))
        tex = (RES_HD if pieza in hd else RES) + pieza + ".png"
        sprites.append({"tex": tex, "x": x, "abajo": -hundida, "escala": escala / f, "z": Z.get(pieza, 0),
                        "flip": volteada, "ancho": round(w * escala, 1), "alto": round(h * escala, 1)})
        cajas += cajas_de(pieza, x, escala, hundida, volteada, (w, h))
    # (las puestas despues, al final: los nombres de las demas no cambian)
    cajas = [c for c in cajas if not c.get("al_final")] + [c for c in cajas if c.pop("al_final", False)]
    for i, c in enumerate(cajas):
        c["nombre"] = "c%03d" % i
    # (las de fondo ya no se pisan, pero cuentan para los nombres de las demas)
    cajas = [c for c in cajas if not c.pop("fondo", False)]
    marcas = {k: v[0] for k, v in MARCAS.items()}
    pajaros = [{"x": round(x, 1), "h": h, "sentido": s} for x, h, s in PAJAROS]
    tam_ad = json.load(open(os.path.join(ADORNOS_DIR, "adornos.json"), encoding="utf-8"))
    adornos = adornos_de(tam_ad)
    delante = [{"tex": RES_ADORNOS + n + ".png", "x": x, "escala": e, "flip": f,
                "ancho": tam_ad[n][0] * e, "alto": tam_ad[n][1] * e} for n, x, e, f in DELANTE]
    bandada = {k: [[round(float(v), 1) for v in t] for t in BANDADA[k]] for k in BANDADA}
    datos = {"sprites": sprites, "cajas": cajas, "marcas": marcas, "pajaros": pajaros,
             "adornos": adornos, "delante": delante, "bandada": bandada, "mecanismo": mecanismo(tam)}
    json.dump(datos, open(SALIDA, "w", encoding="utf-8"), indent=1)
    print("%d piezas, %d cajas -> %s" % (len(sprites), len(cajas), SALIDA))
    comprobar_trepas(cajas)
    for a in sys.argv[1:]:
        if a.startswith("--ver"):
            ver(datos, a.split("=", 1)[1] if "=" in a else None)


def mecanismo(tam):
    """El altar que se hunde y la losa que sale (mecanismo_altar.gd)."""
    w, h = tam["templo_terrazas"]
    return {
        "altar": "c014", "hundir": HUNDIR, "altar_rects": ALTAR_RECTS, "solo_tapa": SOLO_TAPA,
        "templo_ancho": w, "templo_alto": h,
        "losa": {"tex": RES + "losa_larga.png", "escala": ESC_LOSA, "cara_tex": CARA_LOSA,
                 "x_salida": round(TERRAZA_X1, 1), "oculto": OCULTO_LOSA, "largo": round(LARGO_LOSA, 1),
                 "arriba": round(TERRAZA_ARRIBA, 1),
                 "abajo": round(TERRAZA_ARRIBA - (116.0 - CARA_LOSA) * ESC_LOSA, 1)},
    }


# LAS TREPAS (2026-10-29): que cada cara caiga donde casa alguna forma de subir
# (acciones_egipto.gd): andando hasta PELDANO; de un salto andando hasta SALTO;
# trepando con el video mediano o el alto, en sus bandas (fuera de ellas las
# manos no casan con el borde). Lo que no cae en ninguna no se sube: se avisa.
# Y los escalones de PELDANO a ESCALON_MIN, que no deben existir (andando se ve
# levitar; de un salto o dejandose caer, un tropiezo): se avisa tambien.
DESPEJE = 310.0
ARISTA_MAS = 60.0
RENDIJA = 52.0          # una rendija mas estrecha que el peregrino no es un borde (acciones_egipto.gd)
PELDANO = 15.0
ESCALON_MIN = 60.0
SALTO = 182.0
BANDA_MEDIANA = (150.0, 195.0)
BANDA_ALTA = (295.0, 425.0)


def comprobar_trepas(cajas):
    """Las caras que se suben (de cada sitio donde se puede estar a lo que hay
    mas alto al lado) y con que."""
    todas = cajas + [{"nombre": "arena", "x0": -1e5, "x1": 1e5, "arriba": 0.0, "abajo": -1.0}]

    def nivel(x, pies):
        n = 0.0
        for c in todas:
            if c["abajo"] < pies + c.get("despeje", DESPEJE) and c["x0"] + 0.01 < x < c["x1"] - 0.01:
                n = max(n, c["arriba"])
        return n

    caras = set()
    for s in todas:
        for b in todas:
            if b["arriba"] <= s["arriba"] or b["abajo"] >= s["arriba"] + b.get("despeje", DESPEJE):
                continue
            # al otro lado de una rendija (del filo del bloque de encima al puente)
            for x, d, filo in ((b["x0"], 1, s["x1"]), (b["x1"], -1, s["x0"])):
                if 0.0 < d * (x - filo) < RENDIJA and abs(nivel(filo - d * 8, s["arriba"]) - s["arriba"]) <= 1:
                    caras.add((round(x), s["nombre"], b["nombre"] + " (rendija)", round(b["arriba"] - s["arriba"])))
            for x, d in ((b["x0"], 1), (b["x1"], -1)):
                if not s["x0"] < x - d * 8 < s["x1"]:
                    continue
                if abs(nivel(x - d * 8, s["arriba"]) - s["arriba"]) > 1 or abs(nivel(x + d * 8, s["arriba"]) - b["arriba"]) > 1:
                    continue
                h = b["arriba"] - s["arriba"]
                if h > PELDANO:
                    caras.add((round(x), s["nombre"], b["nombre"], round(h)))
    # LAS ARISTAS: el canto de una repisa que queda por encima de la cabeza, que
    # se trepa desde fuera (acciones_egipto.gd, ARISTA_MAS)
    for b in todas:
        lado = b.get("arista", 0)
        if not lado:
            continue
        x = b["x1"] if lado > 0 else b["x0"]
        for s in todas:
            pies = s["arriba"]
            if not s["x0"] < x + lado * 8 < s["x1"] or abs(nivel(x + lado * 8, pies) - pies) > 1:
                continue
            if b["abajo"] < pies + DESPEJE or b["abajo"] >= pies + DESPEJE + ARISTA_MAS:
                continue
            caras.add((round(x), s["nombre"], b["nombre"] + " (arista)", round(b["arriba"] - pies)))
    print("trepas:")
    sin_trepar = {c["nombre"] for c in todas if c.get("sin_trepar")}
    for x, de, a, h in sorted(caras):
        modos = []
        if h < ESCALON_MIN:
            modos.append("ESCALON FEO (16-60: retocar)")
        elif h <= SALTO:
            modos.append("salto")
        if BANDA_MEDIANA[0] <= h <= BANDA_MEDIANA[1]:
            modos.append("mediana")
        if BANDA_ALTA[0] <= h <= BANDA_ALTA[1]:
            modos.append("alta")
        if de in sin_trepar:
            modos = [m for m in modos if m not in ("mediana", "alta")]
        print("  x %6d  %s -> %s  %4d px  %s" % (x, de, a, h, " / ".join(modos) if modos else "NO SE SUBE"))


def ver(datos, ruta):
    """La vista: la arena, las piezas, las cajas (verde: lo de arriba, rojo: el
    canto) y un peregrino de ALTO_PEREGRINO en cada caja."""
    e = 0.35
    x0 = min(s["x"] for s in datos["sprites"]) - 800
    x1 = max(s["x"] + s["ancho"] for s in datos["sprites"]) + 400
    alto = max(s["alto"] for s in datos["sprites"]) + 300
    W, H = int((x1 - x0) * e), int((alto + 200) * e)
    suelo = int(alto * e)
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = (215, 205, 185)
    img[suelo:] = (150, 175, 205)
    for s in datos["sprites"]:
        p = cv2.imread(os.path.join(PIEZAS, os.path.basename(s["tex"])), cv2.IMREAD_UNCHANGED)
        if s["flip"]:
            p = p[:, ::-1]
        w, h = int(s["ancho"] * e), int(s["alto"] * e)
        p = cv2.resize(p, (w, h), interpolation=cv2.INTER_AREA)
        X = int((s["x"] - x0) * e)
        Y = int(suelo - (s["abajo"] + s["alto"]) * e)
        ys, xs = slice(max(Y, 0), min(Y + h, H)), slice(max(X, 0), min(X + w, W))
        sub = p[ys.start - Y:ys.stop - Y, xs.start - X:xs.stop - X].astype(np.float32)
        a = sub[..., 3:] / 255.0
        img[ys, xs] = (sub[..., :3] * a + img[ys, xs] * (1 - a)).astype(np.uint8)
    for s in datos.get("adornos", []):
        p = cv2.imread(os.path.join(ADORNOS_DIR, os.path.basename(s["tex"])), cv2.IMREAD_UNCHANGED)
        if "filas" in s:
            p = p[:s["filas"]]
        if s["flip"]:
            p = p[:, ::-1]
        w, h = max(1, int(s["ancho"] * e)), max(1, int(s["alto"] * e))
        p = cv2.resize(p, (w, h), interpolation=cv2.INTER_AREA)
        X = int((s["x"] - x0) * e)
        Y = int(suelo - (s["abajo"] + s["alto"]) * e)
        ys, xs = slice(max(Y, 0), min(Y + h, H)), slice(max(X, 0), min(X + w, W))
        sub = p[ys.start - Y:ys.stop - Y, xs.start - X:xs.stop - X].astype(np.float32)
        a = sub[..., 3:] / 255.0
        img[ys, xs] = (sub[..., :3] * a + img[ys, xs] * (1 - a)).astype(np.uint8)
    # la arena por delante del pie de las piezas (lo hundido)
    img[suelo:] = (150, 175, 205)
    for c in datos["cajas"]:
        X0, X1 = int((c["x0"] - x0) * e), int((c["x1"] - x0) * e)
        ya, yb = int(suelo - c["arriba"] * e), int(suelo - c["abajo"] * e)
        cv2.rectangle(img, (X0, ya), (X1, yb), (40, 40, 200), 1)
        cv2.line(img, (X0, ya), (X1, ya), (40, 200, 40), 2)
        cv2.putText(img, "%d" % c["arriba"], (X0 + 2, ya - 3), cv2.FONT_HERSHEY_SIMPLEX, 0.35, (20, 20, 20), 1)
        # el peregrino en medio de la caja
        px = (X0 + X1) // 2
        cv2.rectangle(img, (px - 5, ya - int(ALTO_PEREGRINO * e)), (px + 5, ya), (90, 60, 40), -1)
    ruta = ruta or os.path.join(os.environ.get("TEMP", "."), "recorrido_vista.png")
    cv2.imwrite(ruta, img)
    print("vista:", ruta)


if __name__ == "__main__":
    main()
