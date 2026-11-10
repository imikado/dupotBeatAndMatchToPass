class_name Player
extends Actor

signal life_changed(player, value)

const GROUP_PLAYER := "player"

# Mode 2 joueurs : contour et étiquette au-dessus de la tête (le joueur 2 a ses propres planches, Player2.tscn)
const COOP_COLORS := [Color("7fdbff"), Color("ff9f43")]
const COOP_OUTLINES := [Color(0.05, 0.08, 0.22), Color(0.25, 0.06, 0.04)]

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
# storm: bolts land within STORM_HALF_WIDTH of the player, below STORM_GROUND_TOP (from the screen top)
const STORM_HALF_WIDTH = 130.0
const STORM_GROUND_TOP = 104.0
const STORM_MIN_SPACING = 20.0
const STORM_MAX_DELAY = 0.25
# éclair qui monte de la pointe de l'épée levée vers les nuages, avant que les
# éclairs ne redescendent (pointe : image 3 de attacking_mana01, en local du BodyPivot)
const SWORD_TIP = Vector2(-1, -44)
const SWORD_BEAM_COLOR = Color(0.6, 0.85, 1.0)
const SWORD_BEAM_SKY = 16.0
const SWORD_BEAM_RISE = 0.08
const SWORD_BEAM_FADE = 0.25
# bolts used per salvo (out of the ManaFall nodes), picked at random
const STORM_BOLTS_PER_SALVO = 8

const INVINCIBILITY_DURATION = 0.8
const INVINCIBILITY_BLINK = 0.08

# esquive : délai entre deux esquives, images rémanentes
const DASH_COOLDOWN_MS = 450
const DASH_GHOST_COUNT = 3
const DASH_GHOST_COLOR = Color(0.55, 0.75, 1.0, 0.6)

var _damage = 10

#onready var _animationTree := get_node("AnimationTree")
@onready var _camera := get_node("Camera2D")
@onready var _stateDisplay := get_node("stateDisplay")

@onready var _hitBox := get_node("BodyPivot/HitBox/CollisionShape2D")
@onready var _bodyPivot := get_node("BodyPivot")

@onready var _stateMachine := get_node("StateMachine")

@onready var _manaFalling := get_node("ManaFalling")

var look_direction = Vector2(1, 0): set = set_look_direction

var _cameraLimitRect: ReferenceRect

var _mana_count = 0

var _state: String = "idle"

var _is_invincible := false
var _is_dashing := false
var _last_dash_ms := -100000

var _canvas_modulate: CanvasModulate
var _parallax_layers := {}
var _tint_tween: Tween
var _aura_particles: CPUParticles2D
var _aura_light: PointLight2D
var _aura_tween: Tween
var _lunge_tween: Tween
var _storm_sky: StormSky
var _storm_active := false
var _salvo_discharges := 0

# 0 : joueur 1, 1 : joueur 2 ; préfixe "" en solo (actions d'origine), "p1_" / "p2_" en coop
var player_index := 0
var _input_prefix := ""
var _is_coop := false


func _ready() -> void:
	add_to_group(GROUP_PLAYER)
	updateLife(_life)

	_stateDisplay.visible = Game.is_debug()
	#manaAttackParticules.emitting = false
	_manaFalling.visible = false

	_hitBox.disabled = true

	mana_attack_end()
	#mana_attack_start()

	build_storm_effects()

	Fx.shadow(self, 16).position = Vector2(-1, -1)
	Fx.character_material(get_node("BodyPivot/AnimatedSprite2D"))


# Nom de l'action pour ce joueur (« attack » en solo, « p2_attack » pour le joueur 2)
func action(base: String) -> String:
	return _input_prefix + base


func is_coop() -> bool:
	return _is_coop


func is_alive() -> bool:
	return _life > 0


func setup_coop(index: int, shared_camera: Camera2D) -> void:
	_is_coop = true
	player_index = index
	_input_prefix = PlayerInput.prefix(index)
	_camera.enabled = false
	_camera = shared_camera

	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("outline_color", COOP_OUTLINES[index])

	var tag := Label.new()
	tag.text = "P%d" % (index + 1)
	tag.add_theme_font_override("font", Fx.FONT)
	tag.add_theme_font_size_override("font_size", 5)
	tag.add_theme_color_override("font_color", COOP_COLORS[index])
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 2)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(20, 8)
	tag.position = Vector2(-10, -46)
	tag.modulate.a = 0.85
	tag.name = "CoopTag"
	add_child(tag)


# Coop : joueur tombé, les ennemis l'ignorent et les autres le traversent
func down() -> void:
	remove_from_group(GROUP_PLAYER)
	collision_layer = 0
	var tag := get_node_or_null("CoopTag")
	if tag:
		tag.visible = false


