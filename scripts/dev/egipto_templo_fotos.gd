extends Node
## Prueba del templo del cortejo (2026-10-29): pone al peregrino en lo alto del
## altar (marca "mirador" del recorrido), donde se lanza el video, y saca fotos
## en 'tiempos' (segundos) y sale; sin tiempos, se queda para verlo jugando
## (egipto_templo.bat). Necesita ventana.

@export var carpeta := "user://egipto_templo"
@export var tiempos: Array = [1.0, 4.0, 9.0, 14.0, 19.0, 24.0, 29.0, 34.0]

func _ready() -> void:
	add_to_group(&"sin_pausa")
	DirAccess.make_dir_recursive_absolute(carpeta)
	var nivel := get_parent()
	await get_tree().process_frame
	var p: Node2D = nivel.get_node("DarkStage/Peregrino")
	var acc := nivel.get_node("Acciones")
	var x: float = acc.recorrido["marcas"]["mirador"]
	var arriba := 0.0
	for c in acc.recorrido["cajas"]:
		if x >= float(c["x0"]) and x <= float(c["x1"]):
			arriba = maxf(arriba, float(c["arriba"]))
	p.position = Vector2(x, float(acc.nivel["suelo"]) - arriba)
	nivel.saltar_camara()
	if tiempos.is_empty():
		return
	var antes := 0.0
	for s in tiempos:
		await get_tree().create_timer(float(s) - antes).timeout
		antes = float(s)
		await RenderingServer.frame_post_draw
		var ruta := "%s/templo_%03d.png" % [carpeta, int(float(s) * 10)]
		get_viewport().get_texture().get_image().save_png(ruta)
		print("foto ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()
