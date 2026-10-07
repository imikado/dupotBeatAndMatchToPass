class_name Player
extends Actor

const MAX_LIFE = 100.0
var _life := 100.0

const STATE_ATTACK02 = "Attack02"
const STATE_ATTACK03 = "Attack03"
const STATE_ATTACK04 = "Attack04"
const STATE_ATTACK_MANA01 = "AttackMana01"

const STORM_DARK = Color(0.3, 0.33, 0.55)
const STORM_FLASH = Color(1.5, 1.5, 1.8)
const STORM_FLASH_SOFT = Color(0.9, 0.95, 1.25)
const AURA_COLOR = Color(0.45, 0.7, 1.0)

const INVINCIBILITY_DURATION = 0.8
const INVINCIBILITY_BLINK = 0.08

var _damage = 10

#onready var _animationTree := get_node("AnimationTree")
@onready var _camera := get_node("Camera2D")
@onready var _stateDisplay := get_node("stateDisplay")

@onready var _hitBox := get_node("BodyPivot/HitBox/CollisionShape2D")

@onready var _stateMachine := get_node("StateMachine")

@onready var _manaFalling := get_node("ManaFalling")

var look_direction = Vector2(1, 0): set = set_look_direction

var _cameraLimitRect: ReferenceRect

var _mana_count = 0

var _state: String = "idle"

var _is_invincible := false

var _canvas_modulate: CanvasModulate
var _parallax_layers := {}
var _tint_tween: Tween
var _aura_particles: CPUParticles2D
var _aura_light: PointLight2D
var _aura_tween: Tween


func _ready() -> void:
	updateLife(_life)

	_stateDisplay.visible = Game.is_debug()
	#manaAttackParticules.emitting = false
	_manaFalling.visible = false

	_hitBox.disabled = true

	mana_attack_end()
	#mana_attack_start()

	build_storm_effects()


func build_storm_effects() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = Color.WHITE
	add_child(_canvas_modulate)

	_aura_light = Fx.light(self, AURA_COLOR, 0.9)
	_aura_light.position = Vector2(0, -12)

	_aura_particles = CPUParticles2D.new()
	_aura_particles.emitting = false
	_aura_particles.amount = 24
	_aura_particles.lifetime = 0.7
	_aura_particles.position = Vector2(0, -4)
	_aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_aura_particles.emission_sphere_radius = 10.0
	_aura_particles.direction = Vector2.UP
	_aura_particles.spread = 15.0
	_aura_particles.gravity = Vector2(0, -60)
	_aura_particles.initial_velocity_min = 10.0
	_aura_particles.initial_velocity_max = 25.0
	_aura_particles.scale_amount_min = 1.0
	_aura_particles.scale_amount_max = 2.0
	_aura_particles.material = Fx.additive_material()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.95, 1.0, 1.0))
	ramp.set_color(1, Color(0.3, 0.5, 1.0, 0.0))
	_aura_particles.color_ramp = ramp
	add_child(_aura_particles)

	var bolts = _manaFalling.get_children()
	for i in range(bolts.size()):
		bolts[i].set_has_light(i % 3 == 0)


func set_look_direction(value):
	look_direction = value


func updateLife(newLife: float):
	_life = clamp(newLife, 0.0, MAX_LIFE)
	Events.emit_signal("player_health_changed", (_life / MAX_LIFE) * 100)


func set_life(newLife: float):
	_life = clamp(newLife, 0.0, MAX_LIFE)


func heal(amount: float):
	updateLife(_life + amount)


func took_damage(damage: int):
	if _is_invincible or _life <= 0 or _state == STATE_ATTACK_MANA01:
		return

	updateLife(_life - damage)
	if _life <= 0:
		return

	Sound.play("player_hurt")
	_stateMachine.set_damaged()
	shake_camera(4.0, 0.25)
	start_invincibility()


func start_invincibility():
	_is_invincible = true

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	var blink_count = int((INVINCIBILITY_DURATION - 0.2) / (INVINCIBILITY_BLINK * 2))
	for i in range(blink_count):
		tween.tween_property(self, "modulate:a", 0.3, INVINCIBILITY_BLINK)
		tween.tween_property(self, "modulate:a", 1.0, INVINCIBILITY_BLINK)

	tween.tween_callback(func(): _is_invincible = false)


