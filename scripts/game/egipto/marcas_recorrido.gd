class_name MarcasRecorrido
extends Node2D
## MARCAR FALLOS DEL RECORRIDO (2026-10-28; el usuario: como le digo donde
## queda mal el peregrino respecto a las piedras, sin depender de la pantalla).
## Todo va en coordenadas del juego, no de la pantalla:
##   F3  ver u ocultar lo que se pisa: las cajas de recorrido.json (verde: la
##       cara de arriba, lo que se pisa; rojo: la caja; su nombre, el de
##       recorrido.json), los pies del peregrino y, arriba, donde esta.
##   F4  marcar un fallo: guarda la pantalla (con las cajas a la vista) y una
##       linea en marcas.jsonl con el sitio, la caja que pisa, el estado y la
##       animacion, en raw/master_builder/egipto_marcas/. Luego basta con decir
##       "la marca 3: ..." y que esta mal.

const CARPETA := "res://raw/master_builder/egipto_marcas"

var acciones: Node            # acciones_egipto.gd
var peregrino: Node2D

var _ver := false
var _hud: Label
var _aviso: Label
var _t_aviso := 0.0
var _n := 0

func _ready() -> void:
	z_index = 40
	visible = false
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(40, 40)
	_hud.add_theme_font_size_override("font_size", 30)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 8)
	_hud.visible = false
	capa.add_child(_hud)
	_aviso = Label.new()
	_aviso.position = Vector2(40, 100)
	_aviso.add_theme_font_size_override("font_size", 40)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 10)
	_aviso.modulate.a = 0.0
	capa.add_child(_aviso)
	# la siguiente marca, tras las que ya haya
	var ruta := ProjectSettings.globalize_path(CARPETA + "/marcas.jsonl")
	if FileAccess.file_exists(ruta):
		_n = FileAccess.get_file_as_string(ruta).strip_edges().split("\n").size()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F3:
		_ver = not _ver
		visible = _ver
		_hud.visible = _ver
		queue_redraw()
	elif k.keycode == KEY_F4:
		_marcar()

func _process(delta: float) -> void:
	if _t_aviso > 0.0:
		_t_aviso -= delta
		_aviso.modulate.a = clampf(_t_aviso, 0.0, 1.0)
	if _ver:
		_hud.text = _texto()
		queue_redraw()

## La caja que pisa (o "arena").
func _caja_bajo_los_pies() -> String:
	var p := peregrino.position
	for c in acciones.recorrido["cajas"]:
		if p.x >= float(c["x0"]) and p.x <= float(c["x1"]) and absf(-float(c["arriba"]) - p.y) < 3.0:
			return String(c["nombre"])
	return "arena" if absf(p.y) < 3.0 else "-"

func _texto() -> String:
	var dm: Dictionary = peregrino.datos_movimiento()
	return "x %.0f  altura %.0f  pisa %s  %s / %s" % [peregrino.position.x, -peregrino.position.y,
			_caja_bajo_los_pies(), dm["estado"], dm["animacion"]]

func _draw() -> void:
	if acciones == null or acciones.recorrido.is_empty():
		return
	var fuente := ThemeDB.fallback_font
	for c in acciones.recorrido["cajas"]:
		var x0 := float(c["x0"])
		var x1 := float(c["x1"])
		var ya := -float(c["arriba"])
		var yb := -float(c["abajo"])
		draw_rect(Rect2(x0, ya, x1 - x0, yb - ya), Color(1, 0.2, 0.2, 0.12))
		draw_rect(Rect2(x0, ya, x1 - x0, yb - ya), Color(1, 0.25, 0.2, 0.8), false, 3.0)
		draw_line(Vector2(x0, ya), Vector2(x1, ya), Color(0.2, 1, 0.3), 7.0)
		draw_string_outline(fuente, Vector2(x0 + 8, ya - 12), String(c["nombre"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color.BLACK)
		draw_string(fuente, Vector2(x0 + 8, ya - 12), String(c["nombre"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.6, 1, 0.6))
	# los pies (el nodo) y una raya a la altura de la cabeza (DESPEJE)
	var p := peregrino.position
	draw_circle(p, 12.0, Color(1, 0.9, 0.2))
	draw_line(p + Vector2(-60, -acciones.DESPEJE), p + Vector2(60, -acciones.DESPEJE), Color(1, 0.9, 0.2), 4.0)

func _marcar() -> void:
	var dir := ProjectSettings.globalize_path(CARPETA)
	DirAccess.make_dir_recursive_absolute(dir)
	_n += 1
	var antes := _ver
	visible = true
	_hud.visible = true
	_hud.text = "marca %d  %s" % [_n, _texto()]
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/marca_%02d.png" % [dir, _n])
	visible = antes
	_hud.visible = antes
	var dm: Dictionary = peregrino.datos_movimiento()
	var linea := {"marca": _n, "fecha": Time.get_datetime_string_from_system(), "x": snappedf(peregrino.position.x, 0.1),
			"altura": snappedf(-peregrino.position.y, 0.1), "pisa": _caja_bajo_los_pies(), "estado": dm["estado"],
			"animacion": dm["animacion"], "fotograma": dm["fotograma"], "mirando": peregrino.mirando()}
	var f := FileAccess.open(dir + "/marcas.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists(dir + "/marcas.jsonl") else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(linea))
	f.close()
	_aviso.text = "Marca %d guardada" % _n
	_t_aviso = 2.5
