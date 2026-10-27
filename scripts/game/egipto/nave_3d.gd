class_name Nave3D
extends Node3D
## LA NAVE (Acto I de Egipto, 2026-10-27): un guino, al estilo de las de Planet
## of Lana, hecha en 3D low poly facetado copiando la imagen del usuario
## (raw/master_builder/referencias/egipto_nave/nave.png, de lado sobre verde):
## casco de vaina marfil cuyo lomo sigue hacia atras en una aleta en punta, la
## cabina oscura delante con una linea cian debajo, la franja oscura del costado,
## el motor redondo atras con su anillo cian y cuatro patas que se recogen.
## (Lo pequeno que se mueve puede ir por codigo en 3D; piedra, plantas y
## paisaje salen de las imagenes.)
##
## Los perfiles de arriba y de abajo estan medidos en la imagen (el morro en
## x = 1,05, la punta de la aleta en x = -0,86). Morro a +X, arriba +Y; de
## lado se ve desde +Z.
##   patas: 1 fuera (posada), 0 recogidas.  luz: brillo del cian (0 a 1).

# (medidos en la imagen, ya con su luz: marfil 187,175,160 y grafito 47,53,56)
const MARFIL := Color(0.8, 0.76, 0.69)
const GRAFITO := Color(0.16, 0.175, 0.19)
const CRISTAL := Color(0.24, 0.25, 0.27)
const CIAN := Color(0.35, 0.9, 1.0)
# PINTADA (2026-10-27, "que no parezca un pegote"): como el resto del fondo, en
# dos tonos (cara al sol / cara en sombra, sin degradado ni brillos) y con la
# paleta de la escena: el marfil hacia la piedra clara, el grafito hacia el azul
# de las sombras lejanas y el cian apagado, una luz en la bruma.
const MARFIL_P := Color(0.86, 0.79, 0.69)
const GRAFITO_P := Color(0.17, 0.2, 0.25)
const CRISTAL_P := Color(0.2, 0.24, 0.3)
const CIAN_P := Color(0.6, 0.85, 0.88)

@export var pintada := true

# perfil del casco: [x, arriba, abajo]
const CASCO := [[-0.45, 0.49, -0.10], [-0.3, 0.499, -0.16], [-0.15, 0.5, -0.2], [0.0, 0.49, -0.246],
		[0.15, 0.47, -0.268], [0.3, 0.435, -0.27], [0.45, 0.378, -0.268], [0.6, 0.312, -0.24],
		[0.75, 0.243, -0.215], [0.87, 0.18, -0.18], [0.96, 0.12, -0.13], [1.02, 0.06, -0.07], [1.05, 0.0, 0.0]]
# la aleta: [x, arriba, abajo, medio ancho]
const ALETA := [[-0.4, 0.492, 0.3, 0.2], [-0.53, 0.482, 0.331, 0.15], [-0.62, 0.47, 0.354, 0.11],
		[-0.7, 0.455, 0.375, 0.07], [-0.78, 0.437, 0.39, 0.04], [-0.86, 0.412, 0.405, 0.01]]

@export var patas := 1.0:
	set(v):
		patas = clampf(v, 0.0, 1.0)
		_colocar_patas()
@export var luz := 0.6:
	set(v):
		luz = v
		if _mat_cian:
			_mat_cian.emission_energy_multiplier = (0.3 + 0.9 * luz) if pintada else (0.6 + 2.4 * luz)

var _mat_marfil: StandardMaterial3D
var _mat_grafito: StandardMaterial3D
var _mat_cristal: StandardMaterial3D
var _mat_cian: StandardMaterial3D
var _patas: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7
	_mat_marfil = _material(MARFIL_P if pintada else MARFIL, 0.8)
	_mat_grafito = _material(GRAFITO_P if pintada else GRAFITO, 0.6)
	_mat_cristal = _material(CRISTAL_P if pintada else CRISTAL, 0.25)
	if not pintada:
		_mat_cristal.metallic_specular = 0.8
	var cian := CIAN_P if pintada else CIAN
	_mat_cian = _material(cian, 0.5)
	_mat_cian.emission_enabled = true
	_mat_cian.emission = cian
	luz = luz
	_casco()
	_aleta()
	_motor()
	_pata(Vector3(-0.2, -0.17, 0.12), Vector2(-0.11, -0.26))
	_pata(Vector3(-0.2, -0.17, -0.12), Vector2(-0.11, -0.26))
	_pata(Vector3(0.52, -0.22, 0.12), Vector2(0.12, -0.21))
	_pata(Vector3(0.52, -0.22, -0.12), Vector2(0.12, -0.21))
	_colocar_patas()

