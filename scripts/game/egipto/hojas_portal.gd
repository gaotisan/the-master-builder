extends Node2D
class_name HojasPortal
## LAS HOJAS DEL PORTAL (2026-10-28). El peregrino cae del cielo en Egipto como en
## la hojarasca, y con el, hojas: el usuario ("lo mejor es poner un montonaco de
## hojas... como si fuera el portal y siempre que cae, mejor hojas"; el monton de
## arena quedaba "cutrisimo"). Son las hojas de verdad de la hojarasca
## (hojas_voladoras.gd) a pleno sol (luz_plena), en un monton donde cae: una
## capa algo detras de el y otra algo delante (le tapa los pies), y otro monton
## grande en primer plano, en sombra, con mas paralaje (primer_plano()).
## Lo que hacen, como en caida_hojarasca.gd (sus mismas tablas y sonidos): el
## golpe las levanta en abanico y vuelven a caer encima; cada pisada sobre ellas
## levanta unas pocas; al levantarse se le caen las que se le quedaron encima.
##
## Las columnas de hojas_voladoras.gd dan la vuelta a los 2912 px: el monton va
## en medio (CENTRO) y lo demas vacio, lejos de donde dan la vuelta.

const HOJAS := preload("res://scripts/game/hojas_voladoras.gd")
const CENTRO := 1456.0
const ANCHO := 2912.0
## (de caida_hojarasca.gd)
const CONTACTOS := {
	"paso_suave": {"n": Vector2i(1, 2), "vel": Vector2(60, 220), "pie": 30.0, "delante": 0.7, "alto": 0.35},
	"paso":       {"n": Vector2i(3, 5), "vel": Vector2(110, 420), "pie": 38.0, "delante": 0.7, "alto": 0.45},
	"zancada":    {"n": Vector2i(6, 9), "vel": Vector2(200, 640), "pie": 46.0, "delante": 0.6, "alto": 0.5},
	"frenada":    {"n": Vector2i(9, 13), "vel": Vector2(160, 560), "pie": 60.0, "delante": 0.95, "alto": 0.25},
	"despegue":   {"n": Vector2i(6, 10), "vel": Vector2(160, 520), "pie": 10.0, "delante": 0.2, "alto": 0.55},
	"caida":      {"n": Vector2i(14, 20), "vel": Vector2(180, 720), "pie": 0.0, "delante": 0.5, "alto": 0.6},
}
const SALTOS := {
	"saltar":       {13: "despegue", 48: "caida"},
	"salto_correr": {4: "despegue", 33: "caida"},
	"salto_parado": {18: "despegue", 47: "caida"},
	"flotar_posarse": {0: "caida"},
}
const PISADA_ANIM := {
	"andar": "paso", "parada_andar": "paso", "aterrizaje_correr": "zancada",
	"correr": "zancada", "arranque_correr": "zancada", "parada_correr": "frenada",
	"andar_agachado": "paso_suave", "arranque_agachado": "paso_suave",
}
const FUERZA_SALTO := {"salto_parado": 0.8, "saltar": 1.0, "salto_correr": 1.3, "flotar_posarse": 0.35}
const PASOS := [
	preload("res://assets/audio/hojarasca_paso_1.wav"), preload("res://assets/audio/hojarasca_paso_2.wav"),
	preload("res://assets/audio/hojarasca_paso_3.wav"), preload("res://assets/audio/hojarasca_paso_4.wav"),
	preload("res://assets/audio/hojarasca_paso_5.wav"), preload("res://assets/audio/hojarasca_paso_6.wav"),
]

## El monton donde cae: px de alto en medio (la capa de delante; la de detras,
## algo menos) y de ancho (la campana).
@export var alto_monton: float = 120.0
@export var ancho_monton: float = 150.0
## Donde queda el cuerpo tumbado respecto al nodo del peregrino (de la hojarasca).
@export var cuerpo_desde: float = -170.0
@export var cuerpo_hasta: float = 160.0
@export var golpe_hojas: int = 220
@export var golpe_vel_min: float = 300.0
@export var golpe_vel_max: float = 880.0
@export var hojas_pegadas: int = 26
@export var velocidad_referencia: float = 160.0
@export var golpe_db: float = -13.0
@export var paso_db: float = -19.0
@export var levantarse_db: float = -15.0

