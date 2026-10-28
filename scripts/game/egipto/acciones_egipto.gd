extends "res://scripts/characters/acciones_perfil.gd"
## ACCIONES DEL ACTO I DE EGIPTO (2026-10-25). Las de perfil de siempre
## (acciones_perfil.gd, sin tocarlo) con el nivel de tools/egipto/montaje.py:
##   - El terreno son objetos quietos e invisibles (el dibujo va aparte: los
##     recortes de las referencias): columnas macizas desde el suelo de abajo
##     (el del patio, donde se empuja y se tira), con la altura de lo dibujado.
##   - LOS ESCALONES: lo que sube o baja hasta PELDANO px no es una cara ni un
##     borde (no para, no salta solo): las escaleras dibujadas se andan. El nivel
##     (egipto_acto1.gd) lleva el nodo a la altura de cada peldano.
##   - EL PASO BAJO: un sillar mas alto que el paso no cabe dentro (empujarlo
##     hacia alli no tiene sitio): el sillar alto que tapa la boca se aparta
##     tirando.
##   - LA LOSA del final no se mueve: andando contra ella, el empuje v2 hasta
##     apoyar las manos, unos segundos de esfuerzo sin avanzar y vuelta al
##     reposo; luego losa_intentada (el nivel corta ahi el acto). Esta sobre lo
##     que haya debajo (base), no en el suelo de abajo.
##   - LAS REPISAS (2026-10-28, el recorrido de piedra: tools/egipto/recorrido.py):
##     cajas con cara de arriba y de abajo, unas sobre otras. Lo que queda por
##     encima de la cabeza (DESPEJE) no estorba: se pasa por debajo y no es
##     suelo; lo demas, como siempre (cara que se trepa o se salta, suelo).

signal losa_intentada

const NIVEL := "res://assets/egipto/acto1/nivel.json"
const RECORRIDO := "res://assets/egipto/acto1/recorrido.json"
## Lo que tiene que quedar sobre los pies hasta la cara de abajo de una repisa
## para pasar por debajo (el peregrino mide ~305 px con la capucha).
const DESPEJE := 310.0
const OBJETOS_EGIPTO := "res://assets/egipto/acto1/objetos/%s.png"

## Lo que sube o baja un escalon que se anda (px).
@export var peldano := 52.0
## Del empuje v2 contra la losa: fotogramas del esfuerzo (ida y vuelta entre
## ellos, con las manos ya en la piedra) y cuanto dura.
@export var losa_esfuerzo := Vector2i(47, 60)
@export var losa_segundos := 2.6
## SOLO PLAYA (2026-10-26): sin ruinas ni sillares ni losa, el suelo plano de la
## arena de punta a punta (mientras llegan las piezas nuevas). Los limites, los
## de la arena de la tira.
@export var solo_playa := false
@export var limites_playa := Vector2(200.0, 22400.0)
## Para probar un tramo: {nombre del sillar: x0} donde empieza.
@export var prueba_bloques := {}
## En la playa, el recorrido de piedra (recorrido.json), si esta.
@export var con_recorrido := true

var recorrido := {}
## la cara de abajo (altura sobre la arena) de cada caja que no llega al suelo
var _abajo := {}

var nivel := {}
var _losa_base := 0.0
# la losa: -1 sin empezar; si no, segundos dentro del intento
var _losa_t := -1.0
var _losa_fase := 0                  # 0 hasta las manos, 1 esfuerzo, 2 vuelta
var _losa_f := 0.0
var _losa_x_manos := 0.0
var _losa_hecha := false

