class_name NavePosada
extends Node2D
## UNA NAVE QUE SE POSA Y DESPEGA (Acto I de Egipto, 2026-10-27): un guino en
## las azoteas de los pilonos gemelos de la ciudad del fondo. La nave es 3D
## (Nave3D, copiada de la imagen del usuario) pintada en su propio SubViewport
## y puesta como una imagen mas en la capa: el 2D la lleva de sitio y el 3D la
## gira (se encabrita al subir, se ladea, se vuelve al llegar) y recoge o saca
## las patas. Ciclo: posada -> despega -> fuera -> llega -> posada.
## La posicion del nodo es donde apoya los pies.
##
## Para que no parezca un pegote ("que no queden pegadas"): la luz de la escena
## en dos tonos (sol bajo y calido de la izquierda, sombra azul pizarra, medidos
## en el pilono), el aire de su capa, bordes suaves como lo pintado, su sombra
## en la azotea, polvo al posarse y al despegar, una sola en el aire cada vez y
## un movimiento con peso.

const PX := 100.0                  # px del SubViewport por unidad de la nave
const PIES := 0.44                 # unidades de la nave del centro a la suela
const LARGO := 1.95                # unidades de la nave de cola a morro

@export var ancho := 60.0          # px (de la capa) de largo de la nave
@export var sentido := 1.0         # hacia donde se va (1 derecha, -1 izquierda)
@export var subida := 520.0        # px que sube al irse / desde donde baja
@export var estado := "posada"     # con el que empieza
@export var espera := 20.0         # lo que dura ese primer estado
@export var giro_posada := 0.4     # vuelta de la nave posada (algo de 3/4)
## el aire de su capa: lo lejano se mezcla con el color del horizonte (como la
## ciudad del fondo, capas.py AIRE_CIUDAD)
const AIRE := Color(0.69, 0.76, 0.75)
@export var aire := AIRE
@export var aire_k := 0.28
## y el contraste de su capa (la ciudad va al 62 %, capas.py LUZ_CIUDAD): sin el,
## su marfil y su grafito eran lo mas claro y lo mas oscuro del plano (2026-10-28)
@export var contraste := 0.75

# la luz del pilono (tira del fondo): cara al sol 212,136,86 y en sombra 60,78,88
const SOMBRA := Color(0.51, 0.63, 0.8)      # luz ambiente: lo que queda en sombra (sRGB)
const SOL := Color(1.0, 0.76, 0.48)         # el sol bajo de la tarde (sRGB)
const SOL_DIR := Vector3(0.75, -0.45, -0.6) # de la izquierda, bajo, algo de frente
const SOL_E := 1.0

## (el aire y unos bordes suaves: la media de 3 x 3 muestras alrededor, como
## una pincelada, en lugar del dentado de la imagen 3D reducida)
const SHADER_AIRE := """
shader_type canvas_item;
uniform vec3 aire;
uniform float k;
uniform float contraste = 1.0;
uniform float paso = 2.5;
void fragment() {
	vec4 c = vec4(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			c += texture(TEXTURE, UV + vec2(float(i), float(j)) * paso * TEXTURE_PIXEL_SIZE);
		}
	}
	c /= 9.0;
	vec3 rgb = c.a > 0.001 ? c.rgb / c.a : c.rgb;
	rgb = aire + (rgb - aire) * contraste;
	COLOR = vec4(mix(rgb, aire, k), c.a * COLOR.a);
}
"""

## cuantas van por el aire (todas las naves): una sola cada vez
static var _volando := 0

