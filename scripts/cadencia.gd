extends Node
## CADENCIA (2026-10-30). Si la maquina no llega al refresco de la pantalla, el
## juego se fija a la mitad (30 fps en una de 60 Hz): asi cada fotograma dura
## dos refrescos y el paso sale regular. Sin el tope, a ~35 fps unos duran uno
## y otros dos (en la P520 frenada, andando por el camino derecho: 212 de uno y
## 247 de dos) y el peregrino andaba a tirones.
##
## Se mira una ventana de VENTANA s; si en ella LENTOS de los fotogramas tardan
## dos refrescos o mas, se fija. Tras un cambio de escena se espera un poco (la
## carga da tirones sueltos que no cuentan). Una vez fijado, se queda hasta
## cerrar el juego: con el tope puesto no se ve si ya llegaria, y subir y bajar
## se notaria mas que quedarse en 30.
##
## Solo con vsync y sin tope de otro (los medidores de scripts/dev lo quitan) ni
## --write-movie / --fixed-fps. Para probar: tras --, fps30 (fijado desde el
## principio) o fps60 (nunca).

const VENTANA := 2.0
const LENTOS := 0.25
const ESPERA_TRAS_CAMBIO := 1.0

var _hz := 60.0
var _activo := true
var _fijado := false
var _espera := ESPERA_TRAS_CAMBIO
var _dts: Array[float] = []
var _suma := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hz := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	if hz > 1.0:
		_hz = hz
	for a in OS.get_cmdline_args():
		if a.begins_with("--write-movie") or a.begins_with("--fixed-fps"):
			_activo = false
	var args := OS.get_cmdline_user_args()
	if "fps60" in args:
		_activo = false
	get_tree().scene_changed.connect(_al_cambiar)
	if "fps30" in args and _activo:
		_fijar()


func _al_cambiar() -> void:
	_espera = ESPERA_TRAS_CAMBIO


func _process(delta: float) -> void:
	if _fijado or not _activo:
		return
	if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED or Engine.max_fps != 0:
		return
	if _espera > 0.0:
		_espera -= delta
		_dts.clear()
		_suma = 0.0
		return
	_dts.append(delta)
	_suma += delta
	while _suma > VENTANA and _dts.size() > 1:
		_suma -= _dts.pop_front()
	if _suma < VENTANA * 0.9:
		return
	var lentos := 0
	for dt in _dts:
		if dt > 1.5 / _hz:
			lentos += 1
	if lentos >= LENTOS * _dts.size():
		_fijar()


func _fijar() -> void:
	_fijado = true
	Engine.max_fps = maxi(roundi(_hz / 2.0), 30)
	print("Cadencia: no llega a %.0f fps, fijado a %d" % [_hz, Engine.max_fps])
