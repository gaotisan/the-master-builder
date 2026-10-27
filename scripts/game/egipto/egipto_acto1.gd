extends Node2D
## EGIPTO, ACTO I "La pista de los vivos" (PRUEBA, 2026-10-25). El peregrino de
## perfil, con el baculo a la espalda, por las ruinas junto al Nilo hasta la losa.
## El nivel lo monta tools/egipto/montaje.py con recortes de las imagenes de
## referencia (nivel.json: lo que se pisa, que sale del dibujo; arte.json: los
## sprites). Lo que se pisa y se mueve lo llevan las acciones (acciones_egipto.gd);
## aqui:
##   - LA CAMARA, como en los plataformas cuidados (Celeste, Inside): sigue con
##     amortiguacion, mira por delante de hacia donde va (mas cuanto mas corre),
##     no se mueve en vertical por escalones ni saltos (zona muerta: sigue el
##     suelo, no el arco), encuadra cada tramo con su zoom y su altura (claves
##     de montaje.py: abierto al llegar y al correr, cerrado en el paso bajo,
##     mirando arriba ante la estructura alta), no se sale del nivel por los
##     extremos y tiembla un poco al caer de alto. Las cinematicas la llevan a mano.
##   - LOS ESCALONES: las escaleras dibujadas se suben y se bajan andando (lo de
##     hasta PELDANO px; ver acciones_egipto.gd): el nodo se lleva suave a la
##     altura de cada peldano.
##   - EL PASO BAJO (techos): de pie no se entra; agachado si, y dentro se queda
##     agachado (la tecla abajo se mantiene desde aqui) y sin saltar ni correr.
##   - LA ENTRADA: desde negro, entra andando y se para a mirar.
##   - EL MIRADOR: se para y mira; el encuadre se abre con bandas (la procesion
##     ira en el fondo, en la pasada de los fondos).
##   - EL FINAL: tras el intento contra la losa, la camara se aleja y funde a
##     negro con FIN DEL ACTO I.
##   - CAPAS: el fondo de las imagenes (tools/egipto/fondo.py: lejos, cielo y
##     ciudad; medio, el Nilo con sus juncos y palmeras, con brillos en el agua
##     y faluchos navegando), cada uno en su CanvasLayer con su paralaje y casi
##     sin zoom (lo lejano no se acerca); la trasera (palmeras de las imagenes,
##     con paralaje), lo del juego, y el primer termino oscuro que pasa por
##     delante (paralaje).

const BASTON := preload("res://scenes/characters/baston.tscn")
const ARTE := "res://assets/egipto/acto1/arte.json"
const VIENTO := preload("res://scripts/game/egipto/viento.gdshader")
const FONDO := "res://assets/egipto/acto1/fondo/fondo.json"
## LA TIRA (tools/egipto/tira.py): las extensiones de Midjourney cosidas; si
## esta, manda sobre el fondo viejo, la arena repetida y las palmeras de detras.
const TIRA := "res://assets/egipto/acto1/tira/tira.json"
## LAS CAPAS de tiras generadas por separado (tools/egipto/capas.py): van
## delante de las de la tira en la lista y quitan las de la tira que nombran.
const CAPAS := "res://assets/egipto/acto1/capas/capas.json"
## El zoom con el que las capas de la tira casan como en la imagen (las lejanas
## casi no siguen el zoom de la camara) y la camara de referencia (todas
## alineadas como en la imagen).
## La camara de referencia de la tira: la de arranque (con ella, las capas se
## ven exactamente como la imagen de la que salen) y su zoom.
var TIRA_ZOOM := 0.55
var TIRA_C0 := Vector2(1500.0, -1100.0)
const AGUA := preload("res://scripts/game/egipto/fondo_agua.gdshader")
## El paralaje se cuenta desde aqui en y (la altura tipica de la camara).
const REF_Y := -460.0
const ANDANDO := ["REPOSO", "ARRANQUE_ANDAR", "ANDAR", "PARADA_ANDAR", "ARRANQUE_CORRER", "CORRER", "PARADA_CORRER",
		"AGACHANDO", "AGACHADO", "INCORPORANDO", "ARRANQUE_AGACHADO", "ANDAR_AGACHADO", "PARADA_AGACHADO",
		"GIRO_AGACHADO", "PASO_AGACHADO", "GIRO", "ATERRIZAJE_CORRER"]

@export var boceto := true
## Lo que mira por delante (px de juego) y lo que tarda en llegar.
@export var adelanto := 300.0
@export var rapidez_x := 2.4
@export var rapidez_y := 1.8
@export var rapidez_zoom := 1.0
## Zona muerta vertical: lo que puede cambiar la altura del suelo sin que la camara se mueva.
@export var zona_muerta_y := 70.0
## Escalones: velocidad a la que se lleva el nodo a la altura del peldano (px/s).
@export var subida_peldano := 520.0
## Cinematicas (desactivables para probar el recorrido).
@export var entrada := true
@export var mirador := true
@export var segundos_contemplar := 2.6
@export var segundos_mirador := 6.0
## Para probar un tramo: empieza aqui (sin la entrada). Negativo: desde el principio.
@export var x_prueba := -1.0

