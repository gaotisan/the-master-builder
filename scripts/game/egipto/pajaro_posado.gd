class_name PajaroPosado
extends Node2D
## UNA PALOMA EN EL RECORRIDO (2026-10-28; de lo que da vida a una ruina: las
## cosas pequenas que se mueven pueden ir en 3D por codigo). Posada, picotea y
## mueve la cabeza; si el peregrino se acerca, echa a volar lejos de el
## aleteando y se va. Cuando el peregrino esta lejos, al rato vuelve a estar
## posada.
##
## La posicion del nodo es donde apoya las patas.
##
## CADA UNA DISTINTA (2026-10-28, el usuario: "no pueden ser iguales todas en
## tamano y color y en forma de volar"): por su sitio (siempre la misma en el
## mismo sitio) sale su plumaje (PLUMAJES), su tamano y su complexion, lo
## confiada que es, como picotea y como vuela: aleteo mas rapido o mas lento,
## despegue empinado o tendido, a rafagas con planeos o seguido, y con su
## vaiven.
##
## REHECHA PARA LA BANDADA (2026-10-29; antes era un huevo con dos tablas por
## alas, lila, que no se leia como paloma):
##   - EL CUERPO, de paloma: anillos cosidos (cuerpo, cuello, cabeza, cola) con
##     sus caras planas, facetado como el peregrino; pecho abultado, cabeza
##     pequena, cuello con brillo verde y morado a los lados, cola con su banda
##     oscura en la punta, patas rojas.
##   - LAS ALAS, en dos trozos (brazo y mano) con las dos barras negras y las
##     primarias oscuras; plegadas van pegadas al costado, con la punta sobre la
##     cola; al volar, la mano se dobla al subir el ala y se estira al bajarla.
##   - QUE HACE: comiendo (la bandada), picotea en el suelo, anda a pasitos con
##     el cabeceo de la paloma (la cabeza adelante y quieta mientras el cuerpo
##     la alcanza), se para a mirar y se da la vuelta. Espantada, se pone alerta,
##     arranca con aletazos fuertes y se va, o va a POSARSE a un sitio (destino):
##     llega por arriba, planea con las alas en V, frena con el cuerpo de pie, la
##     cola abierta y las patas por delante, se posa y pliega las alas.
##   - TODAS EN UN SOLO SUBVIEWPORT (estudio_palomas.gd): cada una en su casilla.
##     Si nadie le da un estudio, se hace uno para ella sola.
##   - VISTA un poco desde arriba (VISTA): como las piedras, que ensenan su cara
##     de arriba; asi se ve algo del lomo y las alas al volar.

@export var sentido := 1.0          # hacia donde mira posada (1 derecha)
@export var largo := -1.0           # px (de juego) de la cola al pico; < 0: el suyo
@export var plumaje := -1           # cual de PLUMAJES; < 0: el suyo
## Comiendo en el suelo (la bandada): picotea mas a menudo y anda a pasitos
## dentro de zona (x de juego; ZERO: no se mueve de su sitio).
@export var comiendo := false
@export var zona := Vector2.ZERO
## Se espanta ella sola si se acerca el peregrino (la bandada lo apaga: alli se
## espantan todas a la vez).
@export var espanto_cerca := true
@export var aleteo_db := -15.0      # su aleteo al echar a volar sola

const ALETEO := preload("res://assets/audio/paloma_aleteo.ogg")

