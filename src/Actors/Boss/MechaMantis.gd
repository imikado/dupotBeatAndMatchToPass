class_name MechaMantis
extends Enemy

# Mini boss de fin de niveau : mante religieuse robotique, deux fois la taille des
# ennemis simples. Tombe du ciel quand la dernière barrière s'ouvre et garde la porte.
# - coup de faux (attaque normale, préparation lisible avant la frappe)
# - écrasement au sol : cercle rouge d'avertissement puis onde de choc autour de lui
# - enragé sous la moitié de sa vie : plus rapide, écrasements plus fréquents
# - super armure : ne recule presque pas et n'est sonné que tous les STAGGER_HITS coups

signal defeated(boss)

const BOSS_NAME := "MECHA MANTIS"

const BASE_LIFE := 420.0
const LIFE_PER_LEVEL := 90.0
const COOP_LIFE_FACTOR := 1.6
const BASE_DAMAGE := 14
const SLAM_DAMAGE := 18
const REWARD_FACTOR := 25
const BODY_SCALE := 2.0

const STAGGER_HITS := 7
const KNOCKBACK_FACTOR := 0.2

const SLAM_RADIUS := 46.0
# écart vertical max avec le joueur pour être touché (même couloir de marche)
const SLAM_LANE := 16.0
const SLAM_TRIGGER_DISTANCE := 60.0
const SLAM_WINDUP := 0.8
const SLAM_WINDUP_ENRAGED := 0.55
const SLAM_COOLDOWN_MS := 5200
const SLAM_COOLDOWN_ENRAGED_MS := 3200
const SLAM_JUMP := 10.0
const SLAM_COLOR := Color("ff4d4d")
# assez loin pour sortir du cercle (SLAM_RADIUS) depuis le contact
const SLAM_EJECT_DISTANCE := 40.0

const ENRAGE_RATIO := 0.5
const ENRAGE_SPEED_FACTOR := 1.35

const INTRO_DROP := 160.0
const INTRO_FALL := 0.5
const INTRO_PAUSE := 0.8

const BAR_WIDTH := 180
const BAR_HEIGHT := 6
const BAR_Y := 166
# bas des lettres (contour compris) juste au-dessus de la barre
const BAR_LABEL_Y := -12
# au-dessus des buissons du premier plan (ForestBackground, couche 100)
const BAR_LAYER := 101

var _intro := true
var _slamming := false
var _enraged := false
var _hits_since_stagger := 0
var _next_slam_ms := 0
var _bar: PixelBar
var _bar_root: Control
var _bar_layer: CanvasLayer
var _slam_tween: Tween
# hauteur du sprite au repos (pieds sur la ligne du sol), lue dans la scène
var _sprite_y := 0.0


func _init() -> void:
	_near_distance = 56
	_damage = BASE_DAMAGE
	_walk_speed = 13.0
	_shadow_width = 40
	_knockback_factor = KNOCKBACK_FACTOR
	_type = Game.ENEMY_TYPE_LIST.BOSS


# À appeler avant add_child
func setup(level: int, difficulty: int, coop: bool) -> void:
	_max_life = BASE_LIFE + LIFE_PER_LEVEL * maxi(level - 1, 0)
	if coop:
		_max_life *= COOP_LIFE_FACTOR
	_life = _max_life
	apply_difficulty(difficulty)


func _ready() -> void:
	super._ready()
	set_physics_process(false)
	_stateMachine.process_mode = Node.PROCESS_MODE_DISABLED
	_animationPlayer.play("idle")
	_sprite_y = _sprite.position.y
	build_life_bar()


func get_reward_factor() -> int:
	return REWARD_FACTOR


func get_body_scale() -> float:
	return BODY_SCALE


func get_variant_color() -> Color:
	return Fx.enemy_color(_type)


func set_wanted(_wanted: bool) -> void:
	pass


# Toujours au contact, sans place d'attente : les sbires restants ne le font pas reculer
func get_attack_slot_offset(_side: float) -> Vector2:
	return Vector2.ZERO


func is_in_front_slot() -> bool:
	return true


func is_intro() -> bool:
	return _intro


func is_enraged() -> bool:
	return _enraged


# Chute depuis le haut de l'écran : l'ombre grandit au sol, impact, nom du boss
func start_intro() -> void:
	_bodyPivot.position.y = -INTRO_DROP
	# l'ombre portée suit le pivot : elle tomberait dans le ciel avec le corps
	set_cast_shadow_enabled(false)
	var tween := create_tween()
	tween.tween_property(_bodyPivot, "position:y", 0.0, INTRO_FALL).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_intro_landed)
	tween.tween_interval(INTRO_PAUSE)
	tween.tween_callback(_end_intro)


