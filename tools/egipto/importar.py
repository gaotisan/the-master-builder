"""Deja las texturas de assets/egipto/acto1 listas para Godot: compresion en VRAM
(BPTC) y mipmaps (al abrir el encuadre la piedra no parpadea), y quita los
.import de texturas que ya no existen. Escribe el .import de las nuevas antes de
que Godot las vea; luego: Godot --headless --import.
"""
import os

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.dirname(os.path.dirname(AQUI))
CARPETAS = [os.path.join(PROYECTO, "assets", "egipto", "acto1", c) for c in ("tex", "objetos", "fondo", "tira", "capas", "barcos")]

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


def main():
    nuevos = viejos = 0
    for c in CARPETAS:
        if not os.path.isdir(c):
            continue
        for f in os.listdir(c):
            ruta = os.path.join(c, f)
            if f.endswith(".png.import") and not os.path.exists(ruta[:-7]):
                os.remove(ruta)
                viejos += 1
            elif f.endswith(".png"):
                imp = ruta + ".import"
                if os.path.exists(imp):
                    t = open(imp, encoding="utf-8").read()
                    if "compress/mode=2" in t and "mipmaps/generate=true" in t:
                        continue
                    t = t[:t.index("[params]")] + PARAMS
                else:
                    t = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + PARAMS
                    nuevos += 1
                open(imp, "w", encoding="utf-8").write(t)
    print("import: %d nuevos, %d quitados" % (nuevos, viejos))


if __name__ == "__main__":
    main()
