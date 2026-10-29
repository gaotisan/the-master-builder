class_name TemploRio
extends Node2D
## EL TEMPLO DEL CORTEJO (2026-10-29, el usuario: el templo de sus videos en la
## orilla de enfrente, en lugar del de la torre; "el primer fotograma del video
## se encaja ahi, luego se activa cuando el peregrino llega arriba y se lanza";
## el video acaba con el templo sin barco y sin gente, y eso se queda).
##   - Quieto en su primer fotograma hasta lanzar(); luego el video (los tres
##     unidos: la procesion baja el sarcofago, el barco atraca y lo cargan, y se
##     va remando) y al acabar, su ultimo fotograma para siempre.
##   - Sobre croma: lo recorta templo_rio.gdshader, con el color de la orilla; y
##     su reflejo en el agua, el mismo dibujo boca abajo.
##   - Con el video, los canticos del cortejo (el audio del primer video), lejos
##     y bajitos, hasta que la gente se mete en el templo.
##   - El barco: en el video se iria por el borde; desde que llega cerca (el
##     fotograma del relevo, templo.json "barco") el video lo lleva borrado y
##     sigue este, suelto, rio abajo a su velocidad, con su reflejo, remando:
##     los fotogramas del remo del video, adelante y atras desde el del relevo;
##     y su espuma (barco_espuma.gdshader): la ola de la proa, la raya del casco,
##     la estela y lo que salpica el remo con su fotograma.
## Lo prepara tools/egipto/templo_rio.py (assets/egipto/acto1/templo/templo.json);
## va en la capa de la orilla, en sus coordenadas.

const SHADER := preload("res://scripts/game/egipto/templo_rio.gdshader")
const ESPUMA := preload("res://scripts/game/egipto/barco_espuma.gdshader")
## La espuma: cuanto se ve (1 = como esta pintada), cuanto le cuesta salir tras
## el relevo (el video ya trae la suya, mas tenue) y lo que se alarga la estela.
var espuma_fuerza := 1.0
var espuma_entra := 0.8
const ESTELA := 220.0
## Px de la textura por cada px de las medidas a mano (hechas con el video a 640
## de ancho: la espuma, el reflejo; templo.json "px").
var _px := 1.0

signal acabado

var lanzado := false
## El volumen de los canticos (lo pone el nivel).
var cantos_db := -14.0
var _quieto: Sprite2D
var _reflejo: Sprite2D
var _video: VideoStreamPlayer
var _ultimo: Texture2D
var _cantos: AudioStreamPlayer
var _barco: Sprite2D
var _barco_reflejo: Sprite2D
var _barco_d: Dictionary
var _barco_t := -1.0   # s desde el relevo (negativo: aun lo lleva el video)
var _barco_fot: Array[Texture2D] = []
var _espuma: ColorRect
var _espuma_mat: ShaderMaterial
## Cuanto sigue el barco rio abajo antes de quitarlo (s).
var barco_dura := 90.0
## Lo que tarda en meterse en el agua tras el relevo (templo.json "hundir").
var hundir_en := 1.5

func montar(d: Dictionary) -> void:
	_px = float(d.get("px", 1.0))
	position = Vector2(float(d["x"]), float(d["y"]))
	var e := float(d["escala"])
	scale = Vector2(e, e)
	var m := _material(d, false)
	_quieto = Sprite2D.new()
	_quieto.texture = load(d["primero"])
	_quieto.centered = false
	_quieto.material = m
	# (sin mipmaps, como el video: con ellos el ultimo fotograma salia borroso)
	_quieto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_quieto)
	_ultimo = load(d["ultimo"])
	# el reflejo, justo debajo (la textura acaba en la linea del agua)
	_reflejo = Sprite2D.new()
	_reflejo.texture = _quieto.texture
	_reflejo.centered = false
	_reflejo.flip_v = true
	_reflejo.position.y = _quieto.texture.get_height()
	_reflejo.material = _material(d, true)
	add_child(_reflejo)
	_video = VideoStreamPlayer.new()
	_video.stream = load(d["video"])
	_video.material = m
	_video.size = _quieto.texture.get_size()
	_video.expand = true
	_video.visible = false
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_al_acabar)
	add_child(_video)
	_cantos = AudioStreamPlayer.new()
	_cantos.stream = load(d["cantos"])
	add_child(_cantos)
	if d.has("barco"):
		_barco_d = d["barco"]
		for ruta in _barco_d["fotogramas"]:
			_barco_fot.append(load(ruta))
		var bt: Texture2D = _barco_fot[-1]
		_barco = Sprite2D.new()
		_barco.texture = bt
		_barco.centered = false
		_barco.material = m
		_barco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_barco.visible = false
		add_child(_barco)
		# (su textura tambien acaba en la linea del agua)
		_barco_reflejo = Sprite2D.new()
		_barco_reflejo.texture = bt
		_barco_reflejo.centered = false
		_barco_reflejo.flip_v = true
		_barco_reflejo.material = _material(d, true)
		_barco_reflejo.visible = false
		add_child(_barco_reflejo)
		# la espuma, encima del casco y del agua: de la estela a la proa
		var esp: Dictionary = _barco_d["espuma"]
		var ruido := NoiseTexture2D.new()
		ruido.seamless = true
		ruido.width = 256
		ruido.height = 256
		ruido.noise = FastNoiseLite.new()
		ruido.noise.frequency = 0.03
		_espuma_mat = ShaderMaterial.new()
		_espuma_mat.shader = ESPUMA
		_espuma_mat.set_shader_parameter("ruido", ruido)
		var arriba := 6.0
		var alto := 24.0
		# (la espuma, en px de 640 de ancho: el rectangulo escalado por _px)
		var largo := ESTELA + float(esp["proa"]) / _px + 12.0
		_espuma_mat.set_shader_parameter("tam", Vector2(largo, alto))
		_espuma_mat.set_shader_parameter("linea", arriba)
		for c in ["popa", "proa", "remo"]:
			_espuma_mat.set_shader_parameter(c, ESTELA + float(esp[c]) / _px)
		_espuma = ColorRect.new()
		_espuma.material = _espuma_mat
		_espuma.size = Vector2(largo, alto)
		_espuma.scale = Vector2(_px, _px)
		_espuma.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_espuma.visible = false
		add_child(_espuma)

