class_name MecanismoAltar
extends Node
## EL ALTAR QUE SE HUNDE Y LA LOSA QUE SALE (2026-10-31, Acto I de Egipto, segunda
## parte; el usuario: "al subir al altar este baja un poco y libera una plataforma
## que va hasta el siguiente bloque ... al bajarse empieza a retraerse").
##   - Siempre que este de pie en lo alto del altar (2026-10-31, el usuario: el
##     video del templo y la losa son "eventos independientes": tambien sale
##     mientras se ve el video, con el peregrino quieto encima), la tapa del
##     altar baja un poco (hundir) y la losa larga sale de
##     debajo del voladizo de la terraza hasta el capitel de la columna de las
##     ruinas (tools/egipto/recorrido.py, "mecanismo" en recorrido.json).
##   - Al bajarse del altar, la losa vuelve a meterse: empieza despacio y va
##     cogiendo velocidad (segundos_recoger, de toda fuera a dentro), y el altar
##     sube con ella. Andando no se llega; corriendo, si (el puzle: esperar a que
##     salga entera y cruzar corriendo).
##   - Lo que esta de pie encima de la losa se va con ella (la piedra le lleva):
##     si no llega, acaba otra vez en la terraza. De su punta no se cae al vacio:
##     se para en el filo (acciones_egipto.gd, _accion_en), salvo que salte.
## Lo que se pisa son objetos de las acciones (la caja del altar, que cambia de
## alto, y la de la losa, que cambia de ancho); el dibujo, el altar recortado del
## templo (el templo con su hueco, pie_piedra.gdshader hueco_modo) y la losa,
## los dos por detras del templo.

signal salida_entera

const PIE_PIEDRA := preload("res://scripts/game/egipto/pie_piedra.gdshader")
## La caja de la losa en las acciones.
const LOSA := "_losa_altar"
## Si esta, el roce de la piedra al moverse (falta: no hay sonido de piedra
## arrastrada en el proyecto).
const SONIDO := "res://assets/audio/piedra_arrastre.ogg"

## Lo que tarda en salir entera (s) y en volver a meterse desde entera (s,
## empezando parada y cogiendo velocidad). Con 10: bajando del altar andando y
## arrancando a correr en la terraza llega de sobra; andando, no llega (con 12
## llegaba justo: la rendija de menos de 52 px entre la punta y el capitel aun se
## pasa) y la losa le devuelve a la terraza.
@export var segundos_salir := 2.2
@export var segundos_recoger := 10.0
## Despues de que la losa le haya llevado, lo que el filo de la terraza no deja
## caer (s): si no, con la tecla aun pulsada, se iba de la terraza a la arena (981).
@export var segundos_sin_caida := 1.5
## Lo que tarda el altar en bajar al pisarlo (s).
@export var segundos_hundir := 0.5
@export var sonido_db := -14.0

var acciones: Node
var peregrino: Node2D
var datos: Dictionary
## Mientras no, el altar es piedra quieta (desde 2026-10-31 siempre activo).
var activo := true

var _altar: Object            # la caja del altar (Objeto de acciones_perfil.gd)
var _altar_alto0 := 0.0
var _losa: Object             # la de la losa
var _sprite_altar: Sprite2D
var _altar_y0 := 0.0
var _sprite_losa: Sprite2D
var _losa_tex_w := 0.0
var _escarabajo: Node2D
var _escarabajo_y0 := 0.0
var _sonido: AudioStreamPlayer2D
## Lo fuera que esta la losa (0 dentro, 1 entera) y a que velocidad vuelve.
var e := 0.0
var _vel := 0.0
## Lo hundido que esta el altar (0 arriba, 1 abajo del todo).
var _hundido := 0.0
var _encima := false
var _desde_llevado := INF
var _llevado_con_tecla := false

func _ready() -> void:
	# antes de las acciones (10): lo que se pisa ya movido cuando miran los
	# limites, y el peregrino llevado con ello; despues del peregrino (0)
	process_physics_priority = 5

