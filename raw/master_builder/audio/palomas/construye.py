"""Las palomas de Egipto (2026-10-29): sus sonidos sacados del video del usuario
(Person_startles_resting_pigeons, de Flow, 8 s): al principio la bandada posada
arrullando y luego, cuando entra la persona, la espantada.

    python construye.py

Escribe en assets/audio:
  - palomas_arrullo.ogg: el arrullo de la bandada posada, en bucle (8 s: las dos
    frases de arrullo del video, 0,2-1,3 s y 1,4-2,4 s, solapadas a varios
    tonos como si arrullaran varias; el bucle casa principio con final).
  - palomas_espantada.ogg: la bandada que sale volando (3,2-6,9 s del video;
    entra con la primera palmada de alas a los 0,2 s del fichero).
  - paloma_aleteo.ogg: una sola que echa a volar (la cola de la espantada,
    6,0-7,3 s: las ultimas palmadas sueltas).
Y palomas_ficha.png, la onda de cada uno, para comprobar.
"""
import os, subprocess, numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt, resample_poly
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(RAIZ, "tools", "ffmpeg", "bin", "ffmpeg.exe")
DESTINO = os.path.join(RAIZ, "assets", "audio")
FUENTE = os.path.join(AQUI, "palomas_espantadas_video.wav")
SR = 48000


def leer():
    sr, a = wavfile.read(FUENTE)
    a = a.astype(np.float32) / 32768.0
    if a.ndim > 1:
        a = a.mean(axis=1)
    if sr != SR:
        a = resample_poly(a, SR, sr).astype(np.float32)
    # (fuera el retumbe de la sala por debajo de 90 Hz)
    return sosfiltfilt(butter(4, 90, "highpass", fs=SR, output="sos"), a).astype(np.float32)


def trozo(a, t0, t1, fundido=0.03):
    t = a[int(t0 * SR):int(t1 * SR)].copy()
    n = int(fundido * SR)
    t[:n] *= np.linspace(0, 1, n)
    t[-n:] *= np.linspace(1, 0, n)
    return t


def tono(t, k):
    """Sube o baja el tono k veces (cambia algo la duracion: es un arrullo, da igual)."""
    x = np.arange(0, len(t) - 1, k)
    return np.interp(x, np.arange(len(t)), t).astype(np.float32)


def normalizar(t, pico_db):
    return t * (10 ** (pico_db / 20) / (np.abs(t).max() + 1e-9))


def arrullo(a):
    largo = 8.0
    n = int(largo * SR)
    out = np.zeros(n, np.float32)
    frases = [trozo(a, 0.2, 1.3, 0.08), trozo(a, 1.4, 2.4, 0.08)]
    rng = np.random.default_rng(7)
    # varias palomas: cada frase entra a su tiempo, con su tono y su volumen;
    # lo que pasa del final vuelve al principio (bucle sin costura)
    t = 0.0
    while t < largo:
        f = tono(frases[rng.integers(2)], rng.uniform(0.9, 1.1)) * rng.uniform(0.45, 1.0)
        i = int(t * SR)
        idx = (np.arange(len(f)) + i) % n
        np.add.at(out, idx, f)
        t += rng.uniform(0.35, 0.9)
    return normalizar(out, -6.0)


def ogg(nombre, t):
    wav = os.path.join(AQUI, nombre + ".wav")
    wavfile.write(wav, SR, (np.clip(t, -1, 1) * 32767).astype(np.int16))
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6",
                    os.path.join(DESTINO, nombre + ".ogg")], check=True)
    os.remove(wav)


def main():
    a = leer()
    sonidos = {
        "palomas_arrullo": arrullo(a),
        "palomas_espantada": normalizar(trozo(a, 3.2, 6.9, 0.04), -1.0),
        "paloma_aleteo": normalizar(trozo(a, 6.0, 7.3, 0.02), -3.0),
    }
    fig, ejes = plt.subplots(len(sonidos), 1, figsize=(12, 6))
    for (nombre, t), ax in zip(sonidos.items(), ejes):
        ogg(nombre, t)
        ax.plot(np.arange(len(t)) / SR, t, lw=0.3)
        ax.set_title(nombre)
    fig.tight_layout()
    fig.savefig(os.path.join(AQUI, "palomas_ficha.png"), dpi=80)
    print("hecho:", ", ".join(sonidos))


if __name__ == "__main__":
    main()