## De ancho, en unidades de su capa.
func ancho() -> float:
	return _quieto.texture.get_width() * scale.x

func lanzar() -> void:
	if lanzado:
		return
	lanzado = true
	_video.play()
	_cantos.volume_db = cantos_db
	_cantos.play()
	# (el quieto hasta que el video tenga su primer fotograma)
	await get_tree().process_frame
	await get_tree().process_frame
	_video.visible = true
	_quieto.visible = false
	_reflejo.texture = _video.get_video_texture()

func _process(delta: float) -> void:
	if _barco == null or not lanzado:
		return
	if _barco_t < 0.0:
		# el relevo, a la vez que el video
		var desde := float(_barco_d["desde"])
		if _video.stream_position < desde:
			return
		_barco_t = _video.stream_position - desde
		_barco.visible = true
		_barco_reflejo.visible = true
		_espuma.visible = true
	else:
		_barco_t += delta
	if _barco_t > barco_dura:
		_barco.queue_free()
		_barco_reflejo.queue_free()
		_espuma.queue_free()
		_barco = null
		return
	# el remo: del fotograma del relevo (el ultimo) hacia atras y vuelta
	var n := _barco_fot.size()
	var f := int(_barco_t * float(_barco_d["fps"])) % maxi(2 * (n - 1), 1)
	var i := n - 1 - f if f < n else f - n + 1
	var tex := _barco_fot[i]
	_barco.texture = tex
	_barco_reflejo.texture = tex
	# un poco mas metido en el agua, poco a poco tras el relevo: lo de abajo,
	# recortado, y el barco bajado lo mismo (la linea del agua no se mueve)
	var hondo := float(_barco_d.get("hundir", 0.0)) * smoothstep(0.0, hundir_en, _barco_t)
	var sz := tex.get_size() - Vector2(0.0, hondo)
	for s in [_barco, _barco_reflejo]:
		s.region_enabled = true
		s.region_rect = Rect2(Vector2.ZERO, sz)
	var x := float(_barco_d["x"]) + float(_barco_d["velocidad"]) * _barco_t
	_barco.position = Vector2(x, float(_barco_d["y"]) + hondo)
	_barco_reflejo.position = Vector2(x, float(_barco_d["y"]) + tex.get_height())
	# la espuma, con el barco; el remo salpica en sus fotogramas
	var esp: Dictionary = _barco_d["espuma"]
	_espuma.position = Vector2(x - ESTELA * _px, float(_barco_d["y"]) + float(esp["linea"]) - 6.0 * _px)
	_espuma_mat.set_shader_parameter("avance", float(_barco_d["velocidad"]) * _barco_t / _px)
	var sal: Array = esp["salpica"]
	_espuma_mat.set_shader_parameter("salpica", smoothstep(float(sal[0]) - 2.0, float(sal[0]) + 4.0, float(i)))
	_espuma_mat.set_shader_parameter("fuerza", espuma_fuerza * clampf(_barco_t / espuma_entra, 0.0, 1.0))

func _al_acabar() -> void:
	_quieto.texture = _ultimo
	_reflejo.texture = _ultimo
	_quieto.visible = true
	_video.visible = false
	acabado.emit()

func _material(d: Dictionary, es_reflejo: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	# (templo.json "grado": filas = canal de salida RGB, la ultima columna se suma)
	var g: Array = d["grado"]
	m.set_shader_parameter("grado", Basis(_columna(g, 0), _columna(g, 1), _columna(g, 2)))
	m.set_shader_parameter("grado_add", _columna(g, 3))
	m.set_shader_parameter("reflejo", es_reflejo)
	m.set_shader_parameter("px", _px)
	# (templo.json "velo": color 0-255 y cuanto)
	if d.has("velo"):
		m.set_shader_parameter("velo_color", _v3(d["velo"]["color"]) / 255.0)
		m.set_shader_parameter("velo", float(d["velo"]["cuanto"]))
	return m

func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _columna(g: Array, j: int) -> Vector3:
	return Vector3(float(g[0][j]), float(g[1][j]), float(g[2][j]))
