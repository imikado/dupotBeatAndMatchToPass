class_name EnemyStateDied
extends EnemyAbstractState

var speed = 0.0
var velocity = Vector2()


func enter():
	play_animation(ANIM_DIED)

func update(delta):
	return


func _on_animation_finished(anim_name):
	die()
