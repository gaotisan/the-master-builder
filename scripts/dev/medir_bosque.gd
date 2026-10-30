extends Node
## MEDIR UN PLANO DEL BOSQUE (2026-10-29): abre 'escena' y, con el peregrino
## quieto y sin vsync, apaga por turnos cada capa (A/B seguido, 'rondas' veces)
## y escribe cuanto baja el fotograma y la GPU. Despues, con vsync como al jugar,
## lo hace andar 'andar' s hacia el fondo y escribe la cadencia: cuantos
## fotogramas duran 1, 2 o mas refrescos de 60 Hz (lo que se ve como tirones).
## Necesita ventana. Uso: medir_bosque.bat [res://scenes/game/camino_bosque.tscn]

@export var escena := "res://scenes/game/camino_derecho.tscn"
@export var asentar := 0.3
@export var medir := 1.0
@export var rondas := 5
@export var andar := 12.0

var _plano: Node
var _vp: RID
var _midiendo := false
var _dts: PackedFloat32Array = []
var _gpus: PackedFloat32Array = []
var _aire_vp: RID
var _extra := PackedFloat64Array([0, 0, 0, 0])   # GPU aire, CPU render, CPU preparar, scripts
var _t_scripts := 0
var _antes: Node
var _lineas: PackedStringArray = []


func _ready() -> void:
	add_to_group(&"sin_pausa")
	var solo := []
	var con_andar := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("res://"):
			escena = a
		elif a == "sin_andar":
			con_andar = false
		elif a == "andar":
			solo = ["-"]     # ninguna capa: solo la cadencia andando
		elif a.begins_with("solo="):
			solo = a.substr(5).split(",")
	_plano = load(escena).instantiate()
	get_tree().root.add_child.call_deferred(_plano)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = _plano
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_aire_vp = (_plano.get_node("AireVista") as SubViewport).get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_aire_vp, true)
	# el tiempo de los scripts: de un nodo que va el primero a este, que va el ultimo
	process_priority = 100000
	_antes = Node.new()
	_antes.process_priority = -100000
	_antes.set_script(_marca())
	_antes.set_meta(&"medidor", self)
	add_child(_antes)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var tope := Engine.max_fps     # el de Cadencia (fps30), para andar
	Engine.max_fps = 0
	await get_tree().create_timer(3.0).timeout
	_linea("%s  ventana %s" % [escena, DisplayServer.window_get_size()])
	var capas := _capas() if solo != ["-"] else {}
	var base := await _medir()
	_linea("base: fotograma %.2f ms, GPU (con el aire) %.2f ms; GPU aire %.2f, CPU render %.2f, CPU preparar %.2f, scripts %.2f ms" % [
		base[0], base[1], _extra[0], _extra[1], _extra[2], _extra[3]])
	for nombre in capas:
		if not solo.is_empty() and not solo.any(func(x): return nombre.contains(x)):
			continue
		var difs := []
		for r in rondas:
			var antes := await _medir()
			var deshacer: Callable = capas[nombre].call()
			await get_tree().create_timer(asentar).timeout
			var sin := await _medir()
			deshacer.call()
			await get_tree().create_timer(asentar).timeout
			difs.append(sin[0] - antes[0])
		difs.sort()
		var gana := Vector2(difs[difs.size() / 2], difs[0])
		_linea("  sin %-22s fotograma %+.2f ms (mediana de %d; la menor %+.2f)" % [nombre, gana.x, rondas, gana.y])
	if not con_andar:
		get_tree().quit()
		return
	# Andando, con vsync.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = tope
	await get_tree().create_timer(1.0).timeout
	Input.action_press("saltar")
	# (de paso, lo que tarda Cadencia en decidir si fija el tope)
	await get_tree().create_timer(4.0).timeout
	var r := await _medir(andar)
	Input.action_release("saltar")
	var cuenta := {}
	var peor := 0.0
	for dt in _dts:
		var refrescos := clampi(roundi(dt * 1000.0 / 16.667), 1, 9)
		cuenta[refrescos] = cuenta.get(refrescos, 0) + 1
		peor = maxf(peor, dt * 1000.0)
	var claves := cuenta.keys()
	claves.sort()
	var partes := []
	for k in claves:
		partes.append("%dx%d" % [cuenta[k], k])
	_linea("tope de fps: %d" % Engine.max_fps)
	_linea("andando con vsync: %.1f fps, peor %.0f ms, GPU %.2f ms (aire %.2f), CPU render %.2f, preparar %.2f, scripts %.2f; fotogramas x refrescos: %s" % [
		1000.0 / r[0], peor, r[1], _extra[0], _extra[1], _extra[2], _extra[3], ", ".join(partes)])
	get_tree().quit()


