class_name PlayerStateDash
extends PlayerAbstractStateMotion

# Esquive : courte ruée dans la direction tenue (ou devant soi), invincible pendant la ruée
const DASH_SPEED = 230.0
const DASH_DURATION = 0.16

var _direction := Vector2.RIGHT
var _time := 0.0


func enter():
	var input_direction = get_input_direction()
	if input_direction == Vector2.ZERO:
		input_direction = Vector2(owner.get_node("BodyPivot").scale.x, 0)
	update_look_direction(input_direction)
	_direction = input_direction.normalized()
	_time = 0.0
	play_animation(ANIM_WALK_RIGHT)
	owner.dash_begin()


func exit():
	owner.dash_end()


func update(delta):
	_time += delta
	var body: CharacterBody2D = owner
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body.velocity = _direction * DASH_SPEED
	body.move_and_slide()
	if _time >= DASH_DURATION:
		emit_signal("finished", STATE_WALK)


func _on_animation_finished(_anim_name):
	return
