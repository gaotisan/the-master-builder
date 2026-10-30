"""Fondo del camino derecho con la casa de Dominus al fondo (2026-10-29: el
contraplano del camino del bosque ya no es el cruce de tres caminos sino este
camino recto, de espaldas hasta la verja).

LA CASA. Como en el cruce (cruce_bosque/componer.py poner_casa: la casa en
silueta sobre la niebla, con menos contraste, y las ramas de aqui delante), en
el hueco de niebla clara del fondo del camino, bajo el resplandor. Aqui la
niebla es mas clara que en el cruce y se veian los trozos de seto y arbol que
traia el contorno del cruce como una caja alrededor del castillo: CONTORNO va
pegado a los pilares, la verja y las torres.

El color no se toca aqui: lo iguala al camino del bosque mascaras.py
(fondo_vivo.py, como en los otros planos).

Fuente: fondo_suavizado.png (sin el relieve de grabado). Salida:
fondo_compuesto.png (lo lee mascaras.py).
Uso: python componer.py
"""
import importlib.util
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location("componer_cruce", os.path.join(AQUI, "..", "cruce_bosque", "componer.py"))
cruce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cruce)

# Contorno de pilares (con su remate), verja y castillo en casa_midjourney.png (px).
CONTORNO = [(1120, 1112), (1120, 860), (1135, 775), (1160, 760), (1175, 675), (1190, 760), (1215, 775),
			(1230, 840), (1230, 540), (1280, 520), (1340, 420), (1350, 300), (1395, 230), (1435, 115), (1470, 300),
			(1505, 185), (1535, 310), (1630, 400), (1662, 520), (1662, 840), (1735, 840), (1760, 760), (1780, 675),
			(1795, 760), (1820, 775), (1840, 860), (1840, 1112)]
# El pie de la verja: al final del camino (el ultimo punto del peregrino en
# camino_derecho.tscn, pies 1490, 1150), y su ancho de pilar a pilar por fuera
# (el mismo tamano que en el cruce: alli 330 px con un contorno de 760).
BASE = (1488.0, 1150.0)
ANCHO = 330.0 * 720.0 / 760.0


def main():
	fondo = cv2.cvtColor(cv2.imread(os.path.join(AQUI, "fondo_suavizado.png")), cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	out = cruce.poner_casa(fondo, CONTORNO, BASE, ANCHO)
	cv2.imwrite(os.path.join(AQUI, "fondo_compuesto.png"),
				cv2.cvtColor((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR))
	print("  fondo_compuesto.png")


if __name__ == "__main__":
	main()
