class_name Player
extends Actor

signal life_changed(player, value)
signal combo_feedback(message: String)

const GROUP_PLAYER := "player"

# Mode 2 joueurs : contour et étiquette au-dessus de la tête (le joueur 2 a ses propres planches, Player2.tscn)
const COOP_COLORS := [Color("7fdbff"), Color("ff9f43")]
const COOP_OUTLINES := [Color(0.05, 0.08, 0.22), Color(0.25, 0.06, 0.04)]

const SPRITE_POSITION := Vector2(-1, -29)
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
const SWORD_TIP = Vector2(-1, -36)
const SWORD_BEAM_COLOR = Color(0.6, 0.85, 1.0)
const SWORD_BEAM_SKY = 16.0
const SWORD_BEAM_RISE = 0.08
const SWORD_BEAM_FADE = 0.25
# éclairs par salve : GlobalPlayer.storm_bolts (8, puis plus aux niveaux de mana 4 et 5)
# salves : GlobalPlayer.storm_salvos ; l'animation en prévoit 3, les suivantes sont sautées
# et l'animation reprend juste après la dernière clé de salve
const STORM_SKIP_TO = 1.85

const INVINCIBILITY_DURATION = 0.8
const INVINCIBILITY_BLINK = 0.08

# esquive : délai entre deux esquives, images rémanentes
const DASH_COOLDOWN_MS = 450
const DASH_GHOST_COUNT = 3
const DASH_GHOST_COLOR = Color(0.55, 0.75, 1.0, 0.6)

# attaque en puissance (esquive + attaque)
const ANIM_DASH_POWER = "dash_power"
const DASH_ATTACK_WINDOW_MS = 130
const POWER_DAMAGE = 40
# Dégâts : facteur du niveau d'attaque (GlobalPlayer.attack_level_factor, 45 % au
# niveau 1) × bonus d'attaque de la boutique
# Double hache : mêmes coups que l'épée, plus lents mais plus forts
const AXE_SLOW = 1.7
const AXE_DAMAGE = 1.6
const AXE_KNOCKBACK = 1.3
const AXE_CUT_COLOR = Color(1.0, 0.72, 0.45)
const AXE_SWING_PITCH = 0.8
# Bombe : jet (planches « mains vides »), la bombe est dans la main jusqu'au lâcher
const ANIM_THROW = "throw_right"
const THROW_DURATION = 0.5
const THROW_RELEASE = 0.2
const THROW_DISTANCE = 56.0
const THROW_DISTANCE_HEAVY = 92.0
# [planche, image, position de la main dans l'image 64x64] (tools/generate_weapon_sprites.py)
const THROW_POSES := [
	["mana_unarmed", 1, Vector2(31, 53)],
	["mana_unarmed", 2, Vector2(32, 31)],
	["cross_unarmed", 5, Vector2(42, 48)],
	["followups_unarmed", 3, Vector2(39, 53)],
]
const THROW_TIMES := [0.0, 0.1, 0.2, 0.3]
const POWER_KNOCKBACK = 28.0
const POWER_RADIUS = Vector2(24, 12)
const POWER_COLOR = Color(1.0, 0.85, 0.35)

var _damage = 8
var _strike: Dictionary = {}
var _combo_hit_index := -1
var _struck_bodies := {}
var _combo_label: Label

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

# CanvasModulate partagé entre les joueurs en coop ; ses metas portent l'état commun :
# "storm_count" (orages actifs), "tint_tween" (teinte en cours), "parallax_layers" (couleurs d'origine)
var _canvas_modulate: CanvasModulate
var _aura_particles: CPUParticles2D
var _aura_light: PointLight2D
var _sprite_material: ShaderMaterial
# Lueur de mana de l'attaque lourde : flash bleu du corps, halo et anneau au sol
const HEAVY_MANA_COLOR = Color(0.35, 0.6, 1.0)
const HEAVY_MANA_FLASH = 0.55
const HEAVY_MANA_GLOW_DURATION = 0.35
var _heavy_glow_tween: Tween
var _heavy_light: PointLight2D
var _aura_tween: Tween
var _lunge_tween: Tween
var _storm_sky: StormSky
var _storm_active := false
var _salvo_discharges := 0
var _salvo_index := 0
# images par arme (la bombe garde celles de l'épée hors du jet)
var _weapon_frames := {}
var _held_bomb: Sprite2D
var _throw_heavy := false