func _on_intro_landed() -> void:
	set_cast_shadow_enabled(true)
	ground_impact(SLAM_RADIUS + 10.0, Fx.enemy_color(_type))
	Fx.squash(_bodyPivot, Vector2(1.3, 0.75), 0.2)
	Fx.floating_text(get_parent(), BOSS_NAME, global_position + Vector2(0, -78), Color("ffd34d"), 7)
	Game.hit_stop(0.08)


func set_cast_shadow_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CastShadow:
			child.set_process(enabled)
			child.visible = enabled


func _end_intro() -> void:
	if _life <= 0:
		return
	_intro = false
	_next_slam_ms = Time.get_ticks_msec() + SLAM_COOLDOWN_MS / 2
	set_physics_process(true)
	_stateMachine.process_mode = Node.PROCESS_MODE_INHERIT
	_stateMachine.set_state_walk()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _slamming or _life <= 0 or not is_instance_valid(_player):
		return
	var state = _stateMachine.get_current_state_name()
	if state != EnemyStateMachine.STATE_WALK and state != EnemyStateMachine.STATE_IDLE:
		return
	if Time.get_ticks_msec() >= _next_slam_ms and global_position.distance_to(_player.global_position) < SLAM_TRIGGER_DISTANCE:
		start_slam()


# Écrasement : il se dresse en clignotant rouge, un cercle montre la zone, puis frappe le sol
func start_slam() -> void:
	_slamming = true
	_stateMachine.process_mode = Node.PROCESS_MODE_DISABLED
	_animationPlayer.stop()
	_sprite.animation = &"attacking01"
	_sprite.frame = 1
	stop_catchup_dash()

	var windup := SLAM_WINDUP_ENRAGED if _enraged else SLAM_WINDUP
	Fx.ring(get_parent(), global_position, SLAM_COLOR, SLAM_RADIUS, windup)
	Sound.play("swing", 0.02, 2.0, 0.55)

	if _flash_tween:
		_flash_tween.kill()
	_material.set_shader_parameter("flash_color", SLAM_COLOR)
	_flash_tween = create_tween().set_loops(3)
	_flash_tween.tween_method(func(value: float): _material.set_shader_parameter("flash", value), 0.8, 0.0, windup / 3.0)

	_slam_tween = create_tween()
	_slam_tween.tween_property(_sprite, "position:y", _sprite_y - SLAM_JUMP, windup * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_slam_tween.tween_property(_sprite, "position:y", _sprite_y, windup * 0.2).set_ease(Tween.EASE_IN)
	_slam_tween.tween_callback(_slam_impact)
	_slam_tween.tween_interval(0.4)
	_slam_tween.tween_callback(_end_slam)


func _slam_impact() -> void:
	if _life <= 0:
		return
	_sprite.frame = 3
	ground_impact(SLAM_RADIUS, SLAM_COLOR)
	for player in get_tree().get_nodes_in_group(Player.GROUP_PLAYER):
		if not player.is_alive():
			continue
		var offset: Vector2 = player.global_position - global_position
		if absf(offset.x) <= SLAM_RADIUS and absf(offset.y) <= SLAM_LANE:
			Events.emit_signal("actor_took_damage", player, roundi(SLAM_DAMAGE * (_damage / float(BASE_DAMAGE))))
			# souffle de l'explosion : les joueurs touchés sont projetés hors du cercle
			player.eject(global_position, SLAM_EJECT_DISTANCE)


func _end_slam() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_material.set_shader_parameter("flash", 0.0)
	_sprite.position.y = _sprite_y
	_slamming = false
	_next_slam_ms = Time.get_ticks_msec() + (SLAM_COOLDOWN_ENRAGED_MS if _enraged else SLAM_COOLDOWN_MS)
	if _life <= 0:
		return
	_stateMachine.process_mode = Node.PROCESS_MODE_INHERIT
	_stateMachine.set_state_walk()


# Onde de choc, poussière des deux côtés, éclats et secousse de la caméra
func ground_impact(radius: float, color: Color) -> void:
	var parent := get_parent()
	Fx.ring(parent, global_position, color, radius, 0.35)
	Fx.ring(parent, global_position, Color.WHITE, radius * 0.6, 0.25)
	Fx.dust(parent, global_position + Vector2(-10, 0), -1.0)
	Fx.dust(parent, global_position + Vector2(10, 0), 1.0)
	Fx.burst(parent, global_position + Vector2(0, -4), color, 18)
	Sound.play("thunder", 0.05, -6.0, 0.6)
	shake_cameras(4.0, 0.3)


func shake_cameras(strength: float, duration: float) -> void:
	for player in get_tree().get_nodes_in_group(Player.GROUP_PLAYER):
		player.shake_camera(strength, duration)
		return


# Coup de faux : appelés par l'animation d'attaque
func on_attack_windup() -> void:
	Sound.play("swing", 0.02, 0.0, 0.6)
	if _flash_tween:
		_flash_tween.kill()
	_material.set_shader_parameter("flash_color", Color.WHITE)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(value: float): _material.set_shader_parameter("flash", value), 0.6, 0.0, 0.3)


