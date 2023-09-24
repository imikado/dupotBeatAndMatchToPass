class_name PlayerStateGetLifeBottle
extends PlayerAbstractStateMotion

func enter():
	play_animation(ANIM_GET_LIFE_BOTTLE)

func handle_input(event):
	return .handle_input(event)
	
	
func _on_animation_finished(anim_name):
	emit_signal("finished", STATE_WALK)