## Monta lo que se ve y lo que se pisa. templo: el sprite del templo de las
## terrazas (su material lleva el hueco del altar); padre: donde van los sprites
## (el nodo del recorrido); escarabajo: la placa del frente del altar (baja con el).
func montar(templo: Sprite2D, padre: Node2D, escarabajo: Node2D) -> void:
	var suelo: float = acciones._suelo
	_altar = acciones._objeto("_" + String(datos["altar"]))
	_altar_alto0 = _altar.alto
	# EL ALTAR: su trozo de la textura del templo, por detras del templo (al bajar
	# se mete detras del peldano corrido de los obeliscos y de la terraza)
	var tex := templo.texture
	var k := tex.get_width() / float(datos["templo_ancho"])
	var a: Array = datos["altar_rects"]
	var r := Rect2()
	for i in a.size():
		var ri := Rect2(float(a[i][0]), float(a[i][1]), float(a[i][2]) - float(a[i][0]), float(a[i][3]) - float(a[i][1]))
		r = ri if i == 0 else r.merge(ri)
	_sprite_altar = Sprite2D.new()
	_sprite_altar.name = "Altar"
	_sprite_altar.texture = tex
	_sprite_altar.centered = false
	_sprite_altar.region_enabled = true
	_sprite_altar.region_rect = Rect2(r.position * k, r.size * k)
	_sprite_altar.scale = templo.scale
	_sprite_altar.position = templo.position + r.position * k * templo.scale
	# (solo la tapa, "solo_tapa": por delante del templo, baja sobre el cuerpo
	# del altar; el altar entero, por detras: se mete tras el peldano corrido)
	_sprite_altar.z_index = 0 if datos.get("solo_tapa", false) else -1
	_altar_y0 = _sprite_altar.position.y
	var uv := []
	var w := float(datos["templo_ancho"])
	var h := float(datos["templo_alto"])
	for q in a:
		uv.append(Vector4(float(q[0]) / w, float(q[1]) / h, float(q[2]) / w, float(q[3]) / h))
	while uv.size() < 2:
		uv.append(Vector4.ZERO)
	var mt := templo.material as ShaderMaterial
	var ma := mt.duplicate() as ShaderMaterial
	for m in [mt, ma]:
		m.set_shader_parameter("hueco_a", uv[0])
		m.set_shader_parameter("hueco_b", uv[1])
	mt.set_shader_parameter("hueco_modo", 1)
	ma.set_shader_parameter("hueco_modo", 2)
	_sprite_altar.material = ma
	padre.add_child(_sprite_altar)
	# (con solo la tapa, la placa del escarabajo no se mueve)
	_escarabajo = null if datos.get("solo_tapa", false) else escarabajo
	if _escarabajo:
		# (detras del templo, como el altar, y despues de el)
		_escarabajo.z_as_relative = false
		_escarabajo.z_index = padre.z_index + _sprite_altar.z_index
		_escarabajo_y0 = _escarabajo.position.y
	# LA LOSA: sale por la derecha del voladizo de la terraza; lo de dentro, sin
	# dibujar (el trozo que se ve es su punta: la textura de la derecha)
	var l: Dictionary = datos["losa"]
	_sprite_losa = Sprite2D.new()
	_sprite_losa.name = "LosaAltar"
	_sprite_losa.texture = load(String(l["tex"]))
	_sprite_losa.centered = false
	_sprite_losa.region_enabled = true
	var el: float = l["escala"]
	_sprite_losa.scale = Vector2(el, el)
	_losa_tex_w = _sprite_losa.texture.get_width()
	_sprite_losa.position.y = suelo - acciones.PLANTA - float(l["arriba"]) - float(l["cara_tex"]) * el
	_sprite_losa.z_index = -1
	var ml := ShaderMaterial.new()
	ml.shader = PIE_PIEDRA
	ml.set_shader_parameter("suelo_uv", 99.0)
	var th: float = _sprite_losa.texture.get_height()
	ml.set_shader_parameter("cajas", [Vector4(0.0, 1.0, float(l["cara_tex"]) / th, 0.25)] as Array[Vector4])
	ml.set_shader_parameter("n_cajas", 1)
	ml.set_shader_parameter("filo_uv", 6.0 / th)
	ml.set_shader_parameter("canto_suave", 10.0 / th)
	_sprite_losa.material = ml
	_sprite_losa.visible = false
	padre.add_child(_sprite_losa)
	_losa = acciones.nuevo_objeto(LOSA, float(l["x_salida"]), 0.0, float(l["arriba"]), float(l["abajo"]))
	if ResourceLoader.exists(SONIDO):
		_sonido = AudioStreamPlayer2D.new()
		_sonido.stream = load(SONIDO)
		_sonido.volume_db = -80.0
		_sonido.max_distance = 6000.0
		add_child(_sonido)
	_poner()

## Al acabar el video (el peregrino en lo alto): espera a que la losa haya
## salido entera (si ya salio mientras el video, nada).
func revelar() -> void:
	activo = true
	if e < 1.0:
		await salida_entera

## Donde mirar mientras sale la losa la primera vez (x, altura sobre la arena).
func vista() -> Vector2:
	var l: Dictionary = datos["losa"]
	return Vector2(float(l["x_salida"]) + float(l["largo"]) * 0.5, float(l["arriba"]))