func build_storm_effects() -> void:
	# un seul CanvasModulate par canvas : partagé entre les joueurs en coop
	for node in get_tree().get_nodes_in_group("storm_canvas_modulate"):
		if node.is_inside_tree() and node.get_parent() != self:
			_canvas_modulate = node
	if _canvas_modulate == null:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.color = Color.WHITE
		_canvas_modulate.add_to_group("storm_canvas_modulate")
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

	# storm sky textures are built once here, not on the first cast (avoids a hitch)
	StormSky.cloud_texture(int(get_viewport_rect().size.x) + StormSky.CLOUD_MARGIN)
	StormSky.rain_texture()

	var bolts = _manaFalling.get_children()
	for i in range(bolts.size()):
		bolts[i].set_has_light(i % 3 == 0)
		bolts[i].discharged.connect(_on_bolt_discharged)
		if not bolts[i].fall_ended.is_connected(_on_ManaFall_fall_ended):
			bolts[i].fall_ended.connect(_on_ManaFall_fall_ended)


func set_look_direction(value):
	look_direction = value


func updateLife(newLife: float):
	_life = clamp(newLife, 0.0, MAX_LIFE)
	life_changed.emit(self, (_life / MAX_LIFE) * 100)
	if not _is_coop:
		Events.emit_signal("player_health_changed", (_life / MAX_LIFE) * 100)


func set_life(newLife: float):
	_life = clamp(newLife, 0.0, MAX_LIFE)


func heal(amount: float):
	updateLife(_life + amount)


func took_damage(damage: int):
	if _is_invincible or _is_dashing or _life <= 0 or _state == STATE_ATTACK_MANA01:
		return

	updateLife(_life - damage)
	if _life <= 0:
		return

	Sound.play("player_hurt")
	_stateMachine.set_damaged()
	Fx.squash(_bodyPivot, Vector2(1.25, 0.8), 0.2)
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


func can_dash() -> bool:
	return Time.get_ticks_msec() - _last_dash_ms >= DASH_COOLDOWN_MS


func dash_begin() -> void:
	_is_dashing = true
	_last_dash_ms = Time.get_ticks_msec()
	Sound.play("swing", 0.05, -4.0, 0.7)
	Fx.squash(_bodyPivot, Vector2(1.3, 0.8), 0.15)
	dust()
	var tween := create_tween()
	for i in range(DASH_GHOST_COUNT):
		tween.tween_callback(spawn_dash_ghost)
		tween.tween_interval(0.04)


func dash_end() -> void:
	_is_dashing = false
	_last_dash_ms = Time.get_ticks_msec()


# image rémanente bleutée qui s'efface sur place
func spawn_dash_ghost() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.modulate = DASH_GHOST_COLOR
	# dans le conteneur trié en y, juste avant le joueur : dessinée derrière lui
	get_parent().add_child(ghost)
	get_parent().move_child(ghost, get_index())
	ghost.global_transform = sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


# Petit pas en avant pendant un coup d'épée, avec étirement du personnage
func attack_lunge(distance: float, amount: Vector2 = Vector2(1.15, 0.9)) -> void:
	var direction := Vector2(-1 if _bodyPivot.scale.x < 0 else 1, 0)
	Fx.squash(_bodyPivot, amount, 0.15)

	if _lunge_tween:
		_lunge_tween.kill()
	var moved := [0.0]
	_lunge_tween = create_tween()
	_lunge_tween.tween_method(func(done: float):
		move_and_collide(direction * (done - moved[0]))
		moved[0] = done
	, 0.0, distance, 0.08).set_ease(Tween.EASE_OUT)


func dust() -> void:
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	Fx.dust(get_parent(), global_position + Vector2(-4 * direction, -1), direction)


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
		body.last_attacker = self
		Events.emit_signal("actor_took_damage", body, _damage)
	elif body.is_in_group(Game.GROUP_BONUSACTOR):
		body.last_attacker = self
		if body.can_let_item():
			body.let_item(global_position)
			Events.emit_signal("actor_let_item", body)
			print("hit bonusactor")
	pass  # Replace with function body.


func mana_cast_begin() -> void:
	_storm_active = true
	_parallax_layers.clear()
	for layer in get_tree().root.find_children("*", "ParallaxLayer", true, false):
		_parallax_layers[layer] = layer.modulate
	tint_world(STORM_DARK, 0.3)

	if is_instance_valid(_storm_sky):
		_storm_sky.close()
	_storm_sky = StormSky.new()
	add_child(_storm_sky)

	_aura_particles.emitting = true
	_aura_light.enabled = true
	_aura_light.energy = 0.0
	if _aura_tween:
		_aura_tween.kill()
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(_aura_light, "energy", 1.4, 0.25)
	_aura_tween.tween_property(_aura_light, "energy", 0.7, 0.25)


func mana_cast_end() -> void:
	_storm_active = false
	tint_world(Color.WHITE, 0.4)

	if is_instance_valid(_storm_sky):
		_storm_sky.close()
	_storm_sky = null

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


