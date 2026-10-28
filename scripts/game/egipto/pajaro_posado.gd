class_name PajaroPosado
extends Node2D
## UNA PALOMA EN EL RECORRIDO (2026-10-28; de lo que da vida a una ruina: las
## cosas pequenas que se mueven pueden ir en 3D por codigo). Una paloma facetada
## (cuerpo, cabeza, pico, cola y dos alas) en su SubViewport, con la luz de la
## escena (la de NavePosada). Posada, picotea y mueve la cabeza; si el peregrino
## se acerca, echa a volar lejos de el aleteando y se va. Cuando el peregrino
## esta lejos, al rato vuelve a estar posada.
##
## La posicion del nodo es donde apoya las patas.
##
## CADA UNA DISTINTA (2026-10-28, el usuario: "no pueden ser iguales todas en
## tamano y color y en forma de volar"): por su sitio (siempre la misma en el
## mismo sitio) sale su plumaje (PLUMAJES), su tamano y su complexion, lo
## confiada que es, como picotea y como vuela: aleteo mas rapido o mas lento,
## despegue empinado o tendido, a rafagas con planeos o seguido, y con su
## vaiven.

@export var sentido := 1.0          # hacia donde mira posada (1 derecha)
@export var largo := -1.0           # px (de juego) de la cola al pico; < 0: el suyo
@export var plumaje := -1           # cual de PLUMAJES; < 0: el suyo

## [cuerpo, alas, cabeza, cola]: la bravia gris de cabeza oscura, la blanca, la
## turca parda, la torcaz gris de pecho rosado, la pizarra oscura
const PLUMAJES := [
	[Color(0.7, 0.72, 0.77), Color(0.6, 0.62, 0.68), Color(0.42, 0.46, 0.52), Color(0.38, 0.4, 0.46)],
	[Color(0.92, 0.91, 0.88), Color(0.86, 0.85, 0.82), Color(0.94, 0.93, 0.9), Color(0.8, 0.79, 0.76)],
	[Color(0.78, 0.68, 0.58), Color(0.66, 0.56, 0.46), Color(0.74, 0.66, 0.58), Color(0.5, 0.42, 0.36)],
	[Color(0.74, 0.66, 0.68), Color(0.58, 0.6, 0.66), Color(0.6, 0.62, 0.68), Color(0.4, 0.42, 0.48)],
	[Color(0.46, 0.48, 0.54), Color(0.38, 0.4, 0.46), Color(0.3, 0.33, 0.38), Color(0.26, 0.28, 0.32)],
]

var peregrino: Node2D

const PX := 64.0                    # px del SubViewport por unidad 3D
var _vp: SubViewport
var _img: Sprite2D
var _raiz: Node3D
var _cabeza: Node3D
var _alas: Array[Node3D] = []
var _estado := "posada"
var _t := 0.0
var _t_estado := 0.0
var _vel := Vector2.ZERO
var _huida := 1.0
var _picar := 0.0
var _rng := RandomNumberGenerator.new()
var _casa := Vector2.ZERO
# lo suyo (ver CADA UNA DISTINTA)
var _colores: Array = []
var _gorda := 1.0                   # complexion (ancho del cuerpo)
var _espanto := 380.0               # px a los que se asusta
var _tarda := 0.2                   # lo que tarda en reaccionar (s)
var _picoteo := Vector2(1.2, 3.5)   # cada cuanto picotea (s)
var _aleteo := 52.0                 # rad/s del aleteo
var _empuje := Vector2(140.0, 260.0) # la arrancada: hacia delante, hacia arriba
var _tendida := 260.0               # lo que acelera alejandose (px/s^2)
var _rafaga := 0.0                  # s de planeo entre rafagas de aleteo (0: seguido)
var _vaiven := 0.0                  # px del vaiven arriba y abajo en vuelo

