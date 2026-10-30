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
## La musica del acto (2026-10-28, del usuario: "Act I - Ancient Exploration",
## en lugar del viento; sin el segundo de silencio del principio). Al empezar
## suena solo la intro en bucle (2026-10-29, tools/egipto/musica_bucle.py): el
## fundido de entrada una vez y luego sus 3 compases desde MUSICA_BUCLE.
const MUSICA := preload("res://assets/audio/musica_egipto_acto1_intro.ogg")
const MUSICA_BUCLE := 4.819396
## El tema (tools/egipto/musica_tema.py): al acabar el video del templo del
## cortejo (el usuario: "aparece demasiado pronto ... que empiece justo cuando se
## acaba la animacion y mientras mantener el otro bucle"), en el golpe del
## siguiente compas de la intro, y luego se repite el solo, sin volver a la intro.
const MUSICA_TEMA := preload("res://assets/audio/musica_egipto_acto1_tema.ogg")
const MUSICA_COMPAS := 5.9230   # los compases de la intro (musica_bucle.py)
## El templo del cortejo en la orilla de enfrente (tools/egipto/templo_rio.py):
## su video se lanza al llegar a lo alto del altar.
const TEMPLO := "res://assets/egipto/acto1/templo/templo.json"
var _templo: TemploRio
var _templo_capa: Array = []      # la entrada de su capa en _tira_capas
## En lo alto del altar, la camara se va al templo: donde queda en la pantalla
## (fraccion del ancho) y el zoom.
@export var templo_en_pantalla := 0.3
@export var zoom_templo := 0.55
@export var templo_cantos_db := -32.0   # los canticos del cortejo (lejos, muy bajitos: a -16 "se escuchan un monton")
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
@export var rapidez_y_caida := 7.0     # cayendo de un borde alto
## El temblor de la camara al caer de alto (apagado 2026-10-29: "como si fuera un
## golpe y temblara todo"; con el seguimiento de la camara basta). El del golpe
## de la caida del cielo va aparte.
@export var temblor_al_caer := false
## Escalones: velocidad a la que se lleva el nodo a la altura del peldano (px/s).
@export var subida_peldano := 520.0
## Cinematicas (desactivables para probar el recorrido).
@export var entrada := true
@export var mirador := true
@export var segundos_contemplar := 2.6
@export var segundos_mirador := 6.0
## Para probar un tramo: empieza aqui (sin la entrada). Negativo: desde el principio.
@export var x_prueba := -1.0
@export var musica_db := -12.0     # (como la del camino en la hojarasca)
@export var musica_entrada := 3.0    # s del fundido al empezar
var _musica_p: AudioStreamPlayer
var _musica_al_tema := false
var _musica_pos := 0.0

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
var _barcos: Array = []          # [Sprite2D, reflejo, x0, x1, velocidad, y, fase, x, opaco]
var _naves: Array = []
var _lluvia: LluviaNaves
## Al lanzarse el video del templo, unas naves bajan del cielo y se pierden a los
## dos lados de la piramide grande del fondo (x de su punta en la capa de la
## ciudad; LluviaNaves.bajada): siempre las mismas, en el mismo sitio.
const PIRAMIDE_X := 2502.0
const NAVES_TEMPLO := [-430.0, -240.0, 250.0, 440.0]   # donde se pierde cada una (desde la punta)
const NAVES_TEMPLO_TRAS := [0.4, 2.1, 1.0, 2.9]          # s tras lanzar el video
## Y una en la otra esquina, hacia el otro lado, junto al templo (2026-10-30, el
## usuario: "la gente mira el templo y no se ven cayendo las demas"): donde se
## pierde (x de la capa de la ciudad, entre el pilono de la izquierda y el
## templo) y cuando.
const NAVE_TEMPLO_OTRA := -190.0
const NAVE_TEMPLO_OTRA_TRAS := 1.6
var _con_capas := false
var _datos_capas: Dictionary = {}
var _tira_capas: Array = []      # [CanvasLayer, paralaje x, paralaje y]
var _con_tira := false
var _arena_delante: CanvasLayer
var _tex_mota: Texture2D
var _y_salto := NAN
var _anim_antes := ""
## SOLO PLAYA (ver acciones_egipto.gd): sin las piezas del recorrido ni sus
## cinematicas; la camara con un encuadre fijo.
var _solo_playa := false
var _t_juego := 0.0
## (la imagen entera en pantalla: 1632 filas a la escala de la tira, 1,9)
## (0.87 con las capas a escala 1.2: el mismo encuadre que 0.55 a 1.9, con el
## peregrino mas grande frente a la maleza de la playa)
@export var zoom_playa := 0.87
## los pies, hacia el 88 % de la pantalla: la arena justa, como en la imagen
@export var pies_playa := 0.42     # desde el centro (0,42: los pies a un 8 % del borde de abajo; 2026-10-28, con 0,38 sobraba arena)
@export var pies_subido := 0.2      # (lo mismo a 900 px de altura o mas)
@export var sombra_pies := false     # la sombra de contacto del peregrino (quitada 2026-10-28)
@export var zoom_mirador := 0.68     # en lo alto del mirador (recorrido.json "mirador")
@export var pies_mirador := 0.12

func _ready() -> void:
	nivel = _acciones.nivel
	process_physics_priority = 20          # despues de las acciones (10): sus limites, y luego los del techo
	_baston = BASTON.instantiate()
	_peregrino.add_child(_baston)
	# (el baston tambien en la caida del cielo: aparece al estamparse)
	_baston.set("en_caida", true)
	# (y a la espalda en la caida flotando de lo alto de las piedras)
	_baston.set("en_flotar", true)
	if x_prueba >= 0.0 or _acciones.solo_playa:
		# (en la playa, sin la entrada de cine: con sus bandas negras parecia
		# que el cielo estaba negro)
		entrada = false
	var x0: float = nivel["marcas"]["inicio"] if entrada else nivel["marcas"]["contemplar"]
	if _acciones.solo_playa and _acciones.recorrido.get("marcas", {}).has("inicio"):
		# (el recorrido de piedra: donde aparece el peregrino)
		x0 = float(_acciones.recorrido["marcas"]["inicio"])
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
	_musica()
	_con_tira = ResourceLoader.exists(TIRA)
	# (con la tira, su cielo opaco tapa toda la pantalla: el degradado de detras
	# era una pasada a pantalla completa que no se veia; 2026-10-29, rendimiento)
	if not _con_tira:
		_fondo()
	if _con_tira:
		_montar_tira()
	elif ResourceLoader.exists(FONDO):
		_montar_fondo()
	if _solo_playa:
		boceto = false
		_montar_recorrido()
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
	if _solo_playa:
		_montar_delante()
	if _solo_playa and caida_inicio and not _acciones.recorrido.is_empty():
		_caer_del_cielo()
	_camara.position = _cam_pos
	_camara.zoom = Vector2(_cam_zoom, _cam_zoom)
	_camara.position_smoothing_enabled = false
	_acciones.losa_intentada.connect(_al_intentar_losa)
	if entrada:
		_empezar_entrada()