@onready var _peregrino: Node2D = $DarkStage/Peregrino
@onready var _camara: Camera2D = $DarkStage/Camera
@onready var _acciones: Node = $Acciones

var nivel := {}
var _baston: Node2D
var _cam_pos := Vector2.ZERO
var _cam_zoom := 1.0
var _adelanto_x := 0.0
var _y_ref := 0.0                # el suelo que sigue la camara (con zona muerta)
var _temblor := 0.0
var _y_despegue := NAN
# cinematica: la camara deja de seguir y va a estos valores
var _cine := false
var _cine_pos := Vector2.ZERO
var _cine_zoom := 1.0
var _cine_rapidez := 0.6
var _bandas: Array[ColorRect] = []
var _bandas_alto := 0.0
var _bandas_objetivo := 0.0
var _negro: ColorRect
var _rotulo: Label
var _abajo_real := false
var _agachado_puesto := false
var _mirador_hecho := false
var _final := false
var _capas := {}                 # nombre -> [Node2D, paralaje]
var _materiales := {}
var _sombra: Sprite2D
var _polvo: CPUParticles2D
var _x_fin := 0.0
var _fondo_capas: Array = []     # [CanvasLayer, paralaje x, paralaje y]
var _barcos: Array = []          # [Sprite2D, reflejo, x0, x1, velocidad, y, fase]
var _tira_capas: Array = []      # [CanvasLayer, paralaje x, paralaje y]
var _con_tira := false
var _arena_delante: CanvasLayer
## SOLO PLAYA (ver acciones_egipto.gd): sin las piezas del recorrido ni sus
## cinematicas; la camara con un encuadre fijo.
var _solo_playa := false
var _t_juego := 0.0
## (la imagen entera en pantalla: 1632 filas a la escala de la tira, 1,9)
## (0.87 con las capas a escala 1.2: el mismo encuadre que 0.55 a 1.9, con el
## peregrino mas grande frente a la maleza de la playa)
@export var zoom_playa := 0.87
## los pies, hacia el 88 % de la pantalla: la arena justa, como en la imagen
@export var pies_playa := 0.38

func _ready() -> void:
	nivel = _acciones.nivel
	process_physics_priority = 20          # despues de las acciones (10): sus limites, y luego los del techo
	_baston = BASTON.instantiate()
	_peregrino.add_child(_baston)
	if x_prueba >= 0.0 or _acciones.solo_playa:
		# (en la playa, sin la entrada de cine: con sus bandas negras parecia
		# que el cielo estaba negro)
		entrada = false
	var x0: float = nivel["marcas"]["inicio"] if entrada else nivel["marcas"]["contemplar"]
	if x_prueba >= 0.0:
		x0 = x_prueba
	_peregrino.position = Vector2(x0, _acciones.altura_en(x0))
	_y_ref = _peregrino.position.y
	_x_fin = float(nivel["losa"]["x0"]) + float(nivel["losa"]["ancho"]) + 400.0
	_solo_playa = _acciones.solo_playa
	if _solo_playa:
		mirador = false
		# la playa acaba donde acaba la arena de las capas
		if FileAccess.file_exists(CAPAS):
			var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAPAS))
			if cap.has("fin_suelo"):
				var fin: float = float(cap["fin_suelo"]) - 500.0
				_peregrino.limite_derecho = minf(_peregrino.limite_derecho, fin)
				_acciones.limites_playa.y = minf(_acciones.limites_playa.y, fin)
		_x_fin = _acciones.limites_playa.y + 600.0
	# (los datos de movimiento de DarkStage, solo para estudiarlo)
	$DarkStage/DatosMovimiento.visible = false
	_fondo()
	_con_tira = ResourceLoader.exists(TIRA)
	if _con_tira:
		_montar_tira()
	elif ResourceLoader.exists(FONDO):
		_montar_fondo()
	if _solo_playa:
		boceto = false
		_luz_y_aire()
	elif ResourceLoader.exists(ARTE):
		boceto = false
		_montar_arte()
	if boceto:
		_dibujar_boceto()
	_capa_cine()
	_cam_zoom = _clave(_peregrino.position.x).x
	_cam_pos = _objetivo_camara()
	_cam_pos.x = _dentro_del_nivel(_cam_pos.x, _cam_zoom)
	# (la referencia de las capas: donde arranca la camara)
	TIRA_C0 = Vector2(_cam_pos.x, _cam_pos.y)
	TIRA_ZOOM = _cam_zoom
	_camara.position = _cam_pos
	_camara.zoom = Vector2(_cam_zoom, _cam_zoom)
	_camara.position_smoothing_enabled = false
	_acciones.losa_intentada.connect(_al_intentar_losa)
	if entrada:
		_empezar_entrada()

func _input(event: InputEvent) -> void:
	if event.is_action("agacharse") and not event.is_echo():
		_abajo_real = event.is_pressed()

func _physics_process(delta: float) -> void:
	_t_juego += delta
	# (en la playa, nada del recorrido: ni el paso bajo que agacha, ni los
	# escalones, ni el mirador, ni el temblor al caer; el peregrino, libre)
	if not _solo_playa:
		_techos()
		_peldanos(delta)
		_mirador_si_toca()
		_caidas()
	_mover_camara(delta)
	_mover_bandas(delta)
	_mover_sombra()
	_mover_barcos(delta)
	if _polvo:
		_polvo.position = _cam_pos