# 0 : joueur 1, 1 : joueur 2 ; préfixe "solo_" en solo, "p1_" / "p2_" en coop
var player_index := 0
var _input_prefix := ""
var _is_coop := false


func _ready() -> void:
	build_melee_animations()
	build_throw_animation()
	build_weapon_frames()
	add_to_group(GROUP_PLAYER)
	# actions du joueur seul (setup_coop les remplace en mode 2 joueurs)
	_input_prefix = PlayerInput.prefix(PlayerInput.SOLO)
	updateLife(_life)

	_stateDisplay.visible = Game.is_debug()
	#manaAttackParticules.emitting = false
	_manaFalling.visible = false

	_hitBox.disabled = true

	mana_attack_end()
	#mana_attack_start()

	build_storm_effects()

	Fx.shadow(self, 16).position = Vector2(-1, -1)
	_sprite_material = Fx.character_material(get_node("BodyPivot/AnimatedSprite2D"))
	Fx.cast_shadow(self, get_node("BodyPivot/AnimatedSprite2D"))
	Events.weapon_select_requested.connect(_on_weapon_select_requested)
	apply_weapon()


# Nom de l'action pour ce joueur (« solo_attack » en solo, « p2_attack » pour le joueur 2)
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
	tag.modulate.a = 0.85
	tag.name = "CoopTag"
	# Taille fixée après add_child : hors de l'arbre le Label se dimensionne avec la police par défaut
	add_child(tag)
	tag.size = Vector2(20, 14)
	tag.position = Vector2(-10, -46)
	apply_weapon()


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


# Dégâts de mêlée selon le niveau d'attaque
func attack_damage(base: float) -> int:
	return random_round(base * GlobalPlayer.attack_level_factor(player_index))


# Dégâts d'un éclair selon le niveau de mana
func storm_damage(base: float) -> int:
	return random_round(base * GlobalPlayer.mana_level_factor(player_index))


# arrondi aléatoire : les coups font quelques points, un arrondi simple écraserait les bonus
func random_round(value: float) -> int:
	return maxi(int(floor(value)) + (1 if randf() < value - floor(value) else 0), 1)


func move_speed_factor() -> float:
	return 1.0


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


# appui sur attaque juste après la fin d'une esquive
func just_dashed() -> bool:
	return Time.get_ticks_msec() - _last_dash_ms <= DASH_ATTACK_WINDOW_MS


func power_attack_begin() -> void:
	_strike = {"knockback": POWER_KNOCKBACK, "power": true}
	_struck_bodies.clear()
	_damage = POWER_DAMAGE
	Fx.squash(_bodyPivot, Vector2(0.8, 1.2), 0.08)
	Sound.play("swing", 0.03, 2.0, 0.55)
	_bodyPivot.modulate = Color(1.4, 1.25, 0.9)


func power_attack_rush() -> void:
	_is_dashing = true
	Fx.squash(_bodyPivot, Vector2(1.35, 0.8), 0.18)
	dust()
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	var cut := preload("res://src/Common/Effects/SwordCut.gd").new()
	cut.kind = "thrust"
	cut.facing = direction
	add_child(cut)
	var tween := create_tween()
	for i in range(4):
		tween.tween_callback(spawn_dash_ghost)
		tween.tween_interval(0.045)


