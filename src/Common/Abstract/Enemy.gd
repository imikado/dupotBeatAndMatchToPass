class_name Enemy
extends Actor


var _player : CharacterBody2D
var _near_distance:=10
var _damage:=10
const MAX_LIFE=50.0
var _life:=50.0
var _type= Game.ENEMY_TYPE_LIST.ANT
var _walk_speed:=15.0
var _shadow_width:=14

# Recul quand l'épée touche : léger pour ne pas sortir l'ennemi du combo, fort sur le dernier coup
const KNOCKBACK:=2.0
const KNOCKBACK_FINISHER:=8.0

# Assombri quand un autre personnage passe devant (plus bas à l'écran) en le chevauchant
const DEPTH_SHADE:=0.7
const DEPTH_SHADE_SPEED:=5.0
const OVERLAP_DISTANCE_X:=22.0
const OVERLAP_DISTANCE_Y:=16.0
# En dessous de cet écart, les deux personnages sont sur la même ligne (ex. ennemi qui attaque)
const SAME_LINE_Y:=2.0

var _material:ShaderMaterial
var _depth_shade:=0.0

# Mort : dissolution par pixels (character.gdshader), bord à la couleur de l'ennemi
const DEATH_DURATION:=0.4
const DISSOLVE_ENERGY:=1.8
const DEATH_BURST_AMOUNT:=14

# Éclair : flash bleu-blanc + petits arcs autour du corps ; tué par l'éclair = carbonisé
const LIGHTNING_COLOR:=Color(0.55, 0.75, 1.0)
const LIGHTNING_FLASH_DURATION:=0.3
const LIGHTNING_ARC_COUNT:=3
const LIGHTNING_ARC_LENGTH:=10.0
const ASH_COLOR:=Color(0.55, 0.53, 0.5)
const CHAR_DURATION:=0.12
# Écart max entre l'éclair et le coup mortel (les deux signaux arrivent dans un ordre quelconque)
const LIGHTNING_KILL_WINDOW_MS:=250

# Barre de vie pixel : fond sombre, bordure 1 px, remplissage à la couleur de l'ennemi
const LIFE_BAR_BACKGROUND:=Color(0.078, 0.047, 0.11)
const LIFE_BAR_BORDER:=Color(0.02, 0.01, 0.03)

var _last_strike_ms:=-100000
var _death_ms:=-100000
var _charred:=false
var _flash_tween:Tween

var _is_dying:=false
var _knockback_tween:Tween
var _hit_tween:Tween

var _combo_count=0

# Marqueur « à battre » au-dessus de la tête : l'ennemi charge encore une barrière
const MARKER_HEIGHT:=30.0
const MARKER_BOB:=1.0
var _marker:Sprite2D

@onready var _animationPlayer:=get_node("BodyPivot/AnimationPlayer")
@onready var _stateMachine := get_node("EnemyStateMachine")
@onready var _enemy_progress_bar := get_node("BodyPivot/Control/ProgressBar")
@onready var _timer:=get_node("Timer")

@onready var _hitBox:=get_node("BodyPivot/HitBox")
@onready var _bodyPivot:=get_node("BodyPivot")

var look_direction = Vector2(1, 0): set = set_look_direction

func increment_combo_count():
	_combo_count+=1
	
func get_combo_count():
	return _combo_count

func reset_combo_count():
	_combo_count=0


func get_type():
	return _type


func set_wanted(wanted:bool)->void:
	if _marker == null:
		if not wanted:
			return
		_marker=Sprite2D.new()
		_marker.texture=marker_texture()
		_marker.modulate=Fx.enemy_color(_type).lightened(0.3)
		_marker.position=Vector2(0, -MARKER_HEIGHT)
		add_child(_marker)
		var tween:=_marker.create_tween().set_loops()
		tween.tween_property(_marker, "position:y", -MARKER_HEIGHT - MARKER_BOB, 0.35).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_marker, "position:y", -MARKER_HEIGHT, 0.35).set_trans(Tween.TRANS_SINE)
	_marker.visible=wanted and not _is_dying


static var _marker_texture:ImageTexture

# Petite flèche vers le bas (5×4 px) avec contour sombre
static func marker_texture()->ImageTexture:
	if _marker_texture:
		return _marker_texture
	var rows:=PackedStringArray([
		"ooooooo",
		"o#####o",
		".o###o.",
		"..o#o..",
		"...o...",
	])
	var img:=Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			match rows[y][x]:
				"#": img.set_pixel(x, y, Color.WHITE)
				"o": img.set_pixel(x, y, Color(0.05, 0.03, 0.08))
	_marker_texture=ImageTexture.create_from_image(img)
	return _marker_texture

func get_walk_speed():
	return _walk_speed

# Plus rapide et plus fort à chaque niveau après le niveau 3
func apply_difficulty(difficulty:int):
	_walk_speed*=min(1.0 + 0.1 * difficulty, 1.6)
	_damage=int(round(_damage * min(1.0 + 0.1 * difficulty, 1.5)))