# lightning flash on a real discharge: full flash for the first bolt of a salvo,
# softer ones for the next bolts, then back to the storm darkness
func storm_flash(strong: bool = true) -> void:
	if not _storm_active:
		return
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween()
	if strong:
		tint_world(STORM_FLASH, 0.02, _tint_tween)
		tint_world(STORM_DARK, 0.05, _tint_tween)
		tint_world(STORM_FLASH_SOFT, 0.02, _tint_tween)
		tint_world(STORM_DARK, 0.3, _tint_tween)
	else:
		tint_world(STORM_FLASH_SOFT, 0.02, _tint_tween)
		tint_world(STORM_DARK, 0.2, _tint_tween)


func storm_impact() -> void:
	Sound.play("thunder", 0.15)
	shake_camera(4.0, 0.3)


func mana_attack_start() -> void:
	_salvo_discharges = 0
	sword_beam()
	fall()


func sword_beam() -> void:
	var tip: Vector2 = global_position + SWORD_TIP * Vector2(signf(_bodyPivot.scale.x), 1)
	var sky_y: float = (get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO).y + SWORD_BEAM_SKY
	var beam := Bolt.new()
	beam.color = SWORD_BEAM_COLOR
	beam.jaggedness = 0.18
	beam.branch_count = 1
	beam.top_level = true
	add_child(beam)
	beam.global_position = tip.round()
	beam.set_ends(Vector2.ZERO, Vector2(randf_range(-8, 8), sky_y - tip.y).round())
	beam.set_intensity(2.5)
	beam.reveal(0.0)
	Fx.burst(get_parent(), tip, SWORD_BEAM_COLOR.lightened(0.4), 8)

	var tween := beam.create_tween()
	tween.tween_method(beam.reveal, 0.0, 1.0, SWORD_BEAM_RISE)
	# les nuages s'illuminent quand l'éclair les atteint
	tween.tween_callback(func():
		if is_instance_valid(_storm_sky):
			_storm_sky.flash(beam.global_position.x + beam._to.x))
	tween.tween_method(beam.set_intensity, 2.5, 0.0, SWORD_BEAM_FADE).set_ease(Tween.EASE_IN)
	tween.tween_callback(beam.queue_free)


func mana_attack_end() -> void:
	# bolts still striking end by themselves (they are desynchronised)
	var striking := false
	for fallLoop in _manaFalling.get_children():
		if fallLoop.is_striking():
			striking = true
		else:
			fallLoop.hide_impact()
	if not striking:
		_manaFalling.visible = false

	#_manaAttackParticules.emitting = false


# new random ground points around the player for each salvo, at least
# STORM_MIN_SPACING apart; about one bolt out of three aims at a nearby enemy
func fall() -> void:
	_manaFalling.visible = true
	var bolts := _manaFalling.get_children()
	bolts.shuffle()
	bolts = bolts.slice(0, STORM_BOLTS_PER_SALVO)
	var view := get_viewport().get_canvas_transform().affine_inverse()
	var screen := get_viewport_rect().size
	var top_left: Vector2 = view * Vector2.ZERO
	var area := Rect2(
		Vector2(maxf(global_position.x - STORM_HALF_WIDTH, top_left.x + 8), top_left.y + STORM_GROUND_TOP),
		Vector2.ZERO)
	area.end = Vector2(minf(global_position.x + STORM_HALF_WIDTH, top_left.x + screen.x - 8), top_left.y + screen.y - 16)

	var enemies := []
	for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		if enemy is Node2D and area.grow(8).has_point(enemy.global_position):
			enemies.append(enemy)
	enemies.shuffle()

	var points: Array[Vector2] = []
	for i in range(bolts.size()):
		var point := Vector2.INF
		if i % 3 == 0 and not enemies.is_empty():
			var target: Vector2 = enemies.pop_back().global_position + Vector2(randf_range(-3, 3), randf_range(-2, 2))
			if _far_from(target, points):
				point = target
		var tries := 0
		while point == Vector2.INF and tries < 30:
			var candidate := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			if _far_from(candidate, points) or tries == 29:
				point = candidate
			tries += 1
		points.append(point.round())

	for i in range(bolts.size()):
		bolts[i].global_position = points[i]
		# les éclairs redescendent une fois l'éclair de l'épée arrivé aux nuages
		bolts[i].start_fall(SWORD_BEAM_RISE + randf_range(0.0, STORM_MAX_DELAY))


func _far_from(point: Vector2, points: Array[Vector2]) -> bool:
	for other in points:
		if point.distance_to(other) < STORM_MIN_SPACING:
			return false
	return true


func _on_bolt_discharged(bolt: Node2D) -> void:
	_salvo_discharges += 1
	var first := _salvo_discharges == 1
	if first:
		storm_impact()
	storm_flash(first)
	if is_instance_valid(_storm_sky):
		_storm_sky.flash(bolt.global_position.x)


func _on_ManaFall_fall_ended() -> void:
	mana_attack_end()


# tempête en cours (lancement ou éclairs encore en train de tomber)
func is_storming() -> bool:
	return _storm_active or _manaFalling.visible


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
	Events.emit_signal("player_tookadvantage_of_lifebottle", self)
