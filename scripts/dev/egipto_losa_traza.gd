extends Node
## Prueba de la losa del altar (2026-10-31): escribe cada `cada` s lo fuera que
## esta la losa, lo hundido del altar y donde esta el peregrino.

@export var cada := 0.25

var _t := 0.0

func _physics_process(delta: float) -> void:
	_t += delta
	if fmod(_t, cada) >= delta:
		return
	var nivel := get_parent()
	var m = nivel.get("_mecanismo")
	var p: Node2D = nivel.get_node("DarkStage/Peregrino")
	if m == null:
		return
	var suelo: float = nivel.nivel["suelo"]
	print("losa %.2f e %.3f hundido %.2f x %.0f pies %.1f %s" % [_t, m.e, m._hundido, p.position.x, suelo - p.position.y,
		p.datos_movimiento()["estado"]])
