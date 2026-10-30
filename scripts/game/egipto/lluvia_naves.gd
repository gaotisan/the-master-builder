class_name LluviaNaves
extends Node2D
## LA LLUVIA DE NAVES (Acto I de Egipto, 2026-10-27): un homenaje a Planet of
## Lana (Wishfully), al momento en que Lana mira las naves que caen de un cielo
## azul dejando estelas blancas. Rehecho aqui, no recortado del trailer: unas
## capsulas (Nave3D, en picado, con la luz de la escena) cruzan el cielo en
## diagonal con su estela de humo y se pierden detras de las montanas: va en la
## capa de la ciudad, por delante de su cielo, y se corta en la silueta de
## montanas y edificios (capas.json "silueta", de capas.py).
## Cae UNA sola vez, al principio.
##
## La estela: un nucleo nitido que dura poco y bocanadas que se hinchan y se
## deshacen despacio; las dos derivan juntas con el viento, asi que la estela
## joven es una linea y la vieja, una hilera de humo deshilachandose.
##
## 'donde' devuelve el rectangulo que se ve de la capa (para que caigan a la
## vista).

@export var primera := 9.0              # s hasta la lluvia (solo una)
@export var cuantas := Vector2i(4, 6)
@export var tam := 24.0                 # px (de la capa) de largo de la capsula
@export var humo := Color(1.0, 0.975, 0.94)
## hacia el horizonte el humo se va al color del aire (la calima crema de las
## montanas) y se aclara: lejos, nada es blanco puro (2026-10-28)
@export var humo_lejos := Color(0.93, 0.84, 0.74)
@export var humo_lejos_k := 0.6
## las capsulas, de lejos: el aire de la ciudad (como NavePosada), mas fuerte,
## que eran motas casi negras sobre el cielo
@export var capsula_aire := 0.42
@export var capsula_contraste := 0.55
## donde (en fraccion del ancho de lo que se ve) pueden perderse tras las
## montanas: no detras de la torre alta de la orilla de enfrente (a la
## izquierda, por delante de la ciudad), que parecia que se estrellaban en ella
@export var caen_entre := Vector2(0.36, 0.97)

var silueta := PackedFloat32Array()
var sil_x0 := 0.0
var sil_paso := 1.0
var donde: Callable

var _espera := 0.0
var _hecha := false
var _caen: Array = []
var _tex_capsula: Texture2D
var _mat_capsula: ShaderMaterial
var _mat_humo: ShaderMaterial
var _mancha: GradientTexture2D
var _rng := RandomNumberGenerator.new()
var _t := 0.0

const VIDA_HUMO := 14.0                 # s que tardan las bocanadas en deshacerse
const VIDA_NUCLEO := 3.5                # s que dura la linea nitida de la estela
const VIENTO := Vector2(-2.0, -1.0)     # px/s que deriva el humo (nucleo y bocanadas, igual)
const VEL := Vector2(115.0, 165.0)      # px/s de la caida

## El humo (nucleo y bocanadas): por la altura en pantalla, del blanco arriba al
## color del aire en el horizonte ('y0' y 'y1', fracciones de la pantalla).
const SHADER_HUMO := """
shader_type canvas_item;
uniform vec3 lejos;
uniform float k;
uniform float y0;
uniform float y1;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float f = smoothstep(y0, y1, SCREEN_UV.y) * k;
	COLOR = vec4(mix(c.rgb, lejos, f), c.a * (1.0 - 0.4 * f));
}
"""

func _ready() -> void:
	_rng.randomize()
	_espera = primera
	_mancha = _hacer_mancha()
	# la capsula: una sola Nave3D en picado, compartida por todas (de lejos son
	# motas), con la luz de la escena (la de NavePosada)
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = NavePosada.SOMBRA
	vp.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.basis = Basis.looking_at(NavePosada.SOL_DIR)
	sol.light_color = NavePosada.SOL
	sol.light_energy = NavePosada.SOL_E
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.4
	cam.position = Vector3(0, 0, 5)
	vp.add_child(cam)
	var nave := Nave3D.new()
	nave.patas = 0.0
	nave.luz = 1.0
	vp.add_child(nave)
	# (morro abajo a la izquierda, como cae, y algo vuelta: se le ve el lomo al sol)
	nave.rotation = Vector3(0.35, 0.55, 0.0)
	# (la pose es fija: se pinta una vez y se queda; 2026-10-29, rendimiento)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_tex_capsula = vp.get_texture()
	var sh := Shader.new()
	sh.code = NavePosada.SHADER_AIRE
	_mat_capsula = ShaderMaterial.new()
	_mat_capsula.shader = sh
	var a := NavePosada.AIRE
	_mat_capsula.set_shader_parameter("aire", Vector3(a.r, a.g, a.b))
	_mat_capsula.set_shader_parameter("k", capsula_aire)
	_mat_capsula.set_shader_parameter("contraste", capsula_contraste)
	_mat_capsula.set_shader_parameter("paso", 1.5)
	var sh2 := Shader.new()
	sh2.code = SHADER_HUMO
	_mat_humo = ShaderMaterial.new()
	_mat_humo.shader = sh2
	_mat_humo.set_shader_parameter("lejos", Vector3(humo_lejos.r, humo_lejos.g, humo_lejos.b))
	_mat_humo.set_shader_parameter("k", humo_lejos_k)
	_mat_humo.set_shader_parameter("y0", 0.0)
	_mat_humo.set_shader_parameter("y1", 0.3)

