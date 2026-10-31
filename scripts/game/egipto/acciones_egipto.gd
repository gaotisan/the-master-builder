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
##   - LAS ARISTAS (2026-10-30): el canto de una repisa marcada ("arista" en
##     recorrido.json: 1 el derecho, -1 el izquierdo) se trepa desde fuera aunque
##     quede por encima de la cabeza (hasta DESPEJE + ARISTA_MAS): por debajo se
##     sigue pasando; saliendo de debajo, ya es una cara (la losa sobre las
##     columnas, desde el bloque de encima).

signal losa_intentada

const NIVEL := "res://assets/egipto/acto1/nivel.json"
const RECORRIDO := "res://assets/egipto/acto1/recorrido.json"
## Lo que tiene que quedar sobre los pies hasta la cara de abajo de una repisa
## para pasar por debajo (el peregrino mide ~305 px con la capucha).
const DESPEJE := 310.0
## Lo que puede quedar por encima de DESPEJE una arista que se trepa desde fuera.
const ARISTA_MAS := 60.0
## Una rendija entre dos cajas mas estrecha que esto (el peregrino mide ~100 de
## ancho) no es un borde por el que caer: del filo del bloque de encima al puente.
const RENDIJA := 52.0
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
## el lado de su arista (1 derecho, -1 izquierdo) de las cajas que la tienen
var _arista := {}
## lo que hace falta debajo para pasar, en las que no es DESPEJE ("despeje" en
## recorrido.json: la losa sobre el bloque de encima, por delante de su columna)
var _despeje := {}
## donde empieza el zocalo que sobresale al pie de las que lo tienen ("zocalo" en
## recorrido.json: la base de la columna de las ruinas): desde abajo se para antes
var _zocalo := {}
## lo que se queda del zocalo (medio cuerpo y algo: con 30 de la cara se metia en el)
@export var margen_zocalo := 50.0
## las cajas desde las que no se trepa a lo de al lado ("sin_trepar" en
## recorrido.json: del saliente del medio al remate del pilar alto era un atajo)
var _sin_trepar := {}
## las que no son techo para el salto ("sin_techo": por debajo ya se pasa por
## delante de ellas, como del saliente de abajo; no dejaba saltar a la base derecha)
var _sin_techo := {}
## LAS BAJADAS (2026-10-31, el usuario: "subo de c004 a c005 y luego no puedo
## bajar"): el canto de una caja marcada ("bajada" en recorrido.json: 1 el
## derecho, -1 el izquierdo) que da a una rendija y, pasada ella, a una pared (el
## puente, con la losa pegada) se baja con ABAJO, mirando al filo: el saltito de
## bajar a lo de debajo de mas alla (el bloque de encima). Por donde se sube, se
## baja. Andando hacia alli se para en el filo, y saltando se trepa a la losa:
## con la tecla hacia el filo para bajar, el que queria subir a la losa se veia
## de vuelta abajo (el piloto del zigzag lo hacia).
var _bajada := {}

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
			if c.has("arista"):
				_arista[n] = float(c["arista"])
			if c.has("despeje"):
				_despeje[n] = float(c["despeje"])
			if c.has("zocalo"):
				_zocalo[n] = float(c["zocalo"])
			if c.get("sin_trepar", false):
				_sin_trepar[n] = true
			if c.get("sin_techo", false):
				_sin_techo[n] = true
			if c.has("bajada"):
				_bajada[n] = float(c["bajada"])
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
	# LAS TREPADAS, SOLO DONDE LAS MANOS CASAN CON EL BORDE (2026-10-29; el
	# templo retocado a su medida, retoque_templo.py): la mediana de 150 a 195
	# (su video: 172) y la alta de 295 a 425 (362; las manos van al borde
	# saltando algo mas o algo menos). Lo de menos se sube de un salto andando
	# (llega a ~182); lo de entre medias no se trepa
	banda_mediana = Vector2(150.0, 195.0)
	banda_alta = Vector2(295.0, 425.0)
	if p:
		# el suelo de abajo manda (acciones_perfil.gd lo toma de donde pisa el
		# peregrino al empezar) y los limites son los del nivel
		p.position.y = float(nivel["suelo"])
		p.limite_izquierdo = limites_playa.x if solo_playa else float(nivel["limites"][0])
		p.limite_derecho = limites_playa.y if solo_playa else float(nivel["limites"][1])
	super()
	if _peregrino:
		_peregrino.suelo_en = _suelo_peregrino
		if not recorrido.is_empty():
			# (CAER DE ALTO: sin la de flotar, caida_flotar_desde se queda en INF.
			# 2026-10-31, el usuario: flotar queda para cuando tenga el poder de
			# flotar; sin luz, como aqui, la caida de siempre)
			# (GIRO AGIL: en la piedra, cambiar de sentido andando sin pararse tanto)
			_peregrino.giro_agil = true
			# SIN ESCALONES QUE SE ANDEN (2026-10-29, el usuario: subir y bajar
			# escalones andando "es feisimo"): en la piedra el nodo solo se lleva
			# andando lo que no se nota (hasta 15 px); lo demas se sube de un
			# salto (tambien de parado, sin tecla, delante del escalon) y se baja
			# dejandose caer. El templo, sin escalones de 16 a 60 (retoque_templo.py)
			peldano = 15.0
			_peregrino.salto_encima_parado_cerca = 140.0
			_caida_sin_salto = _peregrino.caida_sin_salto_desde
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
		var abajo := float(_abajo.get(o.nombre, 0.0))
		var despeje := float(_despeje.get(o.nombre, DESPEJE))
		if abajo >= pies + despeje and not (abajo < pies + despeje + ARISTA_MAS and _fuera_de_arista(o)):
			continue
		if x > o.x0 + 0.01 and x < o.x1() - 0.01:
			y = minf(y, _suelo - o.alto)
			dentro = true
		else:
			if o.x1() <= x + 0.01 and (izq == null or o.x1() > izq.x1()):
				izq = o
			if o.x0 >= x - 0.01 and (der == null or o.x0 < der.x0):
				der = o
	# una rendija entre dos cajas por encima de lo de debajo (del bloque de encima
	# al puente, del puente a la losa) no es un borde por el que caer: lleva lo
	# bajo de las dos hasta la otra
	var rendija := izq != null and der != null and der.x0 - izq.x1() < RENDIJA
	if dentro:
		if rendija and minf(izq.alto, der.alto) > _suelo - y:
			return _suelo - minf(izq.alto, der.alto)
		return y
	if rendija:
		return maxf(_suelo - izq.alto, _suelo - der.alto)
	return y

