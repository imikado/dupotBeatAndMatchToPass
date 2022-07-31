class_name PlayerStateDamaged
extends PlayerAbstractStateMotion

func enter():
	play_animation(ANIM_DAMAGED)

func handle_input(event):
	return .handle_input(event)
	
	
func _on_animation_finished(anim_name):
	emit_signal("finished", STATE_WALK)