func _estado() -> String:
	return String(_peregrino.datos_movimiento()["estado"])

## ---- escalones ------------------------------------------------------------------

func _peldanos(delta: float) -> void:
	var p := _peregrino
	if not _acciones.libre() or not (_estado() in ANDANDO):
		return
	var objetivo: float = _acciones.altura_en(p.position.x)
	# NUNCA DE PIE SOBRE EL VACIO: frenando junto al filo de un hueco que se
	# salta (sin limite en el filo, para poder arrancar a correr hacia el), la
	# parada lo llevaba mas alla; se le vuelve al filo
	if objetivo - p.position.y > _acciones.peldano + 2.0:
		var d: float = p.mirando()
		for i in range(1, 160):
			var x: float = p.position.x - d * float(i) * 2.0
			if absf(_acciones.altura_en(x) - p.position.y) <= _acciones.peldano:
				p.position.x = x - d * 8.0
				return
		return
	var dif := objetivo - p.position.y
	if absf(dif) > 0.5 and absf(dif) <= _acciones.peldano + 2.0:
		p.position.y = move_toward(p.position.y, objetivo, subida_peldano * delta)

## ---- camara --------------------------------------------------------------------

## Zoom y altura del encuadre en x (interpolando las claves, suave).
func _clave(x: float) -> Vector2:
	if _solo_playa:
		# (los pies hacia el 82 % de la pantalla: menos arena, mas cielo y fondo)
		return Vector2(zoom_playa, round(pies_playa * 1632.0 / zoom_playa))
	var c: Array = nivel["camara"]
	if c.is_empty():
		return Vector2(0.7, 380.0)
	if x <= float(c[0][0]):
		return Vector2(c[0][1], c[0][2])
	for i in range(c.size() - 1):
		var a: Array = c[i]
		var b: Array = c[i + 1]
		if x <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), x)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	var u: Array = c[c.size() - 1]
	return Vector2(u[1], u[2])

func _objetivo_camara() -> Vector2:
	var p := _peregrino.position
	var k := _clave(p.x)
	return Vector2(p.x + _adelanto_x, _y_ref - k.y)

## Que el encuadre no se salga del nivel por los extremos.
func _dentro_del_nivel(x: float, zoom: float) -> float:
	var medio := get_viewport().get_visible_rect().size.x * 0.5 / zoom
	# (con la tira, el borde izquierdo de sus imagenes: mas alla, negro)
	var izq := (-800.0 if _con_tira else -60.0) + medio
	var der := _x_fin - medio
	if der < izq:
		return (izq + der) * 0.5
	return clampf(x, izq, der)

func _mover_camara(delta: float) -> void:
	if _cine:
		var a := 1.0 - exp(-_cine_rapidez * delta)
		_cam_pos = _cam_pos.lerp(_cine_pos, a)
		_cam_zoom = lerpf(_cam_zoom, _cine_zoom, a)
	else:
		var p := _peregrino
		# el suelo que sigue, con zona muerta (escalones, saltos: el nodo se
		# queda a la altura del despegue mientras vuela)
		var dy := p.position.y - _y_ref
		if absf(dy) > zona_muerta_y:
			_y_ref = p.position.y - signf(dy) * zona_muerta_y
		if _estado() == "REPOSO":
			# quieto, se recentra despacio
			_y_ref = move_toward(_y_ref, p.position.y, 140.0 * delta)
		# por delante de hacia donde mira, y mas cuanto mas deprisa va
		var v: float = absf(float(p.datos_movimiento()["velocidad"]))
		var quiere: float = p.mirando() * adelanto * (0.5 + 0.5 * clampf(v / 435.0, 0.0, 1.0))
		_adelanto_x = lerpf(_adelanto_x, quiere, 1.0 - exp(-0.8 * delta))
		var objetivo := _objetivo_camara()
		var zoom := _clave(p.position.x).x
		_cam_zoom = lerpf(_cam_zoom, zoom, 1.0 - exp(-rapidez_zoom * delta))
		objetivo.x = _dentro_del_nivel(objetivo.x, _cam_zoom)
		_cam_pos.x = lerpf(_cam_pos.x, objetivo.x, 1.0 - exp(-rapidez_x * delta))
		_cam_pos.y = lerpf(_cam_pos.y, objetivo.y, 1.0 - exp(-rapidez_y * delta))
	var temblor := Vector2.ZERO
	if _temblor > 0.0:
		_temblor = maxf(0.0, _temblor - delta)
		var k := _temblor / 0.35
		temblor = Vector2(sin(_temblor * 90.0), cos(_temblor * 77.0)) * 7.0 * k * k
	_camara.position = _cam_pos + temblor
	_camara.zoom = Vector2(_cam_zoom, _cam_zoom)
	for nombre in _capas:
		var c: Array = _capas[nombre]
		var s: float = c[1]
		c[0].position = Vector2(_cam_pos.x * (1.0 - s), (_cam_pos.y - REF_Y) * (1.0 - s))
	# el fondo: su CanvasLayer con su paralaje, y el zoom amortiguado (lo lejano
	# casi no se acerca ni se aleja)
	var centro := get_viewport().get_visible_rect().size * 0.5
	for f in _tira_capas:
		var px: float = f[1]
		var py: float = f[2]
		var zt := _cam_zoom if px >= 1.0 else lerpf(TIRA_ZOOM, _cam_zoom, px)
		var cam := _cam_pos + temblor
		var desp := Vector2(TIRA_C0.x + px * (cam.x - TIRA_C0.x), TIRA_C0.y + py * (cam.y - TIRA_C0.y))
		# (el cielo se desliza solo, aunque el peregrino este quieto)
		desp.x -= float(f[3]) * _t_juego
		f[0].transform = Transform2D(0.0, Vector2(zt, zt), 0.0, centro - desp * zt)
	for f in _fondo_capas:
		var sx: float = f[1]
		var sy: float = f[2]
		var z := lerpf(1.0, _cam_zoom, sx)
		var o := Vector2((_cam_pos.x + temblor.x) * sx, (_cam_pos.y - REF_Y) * sy)
		f[0].transform = Transform2D(0.0, Vector2(z, z), 0.0, centro - o * z)