func _physics_process(delta: float) -> void:
	if _altar == null:
		return
	_encima = activo and _en(_altar)
	var e0 := e
	var antes := _hundido
	if activo and _saltando_sobre_el_altar():
		# (saltando en el sitio: ni sube ni baja hasta que vuelva a pisar; si no,
		# el altar subia bajo sus pies en el aire y se los metia dentro)
		_vel = 0.0
	elif _encima:
		_vel = 0.0
		e = minf(1.0, e + delta / segundos_salir)
		_hundido = minf(1.0, _hundido + delta / segundos_hundir)
		if e >= 1.0 and e0 < 1.0:
			salida_entera.emit()
	elif e > 0.0:
		# (empieza parada y coge velocidad: e = 1 - (t/T)^2 desde entera)
		_vel -= 2.0 / (segundos_recoger * segundos_recoger) * delta
		e = maxf(0.0, e + _vel * delta)
		_hundido = minf(_hundido, e)
	else:
		_vel = 0.0
		_hundido = 0.0
	var l: Dictionary = datos["losa"]
	var dx := (e - e0) * float(l["largo"])
	# lo que esta de pie en la losa, con ella (en la terraza ya no: la losa se
	# mete por debajo)
	_desde_llevado += delta
	if _en(_losa, float(l["x_salida"]) + 1.0):
		_desde_llevado = 0.0
		peregrino.position.x += dx
		if dx < 0.0:
			_llevado_con_tecla = true
	if not Input.is_action_pressed("mover_derecha"):
		_llevado_con_tecla = false
	# (el filo de la terraza, mientras la losa esta fuera o recien la ha dejado, y
	# hasta soltar la tecla si le ha devuelto con ella pulsada)
	var sin_caida := e > 0.0 or _desde_llevado < segundos_sin_caida or _llevado_con_tecla
	acciones.borde_sin_caida = float(l["x_salida"]) if sin_caida else NAN
	# y lo que esta en el altar, con el (antes de mover la caja: se mira donde pisaba)
	var bajar := (_hundido - antes) * float(datos["hundir"])
	if bajar != 0.0 and _en(_altar):
		peregrino.position.y += bajar
	_poner()
	if _sonido:
		var moviendo := absf(e - e0) > 0.00001 or absf(_hundido - antes) > 0.00001
		var objetivo := sonido_db if moviendo else -80.0
		_sonido.volume_db = move_toward(_sonido.volume_db, objetivo, delta * 160.0)
		_sonido.position = Vector2(float(l["x_salida"]), peregrino.position.y)
		if moviendo and not _sonido.playing:
			_sonido.play()

## De pie (no en el aire) encima de esa caja; desde x_min.
func _en(o: Object, x_min := -INF) -> bool:
	if o == null or o.ancho <= 0.5 or peregrino.en_el_aire():
		return false
	var x := peregrino.position.x
	var pies: float = acciones._suelo - peregrino.position.y
	return x > maxf(o.x0, x_min) and x < o.x1() and absf(pies - o.alto) < 3.0

## En el aire, encima del altar (la x en el y por encima de el: el nodo se queda
## a la altura del despegue).
func _saltando_sobre_el_altar() -> bool:
	if not peregrino.en_el_aire():
		return false
	var x := peregrino.position.x
	var pies: float = acciones._suelo - peregrino.position.y
	return x > _altar.x0 and x < _altar.x1() and pies >= _altar.alto - 3.0

## Las cajas y los sprites a como esten e y _hundido.
func _poner() -> void:
	var l: Dictionary = datos["losa"]
	var hundir: float = datos["hundir"]
	_altar.alto = _altar_alto0 - _hundido * hundir
	_sprite_altar.position.y = _altar_y0 + _hundido * hundir
	if _escarabajo:
		_escarabajo.position.y = _escarabajo_y0 + _hundido * hundir
	var largo: float = l["largo"]
	var fuera := e * largo
	acciones.ancho_objeto(_losa, fuera)
	# lo que se ve: la punta (fuera) y lo oculto tras el voladizo (sin pasar
	# de la textura)
	var el: float = l["escala"]
	var oculto: float = l["oculto"]
	var ver := minf((fuera + oculto) / el, _losa_tex_w)
	_sprite_losa.visible = fuera > 0.5
	_sprite_losa.region_rect = Rect2(_losa_tex_w - ver, 0.0, ver, _sprite_losa.texture.get_height())
	_sprite_losa.position.x = float(l["x_salida"]) + fuera - ver * el
