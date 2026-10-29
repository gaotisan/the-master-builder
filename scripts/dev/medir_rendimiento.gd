extends Node
## MEDIR EL RENDIMIENTO DE UN NIVEL (2026-10-29, Egipto): sin vsync, pone al
## peregrino en cada x de 'puntos', deja asentar 'asentar' s y mide 'medir' s:
## FPS, peor fotograma, CPU (proceso y fisica), GPU del viewport, llamadas de
## dibujo, objetos, nodos y memoria de texturas. Con 'puntos' vacio, mide donde
## este (con un Bot que lo lleve) cada 'medir' s hasta 'hasta' s. Escribe una
## linea por medida (y un CSV en 'csv' si no esta vacio). Necesita ventana.

@export var puntos: Array = []
@export var asentar := 1.5
@export var medir := 3.0
@export var hasta := 30.0
@export var csv := ""

var _vp: RID
var _n := 0
var _dt := 0.0
var _peor := 0.0
var _gpu := 0.0
var _gpu_max := 0.0
var _cpu_r := 0.0
var _proc := 0.0
var _fis := 0.0
var _midiendo := false
var _lineas: PackedStringArray = []

func _ready() -> void:
	add_to_group(&"sin_pausa")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_lineas.append("x,fps,peor_ms,gpu_ms,gpu_max_ms,cpu_render_ms,proceso_ms,fisica_ms,dibujos,objetos,primitivas,nodos,tex_mb,video_mb")
	await get_tree().create_timer(0.5).timeout
	var nivel := get_parent()
	var p: Node2D = nivel.get_node("DarkStage/Peregrino")
	if puntos.is_empty():
		var t := 0.0
		while t < hasta:
			await get_tree().create_timer(asentar).timeout
			await _medir(p.position.x)
			t += asentar + medir
	else:
		var acc := nivel.get_node("Acciones")
		for x in puntos:
			p.position = Vector2(float(x), acc.altura_en(float(x)))
			nivel.saltar_camara()
			await get_tree().create_timer(asentar).timeout
			await _medir(float(x))
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_string("\n".join(_lineas))
	get_tree().quit()

func _medir(x: float) -> void:
	_n = 0
	_dt = 0.0
	_peor = 0.0
	_gpu = 0.0
	_gpu_max = 0.0
	_cpu_r = 0.0
	_proc = 0.0
	_fis = 0.0
	_midiendo = true
	await get_tree().create_timer(medir).timeout
	_midiendo = false
	var n := maxf(_n, 1)
	var linea := "%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%.0f,%.0f" % [
		int(x), n / maxf(_dt, 0.001), _peor * 1000.0, _gpu / n, _gpu_max, _cpu_r / n,
		_proc / n * 1000.0, _fis / n * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
	_lineas.append(linea)
	print("medida ", linea)

func _process(delta: float) -> void:
	if not _midiendo:
		return
	_n += 1
	_dt += delta
	_peor = maxf(_peor, delta)
	var g := RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	_gpu += g
	_gpu_max = maxf(_gpu_max, g)
	_cpu_r += RenderingServer.viewport_get_measured_render_time_cpu(_vp)
	_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	_fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