## Al caer de alto (mas de 250 px), la camara tiembla un poco.
func _caidas() -> void:
	var e := _estado()
	if e == "SALTAR":
		if is_nan(_y_despegue):
			_y_despegue = _peregrino.position.y
	elif not is_nan(_y_despegue):
		if _peregrino.position.y - _y_despegue > 250.0:
			_temblor = 0.35
		_y_despegue = NAN

## La camara, ya donde tiene que estar (sin el camino amortiguado): fotos y pruebas.
func saltar_camara() -> void:
	_cine = false
	_y_ref = _peregrino.position.y
	_cam_zoom = _clave(_peregrino.position.x).x
	_adelanto_x = _peregrino.mirando() * adelanto * 0.5
	_cam_pos = _objetivo_camara()
	_cam_pos.x = _dentro_del_nivel(_cam_pos.x, _cam_zoom)
	_mover_camara(0.0)

func _cinematica(pos: Vector2, zoom: float, rapidez := 0.6) -> void:
	_cine = true
	_cine_pos = pos
	_cine_zoom = zoom
	_cine_rapidez = rapidez

func _fin_cinematica() -> void:
	_cine = false
	_y_ref = _peregrino.position.y

## ---- el paso bajo --------------------------------------------------------------

const MEDIO_CUERPO := 48.0
const LUZ_PEREGRINO := Color(1.14, 1.07, 0.97)
var _luz_peregrino := 1.0
func _techos() -> void:
	var p := _peregrino
	var x: float = p.position.x
	var dentro := false
	for t in nivel["techos"]:
		var x0: float = t["x0"]
		var x1: float = t["x1"]
		if x > x0 - MEDIO_CUERPO and x < x1 + MEDIO_CUERPO:
			dentro = true
		elif not _agachado() and not p.control_bloqueado and absf(p.position.y + float(t.get("suelo_h", 0.0))) < 1.0:
			# de pie no entra: la cara del techo es un limite (como la de un sillar),
			# y si se pasa en este tick se le devuelve; cerca, frena en la cara
			if x <= x0 - MEDIO_CUERPO and x > x0 - 700.0:
				p.limite_derecho = minf(p.limite_derecho, x0 - MEDIO_CUERPO - 2.0)
				p.position.x = minf(p.position.x, p.limite_derecho)
				_frenar_cerca(x0 - MEDIO_CUERPO - x)
			elif x >= x1 + MEDIO_CUERPO and x < x1 + 700.0:
				p.limite_izquierdo = maxf(p.limite_izquierdo, x1 + MEDIO_CUERPO + 2.0)
				p.position.x = maxf(p.position.x, p.limite_izquierdo)
				_frenar_cerca(x - x1 - MEDIO_CUERPO)
	# bajo la viga, en su sombra
	var sombra := 0.7 if dentro else 1.0
	# (y la luz de la escena: el sol calido de la manana, un punto mas de luz
	# para que no se vea oscuro y pegado sobre la piedra clara)
	_luz_peregrino = lerpf(_luz_peregrino, sombra, 0.08)
	var m := _luz_peregrino
	p.modulate = Color(m * LUZ_PEREGRINO.r, m * LUZ_PEREGRINO.g, m * LUZ_PEREGRINO.b)
	if dentro:
		if not Input.is_action_pressed("agacharse"):
			Input.action_press("agacharse")
		_agachado_puesto = true
		p.salto_bloqueado = true
		p.correr_bloqueado = true
	elif _agachado_puesto:
		_agachado_puesto = false
		p.salto_bloqueado = false
		p.correr_bloqueado = false
		if not _abajo_real:
			Input.action_release("agacharse")

func _frenar_cerca(falta: float) -> void:
	if falta < _acciones.cerca_obstaculo:
		_peregrino.frenada_limite_andar = _acciones.frenada_obstaculo
		_peregrino.espera_parada_andar = 0

