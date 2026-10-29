extends Node2D
class_name ArenaPortal
## LA CAIDA EN LA ARENA (2026-10-28). El peregrino cae del cielo en un monton de
## arena, con la receta de la hojarasca (el usuario: "lo mismo con los montones
## que tenemos pero con arena"): el monton es arte pintado (las dunas de
## ChatGPT, adornos.py: una detras de el y otra mas baja delante, que tumbado le
## tapa medio cuerpo) y por codigo solo lo que se mueve. La primera vez la arena
## que saltaba eran puntos y la nube, circulos ("faltan puntacos, poco creible"):
##   - la salpicadura: estelas alargadas que miran hacia donde vuelan (granos
##     moviendose deprisa se ven como trazos), de varios tonos, que caen con su
##     peso; unas delante del peregrino y mas detras;
##   - la nube: bocanadas grandes y deshilachadas (ruido, no circulos), bajas, que
##     se abren a los lados, crecen y se quedan un rato flotando;
##   - el monton se aplasta con el golpe y se queda hundido;
##   - al levantarse le cae arena de la ropa, en hilos.

const DUNAS := "res://assets/egipto/acto1/adornos/%s.png"
## [pieza, escala, x del centro respecto a donde cae, px bajo los pies, delante, volteada]
## (2026-10-28, el usuario: "algo mas grande el monton")
@export var monton: Array = [
	["arena_dunas_b_4", 2.0, -40.0, 18.0, false, false],
	["arena_dunas_a_4", 1.6, -60.0, 44.0, true, true],
]
const ARENA_LUZ := Color(0.96, 0.85, 0.7)
const ARENA_MEDIA := Color(0.86, 0.71, 0.58)
const ARENA_SOMBRA := Color(0.7, 0.56, 0.48)
## (de la hojarasca) donde queda el cuerpo tumbado respecto al nodo.
@export var cuerpo_desde: float = -170.0
@export var cuerpo_hasta: float = 160.0
@export var golpe_db: float = -8.0

var peregrino: Node2D
var temblor: Callable          # (s) la camara del nivel
var _montones: Array[Sprite2D] = []
var _suelo := 0.0
var _tex_estela: Texture2D
var _tex_bocanada: Texture2D

func montar(x: float, suelo: float) -> void:
	_suelo = suelo
	for m in monton:
		var tex: Texture2D = load(DUNAS % m[0])
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		# (el origen en el pie, en medio: se aplasta contra el suelo)
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		s.flip_h = m[5]
		s.scale = Vector2(m[1], m[1])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.position = Vector2(x + float(m[2]), suelo + float(m[3]))
		s.z_index = 3 if m[4] else -4
		add_child(s)
		_montones.append(s)
	peregrino.impacto.connect(_al_impacto)
	peregrino.pisada.connect(_al_pisar)
	(peregrino.get_node("Sprite") as AnimatedSprite2D).animation_changed.connect(_al_cambiar_animacion)

func _al_impacto() -> void:
	var x0 := peregrino.position.x
	var centro := x0 + (cuerpo_desde + cuerpo_hasta) * 0.5
	if temblor.is_valid():
		temblor.call(0.45)
	for s in _montones:
		var e := s.scale
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2(e.x * 1.12, e.y * 0.6), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(e.x * 1.07, e.y * 0.78), 0.5).set_trans(Tween.TRANS_SINE)
	# la salpicadura: a rafagas desde varios sitios del cuerpo, cada una con su
	# angulo y su fuerza (de un rectangulo y todas iguales salia un abanico
	# simetrico, "como meteoritos"); mas detras que delante
	var sitios := 7
	for i in sitios:
		var t := (i + randf_range(0.1, 0.9)) / sitios
		var x := lerpf(x0 + cuerpo_desde, x0 + cuerpo_hasta, t)
		var lado := (t - 0.5) * 2.0
		var ang := -PI / 2.0 + lado * randf_range(0.35, 0.8) + randf_range(-0.25, 0.25)
		var fuerza := randf_range(0.55, 1.15) * (1.0 - absf(lado) * 0.3)
		var z := 4 if randf() < 0.3 else -3
		var tarda := randf_range(0.0, 0.08)
		get_tree().create_timer(tarda).timeout.connect(_salpicar.bind(
				Vector2(x, _suelo - randf_range(15.0, 40.0)), randi_range(14, 34), z, fuerza, ang))
	# la nube, baja, a los dos lados y en medio
	for lado in [-1.0, 0.0, 1.0]:
		_nube(Vector2(centro + lado * 70.0, _suelo - 40.0), lado)
	# y la que queda flotando a ras de suelo
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		_nube(Vector2(centro, _suelo - 10.0), 0.0, true))
	_sonar(load("res://assets/audio/peregrino_caida_golpe.wav"), golpe_db, 0.85)

