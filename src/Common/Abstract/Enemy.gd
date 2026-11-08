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
# Teinte selon la profondeur (y des pieds entre le fond et le premier plan de la zone de marche)
const DEPTH_Y_FAR:=120.0
const DEPTH_Y_NEAR:=200.0
const DEPTH_FAR_BRIGHTNESS:=0.62
const DEPTH_FAR_BLUE:=0.1
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

# Calques physiques (noms dans project.godot > layer_names)
# 1 « player » : joueur, murs de marche, barrières électriques (StaticBody2D)
# 2 « enemies » : corps des ennemis
# 3 : calque réservé aux barrières si leur StaticBody2D quitte le calque 1
const PHYSICS_LAYER_PLAYER:=1
const PHYSICS_LAYER_ENEMIES:=2
const PHYSICS_LAYER_BARRIERS:=3
# Les ennemis se poussent entre eux mais ignorent joueur, murs et barrières :
# ils traversent une barrière fermée (le joueur, lui, reste bloqué)
const BODY_LAYER:=1 << (PHYSICS_LAYER_ENEMIES - 1)
const BODY_MASK:=1 << (PHYSICS_LAYER_ENEMIES - 1)
# Obstacles du joueur : sert à savoir si un poste d'attaque lui est accessible
# et à repérer les barrières que l'ennemi traverse
const OBSTACLE_MASK:=(1 << (PHYSICS_LAYER_PLAYER - 1)) | (1 << (PHYSICS_LAYER_BARRIERS - 1))

# Poste d'attaque derrière une barrière fermée (ou dans son arc) : l'ennemi la traverse
# et se place de l'autre côté du joueur, au lieu de rester planté dans l'arc
# (ou, pour l'araignée, de tirer de derrière la barrière, hors d'atteinte)
const ATTACK_SPOT_CLEARANCE:=6.0
# Hauteur du rayon de test : milieu du corps, loin des murs haut et bas
const ATTACK_SPOT_RAY_HEIGHT:=-6.0
var _attack_side:=1.0
var _attack_side_frame:=-1

# Traversée d'une barrière fermée : étincelles et flash à la couleur de la barrière
# quand le centre de l'ennemi passe l'arc
const CROSS_SPARK_AMOUNT:=6
const CROSS_SPARK_HEIGHT:=8.0
const CROSS_FLASH:=0.7
const CROSS_FLASH_DURATION:=0.15
# Dash de traversée : près d'une barrière fermée, l'ennemi file à travers l'arc
const BARRIER_DASH_ZONE:=18.0
const BARRIER_DASH_SPEED_MULT:=5.0
const BARRIER_DASH_GHOST_EVERY:=3
const BARRIER_DASH_GHOST_DURATION:=0.22
# Teinte du flash de l'éclair (valeur par défaut de flash_color dans character.gdshader)
const LIGHTNING_FLASH_TINT:=Color(0.75, 0.88, 1.0)
# forme de barrière chevauchée -> {"barrier": nœud, "side": côté de l'ennemi par rapport à l'arc}
# côté (-1/1) de chaque barrière où se trouvait l'ennemi à l'image précédente
var _barrier_sides:={}
# barrière fermée traversée en dash (null hors dash)
var _dash_barrier:Node=null
var _dash_frames:=0

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
@onready var _sprite:AnimatedSprite2D=get_node("BodyPivot/AnimatedSprite2D")

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
	if _dash_barrier:
		return _walk_speed * BARRIER_DASH_SPEED_MULT
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

	collision_layer=BODY_LAYER
	collision_mask=BODY_MASK


func _physics_process(_delta: float) -> void:
	_check_barrier_crossing()


# Le centre de l'ennemi change de côté de l'arc d'une barrière encore fermée.
# Test géométrique (pas d'Area2D) : la forme de la barrière couvre toute la
# hauteur de la zone de marche, seule l'abscisse compte.
func _check_barrier_crossing() -> void:
	var dash_barrier:Node=null
	for barrier in get_tree().get_nodes_in_group(Game.GROUP_BARRIER):
		var arc_x:float=barrier.get_arc_x()
		if absf(global_position.x - arc_x) < BARRIER_DASH_ZONE and not barrier.is_open():
			dash_barrier=barrier
		var side:=signf(global_position.x - arc_x)
		# pile sur l'arc (déplacements par pas de 0,25 px) : on garde le dernier côté connu
		if side == 0.0:
			continue
		var previous:float=_barrier_sides.get(barrier, side)
		_barrier_sides[barrier]=side
		if side != previous and not barrier.is_open():
			barrier_crossing_feedback(barrier, arc_x)
	_update_barrier_dash(dash_barrier)


