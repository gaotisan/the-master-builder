"""El tema en bucle de la musica del Acto I (Act I - Ancient Exploration).

Lo que suena despues de la intro en bucle (musica_bucle.py) cuando sube al
altar y se lanza el templo del cortejo (2026-10-29, el usuario: "una pista con
el audio original en donde quitamos ese bucle y dejamos solo el estribillo ...
ya se puede repetir todo el rato sin parecer que la estoy poniendo desde el
principio").

Empieza justo donde acaba el bucle de la intro (el golpe con el que entra el
tema, 23,70 s), asi que pasar de uno a otro es la pista original tal cual. Va
hasta el compas que sigue a la ultima nota (169,0 s, que se apaga sola): el
golpe del tema vuelve a caer a compas. La costura: el final se funde con lo que
suena justo antes del golpe del tema (la intro apagandose), como la primera vez.
El tema no se repite literal en la pista (va creciendo), por eso vuelve entero.

    python tools/egipto/musica_tema.py [wav]
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from musica_bucle import ANTES, FFMPEG, GOLPE_B, RAIZ, WAV

SALIDA = RAIZ / "assets" / "audio" / "musica_egipto_acto1_tema.ogg"
# el compas 25 despues del golpe del tema (los golpes se van ~3 ms por compas
# de los 5,9230 s que salen de la intro: medido en los golpes fuertes)
COMPAS = 5.9263
FIN = GOLPE_B + 25 * COMPAS     # 171,86 s: la ultima nota (169,0) ya casi apagada
FUNDIDO = 1.0                   # s de la costura (lo que queda de su cola)


def main() -> None:
    wav = Path(sys.argv[1]) if len(sys.argv) > 1 else WAV
    x, sr = sf.read(wav, dtype="float64")
    b = round((GOLPE_B - ANTES) * sr)
    f = round((FIN - ANTES) * sr)
    n = round(FUNDIDO * sr)
    y = x[b:f].copy()
    # Los ultimos n pasan a ser lo que suena antes del golpe del tema.
    t = np.linspace(0.0, 1.0, n)[:, None]
    y[-n:] = x[f - n:f] * np.cos(t * np.pi / 2) + x[b - n:b] * np.sin(t * np.pi / 2)
    tmp = SALIDA.with_suffix(".tmp.wav")
    sf.write(tmp, y, sr, subtype="PCM_24")
    subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(tmp),
                    "-c:a", "libvorbis", "-q:a", "6",
                    "-metadata", "title=Act I - Ancient Exploration (tema)",
                    "-metadata", "artist=UniqueGnu", str(SALIDA)], check=True)
    tmp.unlink()
    print(f"{SALIDA.name}: {len(y) / sr:.4f} s (bucle entero)")


if __name__ == "__main__":
    main()
