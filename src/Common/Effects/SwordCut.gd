extends Node2D

const DURATION := 0.14
const PATHS := {
    "down": [[2, -34], [14, -30], [25, -20], [22, -5]],
    "sweep": [[-3, -15], [10, -18], [25, -17], [33, -13]],
    "thrust": [[8, -14], [36, -14]],
    "backsweep": [[33, -13], [25, -17], [10, -18], [-3, -15]],
    "rise_back": [[22, -5], [25, -20], [14, -30], [2, -34]],
    "rise": [[6, -5], [23, -13], [26, -25], [10, -36]]
}

var kind := "rise"
var facing := 1.0
var _age := 0.0
var _path := PackedVector2Array()


func _ready() -> void:
	scale.x = facing
	for point in PATHS[kind]:
		_path.append(Vector2(point[0], point[1]))


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	if _path.size() < 2:
		return
	var progress := clampf(_age / DURATION, 0.0, 0.999)
	var start := progress * (_path.size() - 1)
	var segment := int(start)
	var points := PackedVector2Array([_path[segment].lerp(_path[segment + 1], start - segment).round()])
	for i in range(segment + 1, _path.size()):
		points.append(_path[i])
	var alpha := 1.0 - progress
	draw_polyline(points, Color(0.55, 0.8, 1.0, alpha * 0.8), 3.0)
	draw_polyline(points, Color(1.0, 1.0, 1.0, alpha), 1.0)
	if kind == "thrust":
		for offset in [-3, 3]:
			draw_line(Vector2(minf(23.0, 10.0 + progress * 20.0), -14 + offset).round(), Vector2(27, -14 + offset), Color(0.55, 0.8, 1.0, alpha * 0.6))