## LAS ARISTAS: el peregrino fuera de la caja, del lado de su arista (no debajo),
## y solo para trepar (al saltar pegado): andando no es pared, se sigue pasando
## por debajo (de vuelta, del bloque gemelo al bloque bajo).
func _fuera_de_arista(o: Objeto) -> bool:
	if not _con_aristas:
		return false
	var lado := float(_arista.get(o.nombre, 0.0))
	if lado > 0.0:
		return _peregrino.position.x >= o.x1()
	if lado < 0.0:
		return _peregrino.position.x <= o.x0
	return false

## (las aristas cuentan desde que se salta pegado hasta que acaba la trepada)
var _con_aristas := false

## (2026-10-31, el usuario: "como subes de c004 a c005 no lo consigo") Dos formas
## mas de pedirla, las de un jugador: saltando andando hacia ella (se para en la
## arista, como contra una pared, y trepa) y saltando de espaldas a ella, justo
## debajo de su canto (se da la vuelta y trepa).
func _saltar_pegado(desde_tecla := true) -> void:
	_con_aristas = true
	super(desde_tecla)
	# (tambien girando o frenando: la tecla de la vuelta y la del salto casi a la
	# vez; si no, el salto se le quedaba al peregrino y saltaba al acabar el giro)
	var m := _peregrino
	if _modo == Modo.LIBRE and desde_tecla and _trepa_pedido <= 0.0 and not _en_mano() and not m.control_bloqueado \
			and _estado() in ["REPOSO", "GIRO", "PARADA_ANDAR"]:
		var d: float = -m.mirando()
		var a := _accion_en(_siguiente(m.position.x, m.position.y, d), m.position.y, d)
		var o: Objeto = a.get("objeto")
		if a.get("trepa", "") != "" and o != null and _arista.has(o.nombre):
			var ideal: float = a["cara"] - d * float(_datos[a["trepa"]]["cara"])
			if absf(ideal - m.position.x) <= tolerancia_trepar:
				get_viewport().set_input_as_handled()
				_arista_pedida = d
				_trepa_pedido = ESPERA_GIRO_ARISTA
	if _modo == Modo.LIBRE:
		_con_aristas = false
	# EL TECHO BAJO: un salto que no va a ninguna parte, con poco sitio encima
	# (bajo el puente o la losa), no sale: metia la capucha en la piedra
	# (si delante hay algo que se trepa, como contra una pared: se guarda y trepa
	# al pararse en la cara, del bloque bajo al de encima)
	if desde_tecla and _modo == Modo.LIBRE and not get_viewport().is_input_handled() and _techo_bajo():
		get_viewport().set_input_as_handled()
		var a := _accion_en(_siguiente(m.position.x, m.position.y, m.mirando()), m.position.y, m.mirando())
		if a.get("trepa", "") != "" and absf(float(a["parada"]) - m.position.x) <= acercarse_max:
			_trepa_pedido = espera_trepa

