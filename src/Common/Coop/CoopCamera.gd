class_name CoopCamera
extends Camera2D

# Caméra du mode 2 joueurs : suit le milieu des joueurs encore debout et les garde
# tous les deux à l'écran (impossible de s'éloigner au-delà de la largeur de la vue).
# Ajoutée en dernier dans le niveau : son _physics_process passe après celui des joueurs.

const FOLLOW_SPEED := 4.0
const SCREEN_MARGIN := 10.0

var _players: Array = []
var _rect := Rect2()


func setup(players: Array, limit_rect: ReferenceRect) -> void:
	_players = players
	_rect = Rect2(limit_rect.global_position, limit_rect.size)
	limit_left = int(_rect.position.x)
	limit_top = int(_rect.position.y)
	limit_right = int(_rect.end.x)
	limit_bottom = int(_rect.end.y)
	global_position = clamp_center(target_position())
	make_current()
	reset_smoothing()


func alive_players() -> Array:
	return _players.filter(func(player): return is_instance_valid(player) and player.is_alive())


func target_position() -> Vector2:
	var alive := alive_players()
	if alive.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for player in alive:
		sum += player.global_position
	return sum / alive.size()


func half_view() -> Vector2:
	return get_viewport_rect().size / zoom / 2.0


func clamp_center(center: Vector2) -> Vector2:
	var half := half_view()
	center.x = clampf(center.x, _rect.position.x + half.x, maxf(_rect.position.x + half.x, _rect.end.x - half.x))
	center.y = clampf(center.y, _rect.position.y + half.y, maxf(_rect.position.y + half.y, _rect.end.y - half.y))
	return center


func _physics_process(delta: float) -> void:
	var target := clamp_center(target_position())
	global_position = global_position.lerp(target, minf(1.0, FOLLOW_SPEED * delta))

	var half := half_view()
	var left := global_position.x - half.x + SCREEN_MARGIN
	var right := global_position.x + half.x - SCREEN_MARGIN
	for player in alive_players():
		player.global_position.x = clampf(player.global_position.x, left, right)
