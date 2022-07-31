class_name PlayerStateAttack01
extends PlayerAbstractStateMotion

var speed = 0.0
var velocity = Vector2()

var _event_count=0

func enter():
	play_animation(ANIM_ATTACK_01_RIGHT)
	_event_count=0

func handle_input(event):
	if(event.is_action_pressed(INPUT_ATTACK)):
		_event_count+=1
	return .handle_input(event)

func update(delta):
	return


func _on_animation_finished(anim_name):
	if _event_count > 1:
		emit_signal("finished",STATE_ATTACK02)
	else:
		emit_signal("finished", STATE_WALK)
