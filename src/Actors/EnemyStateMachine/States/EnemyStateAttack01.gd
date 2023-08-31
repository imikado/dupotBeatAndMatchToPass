class_name EnemyStateAttack01
extends EnemyAbstractStateMotion

var speed = 0.0
var velocity = Vector2()

var current_direction

func save_and_update_look_direction(input_direction):
	update_look_direction(input_direction)
	current_direction=input_direction

func enter():
	print("enter attacking")
	var input_direction = get_input_direction()
	save_and_update_look_direction(input_direction)
	play_animation(ANIM_ATTACK_01_RIGHT)
	
	
func update(delta):
	return


func _on_animation_finished(anim_name):
	emit_signal("finished", STATE_WALK)
