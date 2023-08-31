class_name EnemyAbstractStateMotion
# Collection of important methods to handle direction and animation
extends EnemyAbstractState



func get_input_direction()->Vector2:
	return owner.get_parent().get_target_direction()


func is_near_player()->bool:
	return owner.get_parent().is_near_player()
	
	
func update_look_direction(direction):

	if direction and owner.get_parent().look_direction != direction:
		owner.get_parent().look_direction = direction
	
		var enemy_side=Vector2(0,1)
		if direction.x < 0:
			enemy_side.x=-1
		else:
			enemy_side.x=1
		
		owner.get_parent().get_node("BodyPivot").set_scale(enemy_side)
