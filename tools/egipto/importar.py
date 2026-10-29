"""Deja las texturas de assets/egipto/acto1 listas para Godot: compresion en VRAM
(BPTC) y mipmaps (al abrir el encuadre la piedra no parpadea), y quita los
.import de texturas que ya no existen. Escribe el .import de las nuevas antes de
que Godot las vea; luego: Godot --headless --import.

La carpeta del templo del cortejo (templo_rio.py), sin comprimir y sin mipmaps,
como su video: su ultimo fotograma y el barco suelto se ven en lugar del video
y con BPTC y mipmaps salian borrosos al acabar (2026-10-29).
"""
import os

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
CARPETAS = [os.path.join(PROYECTO, "assets", "egipto", "acto1", c) for c in ("tex", "objetos", "fondo", "tira", "capas", "barcos", "nave", "templo", "templo/barco")]

PARAMS = """[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
# (como el video: sin comprimir y sin mipmaps)
COMO_VIDEO = ("templo", "barco")
PARAMS_VIDEO = PARAMS.replace("compress/mode=2", "compress/mode=0").replace("mipmaps/generate=true", "mipmaps/generate=false")


def main():
    nuevos = viejos = 0
    for c in CARPETAS:
        if not os.path.isdir(c):
            continue
        params = PARAMS_VIDEO if os.path.basename(c) in COMO_VIDEO else PARAMS
        modo = "compress/mode=0" if params is PARAMS_VIDEO else "compress/mode=2"
        mip = "mipmaps/generate=false" if params is PARAMS_VIDEO else "mipmaps/generate=true"
        for f in os.listdir(c):
            ruta = os.path.join(c, f)
            if f.endswith(".png.import") and not os.path.exists(ruta[:-7]):
                os.remove(ruta)
                viejos += 1
            elif f.endswith(".png"):
                imp = ruta + ".import"
                if os.path.exists(imp):
                    t = open(imp, encoding="utf-8").read()
                    if modo in t and mip in t:
                        continue
                    t = t[:t.index("[params]")] + params
                else:
                    t = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + params
                    nuevos += 1
                open(imp, "w", encoding="utf-8").write(t)
    print("import: %d nuevos, %d quitados" % (nuevos, viejos))


if __name__ == "__main__":
    main()