## EL TECHO BAJO (2026-10-31): con menos de TECHO_SALTO de los pies a la cara de
## abajo de una repisa, aqui o por donde iria el salto, solo se salta a un
## escalon de delante al que se llega sin meter la capucha en la piedra (subir
## al bloque bajo desde la pasarela, al plinto) o se trepa; el salto libre, no
## (de parado la capucha sube hasta ~430 px).
const TECHO_SALTO := 440.0
## Lo que mide el peregrino con la capucha, y lo que se le deja rozar la cara de
## abajo al subir a un escalon (el orbe del baculo a la espalda asoma mas).
const ALTO_PEREGRINO := 305.0
const ROCE_TECHO := 40.0
func _techo_bajo() -> bool:
	var m := _peregrino
	var x := m.position.x
	# (girando, hacia donde acaba mirando: el salto guardado sale al terminar)
	var d: float = float(m.get("_giro_destino")) if _estado() == "GIRO" else m.mirando()
	var pies := _suelo - m.position.y
	var alcance := 60.0 if _estado() in ["REPOSO", "GIRO"] else 300.0
	if _techo_sobre(x - d * 40.0, pies, x + d * alcance) >= TECHO_SALTO:
		return false
	# a un escalon de delante si, a donde el salto apunta para caer encima (SALTAR
	# ENCIMA de peregrino.gd: de parado a 140, andando o corriendo a 300; mas
	# lejos sale el salto entero) y si cabe encima
	var sig := _siguiente(x, m.position.y, d)
	if not sig.is_empty():
		var h: float = m.position.y - float(sig["y"])
		var cara: float = sig["x"]
		var cerca: float = PARADO_ESCALON if _estado() in ["REPOSO", "GIRO"] else ANDANDO_ESCALON
		var hueco := _techo_sobre(x, pies, cara)
		# (corriendo, no: su salto vuela largo y alto; de parado con la tecla hacia
		# atras tampoco: el peregrino no apunta al escalon y sale el salto entero)
		var eje := Input.get_axis("mover_izquierda", "mover_derecha")
		var apunta := not (_estado() in ["CORRER", "ARRANQUE_CORRER"]) and signf(eje) != -d
		if apunta and h > peldano and h <= SALTO_ESCALON and (cara - x) * d <= cerca \
				and h + ALTO_PEREGRINO <= hueco + ROCE_TECHO:
			return false
	return true

