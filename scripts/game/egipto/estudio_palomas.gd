class_name EstudioPalomas
extends Node
## EL ESTUDIO DE LAS PALOMAS (2026-10-29). Todas las palomas de la escena en un
## solo SubViewport: cada una en su casilla de una rejilla (CELDA px), con la
## misma camara ortogonal y la luz de la escena (la de NavePosada). Cada paloma
## pinta su casilla con un Sprite2D (region). Con la bandada son quince o veinte
## palomas: una pasada de 3D para todas en lugar de una por paloma.

const PX := 64.0                    # px del SubViewport por unidad 3D (1 unidad = el largo de la paloma)
const CELDA := 160                  # px de cada casilla (las alas abiertas caben)
const COLS := 6
## Las patas, por debajo del centro de la casilla (unidades).
const PIES := 0.55

var _vp: SubViewport
var _cam: Camera3D
var _usadas := 0

func _montar() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(COLS * CELDA, CELDA)
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# (la sombra de la escena, algo calentada: con la azul tal cual las grises
	# salian lilas al lado de la piedra)
	env.environment.ambient_light_color = NavePosada.SOMBRA.lerp(Color(0.8, 0.72, 0.62), 0.45)
	_vp.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.basis = Basis.looking_at(NavePosada.SOL_DIR)
	sol.light_color = NavePosada.SOL
	sol.light_energy = NavePosada.SOL_E
	_vp.add_child(sol)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)

## Le da una casilla a raiz (la paloma, con las patas en su origen): la coloca
## en el mundo del estudio y devuelve la region de la textura que le toca.
func casilla(raiz: Node3D) -> Rect2:
	if _vp == null:
		_montar()
	var i := _usadas
	_usadas += 1
	var col := i % COLS
	var fila := i / COLS
	var filas := fila + 1
	if _vp.size.y < filas * CELDA:
		_vp.size = Vector2i(COLS * CELDA, filas * CELDA)
	var u := CELDA / PX
	# (la camara, en medio de la rejilla entera)
	_cam.size = _vp.size.y / PX
	_cam.position = Vector3(COLS * u * 0.5, -_vp.size.y / PX * 0.5, 5.0)
	raiz.position = Vector3((col + 0.5) * u, -(fila + 0.5) * u - PIES, 0.0)
	_vp.add_child(raiz)
	return Rect2(col * CELDA, fila * CELDA, CELDA, CELDA)

func textura() -> ViewportTexture:
	if _vp == null:
		_montar()
	return _vp.get_texture()