## La bravia gris (barras negras, cuello verde y morado), la blanca, la roja
## (parda de barras castanas y primarias claras, como las del video del
## usuario), la tizona oscura y la bravia clara.
const PLUMAJES := [
	{"cuerpo": Color(0.6, 0.63, 0.7), "alas": Color(0.67, 0.7, 0.76), "barras": Color(0.13, 0.13, 0.16),
	 "primarias": Color(0.34, 0.36, 0.42), "cabeza": Color(0.44, 0.47, 0.55), "cuello": Color(0.42, 0.46, 0.54),
	 "brillo": Color(0.3, 0.52, 0.44), "brillo2": Color(0.5, 0.42, 0.56), "cola": Color(0.52, 0.55, 0.62),
	 "punta": Color(0.15, 0.15, 0.18)},
	{"cuerpo": Color(0.93, 0.92, 0.89), "alas": Color(0.95, 0.94, 0.91), "barras": Color(0.9, 0.89, 0.86),
	 "primarias": Color(0.88, 0.87, 0.84), "cabeza": Color(0.94, 0.93, 0.9), "cuello": Color(0.92, 0.91, 0.88),
	 "brillo": Color(0.9, 0.9, 0.87), "brillo2": Color(0.92, 0.9, 0.88), "cola": Color(0.9, 0.89, 0.86),
	 "punta": Color(0.86, 0.85, 0.82)},
	{"cuerpo": Color(0.6, 0.42, 0.33), "alas": Color(0.68, 0.5, 0.39), "barras": Color(0.42, 0.24, 0.17),
	 "primarias": Color(0.84, 0.78, 0.7), "cabeza": Color(0.58, 0.41, 0.33), "cuello": Color(0.56, 0.4, 0.33),
	 "brillo": Color(0.6, 0.46, 0.4), "brillo2": Color(0.62, 0.42, 0.42), "cola": Color(0.66, 0.54, 0.45),
	 "punta": Color(0.5, 0.36, 0.28)},
	{"cuerpo": Color(0.36, 0.38, 0.43), "alas": Color(0.4, 0.42, 0.48), "barras": Color(0.16, 0.16, 0.19),
	 "primarias": Color(0.24, 0.25, 0.29), "cabeza": Color(0.29, 0.31, 0.36), "cuello": Color(0.3, 0.32, 0.37),
	 "brillo": Color(0.22, 0.42, 0.36), "brillo2": Color(0.4, 0.28, 0.46), "cola": Color(0.32, 0.34, 0.39),
	 "punta": Color(0.11, 0.11, 0.13)},
	{"cuerpo": Color(0.72, 0.74, 0.79), "alas": Color(0.78, 0.8, 0.85), "barras": Color(0.2, 0.2, 0.24),
	 "primarias": Color(0.44, 0.46, 0.52), "cabeza": Color(0.56, 0.59, 0.66), "cuello": Color(0.54, 0.58, 0.64),
	 "brillo": Color(0.38, 0.58, 0.5), "brillo2": Color(0.58, 0.44, 0.62), "cola": Color(0.62, 0.65, 0.72),
	 "punta": Color(0.18, 0.18, 0.21)},
]
## Cuantas de cada plumaje en una bandada (bravia, blanca, roja, tizona, clara).
const FRECUENCIA := [0.42, 0.12, 0.12, 0.17, 0.17]
const PATAS := Color(0.78, 0.4, 0.4)
const PICO := Color(0.3, 0.27, 0.27)
const VISTA := 0.3                  # rad: lo que se ve desde arriba
const TRES_CUARTOS := 0.35          # rad: lo que gira hacia la camara posada
const ALA := 0.58                   # largo del ala (unidades)
const BRAZO := 0.26                 # donde se dobla (la muneca)
## LAS PATAS, CASI TAPADAS (2026-10-29, el usuario: "las palomas reales posadas no
## se les ven las patas"): el cuerpo va BAJA mas abajo de lo que dan las patas
## enteras (asoma solo un poco de pata), y la que descansa en una repisa se
## sienta sobre la barriga (SENTADA mas) y no se le ven.
const BAJA := 0.085
const SENTADA := 0.06

var peregrino: Node2D
var estudio: EstudioPalomas

var _img: Sprite2D
var _ancla: Node3D
var _raiz: Node3D
var _cuello: Node3D
var _cabeza: Node3D
var _cola: Node3D
var _alas: Array[Node3D] = []
var _patas: Array[Node3D] = []
var _cuello_base := Vector3.ZERO
var _estado := "posada"
var _t := 0.0
var _t_estado := 0.0
var _vel := Vector2.ZERO
var _huida := 1.0
var _destino := Vector2.INF         # INF: se va; si no, se posa ahi
var _rng := RandomNumberGenerator.new()
var _casa := Vector2.ZERO
var _yaw := 0.0
var _abierta := 0.0                 # alas: 0 plegadas, 1 abiertas
var _fase := 0.0                    # del aleteo
var _sonar := true
# lo que hace posada: "mirar", "picar", "andar"
var _accion := "mirar"
var _t_accion := 0.0
var _dura := 1.0
var _picotazos := 0
var _paso := 0.0                    # fase de los pasitos
var _sentada := 0.0                 # 0 de pie, 1 sentada sobre la barriga
var _cabeza_obj := Vector2.ZERO     # giro y ladeo de la cabeza al mirar
var _cabeza_rot := Vector2.ZERO
# lo suyo (ver CADA UNA DISTINTA)
var _colores: Dictionary = {}
var _gorda := 1.0                   # complexion (ancho del cuerpo)
var _espanto := 380.0               # px a los que se asusta
var _tarda := 0.2                   # lo que tarda en reaccionar (s)
var _picoteo := Vector2(1.2, 3.5)   # cada cuanto picotea (s)
var _aleteo := 52.0                 # rad/s del aleteo
var _empuje := Vector2(140.0, 260.0) # la arrancada: hacia delante, hacia arriba
var _tendida := 260.0               # lo que acelera alejandose (px/s^2)
var _rafaga := 0.0                  # s de planeo entre rafagas de aleteo (0: seguido)
var _vaiven := 0.0                  # px del vaiven arriba y abajo en vuelo
var _andar := 40.0                  # px/s andando

