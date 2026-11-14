class_name TrainingDummy
extends Enemy

signal respawned
signal training_life_changed(value: float)

const MAX_TRAINING_LIFE := 100.0
const RESPAWN_DELAY := 0.6
# dégâts affichés au-dessus de la jauge : or pour les gros coups (finisher lourd, slam)
const DAMAGE_TEXT_OFFSET := Vector2(0, -44)
const DAMAGE_TEXT_COLOR := Color("fff0bf")
const DAMAGE_TEXT_COLOR_BIG := Color("ffd34d")
const BIG_DAMAGE := 30

var spawn_position := Vector2.ZERO
var respawn_count := 0
var is_respawning := false
var _feedback_tween: Tween


func _ready() -> void:
	spawn_position = global_position
	_stateMachine.set_active(false)
	_hitBox.monitoring = false
	collision_layer = BODY_LAYER
	collision_mask = 0
	_material = Fx.character_material(_sprite)
	Fx.shadow(self, 14).position = Vector2(0, -1)
	Fx.cast_shadow(self, _sprite)
	style_life_bar(_enemy_progress_bar, Color("ffbd69"))
	_enemy_progress_bar.position = Vector2(-18, -36)
	_enemy_progress_bar.size = Vector2(36, 4)
	_enemy_progress_bar.max_value = MAX_TRAINING_LIFE
	_animationPlayer.animation_finished.connect(_on_training_animation_finished)
	reset_target()


func _physics_process(_delta: float) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	pass


func took_damage(damage: int) -> void:
	if is_respawning or damage <= 0:
		return
	_life = maxf(0.0, _life - damage)
	_enemy_progress_bar.value = _life
	training_life_changed.emit(_life)
	Sound.play("hit", 0.1)
	Fx.hit_spark(get_parent(), global_position + Vector2(0, -12))
	Fx.floating_text(get_parent(), str(damage), global_position + DAMAGE_TEXT_OFFSET, DAMAGE_TEXT_COLOR_BIG if damage >= BIG_DAMAGE else DAMAGE_TEXT_COLOR)
	if _feedback_tween:
		_feedback_tween.kill()
	modulate = Color(1.7, 1.7, 1.7)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	if _life <= 0:
		is_respawning = true
		collision_layer = 0
		remove_from_group(Game.GROUP_ENEMY)
		_animationPlayer.play("died")
	else:
		_animationPlayer.play("damaged")


func _on_training_animation_finished(animation: StringName) -> void:
	if animation == &"died" and is_respawning:
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		if is_inside_tree():
			respawn_count += 1
			reset_target()
			respawned.emit()
	elif not is_respawning:
		_animationPlayer.play("idle")


func reset_target() -> void:
	_life = MAX_TRAINING_LIFE
	is_respawning = false
	last_attacker = null
	global_position = spawn_position
	modulate = Color.WHITE
	collision_layer = BODY_LAYER
	add_to_group(Game.GROUP_ENEMY)
	_enemy_progress_bar.value = _life
	_enemy_progress_bar.show()
	_animationPlayer.play("idle")
	training_life_changed.emit(_life)