func _input(event: InputEvent) -> void:
	if event.is_action("agacharse") and not event.is_echo():
		_abajo_real = event.is_pressed()

## La tecla del baston (accion "baston": Q o Z): sacarlo o guardarlo, como en la
## hojarasca (2026-10-27; el usuario: "no podemos sacar el baston"). De parado,
## con su animacion; andando, frena y la hace (baston.gd: alternar_mano). Con el
## en la mano solo se anda: para correr, saltar o trepar hay que guardarlo. Ni
## en las cinematicas ni a mitad de una accion; con el baculo clavado, el nodo
## de las acciones (que la ve antes) se la queda.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("baston") or event.is_echo():
		return
	if _cine or _final or not _acciones.libre():
		return
	get_viewport().set_input_as_handled()
	_baston.call("alternar_mano")

func _physics_process(delta: float) -> void:
	_t_juego += delta
	# (en la playa, nada del recorrido: ni el paso bajo que agacha, ni los
	# escalones, ni el mirador, ni el temblor al caer; el peregrino, libre)
	if not _solo_playa:
		_techos()
		_peldanos(delta)
		_mirador_si_toca()
		_caidas()
	elif _cayendo_del_cielo():
		pass
	elif not _acciones.recorrido.is_empty():
		# (el recorrido de piedra: sus escalones y las caidas, la sombra de las
		# repisas y el polvo)
		_peldanos(delta)
		_caidas()
		_sombra_repisas()
		_polvo_recorrido()
		_sol_peregrino()
		_templo_si_toca()
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
		# subido al recorrido de piedra, los pies mas arriba en la pantalla: que
		# se vea lo de abajo (por donde ha subido), no solo el cielo
		var alto := clampf((float(nivel["suelo"]) - _y_ref) / 900.0, 0.0, 1.0)
		var pies := lerpf(pies_playa, pies_subido, alto)
		var zoom := zoom_playa
		# en lo alto del mirador, la camara se abre: que luzca la vista
		var mr: Dictionary = _acciones.recorrido.get("marcas", {})
		if mr.has("mirador"):
			var cerca := 1.0 - smoothstep(250.0, 700.0, absf(x - float(mr["mirador"])))
			var k := cerca * smoothstep(950.0, 1150.0, float(nivel["suelo"]) - _y_ref)
			zoom = lerpf(zoom_playa, zoom_mirador, k)
			pies = lerpf(pies, pies_mirador, k)
		return Vector2(zoom, round(pies * 1632.0 / zoom))
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
		# (cayendo por debajo del despegue, los pies que se ven: el nodo se
		# queda arriba y, de un borde alto, el peregrino salia por abajo de la
		# pantalla antes de que bajara la camara)
		var y_ve: float = p.position.y + maxf(float(p.get_node("Sprite").position.y), 0.0)
		var dy := y_ve - _y_ref
		if _cayendo_del_cielo():
			# (cayendo del cielo, la camara espera en el suelo, donde va a caer)
			dy = 0.0
		if absf(dy) > zona_muerta_y:
			_y_ref = y_ve - signf(dy) * zona_muerta_y
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
		# (cayendo de alto, deprisa: con la de siempre llegaba al suelo pegado al
		# borde de abajo)
		var ry := rapidez_y_caida if y_ve > p.position.y + 120.0 else rapidez_y
		_cam_pos.y = lerpf(_cam_pos.y, objetivo.y, 1.0 - exp(-ry * delta))
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
		if temblor_al_caer and _peregrino.position.y - _y_despegue > 250.0:
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

## En lo alto del altar (la caja mas alta del recorrido en la marca del
## mirador), parado: se lanza el video del templo.
func _templo_si_toca() -> void:
	if _templo == null or _templo.lanzado or _cine:
		return
	var mr: Dictionary = _acciones.recorrido.get("marcas", {})
	if not mr.has("mirador"):
		return
	var x: float = mr["mirador"]
	var p := _peregrino
	if absf(p.position.x - x) > 160.0 or _estado() != "REPOSO" or not _acciones.libre():
		return
	var arriba := 0.0
	for c in _acciones.recorrido["cajas"]:
		if x >= float(c["x0"]) and x <= float(c["x1"]):
			arriba = maxf(arriba, float(c["arriba"]))
	if p.position.y > float(nivel["suelo"]) - arriba + 20.0:
		return
	_ver_templo()

## El peregrino se queda mirando al templo (control bloqueado), la camara va
## hacia el y corre el video entero; al acabar, todo como estaba.
func _ver_templo() -> void:
	_peregrino.control_bloqueado = true
	_peregrino.girar_hacia(_peregrino.position.x - 100.0)
	_bandas_objetivo = 0.1
	_cinematica(_camara_al_templo(), zoom_templo, 0.5)
	await get_tree().create_timer(1.5).timeout
	_templo.cantos_db = templo_cantos_db
	_templo.lanzar()
	if _lluvia:
		_lluvia.bajada(NAVES_TEMPLO.map(func(dx: float) -> float: return PIRAMIDE_X + dx), NAVES_TEMPLO_TRAS)
		_lluvia.bajada([NAVE_TEMPLO_OTRA], [NAVE_TEMPLO_OTRA_TRAS], Vector2(0.35, 1.0))
	await _templo.acabado
	_musica_tema()
	await get_tree().create_timer(1.0).timeout
	_bandas_objetivo = 0.0
	_fin_cinematica()
	_peregrino.control_bloqueado = false