func on_attack_slash() -> void:
	Sound.play("swing", 0.02, 2.0, 0.8)
	Fx.squash(_bodyPivot, Vector2(1.15, 0.9))


# Éclair pendant l'élan de l'écrasement : arcs seulement, le clignotement rouge
# d'avertissement reste lisible
func lightning_feedback() -> void:
	if not _slamming:
		super.lightning_feedback()
		return
	var start_angle := randf() * TAU
	for i in range(LIGHTNING_ARC_COUNT):
		_spawn_arc(start_angle + TAU * (i + randf_range(-0.2, 0.2)) / LIGHTNING_ARC_COUNT)


func took_damage(damage: int) -> void:
	if _life <= 0 or _intro:
		return

	update_life(_life - damage)
	Sound.play("hit", 0.15, 0.0, 0.8)
	hit_feedback()

	if get_life() <= 0.0:
		die()
		return

	if not _enraged and _life <= _max_life * ENRAGE_RATIO:
		enrage()

	_hits_since_stagger += 1
	if _hits_since_stagger >= STAGGER_HITS and not _slamming:
		_hits_since_stagger = 0
		disable_hitbox()
		_stateMachine.set_state_damaged()


func enrage() -> void:
	_enraged = true
	_walk_speed *= ENRAGE_SPEED_FACTOR
	_next_slam_ms = mini(_next_slam_ms, Time.get_ticks_msec() + 800)
	Fx.floating_text(get_parent(), "ENRAGED!", global_position + Vector2(0, -78), SLAM_COLOR, 7)
	Fx.ring(get_parent(), global_position + Vector2(0, -30), SLAM_COLOR, 34.0, 0.4)
	if _bar:
		_bar.set_fill_color(SLAM_COLOR)
		_bar.start_blink(Color("ffb0a0"), 0.4)


func die() -> void:
	_death_ms = Time.get_ticks_msec()
	if _slam_tween:
		_slam_tween.kill()
	if _flash_tween:
		_flash_tween.kill()
	disable_hitbox()
	_material.set_shader_parameter("flash", 0.0)
	_sprite.position.y = _sprite_y
	_slamming = false
	_stateMachine.process_mode = Node.PROCESS_MODE_INHERIT
	_stateMachine.set_state_died()
	Game.hit_stop(0.25, 0.1)
	shake_cameras(5.0, 0.5)
	var parent := get_parent()
	var tween := create_tween()
	for i in range(5):
		tween.tween_callback(func():
			if is_instance_valid(parent):
				var at := global_position + Vector2(randf_range(-24, 24), randf_range(-50, -6))
				Fx.burst(parent, at, [Color("ffd34d"), SLAM_COLOR, Fx.enemy_color(_type)][i % 3], 16)
				Fx.ring(parent, at, Color.WHITE, 14.0, 0.25)
				Sound.play("enemy_die", 0.1)
		)
		tween.tween_interval(0.12)
	remove_life_bar()
	defeated.emit(self)


# Coup de faux interrompu (sonné, mort) entre l'activation et la désactivation de la
# zone de frappe : l'animation suivante ne la remet pas à « disabled »
func disable_hitbox() -> void:
	_hitBox.get_node("CollisionShape2D").set_deferred("disabled", true)


func start_death() -> void:
	if _is_dying:
		return
	Fx.ring(get_parent(), global_position, Fx.enemy_color(_type), SLAM_RADIUS + 20.0, 0.5)
	super.start_death()


# Barre de vie du boss en bas de l'écran, avec son nom, à côté du HUD
func build_life_bar() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = BAR_LAYER
	hud.get_parent().add_child(_bar_layer)
	_bar_root = Control.new()
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.position = Vector2((320 - BAR_WIDTH) / 2.0, BAR_Y)
	_bar_layer.add_child(_bar_root)

	var label := Label.new()
	label.text = BOSS_NAME
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", Color("ffd34d"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(BAR_WIDTH, 0)
	label.position = Vector2(0, BAR_LABEL_Y)
	_bar_root.add_child(label)

	_bar = PixelBar.new()
	_bar.max_value = _max_life
	_bar.segment = 0.0
	_bar.fill_color = Fx.enemy_color(_type)
	_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(_bar)
	_bar.set_value(0.0, false)
	_bar.set_value(_max_life)


func remove_life_bar() -> void:
	if is_instance_valid(_bar_root):
		var tween := _bar_root.create_tween()
		tween.tween_interval(0.4)
		tween.tween_property(_bar_root, "modulate:a", 0.0, 0.4)
		tween.tween_callback(_bar_layer.queue_free)


func update_enemy_life(_start_value: float, end_value: float) -> void:
	if _bar:
		_bar.set_value(maxf(end_value, 0.0))
		_bar.flash()


func _exit_tree() -> void:
	if is_instance_valid(_bar_layer) and not _bar_layer.is_queued_for_deletion():
		_bar_layer.queue_free()
