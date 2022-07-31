class_name PlayerStateIdle
extends PlayerAbstractStateMotion

var speed = 0.0
var velocity = Vector2()


func enter():
	play_animation(ANIM_IDLE)

func handle_input(event):
	return .handle_input(event)

func update(delta):
	var input_direction = get_input_direction()
	if input_direction:
		emit_signal("finished", STATE_WALK)
