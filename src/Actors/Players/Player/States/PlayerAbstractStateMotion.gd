class_name PlayerAbstractStateMotion
# Collection of important methods to handle direction and animation
extends PlayerAbstractState



func get_input_direction():
	var input_direction = Vector2()
	input_direction.x = int(Input.is_action_pressed(INPUT_RIGHT)) - int(Input.is_action_pressed(INPUT_LEFT))
	input_direction.y = int(Input.is_action_pressed(INPUT_DOWN)) - int(Input.is_action_pressed(INPUT_UP))
	return input_direction

func update_look_direction(direction):
	if direction and owner.look_direction != direction:
		owner.look_direction = direction
	if not direction.x in [-1, 1]:
		return
	owner.get_node("BodyPivot").set_scale(Vector2(direction.x, 1))