## La altura de la silueta (montanas, piramides, ciudad) en x: por debajo, tapado.
func _y_silueta(x: float) -> float:
	if silueta.is_empty():
		return 1e9
	var f := (x - sil_x0) / sil_paso
	var i := clampi(int(floor(f)), 0, silueta.size() - 2)
	return lerpf(silueta[i], silueta[i + 1], clampf(f - i, 0.0, 1.0))

func _hacer_mancha() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 48
	tex.height = 48
	return tex

## El corte de la estela: blanca en el centro y suave en los bordes.
func _seccion() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 32
	return tex

func _process(delta: float) -> void:
	_t += delta
	if not _hecha:
		_espera -= delta
		if _espera <= 0.0:
			_hecha = _lanzar()
	if not _caen.is_empty():
		_horizonte()
	for c in _caen.duplicate():
		_mover(c, delta)

## Donde cae el horizonte en la pantalla (para el color del humo).
func _horizonte() -> void:
	if not donde.is_valid():
		return
	var r: Rect2 = donde.call()
	if r.size.y <= 0.0:
		return
	var f := (_y_silueta(r.get_center().x) - r.position.y) / r.size.y
	_mat_humo.set_shader_parameter("y0", f - 0.24)
	_mat_humo.set_shader_parameter("y1", f)

## Donde se pierde tras la silueta una capsula que sale de 'p' con velocidad 'v'.
func _impacto(p: Vector2, v: Vector2) -> Vector2:
	var d := v.normalized() * 8.0
	for i in 600:
		if p.y > _y_silueta(p.x):
			return p
		p += d
	return p

## La lluvia: varias capsulas casi en paralelo, escalonadas, desde arriba de lo
## que se ve, en diagonal hacia abajo a la izquierda (como en el trailer),
## repartidas para que no se pierdan todas en el mismo sitio.
func _lanzar() -> bool:
	if not donde.is_valid():
		return false
	var r: Rect2 = donde.call()
	if r.size.x <= 0.0:
		return false
	var n := _rng.randi_range(cuantas.x, cuantas.y)
	var dir := Vector2(-0.55, 1.0).normalized().rotated(_rng.randf_range(-0.06, 0.06))
	for i in n:
		var v := dir.rotated(_rng.randf_range(-0.035, 0.035)) * _rng.randf_range(VEL.x, VEL.y)
		var y := r.position.y - _rng.randf_range(40.0, 260.0)
		# cada una en su franja del cielo, con algo de azar; se prueba hasta que
		# se pierda tras una montana y no en lo alto de un edificio (los pilonos
		# con naves posadas, los obeliscos: parecia que se estrellaban en ellos)
		var x := 0.0
		for intento in 24:
			var f := (float(i) + _rng.randf_range(0.1, 0.9)) / n
			if intento >= 8:
				f = _rng.randf()
			var meta := r.position.x + r.size.x * lerpf(caen_entre.x, caen_entre.y, f)
			# la x de salida para que se pierda en 'meta' (dos pasadas: la silueta no es recta)
			x = meta + 600.0
			for k in 2:
				x += meta - _impacto(Vector2(x, y), v).x
			if not _es_edificio(_impacto(Vector2(x, y), v).x):
				break
		_nueva(Vector2(x, y), v, float(i) * _rng.randf_range(0.5, 1.1))
	return true

## Una bajada fija, siempre igual (2026-10-29, el usuario: al empezar el video del
## templo, "que lleguen del cielo unas cuantas naves a ambos lados de la piramide
## del fondo ... siempre por el mismo sitio"): una capsula por cada x de 'metas'
## (de la capa), que se pierde ahi tras la silueta, cada una 'retrasos' s despues.
func bajada(metas: Array, retrasos: Array, dir := Vector2(-0.35, 1.0), vel := 120.0) -> void:
	if not donde.is_valid():
		return
	var r: Rect2 = donde.call()
	var v := dir.normalized() * vel
	for i in metas.size():
		var meta := float(metas[i])
		# (desde encima de lo que se ve, unas mas altas que otras)
		var y := r.position.y - 90.0 - 45.0 * (i % 2)
		var x := meta + 600.0
		for k in 2:
			x += meta - _impacto(Vector2(x, y), v).x
		_nueva(Vector2(x, y), v * (1.0 + 0.06 * (i % 3)), float(retrasos[i]))

## Si en x la silueta es un edificio que sobresale (mas alto que las montanas de
## alrededor), no una montana.
func _es_edificio(x: float) -> bool:
	var aqui := _y_silueta(x)
	var alrededor: Array[float] = []
	# (ancho: los dos pilonos juntos miden ~700 px de la capa)
	for k in range(-36, 37):
		alrededor.append(_y_silueta(x + k * 25.0))
	alrededor.sort()
	# (y crece hacia abajo: la mediana de alrededor es la altura de las montanas;
	# y mirando tambien un poco a los lados, que la estela es ancha)
	var montes := alrededor[alrededor.size() / 2]
	for dx in [-30.0, 0.0, 30.0]:
		if _y_silueta(x + dx) < montes - 35.0:
			return true
	return false