func shake_camera(strength: float, duration: float):
	var tween = create_tween()
	var steps = int(duration / 0.05)
	for i in range(steps):
		var decay = 1.0 - float(i) / steps
		var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * decay
		tween.tween_property(_camera, "offset", shake_offset, 0.05)
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.05)


func get_life_bottle():
	_stateMachine.get_life_bottle()


func gameover():
	_stateMachine.gameover()


func blink_green():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	tween.tween_property(self, "modulate", Color.GREEN, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func set_camera_limit_rect(referenceRect: ReferenceRect):
	_cameraLimitRect = referenceRect

	var cameraLimitRectGlobalPosition = _cameraLimitRect.global_position
	var cameraLimitRectSize = _cameraLimitRect.size + cameraLimitRectGlobalPosition

	_camera.limit_left = cameraLimitRectGlobalPosition.x
	_camera.limit_top = cameraLimitRectGlobalPosition.y
	_camera.limit_right = cameraLimitRectSize.x
	_camera.limit_bottom = cameraLimitRectSize.y


func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage", body, _damage)
	elif body.is_in_group(Game.GROUP_BONUSACTOR):
		if body.can_let_item():
			body.let_item()
			Events.emit_signal("actor_let_item", body)
			print("hit bonusactor")
	pass  # Replace with function body.


func mana_cast_begin() -> void:
	_parallax_layers.clear()
	for layer in get_tree().root.find_children("*", "ParallaxLayer", true, false):
		_parallax_layers[layer] = layer.modulate
	tint_world(STORM_DARK, 0.3)

	_aura_particles.emitting = true
	_aura_light.enabled = true
	_aura_light.energy = 0.0
	if _aura_tween:
		_aura_tween.kill()
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(_aura_light, "energy", 1.4, 0.25)
	_aura_tween.tween_property(_aura_light, "energy", 0.7, 0.25)


func mana_cast_end() -> void:
	tint_world(Color.WHITE, 0.4)

	_aura_particles.emitting = false
	if _aura_tween:
		_aura_tween.kill()
	var tween := create_tween()
	tween.tween_property(_aura_light, "energy", 0.0, 0.3)
	tween.tween_callback(func(): _aura_light.enabled = false)


# darken or light up the whole world (play area and parallax background)
func tint_world(color: Color, duration: float, tween: Tween = null) -> Tween:
	if tween == null:
		if _tint_tween:
			_tint_tween.kill()
		_tint_tween = create_tween()
		tween = _tint_tween
	tween.tween_property(_canvas_modulate, "color", color, duration)
	for layer in _parallax_layers:
		if is_instance_valid(layer):
			tween.parallel().tween_property(layer, "modulate", _parallax_layers[layer] * color, duration)
	return tween


# lightning flashes: one when the bolts appear, a softer one at impact
func storm_flash() -> void:
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween()
	# faint flicker while the bolts come down
	_tint_tween.tween_interval(0.1)
	tint_world(STORM_FLASH_SOFT * 0.8, 0.03, _tint_tween)
	tint_world(STORM_DARK, 0.15, _tint_tween)
	# full flash when they hit the ground
	_tint_tween.tween_interval(0.2)
	_tint_tween.tween_callback(storm_impact)
	tint_world(STORM_FLASH, 0.02, _tint_tween)
	tint_world(STORM_DARK, 0.05, _tint_tween)
	tint_world(STORM_FLASH_SOFT, 0.02, _tint_tween)
	tint_world(STORM_DARK, 0.35, _tint_tween)


func storm_impact() -> void:
	Sound.play("thunder", 0.15)
	shake_camera(4.0, 0.3)


func mana_attack_start() -> void:
	storm_flash()
	fall()


func mana_attack_end() -> void:
	_manaFalling.visible = false
	for fallLoop in _manaFalling.get_children():
		fallLoop.hide_impact()

	#_manaAttackParticules.emitting = false


func fall() -> void:
	_manaFalling.visible = true
	for fallLoop in _manaFalling.get_children():
		fallLoop.start_fall()


func _on_ManaFall_fall_ended() -> void:
	_manaFalling.visible = false

	mana_attack_end()


func is_combo():
	if _state in [STATE_ATTACK02, STATE_ATTACK03, STATE_ATTACK04]:
		return true
	return false


func get_state():
	return _state


func _on_StateMachine_state_changed(current_state) -> void:
	_state = current_state.name
	pass  # Replace with function body.


func emit_player_tookadvantage_of_lifebottle() -> void:
	Events.emit_signal("player_tookadvantage_of_lifebottle")
