"""La intro en bucle de la musica del Acto I (Act I - Ancient Exploration).

La pista va por compases de ~5,93 s marcados por un golpe grave: 0-5,9 s el
fundido de entrada, 5,93-23,70 s la intro (pedal y notas largas, 3 compases) y
en 23,70 s entra el tema. El bucle es esa intro: el fichero lleva el fundido de
entrada (suena una vez) y los 3 compases; en Godot, loop_offset = INICIO_BUCLE
(sin el segundo de silencio del principio, como la pista completa).

La costura: el final del bucle se funde con lo que suena justo antes del golpe
de 5,93 s, asi al volver a INICIO_BUCLE el sonido sigue sin salto.

    python tools/egipto/musica_bucle.py [wav]
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

RAIZ = Path(__file__).resolve().parents[2]
WAV = Path.home() / "Downloads" / "Act I - Ancient Exploration.wav"
SALIDA = RAIZ / "assets" / "audio" / "musica_egipto_acto1_intro.ogg"
FFMPEG = RAIZ / "tools" / "ffmpeg" / "bin" / "ffmpeg.exe"

SILENCIO = 1.1       # s de silencio del principio que se quitan
GOLPE_A = 5.9344     # el golpe del primer compas de la intro
GOLPE_B = 23.7035    # el golpe con el que entra el tema
ANTES = 0.015        # se corta un poco antes del golpe
FUNDIDO = 0.4        # s de la costura


def main() -> None:
    wav = Path(sys.argv[1]) if len(sys.argv) > 1 else WAV
    x, sr = sf.read(wav, dtype="float64")
    s0 = round(SILENCIO * sr)
    a = round((GOLPE_A - ANTES) * sr)
    b = round((GOLPE_B - ANTES) * sr)
    n = round(FUNDIDO * sr)
    y = x[s0:b].copy()
    # Los ultimos n del bucle pasan a ser lo que suena antes de a.
    t = np.linspace(0.0, 1.0, n)[:, None]
    sale = np.cos(t * np.pi / 2)
    entra = np.sin(t * np.pi / 2)
    y[-n:] = x[b - n:b] * sale + x[a - n:a] * entra
    tmp = SALIDA.with_suffix(".tmp.wav")
    sf.write(tmp, y, sr, subtype="PCM_24")
    subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(tmp),
                    "-c:a", "libvorbis", "-q:a", "6",
                    "-metadata", "title=Act I - Ancient Exploration (intro)",
                    "-metadata", "artist=UniqueGnu", str(SALIDA)], check=True)
    tmp.unlink()
    print(f"{SALIDA.name}: {len(y) / sr:.4f} s, loop_offset = {(a - s0) / sr:.6f} s")


if __name__ == "__main__":
    main()
