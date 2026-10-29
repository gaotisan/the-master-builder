extends Node
## QUIEN SE LLEVA EL TIEMPO DE PROCESO (2026-10-29, Egipto): en la x 'en', agrupa
## los nodos del arbol por script (o por clase, los que no tienen) y, grupo a
## grupo, les apaga el proceso (normal, interno y de fisica) un rato y mide
## cuanto baja TIME_PROCESS y TIME_PHYSICS_PROCESS respecto a lo de antes y
## despues (con todo encendido). Escribe los grupos que mas cuestan.

@export var en := 1000.0
@export var asentar := 0.4
@export var medir := 0.8
@export var rondas := 3
## Si no esta vacio, solo estos grupos (A/B mas fino, con mas rondas).
@export var solo: Array = []

func _ready() -> void:
	add_to_group(&"sin_pausa")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.5).timeout
	var nivel := get_parent()
	var p: Node2D = nivel.get_node("DarkStage/Peregrino")
	p.position = Vector2(en, nivel.get_node("Acciones").altura_en(en))
	nivel.saltar_camara()
	await get_tree().create_timer(2.0).timeout
	var grupos := {}
	for n in _todos(get_tree().root):
		if n == self:
			continue
		var s: Script = n.get_script()
		var k: String = s.resource_path if s else n.get_class()
		if k == "":
			k = n.get_class() + " (script sin ruta)"
		if not grupos.has(k):
			grupos[k] = []
		grupos[k].append(n)
	var res := []
	for k in grupos:
		if k == "Window" or (not solo.is_empty() and not solo.has(k)):
			continue
		var gana := 0.0
		for r in rondas:
			var antes := await _fotograma()
			var estados := _apagar(grupos[k])
			await get_tree().create_timer(asentar).timeout
			var sin := await _fotograma()
			_encender(grupos[k], estados)
			await get_tree().create_timer(asentar).timeout
			gana += antes - sin
		res.append([gana / rondas, 0.0, k, grupos[k].size()])
	res.sort_custom(func(a, b): return a[0] + a[1] > b[0] + b[1])
	var base := await _fotograma()
	print("grupos base: fotograma %.2f ms (%.0f fps)" % [base, 1000.0 / base])
	for r in res.slice(0, 25):
		print("grupo %6.2f ms  x%-4d %s" % [r[0], r[3], r[2]])
	get_tree().quit()

func _apagar(nodos: Array) -> Array:
	var estados := []
	for n in nodos:
		var e := [n.is_processing(), n.is_processing_internal(), n.is_physics_processing(), n.is_physics_processing_internal()]
		if n is SubViewport:
			e.append(n.render_target_update_mode)
			n.render_target_update_mode = SubViewport.UPDATE_DISABLED
		estados.append(e)
		n.set_process(false)
		n.set_process_internal(false)
		n.set_physics_process(false)
		n.set_physics_process_internal(false)
	return estados

func _encender(nodos: Array, estados: Array) -> void:
	for i in nodos.size():
		var n: Node = nodos[i]
		var e: Array = estados[i]
		n.set_process(e[0])
		n.set_process_internal(e[1])
		n.set_physics_process(e[2])
		n.set_physics_process_internal(e[3])
		if n is SubViewport:
			n.render_target_update_mode = e[4]

## La media del fotograma (ms) durante 'medir' s.
func _fotograma() -> float:
	var n := 0
	var t := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(medir * 1000000.0):
		await get_tree().process_frame
		n += 1
	t = float(Time.get_ticks_usec() - t0) / 1000.0
	return t / maxf(n, 1)

func _tiempos() -> Vector2:
	var n := 0
	var pr := 0.0
	var fi := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(medir * 1000.0):
		await get_tree().process_frame
		n += 1
		pr += Performance.get_monitor(Performance.TIME_PROCESS)
		fi += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	return Vector2(pr, fi) / maxf(n, 1) * 1000.0

func _todos(n: Node) -> Array:
	var r := [n]
	for c in n.get_children():
		r.append_array(_todos(c))
	return r
