extends Node
## JUGAR AL AZAR EN EGIPTO (PRUEBA, 2026-10-31): pulsa teclas al azar (andar,
## correr, saltar, saltos seguidos muy rapido) durante `segundos` y escribe lo
## raro que vea, para encontrar fallos del recorrido sin jugar a mano:
##   FLOTA / HUNDIDO  de pie, el nodo lejos del suelo que hay (mas de 16 px)
##   PIES_DENTRO      los pies dentro de una caja (al trepar y al tocar encima de
##                    algo es normal unos fotogramas: mirar los que no sean eso)
##   CABEZA_DENTRO    la capucha dentro de una repisa de encima
##   SALTO_DE_X       el nodo se mueve de golpe en x (la y cambia al tocar suelo,
##                    con el sprite ya alli: SALTO_DE_Y no suele ser fallo)
##   SALTO ...        cada salto que mete la capucha en una repisa: cuanto (px) y
##                    en cual (unos 30 px es el orbe del baculo, que asoma)
## Headless y a 60 fps fijos va unas tres veces mas rapido que jugando:
##   Godot --headless --fixed-fps 60 --path . res://scenes/dev/egipto_azar.tscn
## Para empezar en otro sitio, x_inicio / y_inicio (la y, la de lo que pisa con
## signo menos: -269.6 encima de c004). Varias semillas en paralelo cubren mas.

@export var semilla := 1
@export var segundos := 240.0
@export var x_inicio := NAN
@export var y_inicio := NAN
## Escribir tambien los saltos que no tocan nada (lo que sube la capucha).
@export var ver_saltos := false

var _p: Node2D
var _a: Node
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _sig := 0.0
var _pulsadas := {}
var _y_antes := NAN
var _x_antes := NAN
var _avisos := {}
var _n := 0
var _colocado := false
var _en_salto := false
var _s_x0 := 0.0
var _s_anim := ""
var _s_arco := 0.0
var _s_mete := 0.0
var _s_caja := ""

func _ready() -> void:
	_p = get_node("../DarkStage/Peregrino")
	_a = get_node("../Acciones")
	_rng.seed = semilla
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

func _toque(accion: String, dura := 0.08) -> void:
	_pulsa(accion, true)
	await get_tree().create_timer(dura).timeout
	_pulsa(accion, false)

func _corre(a: String) -> void:
	_pulsa(a, true)
	await get_tree().create_timer(0.1).timeout
	_pulsa(a, false)
	await get_tree().create_timer(0.1).timeout
	_pulsa(a, true)

func _saltos_seguidos() -> void:
	for i in _rng.randi_range(2, 6):
		_toque("saltar", 0.05)
		await get_tree().create_timer(_rng.randf_range(0.08, 0.35)).timeout

func _decidir() -> void:
	var r := _rng.randf()
	var dir := "mover_derecha" if _rng.randf() < 0.6 else "mover_izquierda"
	for a in ["mover_derecha", "mover_izquierda"]:
		if _pulsadas.has(a) and _rng.randf() < 0.7:
			_pulsa(a, false)
	if r < 0.25:
		_pulsa(dir, true)
	elif r < 0.45:
		_corre(dir)
	elif r < 0.65:
		_toque("saltar")
	elif r < 0.78:
		_saltos_seguidos()
	elif r < 0.88:
		_pulsa(dir, true)
		_toque("saltar")
	_sig = _t + _rng.randf_range(0.15, 1.6)

func _aviso(que: String, extra := "") -> void:
	var dm: Dictionary = _p.datos_movimiento()
	var clave := "%s %d" % [que, int(_p.position.x / 40.0)]
	if _avisos.has(clave):
		return
	_avisos[clave] = true
	_n += 1
	print("RARO %.2f %s x %.0f y %.0f %s %s f%d modo %d %s" % [_t, que, _p.position.x, _p.position.y, dm["estado"], dm["animacion"], dm["fotograma"], _a._modo, extra])

