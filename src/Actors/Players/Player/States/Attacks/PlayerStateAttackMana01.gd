class_name PlayerStateManaAttack01
extends PlayerAbstractStateMotion

var speed = 0.0
var velocity = Vector2()

var _event_count=0

func enter():
	play_animation(ANIM_ATTACK_MANA_01_RIGHT)
	_event_count=0
	



func _on_animation_finished(anim_name):
	emit_signal("finished", STATE_WALK)
