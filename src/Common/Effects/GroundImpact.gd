extends Node2D

var radius := Vector2(44, 20)
var _age := 0.0
var _chips: Array[Vector2] = []
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	for i in range(24):
		_chips.append(Vector2(randf_range(-65, 65), randf_range(-90, -30)))
	for i in range(9):
		var direction := Vector2.from_angle(TAU * i / 9.0)
		var points := PackedVector2Array([Vector2.ZERO])
		for step in range(1, 5):
			points.append((direction * radius * step / 5.0 + Vector2(randf_range(-3, 3), randf_range(-2, 2))).round())
		_cracks.append(points)


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.65:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - _age / 0.65, 0.0, 1.0)
	for crack in _cracks:
		draw_polyline(crack, Color(0.15, 0.10, 0.08, fade), 2.0)
		if _age < 0.14:
			draw_polyline(crack, Color(1.0, 0.83, 0.45, fade), 1.0)
	var ring := PackedVector2Array()
	var expansion := minf(_age / 0.28, 1.0)
	for i in range(33):
		ring.append((Vector2.from_angle(TAU * i / 32.0) * radius * expansion).round())
	draw_polyline(ring, Color(0.95, 0.75, 0.45, fade), 1.0)
	for i in range(_chips.size()):
		var point := _chips[i] * _age + Vector2(0, 160 * _age * _age)
		var color := Color(0.65, 0.46, 0.27, fade) if i % 2 else Color(1.0, 0.84, 0.54, fade)
		draw_rect(Rect2(point.round(), Vector2(2, 2)), color)
