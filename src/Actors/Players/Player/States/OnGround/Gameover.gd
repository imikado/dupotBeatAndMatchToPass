extends PlayerAbstractStateMotion

func enter():
	play_animation(ANIM_GAMEOVER)

func handle_input(event):
	return .handle_input(event)
	
	
func _on_animation_finished(anim_name):
	Events.emit_signal("player_gameover")