## Lo que hay de los pies (a esa altura) a la cara de abajo de la repisa mas baja
## que quede encima de xa a xb (o solo en xa); INF si ninguna. Solo las que se
## pasan por debajo (DESPEJE): las demas son escalones o caras.
func _techo_sobre(xa: float, pies: float, xb := NAN) -> float:
	if is_nan(xb):
		xb = xa
	var lo := minf(xa, xb) - 30.0
	var hi := maxf(xa, xb) + 30.0
	var hueco := INF
	for o in _obj:
		if _sin_techo.has(o.nombre):
			continue
		var abajo := float(_abajo.get(o.nombre, 0.0))
		if abajo >= pies + float(_despeje.get(o.nombre, DESPEJE)) and o.x0 < hi and o.x1() > lo:
			hueco = minf(hueco, abajo - pies)
	return hueco

## Andando y de parado, hasta donde el salto cae seguro encima del escalon (a 160
## de la cara andando, o a 117 de parado, a veces no apuntaba y salia el salto
## entero, bajo el puente).
const ANDANDO_ESCALON := 120.0
const PARADO_ESCALON := 100.0
## Bajo el techo bajo, de los bordes de mas de esto se deja caer sin brinco.
const CAIDA_BAJO_TECHO := 20.0
## (el de fuera del techo bajo, el del peregrino)
var _caida_sin_salto := 150.0
## Lo mas alto que sube un salto a un escalon (el andando, ~182).
const SALTO_ESCALON := 182.0

## (lo que tarda el giro y algo: luego trepa)
const ESPERA_GIRO_ARISTA := 3.0
## Hacia donde queda la arista pedida de espaldas (0: ninguna): se gira en
## cuanto este quieto.
var _arista_pedida := 0.0

## Con un salto guardado (ver _saltar_pegado), la arista es pared: se para en
## ella en vez de seguir andando por debajo.
func _libre(delta: float) -> void:
	if _trepa_pedido <= 0.0:
		_arista_pedida = 0.0
	elif _arista_pedida != 0.0 and _peregrino.mirando() != _arista_pedida and _estado() == "REPOSO" \
			and not _peregrino.control_bloqueado:
		_peregrino.girar_hacia(_peregrino.position.x + _arista_pedida * 100.0)
	# (y el salto que el peregrino se guarda, pulsado en el aire o girando: saldria
	# al tocar suelo o al acabar el giro, bajo el techo bajo; el peregrino va
	# antes que esto, asi que en el aire se le quita ya, mirando el techo desde el
	# suelo de debajo)
	var x := _peregrino.position.x
	if (_estado() == "SALTAR" and _techo_sobre(x, _suelo - _nivel(x)) < TECHO_SALTO) \
			or (_estado() != "SALTAR" and _techo_bajo()):
		_peregrino.set("_salto_pedido", -99.0)
	# y de los bordes de debajo se deja caer, sin el brinco (tambien corriendo:
	# el de la carrera subia ~100 px dentro de la losa o del puente)
	if not recorrido.is_empty() and _estado() != "SALTAR":
		var d: float = _peregrino.mirando()
		var bajo := _techo_sobre(x - d * 40.0, _suelo - _peregrino.position.y, x + d * 300.0) < TECHO_SALTO
		_peregrino.caida_sin_salto_desde = CAIDA_BAJO_TECHO if bajo else _caida_sin_salto
		_peregrino.caer_sin_brinco = bajo
	# (corriendo, se para donde toca: FRENADA CORRIENDO A LA MEDIDA de peregrino.gd)
	if not recorrido.is_empty():
		_peregrino.frenada_limite_correr = -1.0
	_con_aristas = _trepa_pedido > 0.0
	super(delta)
	if _modo == Modo.LIBRE:
		_con_aristas = false
	# UN PASO HASTA EL TOPE (2026-10-31, el usuario: tras trepar al puente "le doy
	# a la derecha y no puedo avanzar"): a menos de la frenada de una pared, de
	# parado la tecla no contaba. Ahora da el paso, y lo que el arranque se pasaria
	# lo corta el limite.
	var m := _peregrino
	if _modo == Modo.LIBRE and _estado() in ["REPOSO", "ARRANQUE_ANDAR"]:
		var lim: float = m.limite_derecho if m.mirando() > 0.0 else m.limite_izquierdo
		var queda: float = (lim - m.position.x) * m.mirando()
		if queda > PASO_MIN and queda <= frenada_obstaculo + 1.0:
			m.frenada_limite_andar = 0.0