## La luz del sol en las hojas (hojas_voladoras.gd, luz_plena): su dibujo esta
## hecho para brillar en el haz de la hojarasca (hasta ~1,15); a 1 salian muy
## oscuras sobre la arena al sol.
@export var luz_sol: float = 1.3
## El de primer plano, en sombra (pero no negro).
@export var luz_primer_plano: float = 1.05

## El color de las hojas al sol (modulate de las capas): menos amarillo, hacia
## ocre y oliva como las plantas de la escena (el usuario: "tan amarillas
## quedan feas").
@export var tinte := Color(1, 1, 1)
@export var desatura: float = 0.0     # (0,42 parecia paja: el color lo pondra el monton pintado)
## La alfombra hasta las piedras: px de alto, y lo que se amontona contra ellas.
@export var alfombra: float = 16.0
@export var contra_piedra: float = 34.0

var peregrino: Node2D
var _izq := -INF
var _der := INF
var _detras: Node2D
var _delante: Node2D
var _sonido_golpe: AudioStreamPlayer
var _sonido_paso: AudioStreamPlayer
var _sonido_levantarse: AudioStreamPlayer
var _ultima_x := NAN
var _velocidad := 0.0

## El monton en x (mundo), con los pies en suelo (y del nodo del peregrino en
## la arena).
## (2026-10-28, el usuario: que lleguen hasta las piedras de los lados y la capa
## de delante sobresalga un poco por delante de ellas, "para que queden mas
## integradas"): izq y der, x de juego de las piedras de los lados (la alfombra
## llega hasta ellas y se amontona algo contra cada una); delante_en, el nodo en
## que va la capa de delante (la arena de delante: asi asoma por encima de su
## borde), y delante_bajo, lo que su pie queda por debajo de los pies.
func montar(x: float, suelo: float, izq := -INF, der := INF, delante_en: Node = null, delante_bajo := 12.0) -> void:
	position = Vector2(x - CENTRO, 0.0)
	_izq = izq - position.x
	_der = der - position.x
	_detras = _capa(suelo - 4.0, 5.0, 0.85, -4)
	_delante = _capa(suelo + delante_bajo, 6.5, 1.0, 3)
	if delante_en:
		remove_child(_delante)
		delante_en.add_child(_delante)
		_delante.position = position
	_detras.sembrar(0.0, _monton.bind(0.75, alto_monton, ancho_monton, _detras))
	_delante.sembrar(0.0, _monton.bind(1.0, alto_monton, ancho_monton, _delante))
	_sonido_golpe = _sonido(load("res://assets/audio/hojarasca_golpe.wav"), golpe_db)
	_sonido_levantarse = _sonido(load("res://assets/audio/hojarasca_levantarse.wav"), levantarse_db)
	var pasos := AudioStreamRandomizer.new()
	pasos.random_pitch = 1.08
	pasos.random_volume_offset_db = 2.0
	for s in PASOS:
		pasos.add_stream(-1, s)
	_sonido_paso = _sonido(pasos, paso_db)
	_sonido_paso.max_polyphony = 4
	peregrino.impacto.connect(_al_impacto)
	peregrino.pisada.connect(_al_pisar)
	(peregrino.get_node("Sprite") as AnimatedSprite2D).animation_changed.connect(_al_cambiar_animacion)

## El monton grande de primer plano, en la capa que se le da (con su paralaje):
## en sombra y mas grande (esta mas cerca), con el pie en `pie` (coordenadas de
## la capa).
func primer_plano(capa: Node, pie: Vector2, escala: float, alto: float, ancho: float) -> void:
	var c: Node2D = HOJAS.new()
	c.y_base = 0.0
	c.alto_hoja = 6.5
	c.brillo = 1.0
	c.luz_plena = luz_primer_plano
	c.scale = Vector2(escala, escala)
	c.position = pie - Vector2(CENTRO * escala, 0.0)
	capa.add_child(c)
	c.viraje(desatura, tinte, preload("res://scripts/game/egipto/tinte_hojas.gdshader"))
	c.sembrar(0.0, _monton.bind(1.0, alto, ancho, c))

