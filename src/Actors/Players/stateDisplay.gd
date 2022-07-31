extends Label

var start_position = Vector2()



func _on_Player_state_changed(states_stack):
	text = states_stack[0].get_name()


func _on_StateMachine_state_changed(current_state) -> void:
	text=current_state.get_name()
	pass # Replace with function body.