# Entrée dans la zone d'une barrière fermée : accélération, écrasement, poussière,
# puis images fantômes à la couleur de la barrière tant que l'ennemi avance
func _update_barrier_dash(barrier: Node) -> void:
	if barrier == null:
		_dash_barrier=null
		return
	var moving:=absf(velocity.x) > 1.0
	if _dash_barrier != barrier:
		_dash_barrier=barrier
		_dash_frames=0
		Fx.squash(_bodyPivot, Vector2(1.35, 0.75))
		Fx.dust(get_parent(), global_position, signf(velocity.x) if moving else look_direction.x)
	_dash_frames+=1
	if moving and _dash_frames % BARRIER_DASH_GHOST_EVERY == 0:
		_spawn_dash_ghost(Fx.enemy_color(barrier.get_type()))


func _spawn_dash_ghost(color: Color) -> void:
	var sprite:AnimatedSprite2D=get_node("BodyPivot/AnimatedSprite2D")
	var ghost:=Sprite2D.new()
	ghost.texture=sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered=sprite.centered
	ghost.offset=sprite.offset
	ghost.flip_h=sprite.flip_h
	ghost.modulate=Color(color.lightened(0.3), 0.55)
	get_parent().add_child(ghost)
	ghost.global_transform=sprite.global_transform
	var tween:=ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, BARRIER_DASH_GHOST_DURATION)
	tween.tween_callback(ghost.queue_free)


# Petites étincelles sur l'arc et bref flash du corps, à la couleur de la barrière
func barrier_crossing_feedback(barrier: Node, arc_x: float) -> void:
	var barrier_type=barrier.get_type() if barrier.has_method("get_type") else _type
	var color:=Fx.enemy_color(barrier_type)
	Fx.burst(get_parent(), Vector2(arc_x, global_position.y - CROSS_SPARK_HEIGHT).round(), color.lightened(0.4), CROSS_SPARK_AMOUNT)

	if _flash_tween:
		_flash_tween.kill()
	_material.set_shader_parameter("flash_color", color.lightened(0.5))
	_material.set_shader_parameter("flash", CROSS_FLASH)
	_flash_tween=create_tween()
	_flash_tween.tween_method(func(value: float):
		_material.set_shader_parameter("flash", value)
	, CROSS_FLASH, 0.0, CROSS_FLASH_DURATION)


func _process(delta: float) -> void:
	_update_depth_tint()
	var target:=DEPTH_SHADE if is_behind_someone() else 0.0
	if _depth_shade == target:
		return
	_depth_shade=move_toward(_depth_shade, target, delta * DEPTH_SHADE_SPEED)
	_material.set_shader_parameter("depth_shade", _depth_shade)


# Profondeur de champ : normal au premier plan (bas de la zone de marche), de plus
# en plus sombre et bleuté vers le fond (haut). self_modulate du sprite : le
# modulate du nœud reste libre pour le flash rouge des coups
func _update_depth_tint() -> void:
	var t:=clampf(inverse_lerp(DEPTH_Y_NEAR, DEPTH_Y_FAR, global_position.y), 0.0, 1.0)
	var brightness:=lerpf(1.0, DEPTH_FAR_BRIGHTNESS, t)
	_sprite.self_modulate=Color(brightness, brightness, minf(1.0, brightness + DEPTH_FAR_BLUE * t))


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
	_material.set_shader_parameter("flash_color", LIGHTNING_FLASH_TINT)
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
	_barrier_sides.clear()
	_dash_barrier=null

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
	
# Poste d'attaque : à côté du joueur, du côté où se trouve l'ennemi,
# sauf si ce poste est derrière une barrière fermée (ou dedans)
func get_target_offset_position()->Vector2:
	var side:=get_attack_side()
	return _player.global_position + Vector2(_near_distance/2 * side, 0) + get_attack_slot_offset(side)


# Places autour du joueur pour ne pas s'entasser : les premières au contact (elles
# attaquent), les suivantes en retrait (elles attendent). x est compté vers l'extérieur.
const ATTACK_SLOTS:=[Vector2(0, 0), Vector2(0, -8), Vector2(0, 8),
	Vector2(12, -4), Vector2(12, 4), Vector2(24, 0), Vector2(24, -8), Vector2(24, 8)]
const ATTACK_FRONT_SLOTS:=3
const RANGED_NEAR_DISTANCE:=100
const SPOT_REACHED_DISTANCE:=1.5
var _slot_index:=0
var _slot_frame:=-1