func _ready() -> void:
	# (por su sitio: la misma paloma cada vez en el mismo sitio)
	_rng.seed = hash(Vector2i(position))
	_casa = position
	_colores = PLUMAJES[plumaje if plumaje >= 0 else _rng.randi_range(0, PLUMAJES.size() - 1)]
	if largo < 0.0:
		largo = _rng.randf_range(44.0, 70.0)
	_gorda = _rng.randf_range(0.9, 1.15)
	_espanto = _rng.randf_range(280.0, 480.0)
	_tarda = _rng.randf_range(0.0, 0.45)
	var p := _rng.randf_range(0.8, 2.2)
	_picoteo = Vector2(p, p * 2.6)
	# las pequenas aletean mas deprisa
	_aleteo = lerpf(46.0, 32.0, inverse_lerp(44.0, 70.0, largo)) * _rng.randf_range(0.9, 1.1)
	_empuje = Vector2(_rng.randf_range(60.0, 220.0), _rng.randf_range(200.0, 360.0))
	_tendida = _rng.randf_range(160.0, 340.0)
	_rafaga = 0.0 if _rng.randf() < 0.4 else _rng.randf_range(0.25, 0.6)
	_vaiven = _rng.randf_range(0.0, 22.0)
	_andar = largo * _rng.randf_range(0.6, 0.9)
	_rng.randomize()
	if estudio == null:
		estudio = EstudioPalomas.new()
		add_child(estudio)
	_ancla = Node3D.new()
	_raiz = Node3D.new()
	_raiz.rotation.x = VISTA
	_ancla.add_child(_raiz)
	_montar()
	var region := estudio.casilla(_ancla)
	_img = Sprite2D.new()
	_img.texture = estudio.textura()
	_img.region_enabled = true
	_img.region_rect = region
	# (1 unidad = el largo de la paloma)
	var e := largo / EstudioPalomas.PX
	_img.scale = Vector2(e, e)
	# las patas caen PIES unidades por debajo del centro de la casilla
	_img.position = Vector2(0, -EstudioPalomas.PIES * EstudioPalomas.PX * e)
	add_child(_img)
	_yaw = _yaw_de(sentido)
	_nueva_accion()
	_posar(0.0)

## ---- el modelo -------------------------------------------------------------------

