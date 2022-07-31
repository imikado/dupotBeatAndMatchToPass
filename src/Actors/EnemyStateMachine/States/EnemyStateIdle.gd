class_name EnemyStateIdle
extends EnemyAbstractStateMotion

var speed = 0.0
var velocity = Vector2()


func enter():
	play_animation(ANIM_IDLE)

func handle_input(event):
	return .handle_input(event)