func _physics_process(delta: float) -> void:
	_t += delta
	if not _colocado:
		_colocado = true
		if not is_nan(x_inicio):
			_p.position = Vector2(x_inicio, y_inicio)
		return
	if _t >= segundos:
		print("AZAR FIN semilla %d: %d avisos, x %.0f y %.0f" % [semilla, _n, _p.position.x, _p.position.y])
		get_tree().quit()
		return
	if _t >= _sig:
		_decidir()
	for accion in _pulsadas:
		if not Input.is_action_pressed(accion):
			Input.action_press(accion)
	_comprobar()

## La y (global) de lo mas alto que se ve del sprite: la capucha (o el orbe).
var _cimas := {}
func _cima(spr: AnimatedSprite2D) -> float:
	var clave := "%s %d" % [spr.animation, spr.frame]
	if not _cimas.has(clave):
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		var im := tex.get_image()
		if im.is_compressed():
			im.decompress()
		var r := im.get_used_rect()
		_cimas[clave] = float(r.position.y) - (tex.get_height() * 0.5 if spr.centered else 0.0)
	return spr.to_global(Vector2(0.0, spr.offset.y + float(_cimas[clave]))).y

func _comprobar() -> void:
	var dm: Dictionary = _p.datos_movimiento()
	var est := String(dm["estado"])
	var x: float = _p.position.x
	var y: float = _p.position.y
	var spr: AnimatedSprite2D = _p.get("_sprite")
	var pies: float = y + spr.position.y        # lo que se ve: el nodo mas el arco
	var libre: bool = _a._modo == 0
	# de pie (ni en el aire ni en una accion): el suelo que hay
	if libre and not (est in ["SALTAR", "CAYENDO", "CAIDA"]):
		var n: float = _a._nivel(x)
		if absf(n - y) > 16.0:
			_aviso("FLOTA" if n > y else "HUNDIDO", "nivel %.0f" % n)
	# los pies o la cabeza dentro de una caja (por la x del nodo)
	for o in _a._obj:
		if x <= o.x0 + 4.0 or x >= o.x1() - 4.0:
			continue
		var arriba: float = -o.alto
		var abajo: float = -float(_a._abajo.get(o.nombre, 0.0))
		if pies > arriba + 12.0 and pies < abajo - 4.0:
			_aviso("PIES_DENTRO", o.nombre)
		var cabeza := pies - 290.0
		if libre and cabeza > arriba + 4.0 and cabeza < abajo - 12.0 and pies >= abajo:
			_aviso("CABEZA_DENTRO", o.nombre)
	if not is_nan(_y_antes) and libre and absf(y - _y_antes) > 60.0 and est != "SALTAR":
		_aviso("SALTO_DE_Y", "%.0f -> %.0f" % [_y_antes, y])
	if not is_nan(_x_antes) and absf(x - _x_antes) > 40.0:
		_aviso("SALTO_DE_X", "%.0f -> %.0f" % [_x_antes, x])
	_y_antes = y
	_x_antes = x
	# cada salto: lo que mas sube la capucha y lo que mas la mete en una repisa
	if est == "SALTAR" or est == "CAYENDO":
		if not _en_salto:
			_en_salto = true
			_s_x0 = x
			_s_anim = String(dm["animacion"])
			_s_arco = 0.0
			_s_mete = 0.0
			_s_caja = ""
		_s_arco = maxf(_s_arco, y - _cima(spr))
		for o in _a._obj:
			if x <= o.x0 + 30.0 or x >= o.x1() - 30.0:
				continue
			var abajo2: float = -float(_a._abajo.get(o.nombre, 0.0))
			if abajo2 >= 0.0 or pies < abajo2:
				continue
			var mete := abajo2 - _cima(spr)
			if mete > _s_mete:
				_s_mete = mete
				_s_caja = o.nombre
	elif _en_salto:
		_en_salto = false
		if _s_mete > 0.0 or ver_saltos:
			print("SALTO %.2f %s x %.0f -> %.0f capucha %.0f mete %.0f en %s" % [_t, _s_anim, _s_x0, x, _s_arco, _s_mete, _s_caja])