## Donde poner la camara para que el templo (en su capa, con su paralaje) quede
## a templo_en_pantalla del ancho; de alto, la del peregrino.
func _camara_al_templo() -> Vector2:
	var tam := get_viewport().get_visible_rect().size
	var px: float = _templo_capa[1]
	var zt := lerpf(TIRA_ZOOM, zoom_templo, px)
	var tx := _templo.position.x + _templo.ancho() * 0.5
	var desp_x := tx - (templo_en_pantalla - 0.5) * tam.x / zt
	var x := _dentro_del_nivel(TIRA_C0.x + (desp_x - TIRA_C0.x) / px, zoom_templo)
	return Vector2(x, _peregrino.position.y - 260.0)

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

## ---- el recorrido de piedra (tools/egipto/recorrido.py) ---------------------------
## Las piezas del usuario sobre la arena, detras del peregrino; lo que se pisa
## (sus cajas) lo lleva acciones_egipto.gd.
func _montar_recorrido() -> void:
	var r: Dictionary = _acciones.recorrido
	if r.is_empty():
		return
	var n := Node2D.new()
	n.name = "Recorrido"
	n.z_index = -6
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(n)
	var suelo := float(nivel["suelo"])
	for d in r["sprites"]:
		var s := Sprite2D.new()
		s.texture = load(d["tex"])
		s.centered = false
		s.flip_h = d["flip"]
		var e: float = d["escala"]
		s.scale = Vector2(e, e)
		# (lo que se pisa, a la altura de los pies: PLANTA, como los objetos)
		s.position = Vector2(d["x"], suelo - _acciones.PLANTA - float(d["abajo"]) - float(d["alto"]))
		s.z_index = int(d.get("z", 0))
		# junto a la arena la piedra se oscurece y enfria (le llega menos cielo)
		var m := ShaderMaterial.new()
		m.shader = PIE_PIEDRA
		var alto: float = d["alto"]
		m.set_shader_parameter("suelo_uv", 1.0 + (float(d["abajo"]) + BORDE_ARENA) / alto)
		m.set_shader_parameter("banda_uv", PIE_BANDA / alto)
		if relieve_repisas:
			_cajas_en_uv(m, d, r["cajas"])
		s.material = m
		n.add_child(s)
		_pie_en_arena.append(s)
	_montar_adornos(r, suelo)
	_montar_borde_duro(suelo)
	# las palomas posadas (se espantan al acercarse el peregrino), todas en un
	# mismo estudio 3D (estudio_palomas.gd)
	var estudio := EstudioPalomas.new()
	estudio.name = "EstudioPalomas"
	add_child(estudio)
	var sueltas: Array = []
	var i_pj := 0
	for pj in r.get("pajaros", []):
		var b := PajaroPosado.new()
		# (cada una con un plumaje distinto, por turno)
		b.plumaje = (i_pj * 2) % PajaroPosado.PLUMAJES.size()
		i_pj += 1
		b.position = Vector2(float(pj["x"]), suelo - _acciones.PLANTA - float(pj["h"]))
		b.sentido = float(pj["sentido"])
		b.peregrino = _peregrino
		b.estudio = estudio
		b.z_index = -2
		add_child(b)
		sueltas.append(b)
	# la bandada de la caida: comen a la derecha y se espantan con el golpe (bandada.gd)
	if r.has("bandada"):
		var bd := Bandada.new()
		bd.name = "Bandada"
		bd.peregrino = _peregrino
		bd.estudio = estudio
		bd.vecinas = sueltas
		bd.z_index = -2
		add_child(bd)
		bd.montar(r["bandada"], suelo - _acciones.PLANTA)
	# F3 ver lo que se pisa, F4 marcar un fallo (marcas_recorrido.gd)
	var m := MarcasRecorrido.new()
	m.acciones = _acciones
	m.peregrino = _peregrino
	add_child(m)

## Los adornos del recorrido (recorrido.py, ADORNOS): por detras del peregrino;
## los que nacen en lo alto de una repisa, ademas por detras de la piedra (les
## tapa el pie). Las plantas y las enredaderas se mecen (vaiven.gdshader); lo
## que esta delante de un muro en sombra, con su luz ("luz"); lo apoyado en la
## piedra, con su sombra de contacto.
func _montar_adornos(r: Dictionary, suelo: float) -> void:
	var delante := Node2D.new()
	delante.name = "Adornos"
	delante.z_index = -5
	var detras := Node2D.new()
	detras.name = "AdornosDetras"
	detras.z_index = -7
	for n in [detras, delante]:
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(n)
	for d in r.get("adornos", []):
		var s := Sprite2D.new()
		s.texture = load(d["tex"])
		s.centered = false
		s.flip_h = d["flip"]
		if d.has("filas"):
			# (solo lo de arriba: lo de abajo lo pone la enredadera)
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, s.texture.get_width(), float(d["filas"]))
		var e: float = d["escala"]
		s.scale = Vector2(e, e)
		s.position = Vector2(d["x"], suelo - _acciones.PLANTA - float(d["abajo"]) - float(d["alto"]))
		if float(d["vaiven"]) > 0.0:
			var m := ShaderMaterial.new()
			m.shader = VAIVEN
			m.set_shader_parameter("amplitud", float(d["vaiven"]))
			m.set_shader_parameter("cuelga", d["ancla"] == "techo")
			s.material = m
		var k: float = d.get("luz", 1.0)
		# (la sombra, algo azul: la llena el cielo, como la del peregrino)
		s.modulate = Color(k, k * 1.01, minf(k * 1.08, 1.0))
		if d.has("z"):
			s.z_as_relative = false
			s.z_index = int(d["z"])
		var padre: Node2D = detras if d.get("detras", false) else delante
		# (lo apoyado en la arena, menos las dunas: con el borde nitido de la
		# arena de delante; ver _montar_borde_duro)
		# (las plantas, sin: se funden con la arena como las dunas)
		if float(d["abajo"]) < 30.0:
			var nombre := String(d["tex"]).get_file()
			if nombre.begins_with("arena"):
				_dunas_en_arena.append(s)
			elif not nombre.begins_with("plantas"):
				_pie_en_arena.append(s)
		if d.get("sombra", false):
			_sombra_apoyo(padre, s.position + Vector2(float(d["ancho"]) * 0.5, float(d["alto"])), float(d["ancho"]))
		padre.add_child(s)

const VAIVEN := preload("res://scripts/game/egipto/vaiven.gdshader")

## La sombra de contacto de lo apoyado en la piedra: un ovalo difuso bajo el
## pie, algo corrido a la derecha (el sol viene de arriba a la izquierda).
func _sombra_apoyo(padre: Node, pie: Vector2, ancho: float) -> void:
	var s := Sprite2D.new()
	s.texture = _mota()
	s.modulate = Color(0.14, 0.12, 0.18, 0.5)
	s.scale = Vector2(ancho * 0.95 / 32.0, 22.0 / 32.0)
	s.position = pie + Vector2(ancho * 0.08, -4.0)
	padre.add_child(s)