func _nueva(desde: Vector2, vel: Vector2, retraso: float) -> void:
	# el nucleo: una linea suave, ancha atras (donde ya se abre) y fina en la capsula
	var linea := Line2D.new()
	linea.texture = _seccion()
	linea.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	linea.joint_mode = Line2D.LINE_JOINT_ROUND
	linea.width = tam * 0.85
	var w := Curve.new()
	w.add_point(Vector2(0.0, 2.0))
	w.add_point(Vector2(0.8, 1.0))
	w.add_point(Vector2(1.0, 0.3))
	linea.width_curve = w
	var g := Gradient.new()
	g.set_color(0, Color(humo, 0.0))
	g.set_color(1, Color(humo, 0.88))
	g.add_point(0.5, Color(humo, 0.6))
	linea.gradient = g
	linea.material = _mat_humo
	add_child(linea)
	# las bocanadas: muchas, suaves, que se hinchan y derivan con el viento
	var bocanadas := CPUParticles2D.new()
	bocanadas.texture = _mancha
	bocanadas.local_coords = false
	bocanadas.amount = 760
	bocanadas.lifetime = VIDA_HUMO
	bocanadas.emitting = false
	bocanadas.direction = VIENTO.normalized()
	bocanadas.spread = 40.0
	bocanadas.initial_velocity_min = VIENTO.length() * 0.5
	bocanadas.initial_velocity_max = VIENTO.length() * 1.6
	bocanadas.gravity = Vector2.ZERO
	bocanadas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bocanadas.emission_sphere_radius = tam * 0.22
	bocanadas.scale_amount_min = tam * 0.016
	bocanadas.scale_amount_max = tam * 0.04
	var crece := Curve.new()
	crece.add_point(Vector2(0.0, 0.6))
	crece.add_point(Vector2(0.3, 1.5))
	crece.add_point(Vector2(1.0, 2.6))
	bocanadas.scale_amount_curve = crece
	var cg := Gradient.new()
	cg.set_color(0, Color(humo, 0.0))
	cg.set_color(1, Color(humo, 0.0))
	cg.add_point(0.04, Color(humo, 0.3))
	cg.add_point(0.45, Color(humo, 0.2))
	bocanadas.color_ramp = cg
	bocanadas.material = _mat_humo
	add_child(bocanadas)
	var capsula := Sprite2D.new()
	capsula.texture = _tex_capsula
	capsula.scale = Vector2.ONE * (tam / 130.0)   # (la nave mide ~130 px en su SubViewport)
	capsula.position = desde
	# (la nave esta hecha cayendo a la izquierda; a la derecha, en espejo)
	capsula.flip_h = vel.x > 0.0
	capsula.visible = false
	capsula.material = _mat_capsula
	add_child(capsula)
	_caen.append({"capsula": capsula, "linea": linea, "bocanadas": bocanadas, "puntos": [], "nacidos": [],
			"vel": vel, "retraso": retraso, "viva": true, "fase": _rng.randf() * TAU})

func _mover(c: Dictionary, delta: float) -> void:
	var capsula: Sprite2D = c["capsula"]
	var linea: Line2D = c["linea"]
	var bocanadas: CPUParticles2D = c["bocanadas"]
	var puntos: Array = c["puntos"]
	var nacidos: Array = c["nacidos"]
	c["retraso"] = float(c["retraso"]) - delta
	if float(c["retraso"]) > 0.0:
		return
	if c["viva"]:
		capsula.visible = true
		capsula.position += (c["vel"] as Vector2) * delta
		# (un leve vaiven: cae, no va sobre un rail)
		capsula.rotation = sin(_t * 2.3 + float(c["fase"])) * 0.06
		bocanadas.position = capsula.position
		bocanadas.emitting = true
		if puntos.is_empty() or (puntos[-1] as Vector2).distance_to(capsula.position) > 5.0:
			puntos.append(capsula.position)
			nacidos.append(_t)
		if capsula.position.y > _y_silueta(capsula.position.x):
			# tras las montanas: deja de echar humo; la estela se queda y se deshace
			c["viva"] = false
			capsula.visible = false
			bocanadas.emitting = false
			c["fin"] = _t
	# el nucleo: los puntos de menos de VIDA_NUCLEO s, derivando con el viento
	while not nacidos.is_empty() and _t - float(nacidos[0]) > VIDA_NUCLEO:
		nacidos.pop_front()
		puntos.pop_front()
	var pts := PackedVector2Array()
	for i in puntos.size():
		pts.append((puntos[i] as Vector2) + VIENTO * (_t - float(nacidos[i])))
	linea.points = pts
	if not c["viva"] and _t - float(c.get("fin", _t)) > VIDA_HUMO:
		capsula.queue_free()
		linea.queue_free()
		bocanadas.queue_free()
		_caen.erase(c)
