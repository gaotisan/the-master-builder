extends Node3D
## Prueba de la nave 3D (2026-10-27): la saca grande desde varios angulos y con
## las patas fuera y recogidas, guarda las fotos en 'carpeta' y sale.

@export var carpeta := "user://nave_prueba"
const POSES := [[0.4, 0.0, 1.0], [0.0, 0.0, 1.0], [0.4, 0.0, 0.0], [-0.6, 0.12, 1.0], [1.2, -0.25, 0.4]]

var _nave: Nave3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# (la luz de la escena, la de NavePosada: sombra azul pizarra y sol bajo calido)
	env.environment.ambient_light_color = NavePosada.SOMBRA
	env.environment.ambient_light_energy = 1.0
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.basis = Basis.looking_at(NavePosada.SOL_DIR)
	sol.light_color = NavePosada.SOL
	sol.light_energy = NavePosada.SOL_E
	add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.9
	cam.position = Vector3(0, 0, 5)
	add_child(cam)
	_nave = Nave3D.new()
	add_child(_nave)
	for i in POSES.size():
		var p: Array = POSES[i]
		_nave.rotation = Vector3(p[1], p[0], 0.0)
		_nave.patas = p[2]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/nave_%d.png" % [carpeta, i])
	get_tree().quit()