func _ready() -> void:
	# (por su sitio: la misma paloma cada vez en el mismo sitio)
	_rng.seed = hash(Vector2i(position))
	_casa = position
	_colores = PLUMAJES[plumaje if plumaje >= 0 else _rng.randi_range(0, PLUMAJES.size() - 1)]
	if largo < 0.0:
		largo = _rng.randf_range(44.0, 70.0)
	_gorda = _rng.randf_range(0.88, 1.18)
	_espanto = _rng.randf_range(280.0, 480.0)
	_tarda = _rng.randf_range(0.0, 0.45)
	var p := _rng.randf_range(0.8, 2.2)
	_picoteo = Vector2(p, p * 2.6)
	# las pequenas aletean mas deprisa
	_aleteo = lerpf(62.0, 40.0, inverse_lerp(44.0, 70.0, largo)) * _rng.randf_range(0.9, 1.1)
	_empuje = Vector2(_rng.randf_range(60.0, 220.0), _rng.randf_range(160.0, 340.0))
	_tendida = _rng.randf_range(160.0, 340.0)
	_rafaga = 0.0 if _rng.randf() < 0.4 else _rng.randf_range(0.25, 0.6)
	_vaiven = _rng.randf_range(0.0, 22.0)
	_rng.randomize()
	_vp = SubViewport.new()
	_vp.size = Vector2i(128, 128)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = NavePosada.SOMBRA
	_vp.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.basis = Basis.looking_at(NavePosada.SOL_DIR)
	sol.light_color = NavePosada.SOL
	sol.light_energy = NavePosada.SOL_E
	_vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _vp.size.y / PX
	cam.position = Vector3(0, 0.55, 5)
	_vp.add_child(cam)
	_raiz = Node3D.new()
	_vp.add_child(_raiz)
	_montar()
	_img = Sprite2D.new()
	_img.texture = _vp.get_texture()
	# (1 unidad = el largo de la paloma)
	var e := largo / PX
	_img.scale = Vector2(e, e)
	# las patas (y = 0 en 3D) caen 0,55 unidades por debajo del centro de la imagen
	_img.position = Vector2(0, -0.55 * PX * e)
	add_child(_img)
	_mirar(sentido)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 0.04
	return m