## Pisando el monton (un salto que cae encima, o al andar por el): un poco de
## arena y polvo donde pisa, si pisa el monton.
func pisar(x: float, fuerza: float) -> void:
	var en := false
	for s in _montones:
		var w := s.texture.get_width() * s.scale.x * 0.5
		if absf(x - s.position.x) < w * 0.8:
			en = true
	if not en:
		return
	_salpicar(Vector2(x, _suelo - 20.0), int(8 + 14 * fuerza), -3, 0.4 + 0.35 * fuerza,
			-PI / 2.0 + randf_range(-0.6, 0.6))
	var n := CPUParticles2D.new()
	n.one_shot = true
	n.explosiveness = 0.8
	n.amount = int(3 + 4 * fuerza)
	n.lifetime = 1.6
	n.position = Vector2(x, _suelo - 15.0)
	n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	n.emission_rect_extents = Vector2(50.0, 6.0)
	n.direction = Vector2(0, -1)
	n.spread = 70.0
	n.gravity = Vector2(8, -10)
	n.initial_velocity_min = 30.0
	n.initial_velocity_max = 120.0 * fuerza
	n.damping_min = 80.0
	n.damping_max = 140.0
	n.angle_min = 0.0
	n.angle_max = 360.0
	n.texture = _bocanada()
	n.scale_amount_min = 0.5
	n.scale_amount_max = 0.9 + 0.5 * fuerza
	var crece := Curve.new()
	crece.add_point(Vector2(0, 0.5))
	crece.add_point(Vector2(1, 1.4))
	n.scale_amount_curve = crece
	var g := Gradient.new()
	g.set_color(0, Color(ARENA_LUZ, 0.0))
	g.set_color(1, Color(ARENA_LUZ, 0.0))
	g.add_point(0.1, Color(ARENA_MEDIA, 0.5))
	n.color_ramp = g
	n.z_index = 4
	add_child(n)
	n.emitting = true
	get_tree().create_timer(2.2).timeout.connect(n.queue_free)

## La arena que salta: estelas que miran hacia donde vuelan.
func _salpicar(pos: Vector2, cuantas: int, z: int, fuerza: float, ang := -PI / 2.0) -> void:
	var e := CPUParticles2D.new()
	e.one_shot = true
	e.explosiveness = randf_range(0.7, 0.95)
	e.amount = cuantas
	e.lifetime = randf_range(1.0, 1.5)
	e.position = pos
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = randf_range(12.0, 30.0)
	e.direction = Vector2.from_angle(ang)
	e.spread = randf_range(14.0, 30.0)
	e.gravity = Vector2(0, 1700)
	e.initial_velocity_min = 200.0 * fuerza
	e.initial_velocity_max = 820.0 * fuerza
	e.damping_min = 0.0
	e.damping_max = 120.0
	e.particle_flag_align_y = true
	e.texture = _estela()
	e.scale_amount_min = 0.5
	e.scale_amount_max = 1.4
	var mengua := Curve.new()
	mengua.add_point(Vector2(0, 1.0))
	mengua.add_point(Vector2(0.7, 0.8))
	mengua.add_point(Vector2(1, 0.3))
	e.scale_amount_curve = mengua
	var tonos := Gradient.new()
	tonos.set_color(0, ARENA_SOMBRA)
	tonos.set_color(1, ARENA_LUZ)
	tonos.add_point(0.5, ARENA_MEDIA)
	e.color_initial_ramp = tonos
	var vida := Gradient.new()
	vida.set_color(0, Color(1, 1, 1, 0.95))
	vida.set_color(1, Color(1, 1, 1, 0.0))
	vida.add_point(0.7, Color(1, 1, 1, 0.85))
	e.color_ramp = vida
	e.z_index = z
	add_child(e)
	e.emitting = true
	get_tree().create_timer(2.0).timeout.connect(e.queue_free)

