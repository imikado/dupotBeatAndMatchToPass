class_name Bolt
extends Node2D

# Éclair procédural pixel art, en coordonnées locales.
# 3 Line2D : halo additif, cœur (couleur éclaircie), centre blanc HDR.
# Les branches (halo plus faible + cœur 1 px) partent du tracé principal vers « l'avant ».
#
# Utilisation :
#   var bolt := Bolt.new()
#   bolt.color = Fx.enemy_color(type)
#   add_child(bolt)
#   bolt.set_ends(Vector2(0, -4), Vector2(0, 78))   # génère une forme
#   bolt.regenerate()                               # nouvelle forme, à la demande (timer, tween…)
#   bolt.reveal(0.5)                                # traceur : moitié haute seulement
#   bolt.set_intensity(2.5)                         # > 1 : glow HDR
#
# Rien n'est recalculé à chaque image : seuls regenerate(), set_ends() et reveal()
# reconstruisent les points.

const HALO_WIDTH := 6.0
const CORE_WIDTH := 2.0
const CENTER_WIDTH := 1.0
const HALO_ALPHA := 0.3
# Le centre dépasse 1.0 : il brille avec le glow HDR même à l'intensité 1
const CENTER_HDR := 1.4
const BRANCH_HALO_WIDTH := 3.0
const BRANCH_HALO_ALPHA := 0.18
const BRANCH_DEPTH := 3
# Longueur de segment visée pour choisir la profondeur du tracé principal
const SEGMENT_LENGTH := 6.0
const MAX_DEPTH := 5

@export var color := Color(0.55, 0.75, 1.0):
	set(value):
		color = value
		_apply_style()
# multiplicateur des 3 largeurs (0 = invisible)
@export var thickness := 1.0:
	set(value):
		thickness = value
		_apply_style()
# déplacement max du tracé = longueur × jaggedness
@export var jaggedness := 0.25
@export var branch_count := 1

var _from := Vector2.ZERO
var _to := Vector2(0, 32)
var _ratio := 1.0
var _intensity := 1.0

# Forme normalisée : x le long de from→to (0..1), y perpendiculaire (en longueurs)
var _shape := PackedVector2Array()
var _branch_shapes: Array[PackedVector2Array] = []
var _branch_starts: Array[float] = []

# Points en pixels, calculés par _build()
var _points := PackedVector2Array()
var _branch_points: Array[PackedVector2Array] = []
# Halos (larges et diffus) : mêmes sommets sans les marches de 1 px, bien moins de
# géométrie (les jointures rondes sur chaque marche coûtaient des milliers de triangles)
var _halo_points := PackedVector2Array()
var _branch_halo_points: Array[PackedVector2Array] = []

var _halo: Line2D
var _core: Line2D
var _center: Line2D
# [halo, cœur] par branche, créés à la demande
var _branch_lines: Array = []


func _init() -> void:
	_halo = _new_line()
	_halo.material = Fx.additive_material()
	_halo.joint_mode = Line2D.LINE_JOINT_ROUND
	_core = _new_line()
	_center = _new_line()
	_apply_style()


# Tracé brisé par déplacement du point milieu, points arrondis au pixel puis
# découpés en marches de 1 px (seuls les coins sont gardés).
# offset : déplacement max total (perpendiculaire), depth : 2^depth segments
static func zigzag(from: Vector2, to: Vector2, offset: float, depth: int = 5) -> PackedVector2Array:
	return _staircase(_pixelize(_displace(from, to, offset, depth)))


