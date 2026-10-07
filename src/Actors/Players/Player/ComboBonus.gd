extends AnimatedSprite2D

signal combo_arrived

var _target:Node
var _is_moving := false

func _ready() -> void:
	play()
	

func set_target(target:Node):
	_target=target
	play()
	

func _on_ComboBonus_animation_finished() -> void:
	# also connected to animation_looped: Godot 4 no longer emits animation_finished for looping animations
	if _is_moving:
		return
	_is_moving = true

	var tween = create_tween()
	tween.tween_property(self,"global_position",_get_target_world_position(),1)
	
	tween.connect("finished", Callable(self, "_on_combo_finished"))

# the target lives in the HUD CanvasLayer (screen coordinates): convert it to world coordinates
func _get_target_world_position() -> Vector2:
	if _target == null:
		return global_position
	var screen_position: Vector2 = _target.get_global_transform_with_canvas().origin
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _on_combo_finished()->void:
	queue_free()
	
	emit_signal("combo_arrived")
	
