"""QUITAR EL FONDO (2026-10-28): de cualquier imagen (piedras, atrezzo, edificios
para la franja media...) sin croma: rembg con BiRefNet, en local y sin internet
(el modelo se descarga la primera vez a ~/.u2net). Deja un PNG con transparencia.

Para las hojas sobre croma verde siguen siendo mejores tools/egipto/piezas.py y
adornos.py (separan las piezas y quitan el verde de los filos); esto es para lo
que viene con un paisaje o un fondo cualquiera detras.

Uso: python -I tools/quitar_fondo.py imagen.png [mas.png ...] [opciones]
  --carpeta=ruta   donde dejar los resultados (por defecto, junto a cada imagen)
  --modelo=nombre  birefnet-general (por defecto, el mejor), birefnet-general-lite
                   (mas rapido y pequeno), birefnet-hrsod (mucho detalle), isnet-anime
                   (dibujos), u2net (el clasico)
  --filos          afina los filos semitransparentes (alpha matting: pelo, hojas,
                   telas; tarda mas)
  --recortar       recorta la imagen a lo que queda
Salida: <nombre>_sin_fondo.png
"""
import os
import sys

from PIL import Image
from rembg import new_session, remove


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[1:] if a.startswith("--"))
    if not args:
        print(__doc__)
        return
    sesion = new_session(op.get("modelo", "birefnet-general"))
    for ruta in args:
        img = Image.open(ruta).convert("RGB")
        out = remove(img, session=sesion, alpha_matting="filos" in op,
                     alpha_matting_foreground_threshold=240, alpha_matting_background_threshold=15,
                     alpha_matting_erode_size=8)
        if "recortar" in op:
            caja = out.getbbox()
            if caja:
                out = out.crop(caja)
        carpeta = op.get("carpeta", os.path.dirname(os.path.abspath(ruta)))
        os.makedirs(carpeta, exist_ok=True)
        nombre = os.path.splitext(os.path.basename(ruta))[0] + "_sin_fondo.png"
        destino = os.path.join(carpeta, nombre)
        out.save(destino)
        print(destino)


if __name__ == "__main__":
    main()
