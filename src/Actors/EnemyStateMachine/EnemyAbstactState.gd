class_name EnemyAbstractState
extends AbstractState

const STATE_IDLE="Idle"
const STATE_WALK="Walk"
const STATE_ATTACK01="Attack01"
const STATE_DAMAGED="Damaged"
const STATE_DIED="Died"


const ANIM_IDLE="idle"
const ANIM_WALK_RIGHT="walking_right"
const ANIM_DAMAGED="damaged"
const ANIM_DIED="died"

const ANIM_ATTACK_01_RIGHT="attacking_01_right"

var current_animation:="none"

func die():
	owner.get_parent().queue_free()

func play_animation(animation):
	print("animation:"+animation)
	return owner.get_parent().get_node("BodyPivot/AnimationPlayer").play(animation)