var _nave: Nave3D
var _img: Sprite2D
var _sombra: Sprite2D
var _polvo: CPUParticles2D
var _estela: CPUParticles2D
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 200)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = SOMBRA
	env.environment.ambient_light_energy = 1.0
	vp.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.basis = Basis.looking_at(SOL_DIR)
	sol.light_color = SOL
	sol.light_energy = SOL_E
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = vp.size.y / PX
	cam.position = Vector3(0, 0, 5)
	vp.add_child(cam)
	_nave = Nave3D.new()
	vp.add_child(_nave)
	# la sombra en la azotea: alargada hacia la derecha (el sol, de la izquierda)
	_sombra = Sprite2D.new()
	_sombra.texture = _mancha()
	_sombra.modulate = Color(0.16, 0.22, 0.28, 0.0)
	add_child(_sombra)
	_img = Sprite2D.new()
	_img.texture = vp.get_texture()
	var e := ancho / (LARGO * PX)
	_img.scale = Vector2(e, e)
	var sh := Shader.new()
	sh.code = SHADER_AIRE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("aire", Vector3(aire.r, aire.g, aire.b))
	m.set_shader_parameter("k", aire_k)
	m.set_shader_parameter("contraste", contraste)
	_img.material = m
	add_child(_img)
	_polvo = _hacer_polvo()
	add_child(_polvo)
	# la estela de vapor al irse (el mismo humo blanco que la lluvia de naves)
	_estela = CPUParticles2D.new()
	_estela.texture = _mancha()
	_estela.local_coords = false
	_estela.amount = 160
	_estela.lifetime = 4.0
	_estela.emitting = false
	_estela.spread = 180.0
	_estela.initial_velocity_min = 1.0
	_estela.initial_velocity_max = 4.0
	_estela.gravity = Vector2(-2.0, -1.0)
	_estela.scale_amount_min = ancho * 0.011
	_estela.scale_amount_max = ancho * 0.017
	var crece := Curve.new()
	crece.add_point(Vector2(0.0, 0.6))
	crece.add_point(Vector2(1.0, 2.6))
	_estela.scale_amount_curve = crece
	var cg := Gradient.new()
	cg.set_color(0, Color(1.0, 0.98, 0.95, 0.38))
	cg.set_color(1, Color(1.0, 0.98, 0.95, 0.0))
	_estela.color_ramp = cg
	add_child(_estela)
	_cambiar(estado, espera)
	_mover(0.0)

## Una mancha redonda y suave (para la sombra y el polvo).
func _mancha() -> GradientTexture2D:
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
	return tex

## El polvo de la azotea que levanta al posarse y al despegar: poco, del color
## de la piedra al sol, que se abre a los lados y se deshace (2026-10-27: era
## exagerado; la mitad y mas tenue).
func _hacer_polvo() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _mancha()
	p.emitting = false
	p.one_shot = true
	p.amount = 9
	p.lifetime = 1.4
	p.explosiveness = 0.85
	p.direction = Vector2(1, 0)
	p.spread = 180.0
	p.gravity = Vector2(0, -ancho * 0.04)
	p.initial_velocity_min = ancho * 0.12
	p.initial_velocity_max = ancho * 0.3
	p.damping_min = ancho * 0.25
	p.damping_max = ancho * 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(ancho * 0.22, 1.0)
	p.scale_amount_min = ancho * 0.008
	p.scale_amount_max = ancho * 0.016
	var c := Gradient.new()
	c.set_color(0, Color(0.86, 0.72, 0.58, 0.0))
	c.set_color(1, Color(0.8, 0.78, 0.74, 0.0))
	c.add_point(0.15, Color(0.86, 0.72, 0.58, 0.16))
	p.color_ramp = c
	return p

func _soltar_polvo() -> void:
	_polvo.restart()
	_polvo.emitting = true

func _process(delta: float) -> void:
	_mover(delta)

