class_name EnemyStateIdle
extends EnemyAbstractStateMotion

var speed = 0.0
var velocity = Vector2()


func enter():
	play_animation(ANIM_IDLE)

func handle_input(event):
	return super.handle_input(event)


# En attente (place en retrait) : repart dès que la place bouge ou qu'une place
# au contact se libère
func update(_delta):
	if is_near_player():
		emit_signal("finished", STATE_ATTACK01)
	elif get_input_direction():
		emit_signal("finished", STATE_WALK)