func _agachado() -> bool:
	return _estado() in ["AGACHANDO", "AGACHADO", "ARRANQUE_AGACHADO", "ANDAR_AGACHADO", "PARADA_AGACHADO",
			"GIRO_AGACHADO", "PASO_AGACHADO"]

## ---- cinematicas -------------------------------------------------------------

func _capa_cine() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	var tam := get_viewport().get_visible_rect().size
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.size = Vector2(tam.x, 0)
		b.position = Vector2(0, 0 if i == 0 else tam.y)
		capa.add_child(b)
		_bandas.append(b)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.size = tam
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_negro)
	_negro.modulate.a = 1.0 if entrada else 0.0
	_rotulo = Label.new()
	_rotulo.text = tr("FIN DEL ACTO I")
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo.size = tam
	var fuente := load("res://assets/fonts/Cinzel-Variable.ttf") if ResourceLoader.exists("res://assets/fonts/Cinzel-Variable.ttf") else null
	if fuente:
		_rotulo.add_theme_font_override("font", fuente)
	_rotulo.add_theme_font_size_override("font_size", 64)
	_rotulo.add_theme_color_override("font_color", Color(0.86, 0.8, 0.68))
	_rotulo.modulate.a = 0.0
	capa.add_child(_rotulo)

func _mover_bandas(delta: float) -> void:
	_bandas_alto = lerpf(_bandas_alto, _bandas_objetivo, 1.0 - exp(-1.5 * delta))
	var tam := get_viewport().get_visible_rect().size
	_bandas[0].size.y = _bandas_alto * tam.y
	_bandas[1].size.y = _bandas_alto * tam.y
	_bandas[1].position.y = tam.y - _bandas_alto * tam.y

func _empezar_entrada() -> void:
	_peregrino.control_bloqueado = true
	var tw := create_tween()
	tw.tween_property(_negro, "modulate:a", 0.0, 2.5).set_delay(0.4)
	_bandas_alto = 0.09
	_bandas_objetivo = 0.09
	await get_tree().create_timer(1.2).timeout
	_peregrino.andar_hasta(float(nivel["marcas"]["contemplar"]))
	await _peregrino.llegado
	await get_tree().create_timer(segundos_contemplar).timeout
	_bandas_objetivo = 0.0
	_peregrino.control_bloqueado = false

func _mirador_si_toca() -> void:
	if not mirador or _mirador_hecho or _cine:
		return
	var x: float = nivel["marcas"]["mirador"]
	if _peregrino.position.x < x - 40.0 or _estado() == "SALTAR" or not _acciones.libre():
		return
	_mirador_hecho = true
	_hacer_mirador(x)

func _hacer_mirador(x: float) -> void:
	_peregrino.andar_hasta(x + 80.0)
	_bandas_objetivo = 0.1
	var p := _peregrino.position
	_cinematica(Vector2(x + 600.0, p.y - 420.0), 0.48, 0.45)
	await _peregrino.llegado
	await get_tree().create_timer(segundos_mirador).timeout
	_bandas_objetivo = 0.0
	_fin_cinematica()
	_peregrino.control_bloqueado = false

func _al_intentar_losa() -> void:
	if _final:
		return
	_final = true
	_peregrino.control_bloqueado = true
	await get_tree().create_timer(1.4).timeout
	var l: Dictionary = nivel["losa"]
	_bandas_objetivo = 0.11
	_cinematica(Vector2(float(l["x0"]) - 300.0, -float(l["base"]) - float(l["alto"]) * 0.45), 0.48, 0.35)
	await get_tree().create_timer(4.5).timeout
	var tw := create_tween()
	tw.tween_property(_negro, "modulate:a", 1.0, 3.0)
	tw.tween_property(_rotulo, "modulate:a", 1.0, 2.0).set_delay(0.6)

## ---- el arte (tools/egipto/montaje.py) -------------------------------------------

func _montar_arte() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARTE))
	# (con mipmaps: al abrir el encuadre la piedra no parpadea)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for nombre in ["trasera", "detras", "delante", "frente", "sombra"]:
		if not datos["paralaje"].has(nombre):
			continue
		var n := Node2D.new()
		n.name = "Capa_" + nombre
		add_child(n)
		move_child(n, 0)
		_capas[nombre] = [n, float(datos["paralaje"][nombre])]
	for d in datos["sprites"]:
		# con la tira, sobran la arena repetida y las palmeras de detras
		if _con_tira and (String(d["tex"]).contains("suelo_arena") or String(d["tex"]).contains("/medio_")):
			continue
		var s := Sprite2D.new()
		s.texture = load(d["tex"])
		s.centered = false
		s.flip_h = d["flip"]
		var e: float = d["escala"]
		s.scale = Vector2(e, e)
		s.z_index = int(d["z"])
		var pos := Vector2(d["x"], d["y"])
		if d["ancla"] == "base":
			var tam: Vector2 = s.texture.get_size() * e
			pos -= Vector2(tam.x * 0.5, tam.y)
		var c: Array = _capas[d["capa"]]
		# (lo de una capa con paralaje, donde se ve con la camara alli)
		pos.x *= c[1]
		s.position = pos
		if d["tinte"] != null:
			var k: Array = d["tinte"]
			s.modulate = Color(k[0], k[1], k[2], k[3])
		var v: float = d["viento"]
		if v != 0.0:
			s.material = _material(v)
		c[0].add_child(s)
	# las sombras largas, sobre la arena de delante (por encima de ella)
	if _capas.has("sombra") and _arena_delante:
		var cs: Node2D = _capas["sombra"][0]
		remove_child(cs)
		_arena_delante.add_child(cs)
		_capas.erase("sombra")
	_luz_y_aire()