func update_enemy_life(start_value:float, end_value:float)->void:

	# Mort : la barre (vide) disparaît tout de suite
	if end_value <= 0.0 or _life <= 0:
		hide_progressbar()
		return

	_enemy_progress_bar.visible=true

	var health = float(clamp(end_value, _enemy_progress_bar.min_value, _enemy_progress_bar.max_value))
	# Here, notice we call `interpolate_method()`. We have the `Tween` node
	# repeatedly call the `_update_health_bar()` method on this node.
	
	var tween := create_tween()
	tween.tween_method(Callable(self, "_update_enemy_health_bar"), start_value, health, 0.33)
	
	
	#yield(get_tree().create_timer(1.0), "timeout")
	
	_timer.start()
	
	


func hide_progressbar():
	_enemy_progress_bar.visible=false	


func _update_enemy_health_bar(health_target: float) -> void:
	_enemy_progress_bar.value = snap_life_bar_value(_enemy_progress_bar, health_target)


# Valeur arrondie pour que le remplissage tombe sur un pixel entier
static func snap_life_bar_value(bar: ProgressBar, value: float) -> float:
	var width:float=maxf(bar.size.x, 1.0)
	var span:float=bar.max_value - bar.min_value
	return bar.min_value + round((value - bar.min_value) / span * width) / width * span


# Style pixel des barres de vie des ennemis (dans l'esprit de PixelBar.gd du HUD)
static func style_life_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background:=StyleBoxFlat.new()
	background.bg_color=LIFE_BAR_BACKGROUND
	background.border_color=LIFE_BAR_BORDER
	background.set_border_width_all(1)
	background.anti_aliasing=false
	var fill:=StyleBoxFlat.new()
	fill.bg_color=fill_color
	fill.border_color=LIFE_BAR_BORDER
	fill.set_border_width_all(1)
	fill.anti_aliasing=false
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	

func set_look_direction(value):
	look_direction = value

	
func setPlayer(player: CharacterBody2D):
	_player= player
	set_physics_process(true)

	
func _ready() -> void:
	_animationPlayer.connect("animation_finished", Callable(_stateMachine, "_on_animation_finished"))
	_stateMachine.set_state_walk()
	
	_enemy_progress_bar.set_max(MAX_LIFE)
	_hitBox.connect("body_entered", Callable(self, "_on_HitBox_body_entered"))
	_timer.connect("timeout", Callable(self, "hide_progressbar"))

	Fx.shadow(self, _shadow_width).position = Vector2(0, -1)
	_material=Fx.character_material(get_node("BodyPivot/AnimatedSprite2D"))

	style_life_bar(_enemy_progress_bar, Fx.enemy_color(_type))
	Events.actor_struck_by_lightning.connect(_on_struck_by_lightning)


func _process(delta: float) -> void:
	var target:=DEPTH_SHADE if is_behind_someone() else 0.0
	if _depth_shade == target:
		return
	_depth_shade=move_toward(_depth_shade, target, delta * DEPTH_SHADE_SPEED)
	_material.set_shader_parameter("depth_shade", _depth_shade)


func is_behind_someone() -> bool:
	var others:Array=get_tree().get_nodes_in_group(Game.GROUP_ENEMY)
	if _player:
		others.append(_player)
	for other in others:
		if other == self:
			continue
		var dy:float=other.global_position.y - global_position.y
		if dy > SAME_LINE_Y and dy < OVERLAP_DISTANCE_Y and abs(other.global_position.x - global_position.x) < OVERLAP_DISTANCE_X:
			return true
	return false
	
	
func get_life():
	return _life


func update_life(newLife:int):

	Events.emit_signal("actor_health_changed",self,_life,newLife)
	
	_life=newLife
	
func took_damage(damage:int):
	if _life <=0:
		return
		
	update_life(_life - damage)
	Sound.play("hit", 0.15)
	
	_stateMachine.set_state_damaged()

	hit_feedback()

	if get_life() <= 0.0:
		hide_progressbar()
		if _marker:
			_marker.visible=false
		_death_ms=Time.get_ticks_msec()
		if _death_ms - _last_strike_ms <= LIGHTNING_KILL_WINDOW_MS:
			char_body()
		_stateMachine.set_state_died()


func _on_struck_by_lightning(actor) -> void:
	if actor != self or _is_dying:
		return
	_last_strike_ms=Time.get_ticks_msec()
	# coup mortel reçu juste avant l'éclair (même impact)
	if _life <= 0 and _last_strike_ms - _death_ms <= LIGHTNING_KILL_WINDOW_MS:
		char_body()
	lightning_feedback()