func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Un triangulo de cara plana, con la normal hacia fuera (desde centro) y la
## cara de delante fuera (Godot: en el sentido de las agujas del reloj; con las
## dos caras pintadas, la de detras le da la vuelta a la normal).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, centro: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centro) > 0.0:
		var t := b
		b = c
		c = t
	else:
		n = -n
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## Anillos cosidos: cada anillo [centro (x, y), alto, ancho, color, color de
## los costados (o null)]. El anillo es perpendicular a la linea de los centros.
func _anillos(anillos: Array, k := 8) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := anillos.size()
	var pts: Array = []
	var centros: Array[Vector3] = []
	for i in n:
		var a: Array = anillos[i]
		var c := Vector3(a[0].x, a[0].y, 0.0)
		var sig: Vector2 = anillos[mini(i + 1, n - 1)][0]
		var ant: Vector2 = anillos[maxi(i - 1, 0)][0]
		var t := (sig - ant).normalized()
		var arriba := Vector3(-t.y, t.x, 0.0)
		var anillo: Array[Vector3] = []
		for j in k:
			var ang := TAU * (j + 0.5) / k
			anillo.append(c + arriba * float(a[1]) * sin(ang) + Vector3(0, 0, float(a[2]) * _gorda * cos(ang)))
		pts.append(anillo)
		centros.append(c)
	for i in n - 1:
		var a: Array = anillos[i]
		var centro := (centros[i] + centros[i + 1]) * 0.5
		for j in k:
			var j2 := (j + 1) % k
			# (los costados: los que miran a los lados, no arriba ni abajo)
			var lado := absf(cos(TAU * (j + 1.0) / k)) > 0.6
			var col: Color = a[4] if lado and a.size() > 4 and a[4] != null else a[3]
			_tri(st, pts[i][j], pts[i + 1][j], pts[i + 1][j2], col, centro)
			_tri(st, pts[i][j], pts[i + 1][j2], pts[i][j2], col, centro)
	# las tapas
	for e in [[0, anillos[0][3]], [n - 1, anillos[n - 1][3]]]:
		var i: int = e[0]
		var punta := centros[i] + (centros[i] - centros[1 if i == 0 else n - 2]).normalized() * 0.01
		for j in k:
			_tri(st, pts[i][j], pts[i][(j + 1) % k], punta, e[1], centros[1 if i == 0 else n - 2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat()
	return mi

## La paloma, mirando a +x, de 1 unidad de largo, con las patas en y = 0.
func _montar() -> void:
	var c := _colores
	_raiz.add_child(_anillos([
		[Vector2(-0.27, 0.272), 0.035, 0.055, c["cuerpo"]],
		[Vector2(-0.19, 0.276), 0.08, 0.09, c["cuerpo"]],
		[Vector2(-0.08, 0.282), 0.125, 0.125, c["cuerpo"]],
		[Vector2(0.03, 0.29), 0.15, 0.14, c["cuerpo"]],
		[Vector2(0.13, 0.31), 0.145, 0.13, c["cuerpo"]],
		[Vector2(0.2, 0.345), 0.105, 0.1, c["cuello"], c["brillo2"]],
		[Vector2(0.235, 0.39), 0.06, 0.07, c["cuello"]],
	]))
	# el cuello (se dobla al picotear) y la cabeza
	_cuello_base = Vector3(0.19, 0.36, 0.0)
	_cuello = Node3D.new()
	_cuello.position = _cuello_base
	_raiz.add_child(_cuello)
	_cuello.add_child(_anillos([
		[Vector2(0.0, -0.03), 0.085, 0.085, c["cuello"], c["brillo"]],
		[Vector2(0.03, 0.05), 0.066, 0.066, c["cuello"], c["brillo"]],
		[Vector2(0.05, 0.11), 0.05, 0.05, c["cuello"], c["brillo2"]],
		[Vector2(0.055, 0.15), 0.04, 0.04, c["cabeza"]],
	], 6))
	_cabeza = Node3D.new()
	_cabeza.position = Vector3(0.055, 0.16, 0.0)
	_cuello.add_child(_cabeza)
	_cabeza.add_child(_anillos([
		[Vector2(-0.06, 0.0), 0.02, 0.02, c["cabeza"]],
		[Vector2(-0.035, 0.004), 0.05, 0.044, c["cabeza"]],
		[Vector2(0.005, 0.006), 0.058, 0.048, c["cabeza"]],
		[Vector2(0.045, 0.0), 0.04, 0.034, c["cabeza"]],
		[Vector2(0.068, -0.008), 0.016, 0.016, c["cabeza"]],
	], 6))
	# el pico (con la carnosidad blanca de arriba, la cera)
	_cabeza.add_child(_anillos([
		[Vector2(0.06, -0.006), 0.016, 0.014, Color(0.86, 0.84, 0.8)],
		[Vector2(0.085, -0.012), 0.011, 0.01, PICO],
		[Vector2(0.125, -0.022), 0.003, 0.003, PICO],
	], 5))
	# el ojo, naranja con la pupila: un puntito a cada lado
	for lado in [-1.0, 1.0]:
		var ojo := _anillos([
			[Vector2(0.018, 0.016), 0.0, 0.0, Color(0.9, 0.5, 0.15)],
			[Vector2(0.026, 0.016), 0.012, 0.012, Color(0.9, 0.5, 0.15)],
			[Vector2(0.034, 0.016), 0.0, 0.0, Color(0.9, 0.5, 0.15)],
		], 5)
		ojo.position = Vector3(0, 0, 0.04 * lado)
		_cabeza.add_child(ojo)
	# la cola: plana, se abre en abanico al frenar
	_cola = Node3D.new()
	_cola.position = Vector3(-0.22, 0.275, 0.0)
	_cola.rotation.z = 0.08
	_raiz.add_child(_cola)
	_cola.add_child(_anillos([
		[Vector2(0.0, 0.0), 0.035, 0.07, c["cola"]],
		[Vector2(-0.12, -0.008), 0.02, 0.08, c["cola"]],
		[Vector2(-0.22, -0.016), 0.012, 0.088, c["punta"]],
		[Vector2(-0.3, -0.02), 0.006, 0.085, c["punta"]],
	], 6))
	# las alas
	for lado in [-1.0, 1.0]:
		var hombro := Node3D.new()
		hombro.position = Vector3(0.13, 0.385, 0.118 * lado)
		_raiz.add_child(hombro)
		hombro.add_child(_ala(0.0, BRAZO, lado))
		var mano := Node3D.new()
		mano.position = Vector3(0, 0, BRAZO * lado)
		hombro.add_child(mano)
		var m := _ala(BRAZO, ALA, lado)
		m.position = Vector3(0, 0, -BRAZO * lado)
		mano.add_child(m)
		hombro.set_meta("lado", lado)
		hombro.set_meta("mano", mano)
		_alas.append(hombro)
	# las patas
	for dz in [-0.045, 0.045]:
		var cadera := Node3D.new()
		cadera.position = Vector3(0.03, 0.15, dz)
		_raiz.add_child(cadera)
		var pata := _anillos([
			[Vector2(0.0, 0.0), 0.016, 0.016, PATAS],
			[Vector2(0.0, -0.035), 0.013, 0.013, PATAS],
			[Vector2(0.004, -0.063), 0.012, 0.012, PATAS],
		], 4)
		cadera.add_child(pata)
		var pie := _anillos([
			[Vector2(-0.02, -0.066), 0.005, 0.012, PATAS],
			[Vector2(0.035, -0.066), 0.005, 0.016, PATAS],
		], 4)
		cadera.add_child(pie)
		_patas.append(cadera)

## Un trozo del ala (de s0 a s1 de largo, hacia el lado), plano: el borde de
## ataque en x = 0 y la cuerda hacia atras (-x). Las dos barras oscuras en el
## brazo, las primarias (y mas oscuras sus puntas) en la mano.
func _ala(s0: float, s1: float, lado: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := _colores
	var pasos := maxi(int((s1 - s0) / 0.03), 2)
	var cuerdas := 4
	for i in pasos:
		var sa := lerpf(s0, s1, float(i) / pasos)
		var sb := lerpf(s0, s1, float(i + 1) / pasos)
		for j in cuerdas:
			var ka := float(j) / cuerdas
			var kb := float(j + 1) / cuerdas
			var p00 := _punto_ala(sa, ka, lado)
			var p01 := _punto_ala(sa, kb, lado)
			var p10 := _punto_ala(sb, ka, lado)
			var p11 := _punto_ala(sb, kb, lado)
			var col := _color_ala((sa + sb) * 0.5 / ALA, (ka + kb) * 0.5, c)
			var centro := (p00 + p11) * 0.5 + Vector3(0, -1, 0)
			_tri(st, p00, p10, p11, col, centro)
			_tri(st, p00, p11, p01, col, centro)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat()
	return mi

func _cuerda(s: float) -> float:
	var u := s / ALA
	if u < 0.3:
		return lerpf(0.17, 0.2, u / 0.3)
	if u < 0.5:
		return lerpf(0.2, 0.18, (u - 0.3) / 0.2)
	return lerpf(0.18, 0.035, pow((u - 0.5) / 0.5, 1.3))

func _punto_ala(s: float, k: float, lado: float) -> Vector3:
	var ataque := 0.02 * sin(PI * s / ALA)
	return Vector3(ataque - _cuerda(s) * k, 0.0, s * lado)

func _color_ala(u: float, k: float, c: Dictionary) -> Color:
	if u > 0.62:
		return c["primarias"].darkened(0.35 if u > 0.86 else 0.0)
	if k > 0.35 and ((u > 0.3 and u < 0.37) or (u > 0.43 and u < 0.5)):
		return c["barras"]
	return c["alas"]

## ---- las poses -------------------------------------------------------------------

## El giro hacia d (1 derecha), algo de tres cuartos para que se vea el costado.
func _yaw_de(d: float) -> float:
	return (0.0 if d > 0.0 else PI) - TRES_CUARTOS * d

## Las alas: abierta (0 plegadas, 1 abiertas), su elevacion, la de la mano
## respecto al brazo y lo que se recoge la mano hacia atras.
func _poner_alas(abierta: float, elev: float, mano: float, recoge: float) -> void:
	for h in _alas:
		var lado: float = h.get_meta("lado")
		# plegada: de canto pegada al costado, con la punta hacia atras y algo
		# hacia dentro y abajo (sobre la cola)
		var plegada := Basis.from_euler(Vector3(0.12 * lado, -(PI / 2.0 + 0.1) * lado, PI / 2.0))
		var vuelo := Basis.from_euler(Vector3(-lado * elev, -lado * recoge * 0.35, 0.0))
		h.basis = Basis(plegada.get_rotation_quaternion().slerp(vuelo.get_rotation_quaternion(), abierta))
		var m: Node3D = h.get_meta("mano")
		m.basis = Basis.from_euler(Vector3(-lado * mano * abierta, -lado * recoge * abierta, 0.0))

## El aleteo en la fase f (fuerte: 0..1 lo amplio que va, al arrancar y al frenar).
func _aletear(f: float, fuerte := 0.0) -> void:
	var a := lerpf(0.95, 1.25, fuerte)
	_poner_alas(_abierta, a * sin(f) + 0.2, 0.6 * sin(f - 0.9), 0.75 * maxf(0.0, cos(f)))

func _planear() -> void:
	# (las alas en V)
	_poner_alas(_abierta, 0.32, -0.12, 0.1)

## Posada: picotazo p (0..1), el cabeceo al andar (dx) y lo alerta que esta.
func _posar(p: float, dx := 0.0, alerta := 0.0) -> void:
	_cuello.position = _cuello_base + Vector3(0.05 * p + dx, -0.09 * p + 0.02 * alerta, 0.0)
	_cuello.rotation = Vector3(0, 0, -1.15 * p + 0.15 * alerta)
	_cabeza.rotation = Vector3(0, _cabeza_rot.x * (1.0 - p), -0.55 * p + _cabeza_rot.y * (1.0 - p))
	_raiz.rotation.z = -0.22 * p - 0.05 * alerta
	_cola.scale = Vector3.ONE

## ---- lo que hace -----------------------------------------------------------------

## Que se espante: dentro de retraso s echa a volar; destino INF, se va lejos; si
## no, se posa ahi. sonar: su aleteo (en la bandada suena la de todas).
func asustar(retraso: float, destino := Vector2.INF, sonar := true) -> void:
	if _estado != "posada":
		return
	_estado = "espantada"
	_t_estado = -retraso
	_destino = destino
	_sonar = sonar
	if destino != Vector2.INF:
		_huida = signf(destino.x - position.x)
	elif peregrino:
		_huida = signf(position.x - peregrino.position.x)
	if _huida == 0.0:
		_huida = 1.0

func volando() -> bool:
	return _estado == "espantada" or _estado == "volando"

func _nueva_accion() -> void:
	_t_accion = 0.0
	var r := _rng.randf()
	if comiendo:
		# comiendo: sobre todo picotea; a ratos anda o mira
		if r < 0.55:
			_accion = "picar"
			_picotazos = _rng.randi_range(1, 4)
			_dura = _picotazos * 0.3
		elif r < 0.85 and zona != Vector2.ZERO:
			_accion = "andar"
			_dura = _rng.randf_range(0.5, 1.8)
			# (hacia dentro de su zona si esta en el borde)
			if position.x < zona.x + 30.0:
				sentido = 1.0
			elif position.x > zona.y - 30.0:
				sentido = -1.0
			elif _rng.randf() < 0.35:
				sentido = -sentido
		else:
			_accion = "mirar"
			_dura = _rng.randf_range(0.4, 1.4)
	else:
		if r < 0.3:
			_accion = "picar"
			_picotazos = 1
			_dura = 0.3
		else:
			_accion = "mirar"
			_dura = _rng.randf_range(_picoteo.x, _picoteo.y)
		# (alguna vez se da la vuelta)
		if _rng.randf() < 0.15:
			sentido = -sentido
	_cabeza_obj = Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.15, 0.2))

func _process(delta: float) -> void:
	_t += delta
	_t_estado += delta
	match _estado:
		"posada":
			_en_posada(delta)
		"espantada":
			_en_espantada(delta)
		"volando":
			_en_volando(delta)
		"fuera":
			# vuelve a estar posada cuando el peregrino anda lejos
			if _t_estado > 25.0 and (peregrino == null or absf(peregrino.position.x - _casa.x) > 1800.0):
				position = _casa
				_vel = Vector2.ZERO
				_abierta = 0.0
				_raiz.rotation.z = 0.0
				_poner_alas(0.0, 0.0, 0.0, 0.0)
				_yaw = _yaw_de(sentido)
				visible = true
				_estado = "posada"
	_raiz.rotation.y = lerp_angle(_raiz.rotation.y, _yaw, minf(1.0, delta * 14.0))

func _en_posada(delta: float) -> void:
	_t_accion += delta
	_yaw = _yaw_de(sentido)
	_cabeza_rot = _cabeza_rot.lerp(_cabeza_obj, minf(1.0, delta * 8.0))
	# (pliega las alas si acaba de posarse)
	_abierta = maxf(0.0, _abierta - delta * 3.5)
	_poner_alas(_abierta, 0.4 * _abierta, 0.0, 0.0)
	var p := 0.0
	var dx := 0.0
	match _accion:
		"picar":
			var u := fmod(_t_accion, 0.3) / 0.3
			p = sin(clampf(u / 0.7, 0.0, 1.0) * PI)
		"andar":
			# el cabeceo: la cabeza va adelante de golpe y se queda quieta
			# mientras el cuerpo la alcanza
			_paso += delta / 0.32
			var u := fmod(_paso, 1.0)
			dx = (lerpf(-0.045, 0.045, u / 0.3) if u < 0.3 else lerpf(0.045, -0.045, (u - 0.3) / 0.7))
			position.x += sentido * _andar * delta
			if zona != Vector2.ZERO:
				position.x = clampf(position.x, zona.x, zona.y)
			for i in _patas.size():
				_patas[i].rotation.z = 0.45 * sin(_paso * PI + i * PI)
	if _accion != "andar":
		for pt in _patas:
			pt.rotation.z = 0.0
	# (la que no come, cuando se queda mirando un rato, se sienta)
	var sentarse := not comiendo and _accion == "mirar" and _t_accion > 0.6
	_sentada = move_toward(_sentada, 1.0 if sentarse else 0.0, delta * 2.5)
	var bote := 0.012 * absf(sin(_paso * PI)) if _accion == "andar" else 0.0
	_raiz.position.y = -BAJA - SENTADA * _sentada + bote
	for pt in _patas:
		pt.visible = _sentada < 0.4
	_posar(p, dx)
	if _t_accion >= _dura:
		_nueva_accion()
	if espanto_cerca and peregrino and _cerca():
		asustar(_tarda * _rng.randf_range(0.7, 1.3))

func _en_espantada(delta: float) -> void:
	if _t_estado < 0.0:
		# alerta: la cabeza arriba, quieta
		_cabeza_obj = Vector2.ZERO
		_cabeza_rot = _cabeza_rot.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
		_sentada = move_toward(_sentada, 0.0, delta * 6.0)
		_raiz.position.y = -BAJA - SENTADA * _sentada
		for pt in _patas:
			pt.visible = _sentada < 0.4
		_posar(0.0, 0.0, 1.0)
		return
	if _vel == Vector2.ZERO:
		# la arrancada: un saltito y aletazos fuertes, empinada
		sentido = _huida
		# (de perfil al volar, apenas de tres cuartos)
		_yaw = (0.0 if _huida > 0.0 else PI) - 0.15 * _huida
		_vel = Vector2(_huida * _empuje.x, -_empuje.y)
		_posar(0.0)
		_sentada = 0.0
		_raiz.position.y = -BAJA
		for pt in _patas:
			pt.visible = true
		if _sonar:
			_sonido(ALETEO, aleteo_db, _rng.randf_range(0.9, 1.15))
		if _destino != Vector2.INF:
			_estado = "volando"
			_t_estado = 0.0
			return
	_abierta = minf(1.0, _abierta + delta * 9.0)
	for pt in _patas:
		pt.rotation.z = lerpf(pt.rotation.z, -1.3, minf(1.0, delta * 8.0))
	# sube y se aleja, cada vez mas deprisa y mas tendida; a rafagas de
	# aleteo con planeos (alas abiertas, cae un poco) o seguido
	# (2026-10-29: primero sube empinada hasta pasar por encima del templo, y
	# luego se tiende; tendida desde el principio cruzaba por delante de los
	# muros, "pegote")
	var planea := _rafaga > 0.0 and _t_estado > 1.8 and fmod(_t_estado, 0.5 + _rafaga) > 0.5
	var sube := _t_estado < 1.8
	_vel += Vector2(_huida * _tendida * (0.45 if sube else 1.0), -90.0 if sube else (60.0 if planea else 120.0)) * delta
	_vel.y = maxf(_vel.y, -460.0)
	_vel.x = clampf(_vel.x, -420.0, 420.0)
	position += _vel * delta
	position.y += sin(_t_estado * 7.0) * _vaiven * delta * 7.0
	_fase += delta * _aleteo * (1.25 if _t_estado < 0.5 else 1.0)
	if planea:
		_planear()
	else:
		_aletear(_fase, clampf(1.0 - _t_estado / 0.6, 0.0, 1.0))
	# (el cuerpo, inclinado segun suba o vaya tendida)
	_raiz.rotation.z = clampf(-_vel.y / 900.0, -0.1, 0.45)
	if _t_estado > 8.0 or (_t_estado > 1.0 and _fuera_de_pantalla()):
		_estado = "fuera"
		visible = false
		_t_estado = 0.0

## Volando a posarse en _destino: sube, va por arriba, baja planeando y frena.
func _en_volando(delta: float) -> void:
	_abierta = minf(1.0, _abierta + delta * 9.0)
	var falta := _destino - position
	var dist := falta.length()
	# (se acerca por arriba: apunta por encima del sitio, menos cuanto mas cerca)
	var apunta := _destino + Vector2(0.0, -clampf(dist * 0.35, 0.0, 140.0))
	var dif := apunta - position
	var vmax := lerpf(50.0, 400.0, clampf(dist / 420.0, 0.0, 1.0))
	var deseada := dif.normalized() * vmax
	var giro := 900.0 if _t_estado > 0.25 else 300.0
	_vel += (deseada - _vel).limit_length(giro * delta)
	position += _vel * delta
	if absf(_vel.x) > 30.0:
		sentido = signf(_vel.x)
		_yaw = (0.0 if sentido > 0.0 else PI) - 0.15 * sentido
	var frena := dist < 130.0
	_fase += delta * _aleteo * (1.3 if frena or _t_estado < 0.5 else 1.0)
	if frena:
		# de pie en el aire, la cola en abanico, las patas por delante
		_aletear(_fase, 1.0)
		_raiz.rotation.z = lerpf(_raiz.rotation.z, 0.75, minf(1.0, delta * 6.0))
		_cola.scale = Vector3(1.0, 1.0, 1.7)
		for pt in _patas:
			pt.rotation.z = lerpf(pt.rotation.z, 0.5, minf(1.0, delta * 8.0))
	else:
		if _vel.y > 40.0 and _t_estado > 0.6:
			_planear()
		else:
			_aletear(_fase, clampf(1.0 - _t_estado / 0.6, 0.0, 1.0))
		_raiz.rotation.z = lerpf(_raiz.rotation.z, clampf(-_vel.y / 900.0, -0.15, 0.45), minf(1.0, delta * 6.0))
		for pt in _patas:
			pt.rotation.z = lerpf(pt.rotation.z, -1.3, minf(1.0, delta * 8.0))
	if dist < 7.0 or (dist < 20.0 and _t_estado > 6.0):
		# se posa
		position = _destino
		_casa = _destino
		_vel = Vector2.ZERO
		_raiz.rotation.z = 0.0
		comiendo = false
		zona = Vector2.ZERO
		espanto_cerca = true
		_estado = "posada"
		_t_estado = 0.0
		_accion = "mirar"
		_t_accion = 0.0
		_dura = _rng.randf_range(0.8, 1.6)
		_sonido(ALETEO, aleteo_db - 9.0, _rng.randf_range(1.0, 1.2))

func _cerca() -> bool:
	var d := peregrino.position - position
	return absf(d.x) < _espanto and d.y > -450.0 and d.y < 600.0

func _fuera_de_pantalla() -> bool:
	var p := get_global_transform_with_canvas().origin
	var r := get_viewport_rect().grow(120.0)
	return not r.has_point(p)

func _sonido(s: AudioStream, db: float, tono: float) -> void:
	var a := AudioStreamPlayer2D.new()
	a.stream = s
	a.volume_db = db
	a.pitch_scale = tono
	a.max_distance = 3000.0
	get_parent().add_child(a)
	a.global_position = global_position
	a.finished.connect(a.queue_free)
	a.play()