## Entre medidas (no durante: el volcado mete picos).
func _linea(l: String) -> void:
	_lineas.append(l)
	print(l)


## Cada capa: una funcion que la apaga y devuelve la que la vuelve a encender.
## Las variantes de shader cambian un trozo del codigo (con lo que no se usa, el
## compilador quita las cuentas que lo alimentan).
func _capas() -> Dictionary:
	var c := {}
	var fondo: Sprite2D = _plano.get_node("Fondo")
	var aire: SubViewport = _plano.get_node("AireVista")
	var rect: ColorRect = aire.get_node("Aire")
	c["fondo (shader entero)"] = func():
		var mat := fondo.material
		fondo.material = null
		return func(): fondo.material = mat
	var variantes := {
		"fondo paralaje 6 pasos": [fondo, "const int PASOS = 12;", "const int PASOS = 6;"],
		"fondo paralaje 1 paso": [fondo, "const int PASOS = 12;", "const int PASOS = 1;"],
		"fondo sin copa": [fondo, "if (copa > 0.002) {", "if (false) {"],
		"fondo sin suelo": [fondo, "if (suelo > 0.0) {", "if (false) {"],
		"aire sin niebla": [rect, "float niebla = 1.0 - (1.0 - af) * (1.0 - am) * (1.0 - ac) * (1.0 - as_);", "float niebla = 0.0;"],
		"aire sin rasante": [rect, "float as_ = jirones(g * vec2(0.9, 0.7), t, 0.37) * banda * suelo_fuerza;", "float as_ = 0.0;"],
		"aire sin rayos": [rect, "float rayo = haz *", "float rayo = 0.0 *"],
		"aire sin luz": [rect, "float l = nl * 0.8", "float l = 0.0 * nl * 0.8"],
	}
	for nombre in variantes:
		var v: Array = variantes[nombre]
		c[nombre] = func():
			var mat: ShaderMaterial = v[0].material
			var orig := mat.shader
			assert(orig.code.contains(v[1]), nombre)
			var sh := Shader.new()
			sh.code = orig.code.replace(v[1], v[2])
			mat.shader = sh
			return func(): mat.shader = orig
	c["aire (SubViewport)"] = func():
		var antes := aire.render_target_update_mode
		aire.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return func(): aire.render_target_update_mode = antes
	c["aire a 1/8"] = func():
		var antes := aire.size
		aire.size = antes / 2
		rect.size = Vector2(antes / 2)
		return func():
			aire.size = antes
			rect.size = Vector2(antes)
	c["Peregrino"] = func():
		var nodo: CanvasItem = _plano.get_node_or_null("Peregrino")
		nodo.visible = false
		return func(): nodo.visible = true
	return c


## Media del fotograma y de la GPU (ms) durante `cuanto` s.
func _medir(cuanto := -1.0) -> Vector2:
	_dts.clear()
	_gpus.clear()
	_extra = PackedFloat64Array([0, 0, 0, 0])
	_midiendo = true
	await get_tree().create_timer(medir if cuanto < 0.0 else cuanto).timeout
	_midiendo = false
	var dt := 0.0
	var g := 0.0
	for x in _dts:
		dt += x
	for x in _gpus:
		g += x
	var n := maxf(_dts.size(), 1)
	var orden := _dts.duplicate()
	orden.sort()
	var mediana := orden[orden.size() / 2] if orden.size() > 0 else 0.0
	for i in 4:
		_extra[i] /= n
	return Vector2((mediana if cuanto < 0.0 else dt / n) * 1000.0, g / maxf(_gpus.size(), 1) + _extra[0])


func _process(delta: float) -> void:
	if _midiendo:
		_dts.append(delta)
		_gpus.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
		_extra[0] += RenderingServer.viewport_get_measured_render_time_gpu(_aire_vp)
		_extra[1] += RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.viewport_get_measured_render_time_cpu(_aire_vp)
		_extra[2] += RenderingServer.get_frame_setup_time_cpu()
		_extra[3] += (Time.get_ticks_usec() - _t_scripts) / 1000.0


func marcar() -> void:
	_t_scripts = Time.get_ticks_usec()


static func _marca() -> GDScript:
	var g := GDScript.new()
	g.source_code = "extends Node
func _process(_d):
	get_meta(&'medidor').marcar()
"
	g.reload()
	return g