func _material(v: float) -> ShaderMaterial:
	var clave := str(roundi(v * 100.0))
	if _materiales.has(clave):
		return _materiales[clave]
	var m := ShaderMaterial.new()
	m.shader = VIENTO
	m.set_shader_parameter("amplitud", 0.014 * v)
	m.set_shader_parameter("rapidez", 1.0 + 0.4 * v)
	_materiales[clave] = m
	return m

## El fondo, oscuro hasta la pasada de los fondos con paralaje.
func _fondo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = -100
	add_child(capa)
	var g := Gradient.new()
	g.set_color(0, Color(0.035, 0.03, 0.028))
	g.set_color(1, Color(0.075, 0.062, 0.05))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = get_viewport().get_visible_rect().size
	capa.add_child(r)

## ---- el fondo (tools/egipto/fondo.py) -----------------------------------------------

## La tira: cada capa en su CanvasLayer (las de detras por debajo del juego; la
## arena de delante, por encima: tapa el pie de las piezas), en px de juego.
func _montar_tira() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TIRA))
	var lista: Array = []
	var quita: Array = []
	if ResourceLoader.exists(CAPAS) or FileAccess.file_exists(CAPAS):
		var otras: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAPAS))
		quita = otras.get("quita", [])
		for c in otras["capas"]:
			lista.append([c, otras])
	for c in datos["capas"]:
		if not (String(c["nombre"]) in quita):
			lista.append([c, datos])
	var k := 0
	for par in lista:
		var c: Dictionary = par[0]
		datos = par[1]
		var e: float = datos["escala"]
		var capa := CanvasLayer.new()
		capa.layer = 1 if c.get("delante", false) else -90 + k
		if c.get("delante", false):
			_arena_delante = capa
		capa.name = "Tira_" + String(c["nombre"])
		add_child(capa)
		var agua_mat: ShaderMaterial = null
		if c.has("agua"):
			agua_mat = ShaderMaterial.new()
			agua_mat.shader = AGUA
			agua_mat.set_shader_parameter("desde", float(c["agua"][0]))
			agua_mat.set_shader_parameter("hasta", float(c["agua"][1]))
			agua_mat.set_shader_parameter("ruido", _ruido_rachas())
		for tr in c["trozos"]:
			var s := Sprite2D.new()
			s.texture = load(tr["tex"])
			if agua_mat:
				s.material = agua_mat
			s.centered = false
			var ec: float = c.get("escala", e)
			s.scale = Vector2(ec, ec)
			s.position = Vector2(tr["x"], tr["y"])
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			capa.add_child(s)
		_tira_capas.append([capa, float(c["p"]), float(c["py"]), float(c.get("deriva", 0.0))])
		if c.has("costa") and not c["trozos"].is_empty():
			_calima(capa, c, float(datos["x0"]), float(datos["ancho"]) * float(c.get("escala", e)) / e)
		# los barcos, en su capa, justo delante de la que dice capas.json
		if datos.has("barcos") and String(datos["barcos"].get("tras", "")) == String(c["nombre"]):
			var bd: Dictionary = datos["barcos"]
			var cb := CanvasLayer.new()
			cb.layer = capa.layer
			cb.name = "Tira_barcos"
			add_child(cb)
			_tira_capas.append([cb, float(bd["p"]), float(bd["py"]), 0.0])
			_barcos_tira(cb, float(bd["x0"]), float(bd["x1"]), float(bd["y0"]), float(bd["y1"]), 0.0, 1.0)
		if c.has("agua") and not c["trozos"].is_empty() and not datos.has("barcos"):
			# la franja del agua en el juego (coordenadas de la capa)
			var tr0: Dictionary = c["trozos"][0]
			var ec: float = c.get("escala", e)
			var alto: float = (load(tr0["tex"]) as Texture2D).get_height() * ec
			var y0: float = float(tr0["y"]) + float(c["agua"][0]) * alto
			var y1: float = float(tr0["y"]) + float(c["agua"][1]) * alto
			var x1: float = float(datos["x0"]) + float(datos["ancho"]) * ec / e
			_barcos_tira(capa, float(datos["x0"]), x1, y0, y1)
		k += 1

## El ruido de las rachas de viento del agua (estirado en el shader).
func _ruido_rachas() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	return tex