## Una nube de polvo: bocanadas de ruido que crecen, se abren y se van.
func _nube(pos: Vector2, lado: float, rasante := false) -> void:
	var n := CPUParticles2D.new()
	n.one_shot = true
	n.explosiveness = 0.75 if not rasante else 0.3
	n.amount = 12 if not rasante else 8
	n.lifetime = 2.4 if not rasante else 4.0
	n.position = pos
	n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	n.emission_rect_extents = Vector2(90.0, 18.0) if not rasante else Vector2(220.0, 8.0)
	n.direction = Vector2(lado, -0.6 if lado == 0.0 else -0.25).normalized()
	n.spread = 35.0 if lado != 0.0 else 25.0
	n.gravity = Vector2(10, -14)
	n.initial_velocity_min = 90.0 if not rasante else 10.0
	n.initial_velocity_max = 300.0 if not rasante else 40.0
	n.damping_min = 140.0
	n.damping_max = 220.0
	n.angle_min = 0.0
	n.angle_max = 360.0
	n.angular_velocity_min = -12.0
	n.angular_velocity_max = 12.0
	n.texture = _bocanada()
	n.scale_amount_min = 1.5
	n.scale_amount_max = 2.6
	var crece := Curve.new()
	crece.add_point(Vector2(0, 0.45))
	crece.add_point(Vector2(0.35, 0.9))
	crece.add_point(Vector2(1, 1.5))
	n.scale_amount_curve = crece
	var g := Gradient.new()
	var a := 0.7 if not rasante else 0.4
	g.set_color(0, Color(ARENA_LUZ, 0.0))
	g.set_color(1, Color(ARENA_LUZ, 0.0))
	g.add_point(0.06, Color(ARENA_MEDIA, a))
	g.add_point(0.45, Color(ARENA_LUZ, a * 0.6))
	n.color_ramp = g
	n.z_index = 4
	add_child(n)
	n.emitting = true
	get_tree().create_timer(n.lifetime + 0.5).timeout.connect(n.queue_free)

## Las pisadas sobre el monton: los aterrizajes de los saltos, fuerte; los
## pasos, flojito (como CONTACTOS de la hojarasca).
const ATERRIZA := {"saltar": 48, "salto_correr": 33, "salto_parado": 47, "flotar_posarse": 0}
func _al_pisar(anim: StringName, sprite: int) -> void:
	if peregrino.datos_movimiento()["estado"] in ["CAYENDO", "CAIDA", "TUMBADO", "LEVANTARSE"]:
		return
	var x := peregrino.position.x
	if ATERRIZA.has(String(anim)):
		if int(ATERRIZA[String(anim)]) == sprite:
			pisar(x, 1.0)
	elif String(anim) in ["andar", "correr", "parada_andar", "parada_correr", "arranque_correr", "aterrizaje_correr"]:
		pisar(x + peregrino.mirando() * 30.0, 0.25 if String(anim) == "andar" else 0.5)

## Al levantarse, hilos de arena que le caen de la ropa.
func _al_cambiar_animacion() -> void:
	var sp := peregrino.get_node("Sprite") as AnimatedSprite2D
	if sp.animation != &"levantarse":
		return
	var dur := sp.sprite_frames.get_frame_count(&"levantarse") / sp.sprite_frames.get_animation_speed(&"levantarse")
	for i in 5:
		get_tree().create_timer(dur * (0.15 + 0.17 * i)).timeout.connect(func() -> void:
			var r := CPUParticles2D.new()
			r.one_shot = true
			r.explosiveness = 0.2
			r.amount = 22
			r.lifetime = 0.7
			r.position = peregrino.position + Vector2(randf_range(-60.0, 60.0), -randf_range(60.0, 200.0) * (0.4 + 0.15 * i))
			r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			r.emission_rect_extents = Vector2(30.0, 6.0)
			r.direction = Vector2(0, 1)
			r.spread = 8.0
			r.gravity = Vector2(0, 1300)
			r.initial_velocity_min = 20.0
			r.initial_velocity_max = 80.0
			r.particle_flag_align_y = true
			r.texture = _estela()
			r.scale_amount_min = 0.2
			r.scale_amount_max = 0.45
			var tonos := Gradient.new()
			tonos.set_color(0, ARENA_SOMBRA)
			tonos.set_color(1, ARENA_LUZ)
			r.color_initial_ramp = tonos
			r.z_index = 4
			add_child(r)
			r.emitting = true
			get_tree().create_timer(1.5).timeout.connect(r.queue_free))

func _sonar(s: AudioStream, db: float, tono: float) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = db
	a.pitch_scale = tono
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

## Un grano en vuelo: un trazo blando, mas largo que ancho (16 x 48).
func _estela() -> Texture2D:
	if _tex_estela == null:
		var im := Image.create(16, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 16:
				var u := (x - 7.5) / 7.5
				var v := (y - 23.5) / 23.5
				var a := clampf(1.0 - (u * u + v * v), 0.0, 1.0)
				im.set_pixel(x, y, Color(1, 1, 1, a * a))
		_tex_estela = ImageTexture.create_from_image(im)
	return _tex_estela

## Una bocanada de polvo: ruido con bordes deshilachados (128 x 128).
func _bocanada() -> Texture2D:
	if _tex_bocanada == null:
		var ruido := FastNoiseLite.new()
		ruido.seed = 7
		ruido.frequency = 0.035
		ruido.fractal_octaves = 4
		var im := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
				var r := ruido.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf((1.0 - d) * 1.6 * (0.35 + 0.9 * r) - 0.15, 0.0, 1.0)
				im.set_pixel(x, y, Color(1, 1, 1, a * a))
		_tex_bocanada = ImageTexture.create_from_image(im)
	return _tex_bocanada