# Rang stable (identifiant d'instance) parmi les ennemis du même côté et de même portée,
# en sautant les places qui tombent dans un mur ou une barrière fermée
func get_attack_slot_offset(side: float)->Vector2:
	var frame:=Engine.get_physics_frames()
	if frame != _slot_frame and Engine.is_in_physics_frame():
		_slot_frame=frame
		var rank:=0
		for other in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
			if other == self or other._is_dying or other.is_ranged() != is_ranged() or other._player == null:
				continue
			if other.get_attack_side() == side and other.get_instance_id() < get_instance_id():
				rank+=1
		_slot_index=_free_slot(rank, side)
	return ATTACK_SLOTS[_slot_index] * Vector2(side, 1)


func _free_slot(rank: int, side: float)->int:
	var base:Vector2=_player.global_position + Vector2(_near_distance/2 * side, ATTACK_SPOT_RAY_HEIGHT)
	var query:=PhysicsPointQueryParameters2D.new()
	query.collision_mask=OBSTACLE_MASK
	query.exclude=[_player.get_rid()]
	var space:=get_world_2d().direct_space_state
	var free:=-1
	for i in range(ATTACK_SLOTS.size()):
		query.position=base + ATTACK_SLOTS[i] * Vector2(side, 1)
		var blocked:=false
		for hit in space.intersect_point(query, 4):
			if hit["collider"] is StaticBody2D:
				blocked=true
		if blocked:
			continue
		free+=1
		if free == rank:
			return i
	return ATTACK_SLOTS.size() - 1


# Tireur à distance (araignée) : ses places ne se mêlent pas à celles du corps à corps
func is_ranged()->bool:
	return _near_distance > RANGED_NEAR_DISTANCE


func is_in_front_slot()->bool:
	return _slot_index < ATTACK_FRONT_SLOTS


# -1 : poste à gauche du joueur, 1 : à droite. Calculé une fois par image physique
# (plusieurs appels par image dans les états de marche et d'attaque)
func get_attack_side()->float:
	var natural_side:=-1.0 if global_position.x < _player.global_position.x else 1.0
	var frame:=Engine.get_physics_frames()
	if frame == _attack_side_frame:
		return _attack_side
	# requêtes physiques sûres seulement pendant l'image physique : hors de celle-ci
	# (fin d'animation), on garde le côté de l'image physique précédente
	if not Engine.is_in_physics_frame():
		return _attack_side if _attack_side_frame >= 0 and frame - _attack_side_frame <= 1 else natural_side
	_attack_side_frame=frame
	_attack_side=natural_side
	# Une fois de l'autre côté du joueur, le côté naturel redevient le bon : pas d'aller-retour
	if not is_attack_spot_reachable(natural_side) and is_attack_spot_reachable(-natural_side):
		_attack_side=-natural_side
	return _attack_side


# Aucun obstacle fixe (barrière fermée, mur) entre le joueur et le poste d'attaque,
# en gardant la place du corps de l'ennemi au bout
func is_attack_spot_reachable(side: float)->bool:
	var from:Vector2=_player.global_position + Vector2(0, ATTACK_SPOT_RAY_HEIGHT)
	var to:=from + Vector2((_near_distance/2 + ATTACK_SPOT_CLEARANCE) * side, 0)
	var excluded:Array[RID]=[_player.get_rid()]
	var query:=PhysicsRayQueryParameters2D.create(from, to, OBSTACLE_MASK, excluded)
	var space:=get_world_2d().direct_space_state
	# les corps mobiles éventuels sur ces calques (orbes d'énergie…) ne comptent pas
	for i in range(4):
		var hit:=space.intersect_ray(query)
		if hit.is_empty():
			return true
		if hit["collider"] is StaticBody2D:
			return false
		excluded.append(hit["rid"])
		query.exclude=excluded
	return true


# Au poste : face au joueur (le reste de trajet peut pointer à l'opposé
# quand l'ennemi arrive de l'autre côté après avoir traversé une barrière)
func get_target_direction()->Vector2:
	if is_near_player():
		return Vector2(signf(_player.global_position.x - global_position.x), 0) if _player.global_position.x != global_position.x else Vector2.ZERO

	var target_offset:=get_target_offset_position()
	# arrivé à sa place (d'attente) : on s'arrête plutôt que de marcher sur place
	if global_position.distance_to(target_offset) > SPOT_REACHED_DISTANCE:
		return position.direction_to(target_offset)
	return Vector2.ZERO
	
func is_near_player()->bool:
	var distance_to_player:= global_position.distance_to(get_target_offset_position())

	return distance_to_player < 4 and abs(global_position.y - get_target_offset_position().y) <2 and is_in_front_slot()
		
	
	
func _on_HitBox_body_entered(body: Node) -> void:
	if body is Player:
		Events.emit_signal("actor_took_damage",body,_damage)