# Change les extrémités en gardant la forme actuelle (pas de nouveau tirage) ;
# les prochains regenerate() utiliseront ces extrémités
func set_ends(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	if _shape.is_empty():
		regenerate()
	else:
		_build()


# Nouvelle forme et nouvelles branches, mêmes extrémités
func regenerate() -> void:
	var length := _from.distance_to(_to)
	var depth := clampi(ceili(log(maxf(length, 1.0) / SEGMENT_LENGTH) / log(2.0)), 1, MAX_DEPTH)
	_shape = _displace(Vector2.ZERO, Vector2(1, 0), jaggedness, depth)

	_branch_shapes.clear()
	_branch_starts.clear()
	for i in range(branch_count):
		var index := randi_range(_shape.size() / 5, _shape.size() * 4 / 5)
		var start := _shape[index]
		var side := 1.0 if randf() < 0.5 else -1.0
		var branch_length := randf_range(0.2, 0.4)
		var end := start + Vector2.from_angle(side * randf_range(0.3, 0.8)) * branch_length
		_branch_shapes.append(_displace(start, end, branch_length * maxf(jaggedness, 0.15), BRANCH_DEPTH))
		_branch_starts.append(start.x)
	_build()


# 0..1 : n'affiche que le début du tracé (traceur), branches comprises
func reveal(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_apply_reveal()


# 0 = invisible, 1 = normal, > 1 = HDR (glow). Pilote modulate.
func set_intensity(value: float) -> void:
	_intensity = maxf(value, 0.0)
	var k := maxf(_intensity, 1.0)
	modulate = Color(k, k, k, minf(_intensity, 1.0))


static func _displace(from: Vector2, to: Vector2, offset: float, depth: int) -> PackedVector2Array:
	var points := PackedVector2Array([from, to])
	var normal := (to - from).orthogonal().normalized()
	var amount := offset * 0.5
	for level in range(depth):
		var next := PackedVector2Array()
		for i in range(points.size() - 1):
			next.append(points[i])
			next.append((points[i] + points[i + 1]) * 0.5 + normal * randf_range(-amount, amount))
		next.append(points[points.size() - 1])
		points = next
		amount *= 0.5
	return points


# Arrondi au pixel, sans doublons consécutifs
static func _pixelize(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		var rounded := point.round()
		if result.is_empty() or result[result.size() - 1] != rounded:
			result.append(rounded)
	return result


func _to_pixels(shape: PackedVector2Array, stairs := true) -> PackedVector2Array:
	var axis := _to - _from
	var normal := axis.orthogonal()
	var points := PackedVector2Array()
	points.resize(shape.size())
	for i in range(shape.size()):
		points[i] = _from + axis * shape[i].x + normal * shape[i].y
	if not stairs:
		return _pixelize(points)
	return _staircase(_pixelize(points))


# Remplace chaque segment par des marches de 1 px (4-connexes), ne garde que les coins :
# les diagonales s'affichent en vrais pixels même quand l'écran est agrandi
static func _staircase(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var steps := PackedVector2Array([points[0]])
	for i in range(points.size() - 1):
		var p := points[i]
		var d := points[i + 1] - p
		var nx := int(absf(d.x))
		var ny := int(absf(d.y))
		var sx := signf(d.x)
		var sy := signf(d.y)
		var ix := 0
		var iy := 0
		while ix < nx or iy < ny:
			if iy >= ny or (ix < nx and (0.5 + ix) * ny < (0.5 + iy) * nx):
				p.x += sx
				ix += 1
			else:
				p.y += sy
				iy += 1
			steps.append(p)
	var result := PackedVector2Array([steps[0]])
	for i in range(1, steps.size() - 1):
		# coin : changement de direction
		if steps[i] - steps[i - 1] != steps[i + 1] - steps[i]:
			result.append(steps[i])
	result.append(steps[steps.size() - 1])
	return result


func _build() -> void:
	_points = _to_pixels(_shape)
	_halo_points = _to_pixels(_shape, false)
	_branch_points.clear()
	_branch_halo_points.clear()
	for shape in _branch_shapes:
		_branch_points.append(_to_pixels(shape))
		_branch_halo_points.append(_to_pixels(shape, false))
	while _branch_lines.size() < _branch_points.size():
		var halo := _new_line()
		halo.material = Fx.additive_material()
		halo.joint_mode = Line2D.LINE_JOINT_ROUND
		var core := _new_line()
		# derrière le tracé principal
		move_child(core, 0)
		move_child(halo, 0)
		_branch_lines.append([halo, core])
		_apply_style()
	_apply_reveal()


func _apply_reveal() -> void:
	var shown := _partial(_points, _ratio)
	_halo.points = _partial(_halo_points, _ratio)
	_core.points = shown
	_center.points = shown
	for i in range(_branch_lines.size()):
		var lines: Array = _branch_lines[i]
		var branch := PackedVector2Array()
		var branch_halo := PackedVector2Array()
		if i < _branch_points.size() and _ratio > _branch_starts[i]:
			# la branche se dessine pendant que le traceur avance de 0.3
			var branch_ratio := (_ratio - _branch_starts[i]) / 0.3
			branch = _partial(_branch_points[i], branch_ratio)
			branch_halo = _partial(_branch_halo_points[i], branch_ratio)
		lines[0].points = branch_halo
		lines[1].points = branch


static func _partial(points: PackedVector2Array, ratio: float) -> PackedVector2Array:
	if ratio >= 1.0 or points.size() < 2:
		return points
	if ratio <= 0.0:
		return PackedVector2Array()
	var at := ratio * (points.size() - 1)
	var index := int(at)
	var result := points.slice(0, index + 1)
	var tip := points[index].lerp(points[index + 1], at - index).round()
	if tip != result[result.size() - 1]:
		result.append(tip)
	return result


func _apply_style() -> void:
	if _halo == null:
		return
	_halo.width = HALO_WIDTH * thickness
	_halo.default_color = Color(color, HALO_ALPHA)
	_core.width = CORE_WIDTH * thickness
	_core.default_color = color.lightened(0.45)
	_center.width = CENTER_WIDTH * thickness
	_center.default_color = Color(CENTER_HDR, CENTER_HDR, CENTER_HDR)
	for lines in _branch_lines:
		lines[0].width = BRANCH_HALO_WIDTH * thickness
		lines[0].default_color = Color(color, BRANCH_HALO_ALPHA)
		lines[1].width = CENTER_WIDTH * thickness
		lines[1].default_color = color.lightened(0.6)


func _new_line() -> Line2D:
	var line := Line2D.new()
	line.antialiased = false
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	add_child(line)
	return line