## LA CALIMA: una franja de luz suave sobre la base de la ciudad, en la otra
## orilla, que la separa del agua y la aleja (es lo que da profundidad a lo
## lejano), por debajo de los barcos. Cada capa puede traer la suya (capas.json:
## "calima" y "calima_alto"; la de la orilla de enfrente, mas suave).
@export var calima := 0.22
func _calima(capa: CanvasLayer, c: Dictionary, x0: float, ancho: float) -> void:
	var tr0: Dictionary = c["trozos"][0]
	var ec: float = c["escala"]
	var alto: float = (load(tr0["tex"]) as Texture2D).get_height() * ec
	var y_costa: float = float(tr0["y"]) + float(c["costa"]) * alto
	var fuerza: float = float(c.get("calima", calima))
	var g := Gradient.new()
	# (los extremos antes del punto de en medio: add_point cambia los indices)
	g.set_color(0, Color(1.0, 0.93, 0.8, 0.0))
	g.set_color(1, Color(1.0, 0.93, 0.8, 0.0))
	g.add_point(0.75, Color(1.0, 0.93, 0.8, fuerza))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 128
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var h: float = float(c.get("calima_alto", 360.0))
	s.position = Vector2(x0, y_costa - h * 0.75)
	s.scale = Vector2(ancho / 4.0, h / 128.0)
	capa.add_child(s)

## Los faluchos por el agua de la tira: cuanto mas cerca (mas abajo en la franja
## del agua), mas grandes y mas deprisa; con su reflejo y cabeceando.
const BARCOS_TEX := ["res://assets/egipto/acto1/barcos/barco_0.png",
		"res://assets/egipto/acto1/barcos/barco_1.png",
		"res://assets/egipto/acto1/barcos/barco_2.png",
		"res://assets/egipto/acto1/barcos/barco_3.png"]
@export var barcos_cuantos := 7
func _barcos_tira(capa: CanvasLayer, x0: float, x1: float, y0: float, y1: float, prof0 := 0.12, prof1 := 0.6) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var texs: Array = []
	for r in BARCOS_TEX:
		if ResourceLoader.exists(r):
			texs.append(load(r))
	if texs.is_empty():
		return
	for i in barcos_cuantos:
		var tex: Texture2D = texs[i % texs.size()]
		var prof := rng.randf_range(prof0, prof1)            # 0 la otra orilla, 1 la cercana
		var y := lerpf(y0, y1, prof)
		var alto_obj := lerpf(110.0, 230.0, prof)             # alto del barco en el juego
		var esc := alto_obj / tex.get_height()
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		s.scale = Vector2(esc, esc)
		s.modulate = Color(1.0, 0.95, 0.86, 0.95)
		var r := Sprite2D.new()
		r.texture = tex
		r.centered = false
		r.offset = Vector2(-tex.get_width() * 0.5, 0.0)
		r.flip_v = true
		r.scale = Vector2(esc, esc * 0.7)
		r.modulate = Color(0.85, 0.9, 1.0, 0.25)
		capa.add_child(r)
		capa.add_child(s)
		var v := lerpf(8.0, 26.0, prof) * (1.0 if rng.randf() < 0.5 else -1.0)
		s.flip_h = v < 0.0
		r.flip_h = s.flip_h
		_barcos.append([s, r, x0 + 400.0, x1 - 400.0, v, y, rng.randf() * TAU, rng.randf_range(x0 + 400.0, x1 - 400.0)])

## Donde empieza (x) la tira de cada capa del fondo, en sus coordenadas.
const FONDO_X0 := -1600.0
## Lo que sube el fondo respecto a la imagen entera en pantalla (px de pantalla).
@export var fondo_arriba := -260.0

func _montar_fondo() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONDO))
	var alto: float = datos["alto"]
	# (la imagen, sin el cielo de mas, centrada en pantalla y subida fondo_arriba)
	var extra: float = datos.get("cielo_extra", 0)
	var y_arriba := -(alto - extra) * 0.5 - extra - fondo_arriba
	var k := 0
	for c in datos["capas"]:
		var capa := CanvasLayer.new()
		capa.layer = -90 + k
		capa.name = "Fondo_" + String(c["nombre"])
		add_child(capa)
		var s := Sprite2D.new()
		s.texture = load(c["tex"])
		s.centered = false
		s.position = Vector2(FONDO_X0, y_arriba)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if c["nombre"] == "medio":
			var m := ShaderMaterial.new()
			m.shader = AGUA
			m.set_shader_parameter("desde", 0.38)
			s.material = m
		capa.add_child(s)
		_fondo_capas.append([capa, float(c["paralaje"]), float(c["paralaje_y"])])
		if c["nombre"] == "medio":
			_poner_barcos(capa, datos, y_arriba)
		k += 1