func _bola(r: float, alto: float, c: Color, pos: Vector3, esc := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = alto
	s.radial_segments = 7
	s.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = esc
	return mi

## La paloma, mirando a +x, de 1 unidad de largo, con las patas en y = 0.
func _montar() -> void:
	var cuerpo := _bola(0.24, 0.48, _colores[0], Vector3(0, 0.3, 0), Vector3(1.55, _gorda, _gorda))
	_raiz.add_child(cuerpo)
	_cabeza = Node3D.new()
	_cabeza.position = Vector3(0.3, 0.48, 0)
	_raiz.add_child(_cabeza)
	_cabeza.add_child(_bola(0.11, 0.22, _colores[2], Vector3(0.04, 0.04, 0)))
	var pico := CylinderMesh.new()
	pico.top_radius = 0.0
	pico.bottom_radius = 0.035
	pico.height = 0.12
	pico.radial_segments = 4
	var mp := MeshInstance3D.new()
	mp.mesh = pico
	mp.material_override = _mat(Color(0.35, 0.3, 0.28))
	mp.position = Vector3(0.19, 0.03, 0)
	mp.rotation = Vector3(0, 0, -PI / 2.0)
	_cabeza.add_child(mp)
	# la cola: una cuna plana hacia atras
	var cola := BoxMesh.new()
	cola.size = Vector3(0.32, 0.04, 0.16)
	var mc := MeshInstance3D.new()
	mc.mesh = cola
	mc.material_override = _mat(_colores[3])
	mc.position = Vector3(-0.42, 0.33, 0)
	mc.rotation = Vector3(0, 0, 0.25)
	_raiz.add_child(mc)
	# las alas: plegadas sobre el lomo; giran por el hombro (eje x) al volar
	for lado in [-1.0, 1.0]:
		var hombro := Node3D.new()
		hombro.position = Vector3(0.02, 0.42, 0.12 * lado)
		_raiz.add_child(hombro)
		var ala := BoxMesh.new()
		ala.size = Vector3(0.46, 0.035, 0.5)
		var ma := MeshInstance3D.new()
		ma.mesh = ala
		ma.material_override = _mat(_colores[1])
		ma.position = Vector3(-0.08, 0, 0.25 * lado)
		hombro.add_child(ma)
		hombro.set_meta("lado", lado)
		_alas.append(hombro)
	# las patas
	for dz in [-0.06, 0.06]:
		var pata := CylinderMesh.new()
		pata.top_radius = 0.012
		pata.bottom_radius = 0.012
		pata.height = 0.14
		pata.radial_segments = 4
		var mpt := MeshInstance3D.new()
		mpt.mesh = pata
		mpt.material_override = _mat(Color(0.7, 0.35, 0.33))
		mpt.position = Vector3(0.02, 0.07, dz)
		_raiz.add_child(mpt)
	_plegar(1.0)

## Las alas plegadas (1) o abiertas segun el aleteo (0).
func _plegar(k: float, aleteo := 0.0) -> void:
	for h in _alas:
		var lado: float = h.get_meta("lado")
		# plegada: pegada al cuerpo (casi vertical hacia abajo por el costado);
		# abierta: el aleteo, de arriba a abajo
		var abierta := sin(aleteo) * 1.1 - 0.1
		var plegada := 1.45
		h.rotation = Vector3(lerpf(abierta, plegada, k) * lado, 0, 0)

## Que mire hacia d (1 derecha), algo de tres cuartos para que se vean las alas.
func _mirar(d: float) -> void:
	_raiz.rotation = Vector3(0, (0.0 if d > 0.0 else PI) + 0.45 * d, 0)

func _process(delta: float) -> void:
	_t += delta
	_t_estado += delta
	match _estado:
		"posada":
			# picotea de vez en cuando y mueve la cabeza
			_picar -= delta
			if _picar <= 0.0:
				_picar = _rng.randf_range(_picoteo.x, _picoteo.y)
				_t_estado = 0.0
				# (alguna vez se da la vuelta)
				if _rng.randf() < 0.15:
					sentido = -sentido
					_mirar(sentido)
			var u := clampf(_t_estado / 0.35, 0.0, 1.0)
			_cabeza.rotation = Vector3(0, 0, -0.9 * sin(u * PI) + 0.08 * sin(_t * 3.0))
			_raiz.position.y = 0.0
			if peregrino and _cerca():
				_estado = "espantada"
				_t_estado = -_tarda * _rng.randf_range(0.7, 1.3)
				_huida = signf(position.x - peregrino.position.x)
				if _huida == 0.0:
					_huida = 1.0
		"espantada":
			if _t_estado < 0.0:
				return
			if _vel == Vector2.ZERO:
				_mirar(_huida)
				_vel = Vector2(_huida * _empuje.x, -_empuje.y)
			# sube y se aleja, cada vez mas deprisa y mas tendida; a rafagas de
			# aleteo con planeos (alas abiertas, cae un poco) o seguido
			var planea := _rafaga > 0.0 and _t_estado > 0.6 and fmod(_t_estado, 0.5 + _rafaga) > 0.5
			_vel += Vector2(_huida * _tendida, 60.0 if planea else 120.0) * delta
			_vel.y = maxf(_vel.y, -420.0)
			position += _vel * delta
			position.y += sin(_t_estado * 7.0) * _vaiven * delta * 7.0
			if planea:
				_plegar(0.0, 0.25)
			else:
				_plegar(0.0, _t * _aleteo)
			# (el cuerpo, inclinado segun suba o vaya tendida)
			_raiz.rotation.z = clampf(-_vel.y / 900.0, -0.1, 0.45)
			if _t_estado > 6.0:
				_estado = "fuera"
				visible = false
				_t_estado = 0.0
		"fuera":
			# vuelve a estar posada cuando el peregrino anda lejos
			if _t_estado > 25.0 and (peregrino == null or absf(peregrino.position.x - _casa.x) > 1800.0):
				position = _casa
				_vel = Vector2.ZERO
				_mirar(sentido)
				_plegar(1.0)
				_raiz.rotation.z = 0.0
				visible = true
				_estado = "posada"

func _cerca() -> bool:
	var d := peregrino.position - position
	return absf(d.x) < _espanto and d.y > -450.0 and d.y < 600.0