func _mover(delta: float) -> void:
	_t += delta
	var e := ancho / (LARGO * PX)
	var base := Vector2(0.0, -PIES * PX * e)
	var giro := Vector3(0.0, giro_posada * sentido, 0.0)    # (x ladeo, y vuelta, z cabeceo)
	var k := _t / maxf(espera, 0.01)
	var s := sentido
	var alto := 0.0          # lo que esta separada de la azotea (px)
	match estado:
		"posada":
			# al llegar, se asienta en las patas: un rebote corto que se apaga
			var asienta := exp(-_t * 3.5) * sin(_t * 11.0) * ancho * 0.025
			_img.position = base + Vector2(0.0, asienta)
			giro.z = exp(-_t * 3.0) * sin(_t * 8.0) * 0.03
			_img.modulate.a = 1.0
			_nave.patas = 1.0
			_nave.luz = 0.35 + 0.1 * sin(_t * 1.3)
			if k >= 1.0:
				if _volando > 0:
					espera += 5.0           # (otra va por el aire: espera)
				else:
					_cambiar("despega", 12.0)
					_soltar_polvo()
		"despega":
			# se agacha un instante, se eleva despacio recogiendo las patas
			# (cabeceando, con peso), se vuelve de lado, se encabrita y se va
			# hacia arriba cada vez mas deprisa
			var agacha := sin(clampf(k / 0.08, 0.0, 1.0) * PI) * ancho * 0.02
			var sube := smoothstep(0.05, 0.4, k) * ancho * 0.9
			var vete := pow(clampf((k - 0.45) / 0.55, 0.0, 1.0), 2.2)
			alto = sube + vete * subida
			var bambo := sin(_t * 2.4) * ancho * 0.025 * smoothstep(0.05, 0.3, k) * (1.0 - vete)
			_img.position = base + Vector2(s * vete * subida * 1.3, agacha - alto + bambo)
			var gira := smoothstep(0.25, 0.5, k)
			giro = Vector3(-0.15 * gira + sin(_t * 1.7) * 0.04 * (1.0 - vete),
					lerpf(giro_posada * s, 0.05 * s, gira),
					0.35 * smoothstep(0.4, 0.65, k) + sin(_t * 2.4 + 1.0) * 0.03 * (1.0 - vete))
			_nave.patas = 1.0 - smoothstep(0.15, 0.4, k)
			_nave.luz = 0.4 + 0.6 * smoothstep(0.0, 0.3, k)
			_img.modulate.a = 1.0 - clampf((k - 0.78) / 0.22, 0.0, 1.0)
			# (la estela, desde la cola, cuando ya acelera)
			_estela.position = _img.position + Vector2(-s * ancho * 0.45, 0.0).rotated(-0.35 * s)
			_estela.emitting = vete > 0.02 and k < 0.9
			if k >= 1.0:
				_cambiar("fuera", _rng.randf_range(15.0, 35.0))
		"fuera":
			_img.modulate.a = 0.0
			alto = subida
			if k >= 1.0:
				if _volando > 0:
					espera += 5.0
				else:
					_cambiar("llega", 13.0)
		"llega":
			# aparece arriba, del lado contrario, baja en curva frenando, se
			# vuelve, saca las patas, flota un momento y se posa
			var u := 1.0 - pow(1.0 - clampf(k / 0.78, 0.0, 1.0), 3.0)
			var desde := Vector2(-s * subida * 1.1, -subida)
			var p := desde.lerp(Vector2(0.0, -ancho * 0.7), u)
			var posa := smoothstep(0.8, 1.0, k)
			p.y = lerpf(p.y, 0.0, posa)
			p.y += sin(_t * 2.4) * ancho * 0.025 * (1.0 - posa)
			alto = -p.y
			_img.position = base + p
			giro = Vector3(0.18 * (1.0 - u) + sin(_t * 1.7) * 0.04 * (1.0 - posa),
					lerpf(-0.5 * s, giro_posada * s, smoothstep(0.3, 0.85, k)),
					-0.25 * (1.0 - u) + sin(_t * 2.4 + 1.0) * 0.03 * (1.0 - posa))
			_nave.patas = smoothstep(0.6, 0.85, k)
			_nave.luz = 1.0 - 0.6 * posa
			_img.modulate.a = clampf(k / 0.2, 0.0, 1.0)
			if k >= 1.0:
				_cambiar("posada", _rng.randf_range(35.0, 80.0))
				_soltar_polvo()
	# (hacia la izquierda, la nave mira a la izquierda: media vuelta; el
	# cabeceo y el ladeo van en los ejes de la nave, no cambian de signo)
	if s < 0.0:
		giro.y += PI
	_nave.rotation = giro
	# la sombra: pegada a la azotea, se aclara y se encoge al subir
	var cerca := clampf(1.0 - alto / (ancho * 2.5), 0.0, 1.0)
	_sombra.position = Vector2(ancho * 0.18, 0.0)
	_sombra.scale = Vector2(ancho * 1.1, ancho * 0.12) / 32.0 * lerpf(0.6, 1.0, cerca)
	_sombra.modulate.a = 0.5 * cerca * _img.modulate.a

func _cambiar(nuevo: String, dura: float) -> void:
	var antes := estado in ["despega", "llega"]
	var ahora := nuevo in ["despega", "llega"]
	if ahora and not antes:
		_volando += 1
	elif antes and not ahora:
		_volando -= 1
	estado = nuevo
	espera = dura
	_t = 0.0

func _exit_tree() -> void:
	if estado in ["despega", "llega"]:
		_volando -= 1
