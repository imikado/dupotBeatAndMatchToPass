class_name EnemyStateAttack01
extends EnemyAbstractState

var speed = 0.0
var velocity = Vector2()


func enter():
	print("enter attacking")
	play_animation(ANIM_ATTACK_01_RIGHT)

func update(delta):
	return


func _on_animation_finished(anim_name):
	emit_signal("finished", STATE_WALK)