func _ready() -> void:
	nivel = JSON.parse_string(FileAccess.get_file_as_string(NIVEL))
	var p := get_node_or_null(peregrino_ruta)
	objetos = []
	if solo_playa and con_recorrido and FileAccess.file_exists(RECORRIDO):
		recorrido = JSON.parse_string(FileAccess.get_file_as_string(RECORRIDO))
		for c in recorrido["cajas"]:
			var n := "_" + String(c["nombre"])
			objetos.append([n, c["x0"], float(c["x1"]) - float(c["x0"]), c["arriba"], "", "", true])
			if float(c["abajo"]) > 0.5:
				_abajo[n] = float(c["abajo"])
		if recorrido["marcas"].has("limite_izq"):
			limites_playa.x = float(recorrido["marcas"]["limite_izq"])
	for t in ([] if solo_playa else nivel["terreno"]):
		# (lo de altura 0 es el suelo de abajo, que ya esta: como objeto taparia
		# las rendijas entre dos sillares juntos, que cuentan como uno)
		if float(t["h"]) >= 1.0:
			objetos.append(["_" + t["nombre"], t["x0"], t["x1"] - t["x0"], t["h"], "", "", true])
	if not solo_playa:
		for b in nivel["bloques"]:
			objetos.append([b["nombre"], b["x0"], b["ancho"], b["alto"], b["empuje"], b["accion"], b["trepable"]])
		var l: Dictionary = nivel["losa"]
		_losa_base = float(l.get("base", 0.0))
		# (una columna hasta su cima; con empuje, para que andar contra ella llegue a _empezar_empuje)
		objetos.append(["losa", l["x0"], l["ancho"], _losa_base + float(l["alto"]), "empujar_v2", "", false])
	sueltos = []
	# las dos trepas se solapan (medio hasta 234, alto desde 232): sin el hueco
	# de 225-252 que no se podia subir ni de una forma ni de otra, y que las
	# alturas de lo dibujado (recortes) no siempre esquivan
	margen_altura = 0.36
	if p:
		# el suelo de abajo manda (acciones_perfil.gd lo toma de donde pisa el
		# peregrino al empezar) y los limites son los del nivel
		p.position.y = float(nivel["suelo"])
		p.limite_izquierdo = limites_playa.x if solo_playa else float(nivel["limites"][0])
		p.limite_derecho = limites_playa.y if solo_playa else float(nivel["limites"][1])
	super()
	if _peregrino:
		_peregrino.suelo_en = _suelo_peregrino
	for n in prueba_bloques:
		var o := _objeto(n)
		if o:
			o.x0 = float(prueba_bloques[n])
			_colocar_objeto(o)

## La y de lo que se pisa en x (para colocar al peregrino).
func altura_en(x: float) -> float:
	return _nivel(x)

## LAS REPISAS: el suelo de x para el peregrino donde esta (sus pies, el nodo:
## en el aire se queda a la altura del despegue). Como el de acciones_perfil.gd,
## sin las cajas que le quedan por encima de la cabeza.
func _nivel(x: float) -> float:
	if _abajo.is_empty() or _peregrino == null:
		return super(x)
	var pies := _suelo - _peregrino.position.y
	var y := _suelo
	var dentro := false
	var izq: Objeto = null
	var der: Objeto = null
	for o in _obj:
		if float(_abajo.get(o.nombre, 0.0)) >= pies + DESPEJE:
			continue
		if x > o.x0 + 0.01 and x < o.x1() - 0.01:
			y = minf(y, _suelo - o.alto)
			dentro = true
		elif not dentro:
			if o.x1() <= x + 0.01 and (izq == null or o.x1() > izq.x1()):
				izq = o
			if o.x0 >= x - 0.01 and (der == null or o.x0 < der.x0):
				der = o
	if dentro:
		return y
	if izq and der and der.x0 - izq.x1() < HUECO_JUNTOS:
		return maxf(_suelo - izq.alto, _suelo - der.alto)
	return y

## Sin accion en curso (andando, quieto, saltando).
func libre() -> bool:
	return _modo == Modo.LIBRE and _losa_t < 0.0

## El suelo que ve el peregrino: un escalon que baja no es un borde (no salta
## solo en cada peldano); en el aire, el de verdad.
func _suelo_peregrino(x: float) -> float:
	var y := _nivel(x)
	var aqui: float = _peregrino.position.y
	if y > aqui and y - aqui <= peldano and _estado() != "SALTAR":
		return aqui
	return y

func _objeto(nombre: String) -> Objeto:
	for o in _obj:
		if o.nombre == nombre:
			return o
	return null