## Lo menos que se anda hasta un tope (mas cerca, ya esta en el)
const PASO_MIN := 12.0

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

## LO QUE SE MUEVE SOLO (2026-10-31, la losa del altar: mecanismo_altar.gd): una
## caja mas, con su cara de abajo (abajo, sobre la arena; 0 maciza), que cambia de
## ancho con ancho_objeto. Sin ancho no esta (fuera de la lista: una caja de
## ancho 0 contaria como rendija junto a la terraza).
## La x de un filo del que no se cae ahora (NAN: ninguno; lo pone el mecanismo).
var borde_sin_caida := NAN

func nuevo_objeto(nombre: String, x0: float, ancho: float, arriba: float, abajo := 0.0) -> Objeto:
	var o := Objeto.new()
	o.nombre = nombre
	o.x0 = x0
	o.x_ini = x0
	o.alto = arriba
	o.trepable = false
	o.nodo = _sprite_de(nombre)
	add_child(o.nodo)
	if abajo > 0.5:
		_abajo[nombre] = abajo
	ancho_objeto(o, ancho)
	return o

func ancho_objeto(o: Objeto, ancho: float) -> void:
	o.ancho = maxf(ancho, 0.0)
	var esta := o in _obj
	if o.ancho >= 1.0 and not esta:
		_obj.append(o)
	elif o.ancho < 1.0 and esta:
		_obj.erase(o)

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
	# CAER DE ALTO (2026-10-28, el usuario: en los bordes altos de la piedra "no
	# deja avanzar"): un borde mas alto de lo que se baja de un saltito tambien
	# se deja caer andando; el peregrino baja con la de flotar y la gravedad de
	# siempre (caida_flotar_desde). Parado en el filo, no hace el saltito de bajar.
	if not recorrido.is_empty() and not sig.is_empty() and float(sig["y"]) > y 			and not r.has("baja") and _datos.has("bajar"):
		var x_cae: float = float(sig["x"]) + d * float(_datos["bajar"]["cara_fin"])
		var y_cae := _nivel(x_cae)
		if y_cae - y > subida_alta * (1.0 + margen_altura) and x_cae > _limites.x and x_cae < _limites.y:
			r["baja"] = "bajar"
			r["alta"] = true
			r["y"] = y_cae
	# LA LOSA DEL ALTAR (mecanismo_altar.gd): de su punta no se cae al vacio
	# andando (se para en el filo y, si se esta recogiendo, la losa le lleva de
	# vuelta a la terraza); con la punta en el capitel, se baja a el como siempre
	# (ni del filo de la terraza de donde sale, justo despues de que le haya
	# devuelto a ella: borde_sin_caida)
	if r.get("alta", false) and (sig.get("objeto") != null and sig["objeto"].nombre == MecanismoAltar.LOSA
			or absf(float(sig["x"]) - borde_sin_caida) < 3.0):
		r.erase("baja")
		r.erase("alta")
		r["y"] = sig["y"]
	# SIN TREPAR: de pie en una caja marcada, lo de al lado es pared
	if r.get("trepa", "") != "" and not _sin_trepar.is_empty():
		for o in _obj:
			if _sin_trepar.has(o.nombre) and absf(_suelo - o.alto - y) < 0.5 \
					and float(sig["x"]) > o.x0 - RENDIJA and float(sig["x"]) < o.x1() + RENDIJA:
				r["trepa"] = ""
				r["parada"] = float(sig["x"]) - d * 30.0
				break
	# EL ZOCALO: contra una pared con la base que sobresale (de su lado), se para
	# antes de la base, no con el cuerpo metido en ella
	if r.get("objeto") != null and _zocalo.has(r["objeto"].nombre) and float(sig["y"]) < y:
		var z: float = _zocalo[r["objeto"].nombre]
		if (z - float(sig["x"])) * d < 0.0:
			r["parada"] = z - d * margen_zocalo
	if r.get("objeto") != null and r["objeto"].nombre == "losa" and not _losa_hecha:
		r["empuje"] = "empujar_v2"
		r["parada"] = float(r["cara"]) - d * float(_datos["empujar_v2"]["cara"])
	return r

