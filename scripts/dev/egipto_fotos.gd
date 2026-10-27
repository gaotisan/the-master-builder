extends Node
## Fotos del ACTO I de Egipto (PRUEBA): pone al peregrino en cada x de 'puntos',
## deja asentar la camara y guarda la pantalla en 'carpeta' (foto_<x>.png).
## Para revisar el arte sin jugar: necesita ventana (no --headless).

@export var puntos: Array = [900.0, 3000.0, 5700.0, 7600.0, 10300.0, 10800.0, 12300.0, 14800.0, 16450.0, 19200.0, 21500.0, 23000.0]
@export var carpeta := "user://egipto_fotos"
@export var espera := 1.6
## Si no esta vacio: no mueve a nadie, solo saca fotos en estos segundos (con un
## Bot que lo lleve, para las cinematicas).
@export var tiempos: Array = []

func _ready() -> void:
	# (sin la pausa al perder el foco: la ventana de las fotos no lo tiene)
	add_to_group(&"sin_pausa")
	DirAccess.make_dir_recursive_absolute(carpeta)
	if not tiempos.is_empty():
		var antes := 0.0
		for s in tiempos:
			await get_tree().create_timer(float(s) - antes).timeout
			antes = float(s)
			await RenderingServer.frame_post_draw
			var ruta2 := "%s/cine_%04d.png" % [carpeta, int(float(s) * 10)]
			get_viewport().get_texture().get_image().save_png(ruta2)
			print("foto ", ProjectSettings.globalize_path(ruta2))
		get_tree().quit()
		return
	await get_tree().create_timer(0.5).timeout
	var nivel := get_parent()
	var p: Node2D = nivel.get_node("DarkStage/Peregrino")
	var acc := nivel.get_node("Acciones")
	for x in puntos:
		p.position = Vector2(x, acc.altura_en(x))
		nivel.saltar_camara()
		await get_tree().create_timer(espera).timeout
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		var ruta := "%s/foto_%05d.png" % [carpeta, int(x)]
		im.save_png(ruta)
		print("foto ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()
