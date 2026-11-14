class_name PlayerStateAttack01
extends PlayerAbstractStateMotion

var _elapsed := 0.0
var _buffered := ""
var _buffered_at := -1.0
var _impacted := false
var _next_hit := 0
var _last_press := 0.0
var _strike: Dictionary


func enter():
	_elapsed = 0.0
	_last_press = 0.0
	_buffered = ""
	_buffered_at = -1.0
	_impacted = false
	_next_hit = 0
	_strike = CombatChain.strike(owner.get_node("StateMachine").combo_sequence)
	owner.begin_strike(_strike)
	if _strike.get("mash", false):
		owner.combo_feedback.emit("KEEP TAPPING QUICK / HEAVY")
	var stage: int = owner.get_node("StateMachine").combo_sequence.length()
	var animation := "attacking_heavy_right" if _strike.heavy else "attacking_%02d_right" % stage
	if _strike.finisher:
		animation = _strike.animation
	var animator: AnimationPlayer = owner.get_node("BodyPivot/AnimationPlayer")
	animator.speed_scale = animator.get_animation(animation).length / float(_strike.duration)
	animator.stop()
	play_animation(animation)


func handle_input(_event):
	var press: String = owner.get_node("StateMachine").attack_press
	if press != "" and _strike.get("mash", false):
		_last_press = _elapsed
	if press == "":
		return
	if _elapsed < float(_strike.input_open):
		owner.combo_feedback.emit("KEEP TAPPING QUICK / HEAVY" if _strike.get("mash", false) else "TOO EARLY")
		return
	_buffered = press
	_buffered_at = _elapsed
	owner.combo_feedback.emit("INPUT BUFFERED")


func update(delta):
	_elapsed += delta
	if _buffered != "" and _elapsed - _buffered_at > CombatChain.BUFFER_SECONDS:
		_buffered = ""
		owner.combo_feedback.emit("TOO EARLY - INPUT EXPIRED")
	if _strike.finisher:
		if _strike.get("mash", false) and _next_hit < _strike.hits.size() and _elapsed - _last_press > CombatChain.MASH_WINDOW and _buffered == "":
			owner.combo_feedback.emit("COMBO STOPPED - KEEP TAPPING")
			emit_signal("finished", STATE_WALK)
			return
		while _next_hit < _strike.hits.size() and _elapsed >= float(_strike.hits[_next_hit]):
			owner.combo_impact(_strike, _next_hit)
			_next_hit += 1
	elif not _impacted and _elapsed >= float(_strike.impact):
		_impacted = true
		owner.strike_impact(_strike)
	# coup suivant déjà demandé : on annule la fin d'animation (récupération)
	if _buffered != "" and _elapsed >= float(_strike.cancel):
		_chain()


func exit():
	owner.end_strike()
	owner.get_node("BodyPivot/AnimationPlayer").speed_scale = 1.0


func _on_animation_finished(_anim_name):
	if _buffered != "":
		_chain()
	else:
		emit_signal("finished", STATE_WALK)


func _chain():
	var machine: PlayerStateMachine = owner.get_node("StateMachine")
	owner.combo_feedback.emit("CHAIN ACCEPTED")
	var next := _buffered
	_buffered = ""
	if _strike.finisher:
		machine.combo_sequence = next
		emit_signal("finished", STATE_ATTACK01)
	else:
		machine.combo_sequence += next
		emit_signal("finished", "Attack%02d" % machine.combo_sequence.length())
