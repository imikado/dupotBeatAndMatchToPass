class_name PixelBar
extends Control

# Jauge dessinée pixel par pixel (coordonnées entières de la vue 320x180) :
# bord noir, reflet en haut, ombre en bas, graduations, et traînée qui montre
# la valeur perdue ou gagnée avant de rattraper la nouvelle valeur.

const BORDER_COLOR := Color("140c1c")
const BACKGROUND_COLOR := Color("30253a")
const LOSS_TRAIL_COLOR := Color("f4f4f4")
const GAIN_TRAIL_COLOR := Color("a8f0a0")

const TRAIL_DELAY := 0.35
const TRAIL_DURATION := 0.4
const FLASH_DURATION := 0.15

@export var max_value := 100.0
@export var fill_color := Color("44a840")
# Graduation tous les `segment` points (0 = aucune)
@export var segment := 10.0

var value := 0.0
var _trail_value := 0.0
var _flash := 0.0
# Gain en cours : la jauge rattrape la traînée par en dessous
var _gaining := false
var _blink_on := false
var _blink_color := Color.WHITE

var _trail_tween: Tween
var _flash_tween: Tween
var _blink_tween: Tween


func set_value(new_value: float, animate := true) -> void:
	new_value = clamp(new_value, 0.0, max_value)
	if not animate:
		value = new_value
		_trail_value = new_value
		_gaining = false
		queue_redraw()
		return

	var previous := value
	if is_equal_approx(new_value, previous):
		return

	if _trail_tween:
		_trail_tween.kill()

	var was_gaining := _gaining
	_gaining = new_value > previous
	if not _gaining:
		# Perte : la jauge chute tout de suite, la traînée claire reste puis se vide
		# (si un gain était en cours, sa cible n'a pas été atteinte : on part de la valeur affichée)
		_trail_value = previous if was_gaining else max(_trail_value, previous)
		value = new_value
		_trail_tween = create_tween()
		_trail_tween.tween_interval(TRAIL_DELAY)
		_trail_tween.tween_method(_set_trail_value, _trail_value, new_value, TRAIL_DURATION)
	else:
		# Gain : la traînée montre tout de suite la cible, la jauge la rejoint
		_trail_value = new_value
		_trail_tween = create_tween()
		_trail_tween.tween_method(_set_value_animated, previous, new_value, TRAIL_DURATION)

	queue_redraw()


func set_fill_color(color: Color) -> void:
	if fill_color == color:
		return
	fill_color = color
	queue_redraw()


func flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 0.8
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 0.8, 0.0, FLASH_DURATION)


# Clignotement par paliers (pas de fondu : reste dans l'esprit pixel art)
func start_blink(color: Color, period := 0.25) -> void:
	_blink_color = color
	if _blink_tween and _blink_tween.is_valid():
		return
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(_toggle_blink)
	_blink_tween.tween_interval(period)


func stop_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_blink_on = false
	queue_redraw()


func _toggle_blink() -> void:
	_blink_on = not _blink_on
	queue_redraw()


func _set_trail_value(trail: float) -> void:
	_trail_value = trail
	queue_redraw()


func _set_value_animated(animated: float) -> void:
	value = animated
	queue_redraw()


func _set_flash(amount: float) -> void:
	_flash = amount
	queue_redraw()


func _to_width(amount: float, inner_width: int) -> int:
	return int(round(inner_width * amount / max_value))


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	var inner_w := w - 2
	var inner_h := h - 2

	draw_rect(Rect2(0, 0, w, h), BORDER_COLOR)
	draw_rect(Rect2(1, 1, inner_w, inner_h), BACKGROUND_COLOR)

	var fill_w := _to_width(value, inner_w)
	var trail_w := _to_width(_trail_value, inner_w)

	if trail_w > fill_w:
		var trail_color := GAIN_TRAIL_COLOR if _gaining else LOSS_TRAIL_COLOR
		draw_rect(Rect2(1 + fill_w, 1, trail_w - fill_w, inner_h), trail_color)

	if fill_w > 0:
		var color := _blink_color if _blink_on else fill_color
		draw_rect(Rect2(1, 1, fill_w, inner_h), color)
		draw_rect(Rect2(1, 1, fill_w, 1), color.lightened(0.4))
		if inner_h > 2:
			draw_rect(Rect2(1, h - 2, fill_w, 1), color.darkened(0.35))

	if segment > 0.0:
		var tick := segment
		while tick < max_value - 0.01:
			var x := 1 + _to_width(tick, inner_w)
			draw_rect(Rect2(x, 2 if inner_h > 2 else 1, 1, max(inner_h - 2, 1)), Color(BORDER_COLOR, 0.45))
			tick += segment

	var flash_w: int = max(fill_w, trail_w)
	if _flash > 0.0 and flash_w > 0:
		draw_rect(Rect2(1, 1, flash_w, inner_h), Color(1, 1, 1, _flash))

