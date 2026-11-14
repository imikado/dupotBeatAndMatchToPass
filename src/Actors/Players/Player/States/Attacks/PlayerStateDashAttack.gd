class_name PlayerStateDashAttack
extends PlayerAbstractStateMotion

# Attaque en puissance : esquive + attaque. Courte préparation, ruée épée en avant
# qui frappe tout sur son passage (invincible pendant la ruée), puis récupération.
const WINDUP := 0.08
const RUSH := 0.20
const RECOVERY := 0.27
const RUSH_SPEED := 300.0

var _time := 0.0
var _direction := 1.0
var _rushing := false


func enter():
	_time = 0.0
	_rushing = false
	var input_x: float = get_input_direction().x
	if input_x != 0.0:
		update_look_direction(Vector2(input_x, 0))
	_direction = signf(owner.get_node("BodyPivot").scale.x)
	owner.velocity = Vector2.ZERO
	play_animation("dash_power")
	owner.power_attack_begin()


func exit():
	owner.power_attack_end()


func handle_input(_event):
	return


func update(delta):
	_time += delta
	var body: CharacterBody2D = owner
	if _time < WINDUP:
		return
	if not _rushing and _time < WINDUP + RUSH:
		_rushing = true
		owner.power_attack_rush()
	if _time < WINDUP + RUSH:
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		body.velocity = Vector2(_direction * RUSH_SPEED, 0)
		body.move_and_slide()
		owner.power_attack_hit()
		return
	if _rushing:
		_rushing = false
		body.velocity = Vector2.ZERO
		owner.power_attack_recover()
	if _time >= WINDUP + RUSH + RECOVERY:
		emit_signal("finished", STATE_WALK)


func _on_animation_finished(_anim_name):
	return