# touche une seule fois chaque ennemi devant le joueur pendant la ruée
func power_attack_hit() -> void:
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	var center := global_position + Vector2(direction * 14, 0)
	for body in get_tree().get_nodes_in_group(Game.GROUP_ENEMY) + get_tree().get_nodes_in_group(Game.GROUP_BONUSACTOR):
		if not is_instance_valid(body) or not body is Node2D:
			continue
		if _struck_bodies.has(body.get_instance_id()):
			continue
		if ((body.global_position - center) / POWER_RADIUS).length_squared() > 1.0:
			continue
		_struck_bodies[body.get_instance_id()] = true
		body.last_attacker = self
		if body.is_in_group(Game.GROUP_ENEMY):
			body.set("last_hit_by_storm", false)
			Events.emit_signal("actor_took_damage", body, attack_damage(POWER_DAMAGE))
			Fx.burst(get_parent(), body.global_position + Vector2(0, -12), POWER_COLOR, 12)
			if _struck_bodies.size() == 1:
				Sound.play("hit", 0.03, 2.0, 0.7)
				Game.hit_stop(0.06)
				shake_camera(3.0, 0.15)
		elif body.can_let_item():
			body.let_item(global_position)
			Events.emit_signal("actor_let_item", body)


func power_attack_recover() -> void:
	_is_dashing = false
	Fx.squash(_bodyPivot, Vector2(1.1, 0.92), 0.12)
	dust()


func power_attack_end() -> void:
	_is_dashing = false
	_last_dash_ms = Time.get_ticks_msec()
	_bodyPivot.modulate = Color.WHITE
	_strike = {}
	get_node("BodyPivot/AnimatedSprite2D").position = SPRITE_POSITION
	_hitBox.set_deferred("disabled", true)


