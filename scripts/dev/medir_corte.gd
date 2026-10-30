extends Node
## LO QUE CUESTA UN CORTE DE CAMARA ENTRE PLANOS DEL BOSQUE (2026-10-30): con las
## escenas ya cargadas en segundo plano (como en el juego), mide instanciar,
## meter en el arbol (_ready) y los primeros fotogramas de cada plano, por turnos.

const Estado := preload("res://scripts/characters/peregrino_estado.gd")
const PLANOS := [["res://scenes/game/camino_derecho.tscn", "camino_bosque"],
	["res://scenes/game/camino_bosque.tscn", "camino_derecho"],
	["res://scenes/game/camino_derecho.tscn", "camino_bosque"],
	["res://scenes/game/camino_bosque.tscn", "camino_derecho"]]

var _lineas: PackedStringArray = []


func _ready() -> void:
	process_priority = -100000
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for p in PLANOS:
		ResourceLoader.load_threaded_request(p[0])
	var actual: Node = null
	for p in PLANOS:
		while ResourceLoader.load_threaded_get_status(p[0]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var retener = load("res://resources/characters/peregrino_frontal_hd.tres") if "retener" in OS.get_cmdline_user_args() else null
	for p in PLANOS:
		var ps: PackedScene = ResourceLoader.load_threaded_get(p[0])
		var base := await _fotogramas(30)
		Estado.dejar(get_tree(), true, 0.0, 0.0, p[1])
		var t0 := Time.get_ticks_usec()
		if actual:
			actual.free()
		var t1 := Time.get_ticks_usec()
		_lineas.append("   tras quitar: hojas HD en cache %s" % ResourceLoader.has_cached("res://resources/characters/peregrino_frontal_hd.tres"))
		var nueva := ps.instantiate()
		var t2 := Time.get_ticks_usec()
		var marcas := []
		for h in nueva.get_children():
			h.ready.connect(func(): marcas.append([String(h.name), Time.get_ticks_usec()]))
		get_tree().root.add_child(nueva)
		get_tree().current_scene = nueva
		var t3 := Time.get_ticks_usec()
		var partes := []
		var ant := t2
		for m in marcas:
			if m[1] - ant > 3000:
				partes.append("%s %.0f" % [m[0], (m[1] - ant) / 1000.0])
			ant = m[1]
		partes.append("raiz %.0f" % ((t3 - ant) / 1000.0))
		_lineas.append("   " + ", ".join(partes))
		var primeros := await _fotogramas(6)
		actual = nueva
		_lineas.append("%s: antes %.0f ms/fotograma; quitar %.0f, instanciar %.0f, _ready %.0f ms; primeros fotogramas %s ms" % [
			p[0].get_file(), base[base.size() / 2], (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0,
			" ".join(primeros.map(func(x): return "%.0f" % x))])
		_lineas.append("   " + " ".join(_detalle))
		await get_tree().create_timer(3.0).timeout
	for l in _lineas:
		print(l)
	get_tree().quit()


## Lo que tarda cada uno de los n fotogramas siguientes (ms). En _detalle, de
## cada uno: scripts (de este nodo, que va el primero, al ultimo), GPU y
## pipelines de shader compilados en ese fotograma.
var _detalle: PackedStringArray = []
var _t_proceso := 0


func _process(_d: float) -> void:
	_t_proceso = Time.get_ticks_usec()


func _fotogramas(n: int) -> Array:
	var r := []
	_detalle.clear()
	var t := Time.get_ticks_usec()
	var pip := _pipelines()
	for i in n:
		await get_tree().process_frame
		var a := Time.get_ticks_usec()
		r.append((a - t) / 1000.0)
		var p2 := _pipelines()
		_detalle.append("[gpu %.0f pip %d]" % [RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), p2 - pip])
		pip = p2
		t = a
	return r


func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