func _capa(y_base: float, alto_hoja: float, brillo: float, z: int) -> Node2D:
	var c: Node2D = HOJAS.new()
	c.y_base = y_base
	c.alto_hoja = alto_hoja
	c.brillo = brillo
	c.luz_plena = luz_sol
	c.z_index = z
	add_child(c)
	c.viraje(desatura, tinte, preload("res://scripts/game/egipto/tinte_hojas.gdshader"))
	return c

func _sonido(s: AudioStream, db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = db
	add_child(a)
	return a

## Alto (px) del monton en x local: una campana pequena y recogida donde cae
## (el usuario, 2026-10-28: "condensalas en la zona de la caida, como una pequena
## campana de Gauss"); sin colas (con ellas salian hojas sueltas por los lados).
func _monton(x: float, k: float, alto: float, ancho: float, _c: Node2D) -> float:
	var d := (x - CENTRO) / ancho
	var h := alto * exp(-d * d)
	if is_finite(_izq) and is_finite(_der):
		if x < _izq - 6.0 or x > _der + 6.0:
			return -100.0
		# la alfombra (irregular) y lo amontonado contra cada piedra
		var hueco := minf(x - _izq, _der - x)
		var ondula := 0.7 + 0.3 * sin(x * 0.047) * sin(x * 0.019 + 1.3)
		h = maxf(h, alfombra * ondula * smoothstep(-6.0, 30.0, hueco))
		h += contra_piedra * exp(-pow((x - _izq) / 45.0, 2.0)) + contra_piedra * exp(-pow((_der - x) / 45.0, 2.0))
	elif absf(d) > 1.7:
		return -100.0
	return k * h

func _physics_process(delta: float) -> void:
	if peregrino == null or delta <= 0.0:
		return
	var x := peregrino.position.x
	if not is_nan(_ultima_x):
		_velocidad = lerpf(_velocidad, absf(x - _ultima_x) / delta, 1.0 - exp(-10.0 * delta))
	_ultima_x = x

## El golpe: el cuerpo entra en el monton y lo que habia debajo sale en abanico,
## mas alto en el centro y mas abierto en los extremos; queda el hueco.
func _al_impacto() -> void:
	var x0 := peregrino.position.x - position.x
	var a := x0 + cuerpo_desde - 20.0
	var b := x0 + cuerpo_hasta + 20.0
	var hojas: Array[Dictionary] = _delante.tomar(a, b, golpe_hojas * 2 / 3, 2, 0.8)
	var de_detras: Array[Dictionary] = _detras.tomar(a, b, golpe_hojas / 3, 1, 0.8)
	for k in 2:
		var capa: Node2D = _delante if k == 0 else _detras
		for h in (hojas if k == 0 else de_detras):
			var t := clampf((h["p"].x - a) / (b - a), 0.0, 1.0)
			var fuera := (t - 0.5) * 2.0
			var ang := -PI / 2.0 + fuera * 0.9 + randf_range(-0.45, 0.45)
			var centro := 1.0 - absf(fuera) * 0.45
			capa.lanzar(h, Vector2.from_angle(ang) * lerpf(golpe_vel_min, golpe_vel_max, pow(randf(), 1.4)) * centro,
						randf_range(-1.0, 1.0) * 16.0)
	var y: float = _delante.y_base - 8.0
	for i in golpe_hojas / 3:
		var x := x0 + randf_range(cuerpo_desde, cuerpo_hasta)
		_soltar(Vector2(x, y - randf() * 12.0),
				Vector2.from_angle(-PI / 2.0 + randf_range(-1.2, 1.2)) * randf_range(200.0, 900.0),
				randf() < 0.6, randf_range(0.09, 0.14), randf_range(-20.0, 20.0))
	_sonido_golpe.play()

func _soltar(pos: Vector2, vel: Vector2, delante: bool, escala: float = -1.0, giro: float = INF) -> Dictionary:
	return (_delante if delante else _detras).soltar(pos, vel, escala, giro)

## Cada contacto del pie levanta las hojas de arriba junto al pie (si las hay).
func _al_pisar(anim: StringName, sprite: int) -> void:
	var tipo := ""
	var fuerza := 1.0
	if SALTOS.has(String(anim)):
		tipo = SALTOS[String(anim)].get(sprite, "")
		if tipo == "caida":
			fuerza = FUERZA_SALTO.get(String(anim), 1.0)
	else:
		tipo = PISADA_ANIM.get(String(anim), "paso")
		fuerza = clampf(_velocidad / velocidad_referencia, 0.6, 2.2) ** 0.6
	if tipo == "":
		return
	var c: Dictionary = CONTACTOS[tipo]
	var dir: float = peregrino.mirando()
	var n := int(round(randi_range(c["n"].x, c["n"].y) * fuerza))
	var vel_max: float = c["vel"].y * sqrt(fuerza)
	var hay := 0
	for lado in ([1.0, -1.0] if tipo == "caida" else [1.0]):
		var pie: float = peregrino.position.x - position.x + dir * lado * c["pie"] + (lado * 45.0 if tipo == "caida" else 0.0)
		var hojas: Array[Dictionary] = _delante.tomar(pie - 30.0, pie + 30.0, n * 2 / 3 + 1, 1)
		for h in hojas:
			_delante.lanzar(h, _patada(dir, c["vel"].x, vel_max, c["delante"], c["alto"]))
		var otras: Array[Dictionary] = _detras.tomar(pie - 30.0, pie + 30.0, n - hojas.size(), 1)
		for h in otras:
			_detras.lanzar(h, _patada(dir, c["vel"].x, vel_max, c["delante"], c["alto"]))
		hay += hojas.size() + otras.size()
	if hay > 0:
		_sonido_paso.volume_db = paso_db + (6.0 if tipo == "caida" else 0.0) + (3.0 if tipo in ["zancada", "frenada"] else 0.0)
		_sonido_paso.play()

## Salida de una hoja pateada: casi todas rasantes y despacio, pocas suben.
func _patada(dir: float, v_min: float, v_max: float, delante: float, alto: float) -> Vector2:
	var lado := dir if randf() < delante else -dir
	var rapidez := lerpf(v_min, v_max, pow(randf(), 1.8))
	var ang := lerpf(0.08, 1.35, pow(randf(), 1.0 / maxf(alto, 0.05) * 0.6))
	return Vector2(lado * cos(ang), -sin(ang)) * rapidez

## Al levantarse se le caen las que se le quedaron encima: primero las del
## cuerpo aun tumbado, luego mas arriba segun se incorpora; y un sacudon al final.
func _al_cambiar_animacion() -> void:
	var sprite := peregrino.get_node("Sprite") as AnimatedSprite2D
	if sprite.animation != &"levantarse":
		return
	_sonido_levantarse.play()
	var dur := sprite.sprite_frames.get_frame_count(&"levantarse") / sprite.sprite_frames.get_animation_speed(&"levantarse")
	var y0: float = _delante.y_base - 24.0
	for i in hojas_pegadas:
		var p := pow(randf(), 1.2)
		get_tree().create_timer(p * dur * 0.95).timeout.connect(func() -> void:
			var x := peregrino.position.x - position.x + randf_range(-120.0, 120.0) * (1.0 - p * 0.65)
			var y := y0 - (30.0 + 230.0 * p) * randf_range(0.35, 1.0)
			_soltar(Vector2(x, y), Vector2(randf_range(-70.0, 70.0), randf_range(-60.0, 10.0)),
					randf() < 0.6, randf_range(0.3, 0.38)))
	get_tree().create_timer(dur * 0.92).timeout.connect(func() -> void:
		for i in 6:
			_soltar(peregrino.position - position + Vector2(randf_range(-40.0, 40.0), -randf_range(120.0, 230.0)),
					Vector2(randf_range(-160.0, 160.0), randf_range(-140.0, 0.0)), randf() < 0.6))
