class_name Bandada
extends Node2D
## LA BANDADA DE LA CAIDA (2026-10-29, el usuario: "un grupo de palomas juntas a
## la derecha de la caida del peregrino, como si estuvieran ahi tranquilas
## comiendo; cuando cae el peregrino y hace el ruido, salen volando, algunas se
## van y otras se posan mas alejadas en el templo de piedra").
##   - Comiendo en el suelo (pajaro_posado.gd, comiendo): picotean, andan a
##     pasitos y miran, cada una en su trozo (tramos). Las de mas abajo, delante
##     (y_sort).
##   - Su arrullo en bucle donde estan (palomas_arrullo.ogg, del video del
##     usuario), que se apaga al espantarse.
##   - Con el golpe de la caida (peregrino.impacto) se espantan todas: las mas
##     cercanas antes, cada una con su retraso; suena la espantada del video.
##     Una parte (posan) va a posarse a los posaderos (repisas del templo mas
##     alla), repartidas sin pisarse; las demas se van. Las palomas sueltas de
##     cerca (vecinas, a menos de radio_vecinas) tambien se van.
##   - Si no hay caida (el piloto) y el peregrino llega andando, se espantan
##     igual, todas a la vez. Y otra vez cuando han vuelto a comer (_rearmar).

const ARRULLO := preload("res://assets/audio/palomas_arrullo.ogg")
const ESPANTADA := preload("res://assets/audio/palomas_espantada.ogg")

@export var arrullo_db := -13.0
@export var espantada_db := -3.0
@export var posan := 0.45            # la parte de la bandada que se posa en el templo
@export var cerca := 300.0           # px: si el peregrino llega andando a esto, se espantan
@export var radio_vecinas := 1200.0
@export var hueco := 26.0            # px minimos entre dos palomas comiendo

var peregrino: Node2D
var estudio: EstudioPalomas
## Las palomas sueltas del recorrido (se espantan con el golpe si estan cerca).
var vecinas: Array = []
var palomas: Array[PajaroPosado] = []

var _posaderos: Array = []           # [x0, x1, y de los pies]
var _arrullo: AudioStreamPlayer2D
var _espantada := false
var _x := Vector2(INF, -INF)         # de donde a donde comen
var _y := 0.0
var _rng := RandomNumberGenerator.new()

## d (recorrido.json "bandada"): "tramos" [[x0, x1, altura, cuantas]] donde
## comen y "posaderos" [[x0, x1, altura]] donde se posan; alturas sobre los
## pies en la arena (pies).
func montar(d: Dictionary, pies: float) -> void:
	y_sort_enabled = true
	_rng.seed = 29
	var acum := 0.0
	var n_total := 0
	for t in d["tramos"]:
		var x0: float = t[0]
		var x1: float = t[1]
		var y: float = pies - float(t[2])
		var xs: Array[float] = []
		for i in int(t[3]):
			var x := 0.0
			for intento in 30:
				x = _rng.randf_range(x0 + 12.0, x1 - 12.0)
				if xs.all(func(o: float) -> bool: return absf(o - x) > hueco):
					break
			xs.append(x)
		for x in xs:
			var b := PajaroPosado.new()
			b.plumaje = _plumaje()
			b.comiendo = true
			b.zona = Vector2(x0, x1)
			b.espanto_cerca = false
			b.sentido = 1.0 if _rng.randf() < 0.5 else -1.0
			# (algo de fondo: unas un pelo mas atras que otras)
			b.position = Vector2(x, y + _rng.randf_range(-4.0, 4.0))
			b.peregrino = peregrino
			b.estudio = estudio
			add_child(b)
			palomas.append(b)
			acum += y
			n_total += 1
		_x = Vector2(minf(_x.x, x0), maxf(_x.y, x1))
	_y = acum / maxf(n_total, 1)
	for p in d.get("posaderos", []):
		_posaderos.append([float(p[0]), float(p[1]), pies - float(p[2])])
	_arrullo = AudioStreamPlayer2D.new()
	var s := ARRULLO.duplicate() as AudioStreamOggVorbis
	s.loop = true
	_arrullo.stream = s
	_arrullo.volume_db = arrullo_db
	_arrullo.max_distance = 2800.0
	_arrullo.position = Vector2((_x.x + _x.y) * 0.5, _y)
	add_child(_arrullo)
	_arrullo.play(_rng.randf_range(0.0, 7.0))
	if peregrino and peregrino.has_signal("impacto"):
		peregrino.impacto.connect(func() -> void: espantar(peregrino.position))

## Cual le toca (FRECUENCIA: mas bravias que blancas o rojas).
func _plumaje() -> int:
	var r := _rng.randf()
	for i in PajaroPosado.FRECUENCIA.size():
		r -= PajaroPosado.FRECUENCIA[i]
		if r <= 0.0:
			return i
	return 0

func _process(_delta: float) -> void:
	if peregrino == null:
		return
	if _espantada:
		_rearmar()
		return
	var p := peregrino.position
	if p.x > _x.x - cerca and p.x < _x.y + cerca and absf(p.y - _y) < 400.0:
		espantar(p)

## Que se espanten todas por un ruido en origen.
func espantar(origen: Vector2) -> void:
	if _espantada:
		return
	_espantada = true
	var tw := create_tween()
	tw.tween_property(_arrullo, "volume_db", -60.0, 0.6)
	tw.tween_callback(_arrullo.stop)
	var a := AudioStreamPlayer2D.new()
	a.stream = ESPANTADA
	a.volume_db = espantada_db
	a.max_distance = 3200.0
	a.position = _arrullo.position
	add_child(a)
	a.play()
	# cuales se posan (al azar) y donde (sin pisarse en la repisa)
	var orden := palomas.duplicate()
	orden.shuffle()
	var cuantas := roundi(palomas.size() * posan) if not _posaderos.is_empty() else 0
	var puestas: Array[Vector2] = []
	for i in orden.size():
		var b: PajaroPosado = orden[i]
		var destino := Vector2.INF
		if i < cuantas:
			destino = _sitio(puestas)
			if destino != Vector2.INF:
				puestas.append(destino)
		# las de cerca del golpe, antes
		var retraso := 0.05 + absf(b.position.x - origen.x) / 3000.0 + _rng.randf_range(0.0, 0.3)
		b.asustar(retraso, destino, false)
	for v in vecinas:
		var pv := v as PajaroPosado
		if pv and absf(pv.position.x - origen.x) < radio_vecinas:
			pv.asustar(_rng.randf_range(0.15, 0.5), Vector2.INF, false)

## Cuando han vuelto todas a comer (pajaro_posado.gd: las que se fueron vuelven a
## su sitio al rato, con el peregrino lejos), la bandada vuelve a espantarse si
## se acerca (2026-10-29, el usuario: "hay muchas palomas abajo en el suelo, si
## pasamos se deberian asustar"; antes solo se espantaban una vez).
func _rearmar() -> void:
	if not palomas.any(func(b: PajaroPosado) -> bool: return b.comiendo):
		return
	for b in palomas:
		if b.volando() or not b.visible:
			return
	_espantada = false
	_arrullo.volume_db = arrullo_db
	_arrullo.play(_rng.randf_range(0.0, 7.0))

func _sitio(puestas: Array[Vector2]) -> Vector2:
	for intento in 30:
		var p: Array = _posaderos[_rng.randi_range(0, _posaderos.size() - 1)]
		var s := Vector2(_rng.randf_range(p[0], p[1]), p[2])
		if puestas.all(func(o: Vector2) -> bool: return o.distance_to(s) > 36.0):
			return s
	return Vector2.INF