## Los faluchos por el agua de la capa media: cada uno en su tramo de imagen, a
## la altura de su agua, con su reflejo debajo, cabeceando y yendo despacio.
func _poner_barcos(capa: CanvasLayer, datos: Dictionary, y_arriba: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var barcos: Array = datos["barcos"]
	if barcos.is_empty():
		return
	var n := 0
	for tr in datos["tramos"]:
		for j in 3:
			var b: Dictionary = barcos[(n + j) % barcos.size()]
			var e := rng.randf_range(0.9, 1.2) if String(b["tex"]).contains("lejano") else rng.randf_range(0.5, 0.75)
			var s := Sprite2D.new()
			s.texture = load(b["tex"])
			s.centered = false
			s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height())
			s.scale = Vector2(e, e)
			s.modulate = Color(1.0, 0.93, 0.82, 0.92)          # la luz calida de la manana
			var r := Sprite2D.new()
			r.texture = s.texture
			r.centered = false
			r.offset = Vector2(-s.texture.get_width() * 0.5, 0.0)
			r.flip_v = true
			r.scale = Vector2(e, e * 0.6)
			r.modulate = Color(0.9, 0.9, 0.95, 0.22)
			capa.add_child(r)
			capa.add_child(s)
			var x0: float = FONDO_X0 + float(tr["x0"]) + 300.0
			var x1: float = FONDO_X0 + float(tr["x1"]) - 300.0
			var y: float = y_arriba + float(tr["agua"]) + 60.0 + rng.randf_range(40.0, 180.0)
			var v := rng.randf_range(9.0, 22.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			s.flip_h = v < 0.0
			r.flip_h = s.flip_h
			_barcos.append([s, r, x0, x1, v, y, rng.randf() * TAU, rng.randf_range(x0, x1)])
		n += 1

func _mover_barcos(delta: float) -> void:
	for b in _barcos:
		var s: Sprite2D = b[0]
		var r: Sprite2D = b[1]
		b[7] = float(b[7]) + float(b[4]) * delta
		if b[7] > b[3]:
			b[7] = b[2]
		elif b[7] < b[2]:
			b[7] = b[3]
		var t := Time.get_ticks_msec() / 1000.0
		var bote := sin(t * 1.3 + float(b[6])) * 1.5
		s.position = Vector2(b[7], float(b[5]) + bote)
		s.rotation = sin(t * 1.1 + float(b[6])) * 0.02
		r.position = Vector2(b[7], float(b[5]) + 2.0 - bote * 0.5)
		# que aparezcan y se vayan fundiendo en los extremos de su tramo
		var borde := minf(float(b[7]) - float(b[2]), float(b[3]) - float(b[7]))
		var a := clampf(borde / 300.0, 0.0, 1.0)
		s.modulate.a = 0.92 * a
		r.modulate.a = 0.22 * a

## ---- luz y aire --------------------------------------------------------------

func _luz_y_aire() -> void:
	# la sombra de contacto: una elipse suave en lo que pisa
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.07, 0.04, 0.5))
	g.set_color(1, Color(0.1, 0.07, 0.04, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_sombra = Sprite2D.new()
	_sombra.texture = tex
	_sombra.scale = Vector2(1.5, 0.22)
	_sombra.z_index = -1
	add_child(_sombra)
	# polvo en suspension alrededor de la camara, muy poco
	_polvo = CPUParticles2D.new()
	_polvo.amount = 50
	_polvo.lifetime = 9.0
	_polvo.preprocess = 9.0
	_polvo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_polvo.emission_rect_extents = Vector2(2600, 1500)
	_polvo.direction = Vector2(1, -0.2)
	_polvo.spread = 40.0
	_polvo.gravity = Vector2.ZERO
	_polvo.initial_velocity_min = 8.0
	_polvo.initial_velocity_max = 26.0
	_polvo.scale_amount_min = 1.5
	_polvo.scale_amount_max = 3.5
	var gp := Gradient.new()
	gp.set_color(0, Color(1.0, 0.92, 0.75, 0.0))
	gp.set_color(1, Color(1.0, 0.92, 0.75, 0.0))
	gp.add_point(0.3, Color(1.0, 0.92, 0.75, 0.4))
	gp.add_point(0.7, Color(1.0, 0.92, 0.75, 0.4))
	_polvo.color_ramp = gp
	_polvo.z_index = 25
	add_child(_polvo)

func _mover_sombra() -> void:
	if _sombra == null:
		return
	var p := _peregrino
	var suelo: float = _acciones.altura_en(p.position.x)
	# en el aire el nodo se queda a la altura del despegue y el sprite sube
	var pies: float = p.position.y + p.get_node("Sprite").position.y
	var alto := clampf((suelo - pies) / 350.0, 0.0, 1.0)
	_sombra.position = Vector2(p.position.x, suelo - 4.0)
	_sombra.modulate.a = (1.0 - alto) * _luz_peregrino
	var e := 1.5 * (1.0 - 0.4 * alto)
	_sombra.scale = Vector2(e, 0.22 * (1.0 - 0.4 * alto))
	_sombra.visible = _estado() != "TUMBADO"

## ---- boceto en gris (sin arte) ---------------------------------------------------

func _dibujar_boceto() -> void:
	var raiz := Node2D.new()
	raiz.name = "Boceto"
	raiz.z_index = -20
	add_child(raiz)
	move_child(raiz, 0)
	var suelo: float = nivel["suelo"]
	for t in nivel["terreno"]:
		_caja(raiz, t["x0"], t["x1"], suelo - float(t["h"]), suelo + 400.0, Color(0.74, 0.66, 0.52))
	for t in nivel["techos"]:
		_caja(raiz, t["x0"] - 60, t["x1"] + 60, suelo - float(t["libre"]) - 160, suelo - float(t["libre"]), Color(0.6, 0.52, 0.42))

func _caja(padre: Node, x0: float, x1: float, y0: float, y1: float, c: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	p.color = c
	padre.add_child(p)