## EL PRIMER PLANO (recorrido.py, DELANTE): en su CanvasLayer por encima de todo,
## con mas paralaje que el juego (DELANTE_P): pasa mas deprisa y, al subir, se
## hunde por abajo. Despues de fijar TIRA_C0 (su sitio se cuenta desde ahi).
const DELANTE_P := Vector2(1.3, 1.2)
const DELANTE_BAJO := 140.0       # px de juego por debajo de los pies en la arena

func _montar_delante() -> void:
	var r: Dictionary = _acciones.recorrido
	if r.get("delante", []).is_empty():
		return
	var capa := CanvasLayer.new()
	capa.layer = 2
	capa.name = "Delante"
	add_child(capa)
	var pies: float = float(nivel["suelo"]) - _acciones.PLANTA
	for d in r["delante"]:
		var s := Sprite2D.new()
		s.texture = load(d["tex"])
		s.centered = false
		s.flip_h = d["flip"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var e: float = d["escala"]
		s.scale = Vector2(e, e)
		var lx: float = TIRA_C0.x + DELANTE_P.x * (float(d["x"]) - TIRA_C0.x)
		var ly: float = TIRA_C0.y + DELANTE_P.y * (pies + DELANTE_BAJO - TIRA_C0.y)
		s.position = Vector2(lx - float(d["ancho"]) * 0.5, ly - float(d["alto"]))
		capa.add_child(s)
	_tira_capas.append([capa, DELANTE_P.x, DELANTE_P.y, 0.0])

## ---- la caida del cielo ---------------------------------------------------------

## LA CAIDA DEL CIELO (2026-10-28, el usuario: "que caiga del cielo como en la
## escena de la hojarasca"): la cinematica del peregrino (caer_desde_arriba: cae,
## se estampa, se queda tumbado y se levanta). Mientras dura, la camara espera en
## el suelo. Cae en HOJAS (hojas_portal.gd: las que trae el portal, el usuario:
## "siempre que cae, mejor hojas"); antes, un monton de arena con arena que
## saltaba por codigo: "cutrisimo, parece que no es arena".
@export var caida_inicio := true
## En que cae: "arena" (arena_portal.gd) u "hojas" (hojas_portal.gd).
@export var caida_en := "arena"
## (sin monton de primer plano: el usuario, 2026-10-28, "no metas en primer
## plano, las de la izquierda diria que sobran"; hojas_portal.gd conserva
## primer_plano() por si vuelve)
const CINEMATICA := ["CAYENDO", "CAIDA", "TUMBADO", "LEVANTARSE"]
var _hojas: HojasPortal

func _cayendo_del_cielo() -> bool:
	return _estado() in CINEMATICA

func _caer_del_cielo() -> void:
	var suelo := float(nivel["suelo"])
	if caida_en == "arena":
		# (2026-10-28: en un monton de arena, arena_portal.gd; hojas_portal.gd
		# queda por si vuelven las hojas: caida_en = "hojas")
		var a := ArenaPortal.new()
		a.name = "ArenaPortal"
		a.peregrino = _peregrino
		a.temblor = func(s: float) -> void: _temblor = s
		add_child(a)
		a.montar(_peregrino.position.x, suelo)
		_peregrino.caer_desde_arriba()
		return
	_hojas = HojasPortal.new()
	_hojas.name = "HojasPortal"
	_hojas.peregrino = _peregrino
	add_child(_hojas)
	# (hasta las piedras de los lados: la losa de la izquierda y la base del templo)
	var izq := -INF
	var der := INF
	var x := _peregrino.position.x
	for c in _acciones.recorrido.get("cajas", []):
		if float(c["x1"]) <= x:
			izq = maxf(izq, float(c["x1"]))
		elif float(c["x0"]) >= x:
			der = minf(der, float(c["x0"]))
	_hojas.montar(x, suelo, izq, der, _arena_delante, BORDE_ARENA + 16.0)
	_peregrino.impacto.connect(func() -> void: _temblor = 0.4)
	_peregrino.caer_desde_arriba()

## LO QUE SE PISA, A LA VISTA (pie_piedra.gdshader): las cajas de la pieza
## (las de su textura) en UV, con el alto del canto que se ve bajo la cara de
## arriba (CANTO px de juego, o hasta su cara de abajo si es una losa).
@export var relieve_repisas := true
const CANTO := 60.0

func _cajas_en_uv(m: ShaderMaterial, d: Dictionary, cajas: Array) -> void:
	var pieza := String(d["tex"]).get_file().get_basename()
	var ancho: float = d["ancho"]
	var alto: float = d["alto"]
	var lista: Array[Vector4] = []
	for c in cajas:
		if String(c["pieza"]) != pieza or lista.size() >= 24:
			continue
		var arriba: float = c["arriba"]
		var canto: float = CANTO
		if float(c["abajo"]) > 0.0:
			canto = minf(canto, arriba - float(c["abajo"]))
		lista.append(Vector4((float(c["x0"]) - float(d["x"])) / ancho, (float(c["x1"]) - float(d["x"])) / ancho,
				(alto + float(d["abajo"]) - arriba) / alto, canto / alto))
	m.set_shader_parameter("cajas", lista)
	m.set_shader_parameter("n_cajas", lista.size())
	m.set_shader_parameter("filo_uv", 10.0 / alto)
	m.set_shader_parameter("canto_suave", 18.0 / alto)

## EL SOL EN EL PEREGRINO (sol_peregrino.gdshader): el borde de luz del lado del
## sol, que en el mundo esta siempre arriba a la izquierda (el volteo lo resuelve
## el shader: desde aqui llegaba un fotograma tarde al acabar los giros).
var _sol: ShaderMaterial

func _sol_peregrino() -> void:
	var sp := _peregrino.get_node("Sprite") as AnimatedSprite2D
	if sp.material == null:
		_sol = ShaderMaterial.new()
		_sol.shader = preload("res://scripts/game/egipto/sol_peregrino.gdshader")
		sp.material = _sol

## La piedra del recorrido junto a la arena: mas oscura y mas fria en los
## PIE_BANDA px de abajo (la luz que rebota del cielo no llega).
const PIE_BANDA := 55.0
## Donde la arena de delante corta las piezas: px por debajo de los pies (su
## borde nitido, borde_arena.gdshader: fila ~21 de la rampa de capas.py a escala
## 1,2, desde y 19,9).
## (2026-10-28: la arena de delante sube ARENA_SUBE px con el recorrido; cortaba
## las piedras 46 px por debajo de los pies y el peregrino parecia ir por detras
## de ellas, el usuario: "si has adelantado la linea de las piedras, tienes que
## adelantar las hojas y el peregrino")
const ARENA_SUBE := 34.0
const BORDE_ARENA := 46.0 - ARENA_SUBE
const BORDE_ARENA_SHADER := preload("res://scripts/game/egipto/borde_arena.gdshader")
const PIE_PIEDRA := preload("res://scripts/game/egipto/pie_piedra.gdshader")

## La sombra de contacto de una pieza en la arena de delante (por delante de la
## arena, no de la pieza: va en la capa de la arena de delante).
## EL BORDE NITIDO, SOLO AL PIE DE LO APOYADO (2026-10-29; el usuario: "hay una
## linea rara donde se une las piedras con la arena... parece que son suelos
## distintos"). El borde de la arena de delante se afilo para definir el pie del
## templo (borde_arena.gdshader); en el resto, recto y duro, parecia el canto
## de una losa. Aqui, una mascara a lo largo (PIE_TEXEL px por texel): donde lo
## apoyado (piezas y adornos solidos: ni dunas ni plantas) es opaco justo encima del borde,
## nitido; en lo demas, suave (las dunas de detras se funden con ella). Las
## dunas que tapan el pie de una pieza cuentan como arena. La sombra de contacto
## del pie, con la misma mascara (antes, una franja por pieza a todo su ancho:
## con el templo, una raya oscura de lado a lado, tambien bajo los arcos).
const PIE_TEXEL := 4.0
const PIE_SUAVE := 6                    # texels de transicion a cada lado
var _borde_mat: ShaderMaterial
var _pie_en_arena: Array[Sprite2D] = []
var _dunas_en_arena: Array[Sprite2D] = []

## Lo opaco de esos sprites en los texels de la mascara, justo encima de la linea.
func _opaco_en_linea(sprites: Array[Sprite2D], linea: float, x0: float, n: int) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	v.resize(n)
	for s in sprites:
		var img := s.texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var e := s.scale.x
		var w := img.get_width()
		var h := img.get_height()
		var r0 := s.region_rect.position.y if s.region_enabled else 0.0
		var filas: Array[int] = []
		for dy in [-22.0, -12.0, -4.0]:
			var f := int((linea + dy - s.position.y) / e + r0)
			if f >= 0 and f < h:
				filas.append(f)
		if filas.is_empty():
			continue
		for i in n:
			var u := (x0 + (i + 0.5) * PIE_TEXEL - s.position.x) / e
			if u < 0.0 or u >= w:
				continue
			var ui := w - 1 - int(u) if s.flip_h else int(u)
			for f in filas:
				v[i] = maxf(v[i], img.get_pixel(ui, f).a)
	return v

func _montar_borde_duro(suelo: float) -> void:
	if _borde_mat == null or _pie_en_arena.is_empty():
		return
	var x0 := INF
	var x1 := -INF
	for s in _pie_en_arena:
		x0 = minf(x0, s.position.x)
		x1 = maxf(x1, s.position.x + s.texture.get_width() * s.scale.x)
	x0 -= PIE_TEXEL * PIE_SUAVE * 2.0
	x1 += PIE_TEXEL * PIE_SUAVE * 2.0
	var n := int(ceil((x1 - x0) / PIE_TEXEL))
	var linea := suelo + BORDE_ARENA          # el borde de la arena de delante
	var piedra := _opaco_en_linea(_pie_en_arena, linea, x0, n)
	var duna := _opaco_en_linea(_dunas_en_arena, linea, x0, n)
	# (con su transicion: la media de los de alrededor)
	var duro := PackedFloat32Array()
	duro.resize(n)
	var im := Image.create(n, 1, false, Image.FORMAT_RF)
	for i in n:
		var t := 0.0
		for k in range(-PIE_SUAVE, PIE_SUAVE + 1):
			var j := clampi(i + k, 0, n - 1)
			t += piedra[j] * (1.0 - duna[j])
		duro[i] = t / (2 * PIE_SUAVE + 1)
		im.set_pixel(i, 0, Color(duro[i], 0, 0))
	_borde_mat.set_shader_parameter("pie_tex", ImageTexture.create_from_image(im))
	_borde_mat.set_shader_parameter("pie_x", Vector2(x0, n * PIE_TEXEL))
	_sombra_contacto_mascara(duro, x0, suelo)

## La sombra de contacto (corta y nitida, justo donde la arena corta la piedra),
## solo donde la mascara dice que hay algo apoyado.
func _sombra_contacto_mascara(duro: PackedFloat32Array, x0: float, suelo: float) -> void:
	if _arena_delante == null:
		return
	var n := duro.size()
	var im := Image.create(n, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var a := 0.55 * pow(1.0 - float(y) / 31.0, 2.2)
		for i in n:
			im.set_pixel(i, y, Color(0.14, 0.11, 0.12, a * duro[i]))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(im)
	s.centered = false
	s.position = Vector2(x0, suelo + BORDE_ARENA - 2.0)
	s.scale = Vector2(PIE_TEXEL, 26.0 / 32.0)
	_arena_delante.add_child(s)

## ---- la luz y el polvo del recorrido ---------------------------------------------

## Bajo una repisa (una caja por encima de la cabeza), el peregrino en su sombra.
func _sombra_repisas() -> void:
	var p := _peregrino
	var pies := float(nivel["suelo"]) - p.position.y
	var debajo := false
	for c in _acciones.recorrido["cajas"]:
		var ab := float(c["abajo"])
		if ab > pies + 120.0 and ab < pies + 900.0 and p.position.x > float(c["x0"]) + 20.0 and p.position.x < float(c["x1"]) - 20.0:
			debajo = true
			break
	_luz_peregrino = lerpf(_luz_peregrino, 0.74 if debajo else 1.0, 0.06)
	var k := _luz_peregrino
	# (la sombra, algo azul: la llena el cielo)
	p.modulate = Color(k, k * 1.01, minf(k * 1.08, 1.0))

## Una nube de polvo en pos (cuanto: 0..1). Sobre la arena, de arena; sobre la
## piedra, mas palido.
func _polvo_en(pos: Vector2, cuanto: float, piedra: bool) -> void:
	var e := CPUParticles2D.new()
	e.one_shot = true
	e.explosiveness = 0.9
	e.amount = int(lerpf(6.0, 22.0, cuanto))
	e.lifetime = lerpf(0.7, 1.4, cuanto)
	e.position = pos
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(40.0, 4.0)
	e.direction = Vector2(0, -1)
	e.spread = 80.0
	e.gravity = Vector2(0, 60)
	e.initial_velocity_min = 30.0
	e.initial_velocity_max = lerpf(70.0, 160.0, cuanto)
	e.damping_min = 40.0
	e.damping_max = 80.0
	e.texture = _mota()
	e.scale_amount_min = 0.5
	e.scale_amount_max = lerpf(0.9, 1.6, cuanto)
	var crece := Curve.new()
	crece.add_point(Vector2(0, 0.5))
	crece.add_point(Vector2(1, 1.6))
	e.scale_amount_curve = crece
	var c := Color(0.92, 0.86, 0.76) if piedra else Color(0.9, 0.78, 0.62)
	var g := Gradient.new()
	g.set_color(0, Color(c, 0.0))
	g.set_color(1, Color(c, 0.0))
	g.add_point(0.12, Color(c, 0.5 if piedra else 0.6))
	e.color_ramp = g
	e.z_index = 2
	add_child(e)
	e.emitting = true
	get_tree().create_timer(e.lifetime + 0.3).timeout.connect(e.queue_free)

## Arenilla y piedrecitas que caen del filo al trepar.
func _arenilla_en(pos: Vector2) -> void:
	var e := CPUParticles2D.new()
	e.one_shot = true
	e.explosiveness = 0.3
	e.amount = 14
	e.lifetime = 1.3
	e.position = pos
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(26.0, 2.0)
	e.direction = Vector2(0, 1)
	e.spread = 20.0
	e.gravity = Vector2(0, 900)
	e.initial_velocity_min = 10.0
	e.initial_velocity_max = 60.0
	e.texture = _mota()
	e.scale_amount_min = 0.12
	e.scale_amount_max = 0.3
	e.color = Color(0.78, 0.68, 0.56, 0.9)
	e.z_index = 2
	add_child(e)
	e.emitting = true
	get_tree().create_timer(2.0).timeout.connect(e.queue_free)

func _mota() -> Texture2D:
	if _tex_mota == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_tex_mota = tex
	return _tex_mota

## Al aterrizar, polvo (mas cuanto mas cae); al empezar a trepar, arenilla que
## cae del filo donde se agarra.
func _polvo_recorrido() -> void:
	var e := _estado()
	var p := _peregrino
	var suelo := float(nivel["suelo"])
	if e == "SALTAR":
		if is_nan(_y_salto):
			_y_salto = p.position.y
	elif not is_nan(_y_salto):
		var caida := p.position.y - _y_salto
		_polvo_en(p.position + Vector2(0, -2), clampf(0.25 + caida / 600.0, 0.15, 1.0), absf(p.position.y - suelo) > 2.0)
		_y_salto = NAN
	var anim: String = _acciones._anim if _acciones._modo == _acciones.Modo.ACCION else ""
	if anim != _anim_antes and anim.begins_with("trepar"):
		var cara: float = float(_acciones._datos[anim]["cara"])
		_arenilla_en(Vector2(p.position.x + _acciones._d * (cara + 20.0), _acciones._y_fin - 4.0))
	_anim_antes = anim

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
		_naves = otras.get("naves", [])
		_datos_capas = otras
		_con_capas = true
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
		var borde_mat: ShaderMaterial = null
		for tr in c["trozos"]:
			var s := Sprite2D.new()
			s.texture = load(tr["tex"])
			if agua_mat:
				s.material = agua_mat
			elif c.get("viento", false):
				s.material = _material_orilla(String(tr["tex"]), float(c.get("costa", 0.5)))
			elif c.get("delante", false):
				# (uno para todos los trozos: los mismos parametros)
				if borde_mat == null:
					borde_mat = ShaderMaterial.new()
					borde_mat.shader = BORDE_ARENA_SHADER
					_borde_mat = borde_mat
				s.material = borde_mat
			elif String(c["nombre"]) == "arena" and _solo_playa and not _acciones.recorrido.is_empty():
				# (la arena de detras, a la altura del suelo: sin las sombras azules
				# de palmera, que asomaban entre las piedras como agua)
				var bm := ShaderMaterial.new()
				bm.shader = BORDE_ARENA_SHADER
				var alto_t: float = (load(tr["tex"]) as Texture2D).get_height() * float(c.get("escala", e))
				var v0: float = (float(nivel["suelo"]) - 160.0 - float(tr["y"])) / alto_t
				var v1: float = (float(nivel["suelo"]) + 140.0 - float(tr["y"])) / alto_t
				bm.set_shader_parameter("franja", Vector2(v0, v1))
				s.material = bm
			s.centered = false
			var ec: float = c.get("escala", e)
			s.scale = Vector2(ec, ec)
			s.position = Vector2(tr["x"], tr["y"])
			# (solo las filas con algo, capas.py: las vacias se pintaban igual;
			# el UV de los shaders sigue siendo el de la textura entera)
			if tr.has("filas"):
				var f0: float = tr["filas"][0]
				var f1: float = tr["filas"][1]
				s.region_enabled = true
				s.region_rect = Rect2(0.0, f0, s.texture.get_width(), f1 - f0)
				s.position.y += f0 * ec
			if c.get("delante", false) and _solo_playa and FileAccess.file_exists(_acciones.RECORRIDO):
				s.position.y -= ARENA_SUBE
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			capa.add_child(s)
		# (antes de su calima: la base del templo, en el aire de la orilla)
		if String(c["nombre"]) == "orilla" and FileAccess.file_exists(TEMPLO):
			_templo = TemploRio.new()
			_templo.montar(JSON.parse_string(FileAccess.get_file_as_string(TEMPLO)))
			capa.add_child(_templo)
		_tira_capas.append([capa, float(c["p"]), float(c["py"]), float(c.get("deriva", 0.0))])
		if _templo and _templo.get_parent() == capa:
			_templo_capa = _tira_capas[-1]
		_poner_naves(capa, String(c["nombre"]))
		if String(c["nombre"]) == "ciudad" and _con_capas:
			_poner_lluvia(capa)
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
			_barcos_tira(cb, float(bd["x0"]), float(bd["x1"]), float(bd["y0"]), float(bd["y1"]),
					float(bd.get("prof", [0.0, 1.0])[0]), float(bd.get("prof", [0.0, 1.0])[1]), bd)
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

## La musica del acto en lugar del viento (el de DarkStage, que es de toda la
## intro: aqui se baja al silencio y vuelve a subir la escena que lo use).
func _musica() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(MusicAmbience.SILENCIO, 0.0)
	var pista := MUSICA.duplicate() as AudioStreamOggVorbis
	pista.loop = true
	pista.loop_offset = MUSICA_BUCLE
	var p := AudioStreamPlayer.new()
	p.stream = pista
	p.volume_db = MusicAmbience.SILENCIO
	add_child(p)
	p.play()
	_musica_p = p
	var tw := create_tween()
	tw.tween_property(p, "volume_db", musica_db, musica_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Que entre el tema en el golpe del siguiente compas de la intro.
func _musica_tema() -> void:
	if _musica_p == null:
		return
	_musica_al_tema = true
	_musica_pos = _musica_p.get_playback_position()

func _process(delta: float) -> void:
	if _musica_al_tema:
		_musica_cambio(delta)

## El cambio, en el golpe de un compas: si falta menos de medio fotograma, ya
## (se pierden unos ms de la cola); si ya ha pasado (o el bucle ha vuelto a
## empezar), el tema desde lo que se ha pasado. Lo que quedaba de la intro se
## apaga en un momento. (Sin AudioServer.get_time_since_last_mix: grabando con
## --write-movie lo adelantaba 136 ms; la posicion de la ultima mezcla va como
## mucho una mezcla tarde, y eso lo recoge lo de "ya ha pasado".)
func _musica_cambio(delta: float) -> void:
	var p := _musica_p
	var pos := p.get_playback_position()
	var desde := -1.0
	if pos < _musica_pos - 1.0:
		desde = maxf(pos - MUSICA_BUCLE, 0.0)
	else:
		# el siguiente golpe (el ultimo es el final del fichero)
		var golpe := minf(MUSICA_BUCLE + ceilf((_musica_pos - MUSICA_BUCLE + 0.001) / MUSICA_COMPAS) * MUSICA_COMPAS, p.stream.get_length())
		if _musica_pos < MUSICA_BUCLE:
			golpe = MUSICA_BUCLE
		if pos >= golpe:
			desde = pos - golpe
		elif golpe - pos < delta * 0.5:
			desde = 0.0
	_musica_pos = pos
	if desde < 0.0:
		return
	_musica_al_tema = false
	var tema := MUSICA_TEMA.duplicate() as AudioStreamOggVorbis
	tema.loop = true
	var t := AudioStreamPlayer.new()
	t.stream = tema
	t.volume_db = p.volume_db
	add_child(t)
	t.play(desde)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", MusicAmbience.SILENCIO, 0.35)
	tw.tween_callback(p.queue_free)
	_musica_p = t

## La orilla de enfrente: el viento en su vegetacion (con su mascara, la pieza
## *_viento_N de al lado) y el temblor de su reflejo.
const ORILLA := preload("res://scripts/game/egipto/orilla.gdshader")
var _ruido_tex: NoiseTexture2D
func _material_orilla(tex: String, costa: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ORILLA
	var mascara := tex.replace("medio_orilla_", "medio_orilla_viento_")
	if ResourceLoader.exists(mascara):
		m.set_shader_parameter("viento", load(mascara))
	if _ruido_tex == null:
		_ruido_tex = _ruido_rachas()
	m.set_shader_parameter("ruido", _ruido_tex)
	m.set_shader_parameter("costa", costa)
	return m

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
## METIDOS EN EL AGUA (2026-10-30, el usuario: "parecen que flotan sobre el agua
## ... que hagan surcos en el agua de una forma parecida a la barca funeraria,
## aunque al moverse menos tendran que ser acordes"): de cada textura, la fila de
## la linea del agua (40% del casco hundido; bajo el casco traen ~12 px vacios,
## que lo dejaban en el aire) y donde empieza y acaba el casco en ella (popa,
## proa; la proa a la derecha, hacia donde van sin voltear).
const BARCOS_CASCO := [[641, 143, 652], [378, 48, 287], [355, 36, 241], [174, 36, 160]]
## Su espuma: la del barco del cortejo (barco_espuma.gdshader), en sus mismas
## unidades (1,75 px de la capa: el px del video a 640), mas floja y con la
## estela corta, que van mucho mas despacio.
const BARCOS_ESPUMA_U := 1.75
const BARCOS_ESTELA := 70.0
@export var barcos_espuma := 1.0
## El reflejo, mas fuerte que el de los del fondo: el agua refleja la orilla casi
## entera, y uno flojo los dejaba en el aire.
@export var barcos_reflejo := 0.5
const ESPUMA := preload("res://scripts/game/egipto/barco_espuma.gdshader")
## (con 'conf', de capas.json: cuantos, alto [min, max], rapidez [min, max] y
## carriles: la profundidad de cada uno, fija; 2026-10-30, el usuario: "que no
## vayan nunca en la misma linea para que no se choquen")
func _barcos_tira(capa: CanvasLayer, x0: float, x1: float, y0: float, y1: float, prof0 := 0.12, prof1 := 0.6, conf := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var texs: Array = []
	for r in BARCOS_TEX:
		if ResourceLoader.exists(r):
			texs.append(load(r))
	if texs.is_empty():
		return
	var alto: Array = conf.get("alto", [110.0, 230.0])
	var rapidez: Array = conf.get("rapidez", [8.0, 26.0])
	for i in int(conf.get("cuantos", barcos_cuantos)):
		var tex: Texture2D = texs[i % texs.size()]
		# (repartidos en profundidad, no al azar: que no coincidan dos a la misma altura)
		var prof := lerpf(prof0, prof1, (float(i) + rng.randf_range(0.2, 0.8)) / float(int(conf.get("cuantos", barcos_cuantos))))
		if conf.has("carriles"):
			prof = float(conf["carriles"][i % conf["carriles"].size()])
		var y := lerpf(y0, y1, prof)
		var alto_obj := lerpf(float(alto[0]), float(alto[1]), prof)    # alto del barco en el juego
		var esc := alto_obj / tex.get_height()
		var casco: Array = BARCOS_CASCO[i % texs.size()]
		var agua := float(casco[0])
		# (la fila del agua en y: lo de debajo se recorta cada fotograma, con el
		# cabeceo, en _mover_barcos)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -agua)
		s.scale = Vector2(esc, esc)
		s.region_enabled = true
		s.region_rect = Rect2(0.0, 0.0, tex.get_width(), agua)
		# (opacos y algo en sombra, con la luz de la orilla: tan blancos y
		# transparentes "parecian de papel", junto al barco del cortejo)
		s.modulate = Color(0.94, 0.87, 0.77)
		# el reflejo, desde la linea del agua
		var r := Sprite2D.new()
		r.texture = tex
		r.centered = false
		r.offset = Vector2(-tex.get_width() * 0.5, 0.0)
		r.flip_v = true
		r.scale = Vector2(esc, esc * 0.7)
		r.region_enabled = true
		r.region_rect = s.region_rect
		r.modulate = Color(0.72, 0.76, 0.84, barcos_reflejo)
		capa.add_child(r)
		capa.add_child(s)
		var v := lerpf(float(rapidez[0]), float(rapidez[1]), prof) * (1.0 if rng.randf() < 0.5 else -1.0)
		s.flip_h = v < 0.0
		r.flip_h = s.flip_h
		# la espuma: en un ancla en la linea del agua, volteada con el barco
		var u := BARCOS_ESPUMA_U
		var popa := (float(casco[1]) - tex.get_width() * 0.5) * esc / u
		var proa := (float(casco[2]) - tex.get_width() * 0.5) * esc / u
		var largo := BARCOS_ESTELA + proa - popa + 12.0
		var mat := ShaderMaterial.new()
		mat.shader = ESPUMA
		mat.set_shader_parameter("ruido", _ruido_espuma())
		mat.set_shader_parameter("tam", Vector2(largo, 24.0))
		mat.set_shader_parameter("linea", 6.0)
		mat.set_shader_parameter("popa", BARCOS_ESTELA)
		mat.set_shader_parameter("proa", BARCOS_ESTELA + proa - popa)
		mat.set_shader_parameter("remo", -100.0)
		mat.set_shader_parameter("salpica", 0.0)
		mat.set_shader_parameter("estela_largo", BARCOS_ESTELA * 0.6)
		mat.set_shader_parameter("ola", 0.55)
		var ancla := Node2D.new()
		ancla.scale = Vector2(u * signf(v), u)
		var esp := ColorRect.new()
		esp.material = mat
		esp.size = Vector2(largo, 24.0)
		esp.position = Vector2(popa - BARCOS_ESTELA, -6.0)
		esp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ancla.add_child(esp)
		capa.add_child(ancla)
		_barcos.append([s, r, x0 + 400.0, x1 - 400.0, v, y, rng.randf() * TAU, rng.randf_range(x0 + 400.0, x1 - 400.0), 1.0,
				{"agua": agua, "esc": esc, "ancla": ancla, "mat": mat}])

var _ruido_esp: NoiseTexture2D
func _ruido_espuma() -> NoiseTexture2D:
	if _ruido_esp == null:
		_ruido_esp = NoiseTexture2D.new()
		_ruido_esp.seamless = true
		_ruido_esp.width = 256
		_ruido_esp.height = 256
		_ruido_esp.noise = FastNoiseLite.new()
		_ruido_esp.noise.frequency = 0.03
	return _ruido_esp

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
			_barcos.append([s, r, x0, x1, v, y, rng.randf() * TAU, rng.randf_range(x0, x1), 0.92])
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
		s.modulate.a = float(b[8]) * a
		r.modulate.a = 0.22 * a
		if b.size() > 9:
			# (metido en el agua: sube y baja, y se recorta en la linea del agua,
			# que no se mueve; el reflejo, pegado a ella)
			var m: Dictionary = b[9]
			var esc: float = m["esc"]
			var alto: float = float(m["agua"]) - bote / esc
			s.region_rect.size.y = alto
			r.region_rect.size.y = alto
			s.rotation *= 0.5
			r.position.y = float(b[5])
			r.modulate.a = barcos_reflejo * a
			var ancla: Node2D = m["ancla"]
			ancla.position = Vector2(b[7], float(b[5]))
			ancla.modulate.a = a
			(m["mat"] as ShaderMaterial).set_shader_parameter("avance", float(b[7]) * signf(float(b[4])) / BARCOS_ESPUMA_U)
			(m["mat"] as ShaderMaterial).set_shader_parameter("fuerza", barcos_espuma)

## La lluvia de naves (LluviaNaves, el homenaje a Planet of Lana): en la capa de
## la ciudad, por delante de su cielo, cayendo a la vista y perdiendose tras la
## silueta de las montanas.
func _poner_lluvia(capa: CanvasLayer) -> void:
	var lluvia := LluviaNaves.new()
	var sil: Dictionary = _datos_capas.get("silueta", {})
	if not sil.is_empty():
		lluvia.silueta = PackedFloat32Array(sil["y"])
		lluvia.sil_x0 = float(sil["x0"])
		lluvia.sil_paso = float(sil["paso"])
	lluvia.donde = func() -> Rect2:
		return capa.transform.affine_inverse() * Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	capa.add_child(lluvia)
	_lluvia = lluvia

## ---- las naves -----------------------------------------------------------------
## Un guino (2026-10-27): naves pequenitas, como las de Planet of Lana, en las
## azoteas de los pilonos gemelos de la ciudad del fondo, que despegan y llegan
## (NavePosada; las de capas.json "naves", cada una en su capa).
func _poner_naves(capa: CanvasLayer, nombre: String) -> void:
	for n in _naves:
		if String(n.get("capa", "")) != nombre:
			continue
		var nave := NavePosada.new()
		nave.position = Vector2(float(n["x"]), float(n["y"]))
		nave.ancho = float(n.get("ancho", 40.0))
		nave.sentido = float(n.get("sentido", 1.0))
		nave.estado = String(n.get("estado", "posada"))
		nave.espera = float(n.get("espera", 20.0))
		nave.subida = float(n.get("subida", 520.0))
		nave.aire_k = float(n.get("aire", nave.aire_k))
		capa.add_child(nave)

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
	# (2026-10-28, el usuario: la sombra de los pies "no me gusta mucho": fuera;
	# se queda el codigo por si vuelve)
	_sombra.visible = false
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
	_sombra.visible = sombra_pies and _estado() != "TUMBADO"

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