## Un objeto que se mueve, con su textura; el terreno ("_") no se ve.
func _sprite_de(nombre: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.z_index = -5
	var ruta := OBJETOS_EGIPTO % nombre
	if ResourceLoader.exists(ruta):
		s.texture = load(ruta)
	else:
		var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		im.fill(Color(0, 0, 0, 0) if nombre.begins_with("_") else Color(0.7, 0.6, 0.45))
		s.texture = ImageTexture.create_from_image(im)
		s.visible = not nombre.begins_with("_")
	return s

## La losa, con su textura a su tamano y sobre lo que haya debajo.
func _colocar_objeto(o: Objeto) -> void:
	if o.nombre == "losa":
		o.nodo.scale = Vector2.ONE
		o.nodo.position = Vector2(o.x0, _suelo - PLANTA - o.alto)
		return
	super(o)

## LOS ESCALONES: lo pequeno ni para ni hace bajar de un saltito. Y la losa se
## intenta empujar desde donde este.
func _accion_en(sig: Dictionary, y: float, d: float) -> Dictionary:
	if not sig.is_empty() and absf(y - float(sig["y"])) <= peldano:
		var o: Objeto = sig.get("objeto")
		if o == null or o.nombre.begins_with("_"):
			return {}
	# el filo de un hueco que se salta (al otro lado vuelve la altura de aqui):
	# ni limite ni bajar de un saltito; el peregrino salta solo en el filo
	if not sig.is_empty() and float(sig["y"]) > y + peldano and _es_hueco(float(sig["x"]), y, d):
		return {}
	var r := super(sig, y, d)
	if r.get("objeto") != null and r["objeto"].nombre == "losa" and not _losa_hecha:
		r["empuje"] = "empujar_v2"
		r["parada"] = float(r["cara"]) - d * float(_datos["empujar_v2"]["cara"])
	return r

## Un sillar mas alto que un paso bajo no cabe dentro: el sitio acaba en su boca.
func _hueco_delante(o: Objeto, d: float) -> float:
	var h := super(o, d)
	for t in nivel["techos"]:
		if o.alto <= float(t["libre"]):
			continue
		var boca: float = t["x0"] if d > 0.0 else t["x1"]
		var frente := o.x1() if d > 0.0 else o.x0
		if (boca - frente) * d >= -0.5:
			h = minf(h, (boca - frente) * d)
	return h

## LOS HUECOS (la zanja, el foso): mas alla del filo, en menos de 700 px, el
## suelo vuelve a la altura de aqui (o mas).
func _es_hueco(cara: float, y: float, d: float) -> bool:
	var mas_alla := cara + d
	var sig := _siguiente(mas_alla, _nivel(mas_alla), d)
	return not sig.is_empty() and float(sig["y"]) <= y + 2.0 and absf(float(sig["x"]) - cara) < 700.0

func _physics_process(delta: float) -> void:
	if _losa_t >= 0.0:
		_losa(delta)
		return
	super(delta)

func _empezar_empuje(a: Dictionary, d: float) -> void:
	var o: Objeto = a["objeto"]
	if o.nombre != "losa":
		super(a, d)
		return
	if _losa_hecha:
		_espera = 0.0
		return
	# el empuje v2 desde su sitio: lo que falte se anda antes de apoyar las manos
	var dat: Dictionary = _datos["empujar_v2"]
	_corr = (float(a["cara"]) - _peregrino.position.x) * d - float(dat["cara"])
	_d = d
	_base = _peregrino.position
	_contacto = int(dat["contacto"])
	_peregrino.control_bloqueado = true
	_poner_tramo("empujar_v2")
	_losa_t = 0.0
	_losa_fase = 0
	_losa_f = 0.0
	_losa_x_manos = _base.x + (float(dat["raiz"][_contacto][0]) + _corr) * d
	_ultima = ""

## El intento contra la losa, fotograma a fotograma (como _avanzar, sin bloque):
## hasta las manos al ritmo del video, el esfuerzo de ida y vuelta, y de vuelta
## al primer fotograma por el mismo camino.
func _losa(delta: float) -> void:
	var dat: Dictionary = _datos["empujar_v2"]
	var fps := _fps("empujar_v2")
	_losa_t += delta
	match _losa_fase:
		0:
			_losa_f += delta * fps
			if _losa_f >= losa_esfuerzo.x:
				_losa_fase = 1
				_losa_t = 0.0
		1:
			# ida y vuelta, algo mas lenta que el video: empuja y no pasa nada
			var tramo := float(losa_esfuerzo.y - losa_esfuerzo.x)
			var u := fmod(_losa_t * fps * 0.6, tramo * 2.0)
			_losa_f = losa_esfuerzo.x + (u if u <= tramo else tramo * 2.0 - u)
			if _losa_t >= losa_segundos and absf(_losa_f - losa_esfuerzo.x) < 1.0:
				_losa_fase = 2
		2:
			_losa_f -= delta * fps * 0.8
			if _losa_f <= 0.0:
				_losa_t = -1.0
				_losa_hecha = true
				_peregrino.position.x = _base.x
				_sprite.offset = _peregrino.offset_comun
				_sprite.play("reposo")
				_peregrino.control_bloqueado = false
				_peregrino.set("_esfuerzo", 1.0)
				_peregrino.call("_respirar", true)
				losa_intentada.emit()
				return
	var f := clampi(int(_losa_f), 0, int(dat["n"]) - 1)
	_sprite.frame = f
	var r: Array = dat["raiz"][f]
	var rc: float = float(dat["raiz"][maxi(_contacto, 1)][0])
	var w := clampf(float(r[0]) / rc, 0.0, 1.0) if rc > 0.5 else 1.0
	var x := _base.x + (float(r[0]) + _corr * w) * _d
	# la losa no se mueve: las manos no pasan de donde la tocan
	x = minf(x, _losa_x_manos) if _d > 0.0 else maxf(x, _losa_x_manos)
	_peregrino.position = Vector2(x, _base.y + float(r[1]))