func _material(c: Color, aspereza: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = aspereza
	if pintada:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 0.04             # (el corte entre sol y sombra, nitido)
	return m

## Interpola una tabla de filas [x, ...] en x (la columna k).
static func _tabla(t: Array, x: float, k: int) -> float:
	for i in t.size() - 1:
		var a: Array = t[i]
		var b: Array = t[i + 1]
		var x0: float = a[0]
		var x1: float = b[0]
		if (x - x0) * (x - x1) <= 0.0:
			return lerpf(a[k], b[k], (x - x0) / (x1 - x0))
	return t[-1][k] if absf(x - float(t[-1][0])) < absf(x - float(t[0][0])) else t[0][k]

## Un tubo de secciones elipticas a lo largo de x (de x0 a x1), facetado: cada
## seccion de 'arriba' a 'abajo' y con medio ancho 'ancho'; el material de cada
## cara lo decide 'que(x, v, lado)' (v: -1 abajo, 1 arriba; lado: se ve de lado).
func _tubo(xs: Array, perfil: Callable, que: Callable, radial: int, partes: Dictionary, irregular := 0.03) -> Array:
	var anillos: Array = []
	for i in xs.size():
		var x: float = xs[i]
		var p: Vector3 = perfil.call(x)       # arriba, abajo, medio ancho
		var c := (p.x + p.y) * 0.5
		var h := (p.x - p.y) * 0.5
		var anillo: Array[Vector3] = []
		for j in radial:
			var ang := TAU * float(j) / radial
			var r := 1.0 + (_rng.randf_range(-irregular, irregular) if i > 0 and i < xs.size() - 1 else 0.0)
			anillo.append(Vector3(x, c + sin(ang) * h * r, cos(ang) * p.z * r))
		anillos.append(anillo)
	for i in xs.size() - 1:
		for j in radial:
			var j2 := (j + 1) % radial
			var ang := TAU * (float(j) + 0.5) / radial
			var xm := (float(xs[i]) + float(xs[i + 1])) * 0.5
			var m: StandardMaterial3D = que.call(xm, sin(ang), absf(cos(ang)) > 0.3)
			if not partes.has(m):
				partes[m] = []
			var a: Vector3 = anillos[i][j]
			var b: Vector3 = anillos[i + 1][j]
			var cc: Vector3 = anillos[i + 1][j2]
			var d: Vector3 = anillos[i][j2]
			var p: Vector3 = perfil.call(xm)
			var eje := Vector3(xm, (p.x + p.y) * 0.5, 0.0)
			_tri(partes, m, a, b, cc, (a + b + cc) / 3.0 - eje)
			_tri(partes, m, a, cc, d, (a + cc + d) / 3.0 - eje)
	return anillos

## Una tapa en abanico de un anillo a un punto.
func _tapa(anillo: Array, punta: Vector3, m: StandardMaterial3D, partes: Dictionary, al_reves := false) -> void:
	var centro := Vector3.ZERO
	for v in anillo:
		centro += v
	centro /= anillo.size()
	for j in anillo.size():
		var a: Vector3 = anillo[j]
		var b: Vector3 = anillo[(j + 1) % anillo.size()]
		# (hacia fuera: hacia la punta, y algo hacia el borde)
		_tri(partes, m, a, punta, b, (punta - centro).normalized() + ((a + b) * 0.5 - centro) * 0.5)

## ---- el casco ---------------------------------------------------------------

## El color de cada trozo del casco, como en la imagen.
func _color_casco(x: float, v: float, lado: bool) -> StandardMaterial3D:
	if x > 0.36 and v >= 0.17 and v < 0.82 and lado:
		return _mat_cristal                  # la cabina
	# la franja del costado: ancha junto al motor, se estrecha y sube hasta la cabina
	var k := clampf((x + 0.45) / 0.81, 0.0, 1.0)
	if x <= 0.36 and v > lerpf(-0.42, 0.02, k) and v < lerpf(0.4, 0.17, k) and lado:
		return _mat_grafito
	if x > -0.05 and x < 0.7 and v < -0.78:
		return _mat_grafito                  # el panel de la panza
	return _mat_marfil

func _casco() -> void:
	var xs: Array = []
	for i in 19:
		xs.append(lerpf(-0.45, 1.05, pow(float(i) / 18.0, 0.9)))
	var partes := {}
	var perfil := func(x: float) -> Vector3:
		var arriba := _tabla(CASCO, x, 1)
		var abajo := _tabla(CASCO, x, 2)
		return Vector3(arriba, abajo, (arriba - abajo) * 0.5 * 0.66)
	var anillos := _tubo(xs, perfil, _color_casco, 20, partes, 0.012 if pintada else 0.03)
	# la linea cian de debajo de la cabina: una cinta fina pegada al casco, a los dos lados
	for lado in [1.0, -1.0]:
		var prev: Array = []
		for i in 13:
			var x := lerpf(0.34, 1.02, float(i) / 12.0)
			var p: Vector3 = perfil.call(x)
			var c := (p.x + p.y) * 0.5
			var h := (p.x - p.y) * 0.5
			var d := 0.016 / maxf(h, 0.05)
			var par: Array = []
			for th in [asin(0.12) - d, asin(0.12) + d]:
				par.append(Vector3(x, c + sin(th) * h * 1.015, lado * cos(th) * p.z * 1.015))
			if not prev.is_empty():
				var fuera := Vector3(0.0, 0.12, lado)
				_tri(partes, _mat_cian, prev[0], par[0], par[1], fuera)
				_tri(partes, _mat_cian, prev[0], par[1], prev[1], fuera)
			prev = par
	_tapa(anillos[-1], Vector3(1.07, 0.0, 0.0), _mat_cristal, partes, true)
	_tapa(anillos[0], Vector3(-0.47, 0.2, 0.0), _mat_grafito, partes)
	_malla(partes)

## La aleta: el lomo marfil que sigue hacia atras en punta, con su canto oscuro
## abajo y una rendija cian cerca de la punta.
func _aleta() -> void:
	var xs: Array = []
	for i in 9:
		xs.append(lerpf(-0.86, -0.4, float(i) / 8.0))
	var partes := {}
	var perfil := func(x: float) -> Vector3:
		return Vector3(_tabla(ALETA, x, 1), _tabla(ALETA, x, 2), _tabla(ALETA, x, 3))
	var color := func(x: float, v: float, lado: bool) -> StandardMaterial3D:
		if v > 0.1:
			return _mat_marfil
		if x < -0.6 and x > -0.8 and v > -0.6 and lado:
			return _mat_cian
		return _mat_grafito
	var anillos := _tubo(xs, perfil, color, 10, partes, 0.02)
	_tapa(anillos[0], Vector3(-0.88, 0.41, 0.0), _mat_marfil, partes)
	_malla(partes)

## El motor de atras: un tambor oscuro, el anillo cian y la tapa marfil abombada.
func _motor() -> void:
	var partes := {}
	var c := Vector2(0.0, 0.09)
	var tambor := func(x: float) -> Vector3:
		var r := 0.2
		if x < -0.56:
			r = 0.205                         # el anillo
		return Vector3(c.y + r, c.y - r, r)
	var color := func(x: float, _v: float, _l: bool) -> StandardMaterial3D:
		return _mat_cian if x < -0.56 else _mat_grafito
	var anillos := _tubo([-0.59, -0.565, -0.555, -0.45, -0.36], tambor, color, 12, partes, 0.0)
	# la tapa: un domo marfil hacia atras
	var domo: Array[Vector3] = []
	for j in 12:
		var ang := TAU * float(j) / 12.0
		domo.append(Vector3(-0.6, c.y + sin(ang) * 0.17, cos(ang) * 0.17))
	if not partes.has(_mat_marfil):
		partes[_mat_marfil] = []
	for j in 12:
		var a: Vector3 = anillos[0][j]
		var b: Vector3 = anillos[0][(j + 1) % 12]
		var d: Vector3 = domo[j]
		var e: Vector3 = domo[(j + 1) % 12]
		var fuera := Vector3(-1.0, 0.0, 0.0)   # (la corona de atras mira hacia atras)
		_tri(partes, _mat_grafito, d, a, b, fuera)
		_tri(partes, _mat_grafito, d, b, e, fuera)
	_tapa(domo, Vector3(-0.68, c.y + 0.01, 0.0), _mat_marfil, partes)
	_malla(partes)

## ---- las patas ----------------------------------------------------------------

## Una pata: rotula oscura en el casco, puntal marfil en diagonal hacia fuera y
## pie oscuro. 'hacia': donde queda el pie respecto a la rotula. Se recoge
## girando en la rotula.
func _pata(rotula: Vector3, hacia: Vector2) -> void:
	var raiz := Node3D.new()
	raiz.position = rotula
	add_child(raiz)
	var partes := {}
	var caja := func(c: Vector3, t: Vector3, m: StandardMaterial3D) -> void:
		var perfil := func(_x: float) -> Vector3:
			return Vector3(c.y + t.y, c.y - t.y, t.z)
		var anillos := _tubo([c.x - t.x, c.x + t.x], perfil, func(_x, _v, _l): return m, 6, partes, 0.0)
		_tapa(anillos[0], Vector3(c.x - t.x, c.y, c.z), m, partes)
		_tapa(anillos[1], Vector3(c.x + t.x, c.y, c.z), m, partes, true)
	caja.call(Vector3(0, 0, 0), Vector3(0.05, 0.05, 0.05), _mat_grafito)
	caja.call(Vector3(hacia.x * 1.08, hacia.y - 0.02, 0.0), Vector3(0.1, 0.02, 0.045), _mat_grafito)
	# el puntal: una sola barra en diagonal (en su nodo girado)
	var largo := hacia.length()
	var puntal := Node3D.new()
	puntal.rotation.z = atan2(hacia.y, hacia.x)
	raiz.add_child(puntal)
	var pp := {}
	var perfil_p := func(_x: float) -> Vector3:
		return Vector3(0.032, -0.032, 0.026)
	var an := _tubo([0.02, largo], perfil_p, func(_x, _v, _l): return _mat_marfil, 6, pp, 0.0)
	_tapa(an[1], Vector3(largo, 0.0, 0.0), _mat_marfil, pp, true)
	var mp := _malla(pp)
	remove_child(mp)
	puntal.add_child(mp)
	var mi := _malla(partes)
	remove_child(mi)
	raiz.add_child(mi)
	raiz.set_meta("s", signf(hacia.x))
	raiz.set_meta("y0", rotula.y)
	_patas.append(raiz)

func _colocar_patas() -> void:
	for p in _patas:
		var s: float = p.get_meta("s")
		# recogidas: giradas contra la panza y algo hundidas
		p.rotation.z = (1.0 - patas) * 1.25 * s
		p.position.y = float(p.get_meta("y0")) + (1.0 - patas) * 0.06

## Un triangulo con su normal de cara (el facetado), siempre hacia 'fuera'.
func _tri(partes: Dictionary, m: StandardMaterial3D, a: Vector3, b: Vector3, c: Vector3, fuera: Vector3) -> void:
	if not partes.has(m):
		partes[m] = []
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# (Godot toma por cara de delante la de orden horario, cuyo producto
	# vectorial apunta hacia dentro: si no, la cara se ve por detras y la luz
	# le cae al reves)
	if n.dot(fuera) > 0.0:
		var x := b
		b = c
		c = x
	else:
		n = -n
	partes[m].append_array([[a, n], [b, n], [c, n]])

## Una malla de triangulos sueltos por material (normales de cara hacia fuera).
func _malla(partes: Dictionary) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for m in partes:
		if partes[m].is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vn in partes[m]:
			st.set_normal(vn[1])
			st.add_vertex(vn[0])
		st.set_material(m)
		st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	return mi
