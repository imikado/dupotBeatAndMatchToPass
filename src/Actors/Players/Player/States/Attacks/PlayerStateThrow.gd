class_name PlayerStateThrow
extends PlayerAbstractStateMotion

# Jet de bombe : élan, lâcher à THROW_RELEASE, puis retour à la marche

var heavy := false
var _elapsed := 0.0
var _released := false


func enter():
	_elapsed = 0.0
	_released = false
	owner.throw_begin(heavy)
	var animator: AnimationPlayer = owner.get_node("BodyPivot/AnimationPlayer")
	animator.speed_scale = 1.0
	animator.stop()
	play_animation(Player.ANIM_THROW)


func update(delta):
	_elapsed += delta
	if not _released and _elapsed >= Player.THROW_RELEASE:
		_released = true
		owner.throw_release()


func exit():
	owner.throw_end()


func _on_animation_finished(_anim_name):
	emit_signal("finished", STATE_WALK)
