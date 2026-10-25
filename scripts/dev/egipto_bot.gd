extends Node
## Recorre el ACTO I de Egipto solo (PRUEBA): pasos que esperan a que el
## peregrino llegue a una x o se quede quieto, y pulsan teclas como el jugador.
## Para probar el recorrido entero (y grabarlo con --write-movie) sin nadie al
## teclado. Pasos: ["der"|"izq"] mantener, ["corre", 1|-1] doble toque y
## mantener, ["suelta"], ["salta"], ["agacha"], ["levanta"], ["accion"],
## ["hasta", x] (hasta pasar x hacia donde va), ["quieto"] (reposo y con
## control), ["parado"] (lo mismo aunque siga la tecla), ["espera", s], ["fin"].

@export var pasos: Array = []
@export var personaje: NodePath = ^"../DarkStage/Peregrino"
@export var traza := 0.5          # cada cuanto escribe donde esta (s); 0 nunca
@export var salir_al_acabar := true

var _p: Node2D
var _i := 0
var _t := 0.0
var _t_paso := 0.0
var _t_traza := 0.0
var _dir := 1.0
var _pulsadas := {}

func _ready() -> void:
	_p = get_node(personaje)
	process_physics_priority = -10

func _pulsa(accion: String, si: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = si
	Input.parse_input_event(ev)
	if si:
		_pulsadas[accion] = true
	else:
		_pulsadas.erase(accion)

func _toque(accion: String) -> void:
	_pulsa(accion, true)
	await get_tree().create_timer(0.08).timeout
	_pulsa(accion, false)

func _estado() -> String:
	return String(_p.datos_movimiento()["estado"])

func _physics_process(delta: float) -> void:
	_t += delta
	_t_paso += delta
	if traza > 0.0:
		_t_traza += delta
		if _t_traza >= traza:
			_t_traza = 0.0
			var dm: Dictionary = _p.datos_movimiento()
			print("bot %.1f paso %d x %.0f y %.0f %s %s f%d%s" % [_t, _i, _p.position.x, _p.position.y, dm["estado"], dm["animacion"], dm["fotograma"], " AIRE" if _p.en_el_aire() else ""])
	while _i < pasos.size():
		var paso: Array = pasos[_i]
		var hecho := true
		match String(paso[0]):
			"der", "izq":
				_dir = 1.0 if paso[0] == "der" else -1.0
				_soltar_dir()
				_pulsa("mover_derecha" if _dir > 0.0 else "mover_izquierda", true)
			"corre":
				_dir = float(paso[1])
				var a := "mover_derecha" if _dir > 0.0 else "mover_izquierda"
				_soltar_dir()
				_corre(a)
			"suelta":
				_soltar_dir()
			"salta":
				_toque("saltar")
			"agacha":
				_pulsa("agacharse", true)
			"levanta":
				_pulsa("agacharse", false)
			"accion":
				_toque("accion")
			"hasta":
				hecho = (_p.position.x - float(paso[1])) * _dir >= 0.0
				if not hecho and _t_paso > 60.0:
					print("bot: ATASCADO esperando x %s en %.0f" % [paso[1], _p.position.x])
					hecho = true
			"quieto":
				hecho = _estado() == "REPOSO" and not _p.control_bloqueado and _t_paso > 0.2
				if not hecho and _t_paso > 60.0:
					print("bot: ATASCADO esperando reposo (%s)" % _estado())
					hecho = true
			"parado":
				# quieto aunque siga la tecla (contra una cara o un limite)
				hecho = _estado() == "REPOSO" and not _p.control_bloqueado and _t_paso > 0.6
				if not hecho and _t_paso > 60.0:
					print("bot: ATASCADO esperando que se pare (%s)" % _estado())
					hecho = true
			"espera":
				hecho = _t_paso >= float(paso[1])
			"fin":
				print("bot: FIN en %.1f s, x %.0f y %.0f" % [_t, _p.position.x, _p.position.y])
				if salir_al_acabar:
					get_tree().quit()
				hecho = true
		if not hecho:
			break
		print("bot %.1f hecho %s (x %.0f y %.0f %s)" % [_t, str(paso), _p.position.x, _p.position.y, _estado()])
		_i += 1
		_t_paso = 0.0
	for accion in _pulsadas:
		if not Input.is_action_pressed(accion):
			Input.action_press(accion)

func _soltar_dir() -> void:
	for a in ["mover_derecha", "mover_izquierda"]:
		if _pulsadas.has(a):
			_pulsa(a, false)

func _corre(a: String) -> void:
	# (el doble toque: dos pulsaciones cortas seguidas, cada una de varios fotogramas)
	_pulsa(a, true)
	await get_tree().create_timer(0.1).timeout
	_pulsa(a, false)
	await get_tree().create_timer(0.1).timeout
	_pulsa(a, true)