# Flash bleu-blanc (uniform du shader : le modulate reste aux coups d'épée) et petits arcs
func lightning_feedback() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_material.set_shader_parameter("flash", 1.0)
	_flash_tween=create_tween()
	_flash_tween.tween_method(func(value: float):
		_material.set_shader_parameter("flash", value)
	, 1.0, 0.0, LIGHTNING_FLASH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var start_angle:=randf() * TAU
	for i in range(LIGHTNING_ARC_COUNT):
		_spawn_arc(start_angle + TAU * (i + randf_range(-0.2, 0.2)) / LIGHTNING_ARC_COUNT)


# Arc d'environ 10 px qui part du corps vers l'extérieur, change de forme puis s'éteint.
# Dans le conteneur des personnages (pas en enfant : le modulate rouge des coups le teinterait),
# 1 px plus bas que l'ennemi pour être trié juste après lui
func _spawn_arc(angle: float) -> void:
	var bolt:=Bolt.new()
	bolt.color=LIGHTNING_COLOR
	bolt.thickness=0.5
	bolt.branch_count=0
	bolt.jaggedness=0.35
	get_parent().add_child(bolt)
	bolt.global_position=global_position.round() + Vector2(0, 1)
	var center:=Vector2(0, -13)
	var from:=(center + Vector2.from_angle(angle) * Vector2(5, 6)).round()
	var to:=(from + Vector2.from_angle(angle + randf_range(-0.6, 0.6)) * LIGHTNING_ARC_LENGTH).round()
	bolt.set_ends(from, to)

	var tween:=bolt.create_tween()
	for i in range(2):
		tween.tween_interval(LIGHTNING_FLASH_DURATION / 4)
		tween.tween_callback(bolt.regenerate)
	tween.tween_method(bolt.set_intensity, 1.0, 0.0, LIGHTNING_FLASH_DURATION / 2)
	tween.tween_callback(bolt.queue_free)


# Mort par l'éclair : silhouette noire, puis dissolution en cendres grises
func char_body() -> void:
	if _charred:
		return
	_charred=true
	var tween:=create_tween()
	tween.tween_method(func(value: float):
		_material.set_shader_parameter("char_amount", value)
	, 0.0, 1.0, CHAR_DURATION)


# Flash blanc, écrasement, étincelles et recul à l'opposé du joueur
func hit_feedback():
	var away:=1.0 if global_position.x >= _player.global_position.x else -1.0

	if _hit_tween:
		_hit_tween.kill()
	# HDR 2D : au-delà de ~1.8 le sprite vire au jaune-vert lumineux
	modulate=Color(1.7, 1.7, 1.7)
	_hit_tween = create_tween()
	_hit_tween.tween_interval(0.05)
	_hit_tween.tween_property(self,"modulate",Color.RED,0.1)
	_hit_tween.tween_property(self,"modulate",Color.WHITE,0.2)

	Fx.squash(_bodyPivot, Vector2(0.8, 1.2), 0.15)
	Fx.hit_spark(get_parent(), global_position + Vector2(-away * 5, -10))

	var distance:=KNOCKBACK
	if _player.has_method("get_state") and _player.get_state() == "Attack04":
		distance=KNOCKBACK_FINISHER

	if _knockback_tween:
		_knockback_tween.kill()
	var moved:=[0.0]
	_knockback_tween = create_tween()
	_knockback_tween.tween_method(func(done: float):
		move_and_collide(Vector2(away, 0) * (done - moved[0]))
		moved[0] = done
	, 0.0, distance, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# Fin de l'animation de mort : l'ennemi ne gêne plus, se dissout puis disparaît
func start_death():
	if _is_dying:
		return
	_is_dying=true

	remove_from_group(Game.GROUP_ENEMY)
	_stateMachine.process_mode=Node.PROCESS_MODE_DISABLED
	set_physics_process(false)
	collision_layer=0
	collision_mask=0
	_hitBox.set_deferred("monitoring", false)

	hide_progressbar()
	_timer.stop()
	if _marker:
		_marker.visible=false

	var color:=ASH_COLOR if _charred else Fx.enemy_color(_type)
	_material.set_shader_parameter("dissolve_color", color)
	_material.set_shader_parameter("dissolve_energy", 1.0 if _charred else DISSOLVE_ENERGY)
	Fx.burst(get_parent(), global_position + Vector2(0, -6), color, DEATH_BURST_AMOUNT)

	var tween := create_tween()
	tween.tween_method(func(value: float):
		_material.set_shader_parameter("dissolve", value)
	, 0.0, 1.0, DEATH_DURATION)
	tween.tween_callback(queue_free)
	
func get_target_position()->Vector2:
	return _player.global_position
	
func get_target_offset_position()->Vector2:
	
	var target_offset=Vector2(_near_distance/2,0)
	
	if global_position.x < _player.global_position.x:
		target_offset.x*=-1
	
	return _player.global_position + target_offset
			
	
func get_target_direction()->Vector2:
	var direction := Vector2.ZERO
	var target_offset:=get_target_offset_position()
	
	var distance_to_player:= global_position.distance_to(target_offset) # _player.global_position-position

	if distance_to_player > 0:
		direction=position.direction_to(target_offset)

	return direction
	
func is_near_player()->bool:
	var distance_to_player:= global_position.distance_to(get_target_offset_position())

	return distance_to_player < 4 and abs(global_position.y - get_target_offset_position().y) <2
		
	
	
func _on_HitBox_body_entered(body: Node) -> void:
	if body is Player:
		Events.emit_signal("actor_took_damage",body,_damage)