# image rémanente bleutée qui s'efface sur place
func spawn_dash_ghost() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.modulate = DASH_GHOST_COLOR
	Fx.character_material(ghost).set_shader_parameter("outline_color", DASH_GHOST_COLOR.darkened(0.6))
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
	# une seule secousse à la fois par caméra (partagée en coop)
	var previous = _camera.get_meta("shake_tween") if _camera.has_meta("shake_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween = create_tween()
	_camera.set_meta("shake_tween", tween)
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
	if _strike.get("finisher", false):
		return
	if _struck_bodies.has(body.get_instance_id()):
		return
	_struck_bodies[body.get_instance_id()] = true
	if body.is_in_group(Game.GROUP_ENEMY):
		body.last_attacker = self
		body.set("last_hit_by_storm", false)
		Events.emit_signal("actor_took_damage", body, attack_damage(_damage))
		if _strike.get("heavy", false) and _struck_bodies.size() == 1:
			Game.hit_stop(0.045)
			shake_camera(1.2, 0.1)
	elif body.is_in_group(Game.GROUP_BONUSACTOR):
		body.last_attacker = self
		if body.can_let_item():
			body.let_item(global_position)
			Events.emit_signal("actor_let_item", body)
	elif body.has_method("on_player_hit"):
		body.on_player_hit(self)


func mana_cast_begin() -> void:
	_salvo_index = 0
	if not _storm_active:
		_canvas_modulate.set_meta("storm_count", _canvas_modulate.get_meta("storm_count", 0) + 1)
	_storm_active = true
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
	if _storm_active:
		_canvas_modulate.set_meta("storm_count", maxi(_canvas_modulate.get_meta("storm_count", 0) - 1, 0))
	_storm_active = false
	# coop : le monde reste sombre tant que l'autre joueur est en orage
	if _canvas_modulate.get_meta("storm_count", 0) == 0:
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
		tween = new_tint_tween()
	tween.tween_property(_canvas_modulate, "color", color, duration)
	var layers := parallax_layers()
	for layer in layers:
		if is_instance_valid(layer):
			tween.parallel().tween_property(layer, "modulate", layers[layer] * color, duration)
	return tween


# Teinte partagée : arrête celle en cours (y compris celle de l'autre joueur)
func new_tint_tween() -> Tween:
	var previous = _canvas_modulate.get_meta("tint_tween") if _canvas_modulate.has_meta("tint_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := create_tween()
	_canvas_modulate.set_meta("tint_tween", tween)
	return tween


# Couches de parallaxe et leur couleur d'origine, relevées une seule fois
# (au premier orage, monde encore clair)
func parallax_layers() -> Dictionary:
	if not _canvas_modulate.has_meta("parallax_layers"):
		var layers := {}
		for layer in get_tree().root.find_children("*", "ParallaxLayer", true, false):
			layers[layer] = layer.modulate
		_canvas_modulate.set_meta("parallax_layers", layers)
	return _canvas_modulate.get_meta("parallax_layers")


# lightning flash on a real discharge: full flash for the first bolt of a salvo,
# softer ones for the next bolts, then back to the storm darkness
func storm_flash(strong: bool = true) -> void:
	if not _storm_active:
		return
	var tween := new_tint_tween()
	if strong:
		tint_world(STORM_FLASH, 0.02, tween)
		tint_world(STORM_DARK, 0.05, tween)
		tint_world(STORM_FLASH_SOFT, 0.02, tween)
		tint_world(STORM_DARK, 0.3, tween)
	else:
		tint_world(STORM_FLASH_SOFT, 0.02, tween)
		tint_world(STORM_DARK, 0.2, tween)


func storm_impact() -> void:
	Sound.play("thunder", 0.15)
	shake_camera(4.0, 0.3)


func mana_attack_start() -> void:
	_salvo_index += 1
	if _salvo_index > GlobalPlayer.storm_salvos(player_index):
		# orage moins puissant : l'animation saute les salves restantes
		var animator: AnimationPlayer = _bodyPivot.get_node("AnimationPlayer")
		if animator.current_animation_position < STORM_SKIP_TO:
			animator.seek.call_deferred(STORM_SKIP_TO)
		return
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
	bolts = bolts.slice(0, GlobalPlayer.storm_bolts(player_index))
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
	return not _strike.is_empty() and _stateMachine.combo_sequence.length() > 1


func melee_knockback() -> float:
	if _strike.get("finisher", false) and not _strike.get("slam", false):
		if _combo_hit_index < _strike.hits.size() - 1:
			return 2.0
	return float(_strike.get("knockback", 4.0))


func begin_strike(strike: Dictionary) -> void:
	if strike.heavy and not strike.finisher:
		var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
		var incoming := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		sprite.sprite_frames.set_frame("attacking_heavy", 0, incoming)
	_combo_hit_index = -1
	_strike = strike
	_damage = strike.damage
	_struck_bodies.clear()
	velocity = Vector2.ZERO
	_hitBox.position.x = 20.0 if strike.heavy else 16.0
	if _combo_label == null:
		_combo_label = Label.new()
		_combo_label.add_theme_font_override("font", Fx.FONT)
		_combo_label.add_theme_font_size_override("font_size", 5)
		_combo_label.add_theme_constant_override("outline_size", 2)
		_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_label.position = Vector2(-55, -56)
		_combo_label.size = Vector2(110, 10)
		add_child(_combo_label)
	_combo_label.text = _stateMachine.combo_sequence.replace("H", "L")
	if strike.finisher:
		_combo_label.text += " " + str(strike.label)
	_combo_label.modulate = Color("ffd34d") if strike.heavy else Color("a6eaff")
	_combo_label.show()


func spend_heavy_mana() -> void:
	if GlobalPlayer.use_heavy_attack_mana(player_index):
		heavy_mana_glow()


func heavy_mana_glow() -> void:
	if _heavy_light == null:
		_heavy_light = Fx.light(self, HEAVY_MANA_COLOR, 0.6)
		_heavy_light.position = Vector2(0, -14)
	_heavy_light.enabled = true
	if _heavy_glow_tween:
		_heavy_glow_tween.kill()
	_sprite_material.set_shader_parameter("flash_color", HEAVY_MANA_COLOR.lightened(0.3))
	_heavy_glow_tween = create_tween().set_parallel(true)
	_heavy_glow_tween.tween_method(func(value: float):
		_sprite_material.set_shader_parameter("flash", value)
	, HEAVY_MANA_FLASH, 0.0, HEAVY_MANA_GLOW_DURATION)
	_heavy_light.energy = 1.4
	_heavy_glow_tween.tween_property(_heavy_light, "energy", 0.0, HEAVY_MANA_GLOW_DURATION)
	_heavy_glow_tween.chain().tween_callback(func(): _heavy_light.enabled = false)
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	Fx.burst(get_parent(), global_position + Vector2(direction * 10, -20), HEAVY_MANA_COLOR.lightened(0.4), 6)
	Fx.ring(get_parent(), global_position, HEAVY_MANA_COLOR, 14.0, 0.3)


func strike_impact(strike: Dictionary) -> void:
	attack_lunge(strike.lunge, Vector2(1.25, 0.85) if strike.heavy else Vector2(1.12, 0.94))
	Sound.play("swing", 0.03, 1.5 if strike.heavy else 0.0, (0.7 if strike.heavy else 1.15) * swing_pitch())
	if strike.heavy:
		dust()


func combo_impact(strike: Dictionary, hit_index: int) -> void:
	_combo_hit_index = hit_index
	var final_hit: bool = hit_index == strike.hits.size() - 1
	var connected := false
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	var center := global_position + Vector2(direction * 18, 0)
	var radius: Vector2 = strike.radius
	_struck_bodies.clear()
	if strike.slam:
		var effect := preload("res://src/Common/Effects/GroundImpact.gd").new()
		effect.name = "GroundImpact"
		effect.radius = radius
		get_parent().add_child(effect)
		effect.global_position = center.round()
		Fx.dust(get_parent(), center, -1)
		Fx.dust(get_parent(), center, 1)
		Sound.play("hit", 0.03, 3.0, 0.6)
		shake_camera(5.0, 0.25)
		Game.hit_stop(0.07)
		Fx.squash(_bodyPivot, Vector2(1.3, 0.75), 0.20)
	else:
		var heavy_cut: bool = strike.heavy_cuts[hit_index]
		if _combo_label:
			_combo_label.text = "%s %s %d/%d" % [_stateMachine.combo_sequence.replace("H", "L"), str(strike.label), hit_index + 1, strike.hits.size()]
			_combo_label.modulate = Color("ffd34d") if heavy_cut else Color("a6eaff")
		var cut := preload("res://src/Common/Effects/SwordCut.gd").new()
		cut.kind = strike.cuts[hit_index]
		cut.facing = direction
		if strike.get("axe", false):
			cut.modulate = AXE_CUT_COLOR
		get_parent().add_child(cut)
		cut.global_position = global_position.round()
		attack_lunge(4.0 if final_hit else 2.0, Vector2(1.04, 0.98))
		Sound.play("swing", 0.02, 1.5 if heavy_cut else 0.0, (0.75 if heavy_cut else 1.15 + hit_index * 0.05) * swing_pitch())
		spawn_dash_ghost()
	for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var offset: Vector2 = (enemy.global_position - center) / radius
		if offset.length_squared() > 1.0 or _struck_bodies.has(enemy.get_instance_id()):
			continue
		_struck_bodies[enemy.get_instance_id()] = true
		enemy.last_attacker = self
		enemy.set("last_hit_by_storm", false)
		connected = true
		Events.emit_signal("actor_took_damage", enemy, attack_damage(int(strike.hit_damage[hit_index]) if strike.has("hit_damage") else int(strike.damage)))
	if connected and final_hit and not strike.slam:
		shake_camera(2.0, 0.1)
		Game.hit_stop(0.035)
	elif connected and not strike.slam and strike.heavy_cuts[hit_index]:
		shake_camera(1.0, 0.08)
		Game.hit_stop(0.015)


func end_strike() -> void:
	get_node("BodyPivot/AnimatedSprite2D").position = SPRITE_POSITION
	_hitBox.set_deferred("disabled", true)
	_hitBox.position.x = 16.0
	if _lunge_tween:
		_lunge_tween.kill()
	_strike = {}
	if _combo_label:
		_combo_label.hide()


func build_melee_animations() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	sprite.sprite_frames = sprite.sprite_frames.duplicate()
	var frames := sprite.sprite_frames
	frames.add_animation("attacking_heavy")
	frames.set_animation_loop("attacking_heavy", false)
	var poses := [
		["attacking01", 0],
		["attacking_mana01", 1],
		["attacking_mana01", 2],
		["attacking04", 2],
		["attacking04", 3],
		["attacking01", 0],
	]
	for pose in poses:
		frames.add_frame("attacking_heavy", frames.get_frame_texture(pose[0], pose[1]))
	var animation := Animation.new()
	animation.length = 0.70
	var frame_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(frame_track, "BodyPivot/AnimatedSprite2D:frame")
	animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
	var times := [0.0, 0.10, 0.22, 0.38, 0.46, 0.58]
	for i in range(6):
		animation.track_insert_key(frame_track, times[i], i)
	var pose_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(pose_track, "BodyPivot/AnimatedSprite2D:animation")
	animation.value_track_set_update_mode(pose_track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(pose_track, 0.0, "attacking_heavy")
	var hit_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(hit_track, "BodyPivot/HitBox/CollisionShape2D:disabled")
	animation.value_track_set_update_mode(hit_track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(hit_track, 0.0, true)
	animation.track_insert_key(hit_track, 0.38, false)
	animation.track_insert_key(hit_track, 0.51, true)
	var animator: AnimationPlayer = get_node("BodyPivot/AnimationPlayer")
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var library: AnimationLibrary = animator.get_animation_library("").duplicate()
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	library.add_animation("attacking_heavy_right", animation)
	var flurry_poses: Array = []
	var cross_poses: Array = []
	add_combo_strip(frames, "cross", 8)
	add_combo_strip(frames, "followups", 8)
	var flurry_segments := [
		["cross_sheet", [4, 5, 6, 7]],
		["followups_sheet", [0, 1, 2, 3]],
		["followups_sheet", [3, 2, 1, 0]],
		["cross_sheet", [0, 1, 2, 3]],
		["cross_sheet", [4, 5, 6, 7]],
		["cross_sheet", [7, 6, 5, 4]],
		["cross_sheet", [4, 5, 6, 7]],
		["followups_sheet", [4, 5, 6, 7]],
	]
	var cross_segments := [
		["cross_sheet", [0, 1, 2, 3]],
		["cross_sheet", [4, 5, 6, 7]],
		["followups_sheet", [0, 1, 2, 3]],
		["followups_sheet", [3, 2, 1, 0]],
		["cross_sheet", [7, 6, 5, 4]],
		["cross_sheet", [4, 5, 6, 7]],
	]
	for segment in flurry_segments:
		for index in segment[1]:
			flurry_poses.append([segment[0], index])
	for segment in cross_segments:
		for index in segment[1]:
			cross_poses.append([segment[0], index])
	add_combo_animation(library, frames, "combo_flurry", flurry_poses,
		CombatChain.FLURRY_TIMES, CombatChain.FLURRY_DURATION)
	add_combo_animation(library, frames, "combo_cross", cross_poses,
		CombatChain.CROSS_TIMES, CombatChain.CROSS_DURATION)
	add_combo_animation(library, frames, "combo_slam", [
		["attacking01", 0], ["attacking_mana01", 1], ["attacking_mana01", 2],
		["attacking_mana01", 2], ["attacking01", 2], ["attacking04", 2],
		["attacking04", 2], ["attacking04", 3],
	], [0.0, 0.12, 0.25, 0.40, 0.50, 0.56, 0.78, 0.94], 1.05)
	add_combo_animation(library, frames, ANIM_DASH_POWER, [
		["attacking01", 0], ["attacking_mana01", 1], ["followups_sheet", 4],
		["followups_sheet", 5], ["followups_sheet", 6], ["followups_sheet", 7],
	], [0.0, 0.04, 0.08, 0.13, 0.22, 0.36], 0.55)


# ---- Armes -------------------------------------------------------------

func weapon() -> String:
	return GlobalPlayer.get_weapon(player_index)


func sprite_folder() -> String:
	return "Player2" if scene_file_path.ends_with("Player2.tscn") else "Player"


# Jet de bombe : poses des planches « mains vides », la bombe tenue suit la main
func build_throw_animation() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	var frames := sprite.sprite_frames
	var folder := sprite_folder()
	var sheets := {
		"mana_unarmed": "res://src/Actors/Players/%s/player-attacking-mana-01-unarmed.png" % folder,
		"cross_unarmed": "res://src/Actors/Players/%s/combo/player-combo-cross-unarmed.png" % folder,
		"followups_unarmed": "res://src/Actors/Players/%s/combo/player-combo-followups-unarmed.png" % folder,
	}
	frames.add_animation("throw")
	frames.set_animation_loop("throw", false)
	for pose in THROW_POSES:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(sheets[pose[0]])
		atlas.region = Rect2(pose[1] * 64, 0, 64, 64)
		frames.add_frame("throw", atlas)
	var animation := Animation.new()
	animation.length = THROW_DURATION
	for property in ["frame", "animation"]:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, "BodyPivot/AnimatedSprite2D:" + property)
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		if property == "frame":
			for i in range(THROW_TIMES.size()):
				animation.track_insert_key(track, THROW_TIMES[i], i)
		else:
			animation.track_insert_key(track, 0.0, "throw")
	var hit_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(hit_track, "BodyPivot/HitBox/CollisionShape2D:disabled")
	animation.track_insert_key(hit_track, 0.0, true)
	var animator: AnimationPlayer = get_node("BodyPivot/AnimationPlayer")
	animator.get_animation_library("").add_animation(ANIM_THROW, animation)

	_held_bomb = Sprite2D.new()
	_held_bomb.texture = Bomb.texture()
	_held_bomb.visible = false
	_held_bomb.z_index = 1
	_bodyPivot.add_child(_held_bomb)
	sprite.frame_changed.connect(_update_held_bomb)


func _update_held_bomb() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	if sprite.animation != "throw" or not _held_bomb.visible:
		return
	_held_bomb.position = hand_position(sprite.frame)


# Main dans le repère du BodyPivot (image 64x64 centrée sur SPRITE_POSITION)
func hand_position(frame: int) -> Vector2:
	return THROW_POSES[clampi(frame, 0, THROW_POSES.size() - 1)][2] - Vector2(32, 32) + SPRITE_POSITION


# Images de la double hache : copie des images de l'épée, planches « -axe » à la place
func build_weapon_frames() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	var sword: SpriteFrames = sprite.sprite_frames
	var axe: SpriteFrames = sword.duplicate()
	var sheets := {}
	for animation in axe.get_animation_names():
		for i in range(axe.get_frame_count(animation)):
			var texture := axe.get_frame_texture(animation, i)
			if not (texture is AtlasTexture) or texture.atlas == null:
				continue
			var path: String = texture.atlas.resource_path
			if not sheets.has(path):
				var axe_path := path.replace(".png", "-axe.png")
				sheets[path] = load(axe_path) if not path.ends_with("-unarmed.png") and ResourceLoader.exists(axe_path) else null
			if sheets[path] == null:
				continue
			var replaced := AtlasTexture.new()
			replaced.atlas = sheets[path]
			replaced.region = texture.region
			axe.set_frame(animation, i, replaced, axe.get_frame_duration(animation, i))
	_weapon_frames = {GlobalPlayer.WEAPON_SWORD: sword, GlobalPlayer.WEAPON_AXE: axe, GlobalPlayer.WEAPON_BOMB: sword}


func apply_weapon() -> void:
	var sprite: AnimatedSprite2D = get_node("BodyPivot/AnimatedSprite2D")
	var frames: SpriteFrames = _weapon_frames.get(weapon(), _weapon_frames[GlobalPlayer.WEAPON_SWORD])
	if sprite.sprite_frames == frames:
		return
	var animation := sprite.animation
	var frame := sprite.frame
	sprite.sprite_frames = frames
	sprite.animation = animation
	sprite.frame = frame


func select_weapon(weapon_: String) -> void:
	if weapon_ == weapon() or not GlobalPlayer.set_weapon(weapon_, player_index):
		return
	apply_weapon()
	var color: Color = WeaponIcons.COLORS[weapon_]
	Sound.play("menu_select", 0.0, -2.0, 1.2)
	Fx.floating_text(get_parent(), GlobalPlayer.WEAPON_TITLES[weapon_], global_position + Vector2(0, -44), color)
	Fx.ring(get_parent(), global_position, color, 14.0, 0.25)
	Events.player_weapon_changed.emit(player_index)


func cycle_weapon() -> void:
	if GlobalPlayer.owned_weapons[player_index].size() > 1:
		select_weapon(GlobalPlayer.next_weapon(player_index))


func _on_weapon_select_requested(index: int, weapon_: String) -> void:
	if index == player_index and is_alive():
		select_weapon(weapon_)


# Coup adapté à l'arme : la hache allonge tous les temps et frappe plus fort
func weapon_strike(strike: Dictionary) -> Dictionary:
	if weapon() != GlobalPlayer.WEAPON_AXE:
		return strike
	var result := strike.duplicate(true)
	for key in ["duration", "impact", "cancel", "input_open"]:
		result[key] = float(result[key]) * AXE_SLOW
	if result.has("hits"):
		result.hits = result.hits.map(func(time): return float(time) * AXE_SLOW)
	result.damage = roundi(float(result.damage) * AXE_DAMAGE)
	if result.has("hit_damage"):
		result.hit_damage = result.hit_damage.map(func(value): return roundi(float(value) * AXE_DAMAGE))
	result.knockback = float(result.knockback) * AXE_KNOCKBACK
	result["axe"] = true
	return result


func swing_pitch() -> float:
	return AXE_SWING_PITCH if weapon() == GlobalPlayer.WEAPON_AXE else 1.0


func throw_begin(heavy: bool) -> void:
	_throw_heavy = heavy
	velocity = Vector2.ZERO
	if heavy:
		spend_heavy_mana()
	_held_bomb.visible = true
	_held_bomb.position = hand_position(0)


func throw_release() -> void:
	if not _held_bomb.visible:
		return
	_held_bomb.visible = false
	var direction := -1.0 if _bodyPivot.scale.x < 0 else 1.0
	var hand := global_position + hand_position(2) * Vector2(direction, 1)
	var distance := THROW_DISTANCE_HEAVY if _throw_heavy else THROW_DISTANCE
	var bomb := Bomb.new()
	bomb.thrower = self
	bomb.heavy = _throw_heavy
	get_parent().add_child(bomb)
	bomb.launch(hand, global_position + Vector2(direction * distance, randf_range(-3, 3)))
	Sound.play("swing", 0.05, 0.0, 0.8)
	attack_lunge(3.0, Vector2(1.1, 0.92))


func throw_end() -> void:
	_held_bomb.visible = false


func add_combo_strip(frames: SpriteFrames, kind: String, count: int) -> void:
	var folder := sprite_folder()
	var sheet: Texture2D = load("res://src/Actors/Players/%s/combo/player-combo-%s.png" % [folder, kind])
	frames.add_animation(kind + "_sheet")
	frames.set_animation_loop(kind + "_sheet", false)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame(kind + "_sheet", atlas)


func add_combo_animation(library: AnimationLibrary, frames: SpriteFrames, name_: String, poses: Array, times: Array, duration: float) -> void:
	frames.add_animation(name_)
	frames.set_animation_loop(name_, false)
	for pose in poses:
		frames.add_frame(name_, frames.get_frame_texture(pose[0], pose[1]))
	var animation := Animation.new()
	animation.length = duration
	for property in ["frame", "animation"]:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, "BodyPivot/AnimatedSprite2D:" + property)
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		if property == "frame":
			for i in range(times.size()):
				animation.track_insert_key(track, times[i], i)
		else:
			animation.track_insert_key(track, 0.0, name_)
	var hit_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(hit_track, "BodyPivot/HitBox/CollisionShape2D:disabled")
	animation.track_insert_key(hit_track, 0.0, true)
	if name_ == "combo_slam":
		var jump_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(jump_track, "BodyPivot/AnimatedSprite2D:position")
		animation.value_track_set_update_mode(jump_track, Animation.UPDATE_DISCRETE)
		for key in [[0.0, 0], [0.25, -5], [0.40, -8], [0.50, -4], [0.56, 0]]:
			animation.track_insert_key(jump_track, key[0], SPRITE_POSITION + Vector2(0, key[1]))
	else:
		var anchor_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(anchor_track, "BodyPivot/AnimatedSprite2D:position")
		animation.track_insert_key(anchor_track, 0.0, SPRITE_POSITION)
	library.add_animation(name_, animation)


func get_state():
	return _state


func _on_StateMachine_state_changed(current_state) -> void:
	_state = current_state.name
	pass  # Replace with function body.


func emit_player_tookadvantage_of_lifebottle() -> void:
	Events.emit_signal("player_tookadvantage_of_lifebottle", self)
