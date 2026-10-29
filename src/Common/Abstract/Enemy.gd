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

var _is_dying:=false
var _knockback_tween:Tween
var _hit_tween:Tween

var _combo_count=0

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

func get_walk_speed():
	return _walk_speed

# Plus rapide et plus fort à chaque niveau après le niveau 3
func apply_difficulty(difficulty:int):
	_walk_speed*=min(1.0 + 0.1 * difficulty, 1.6)
	_damage=int(round(_damage * min(1.0 + 0.1 * difficulty, 1.5)))

func update_enemy_life(start_value:float, end_value:float)->void:

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
	_enemy_progress_bar.value = health_target
	

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
		_stateMachine.set_state_died()


# Flash blanc, écrasement, étincelles et recul à l'opposé du joueur
func hit_feedback():
	var away:=1.0 if global_position.x >= _player.global_position.x else -1.0

	if _hit_tween:
		_hit_tween.kill()
	modulate=Color(2.5, 2.5, 2.5)
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


# Fin de l'animation de mort : l'ennemi ne gêne plus, clignote puis disparaît
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

	var tween := create_tween()
	for i in range(4):
		tween.tween_callback(func(): visible=false)
		tween.tween_interval(0.05)
		tween.tween_callback(func(): visible=true)
		tween.tween_interval(0.05)
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