## LAS BAJADAS: de pie en una caja con bajada hacia d, la pared que hay pasada
## su rendija es tambien el filo de una bajada a lo de debajo de mas alla.
func _bajada_en(sig: Dictionary, y: float, d: float) -> Dictionary:
	if _bajada.is_empty() or sig.is_empty() or float(sig["y"]) >= y or not _datos.has("bajar"):
		return {}
	for o in _obj:
		if float(_bajada.get(o.nombre, 0.0)) != d or absf(_suelo - o.alto - y) > 0.5:
			continue
		var filo := o.x1() if d > 0.0 else o.x0
		var rendija := (float(sig["x"]) - filo) * d
		if rendija < -0.5 or rendija >= RENDIJA:
			continue
		# lo mas alto de debajo donde acaba el saltito
		var x_cae := filo + d * float(_datos["bajar"]["cara_fin"])
		var alto := -INF
		for q in _obj:
			if x_cae > q.x0 and x_cae < q.x1() and q.alto < o.alto - peldano:
				alto = maxf(alto, q.alto)
		if is_inf(alto):
			return {}
		return {"baja": "bajar", "bajada": true, "cara": filo, "y": _suelo - alto,
			"parada": filo - d * float(_datos["bajar"]["cara"])}
	return {}

## CAER DE ALTO: hacia un borde alto, con la tecla hacia el, siempre se deja caer
## andando (tambien desde parado: arranca a andar y salta en el filo).
func _cae_andando(a: Dictionary, s: float, eje: float) -> bool:
	if a.get("alta", false):
		return a.has("baja") and not _en_mano() and _peregrino.mirando() == s and signf(eje) == s
	return super(a, s, eje)

## ABAJO en el filo de una bajada, mirando a el (de pie y libre): baja.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("agacharse") and not event.is_echo() and _bajar_por_bajada():
		get_viewport().set_input_as_handled()
		return
	super(event)

func _bajar_por_bajada() -> bool:
	var m := _peregrino
	# (el peregrino ve la tecla antes que esto: ya empieza a agacharse)
	if _bajada.is_empty() or _modo != Modo.LIBRE or _en_mano() or m.control_bloqueado 			or not (_estado() in ["REPOSO", "AGACHANDO"]):
		return false
	var d: float = m.mirando()
	var b := _bajada_en(_siguiente(m.position.x, m.position.y, d), m.position.y, d)
	if b.is_empty() or absf(float(b["parada"]) - m.position.x) > tolerancia_trepar:
		return false
	# (sin el agacharse que ya empezaba: al acabar se quedaba agachado)
	m._cambiar(m.Estado.REPOSO)
	_empezar_una("bajar", b, d)
	return true

## ...y el saltito de bajar, no (es para lo que se baja de un paso).
func _empezar_una(anim: String, a: Dictionary, d: float) -> void:
	if anim == "bajar" and a.get("alta", false):
		return
	# (la bajada acaba en lo de debajo, no donde lo ve _nivel desde arriba: la losa)
	if anim == "bajar" and a.get("bajada", false):
		_corr = (float(a["cara"]) - _peregrino.position.x) * d - float(_datos[anim]["cara"])
		_y_fin = a["y"]
		_bloque = null
		_al_acabar = Callable()
		_empezar([anim], d)
		return
	super(anim, a, d)

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
