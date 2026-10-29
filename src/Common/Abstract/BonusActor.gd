class_name BonusActor
extends Actor


var _player : Marker2D
var _near_distance:=10
var _damage:=10
const MAX_LIFE=50.0
var _life:=50
var _type= Game.ENEMY_TYPE_LIST.ANT

var _combo_count=0

@onready var _animationPlayer:=get_node("BodyPivot/AnimationPlayer")
@onready var _stateMachine := get_node("BonusActorStateMachine")
@onready var _enemy_progress_bar := get_node("BodyPivot/Control/ProgressBar")
@onready var _timer:=get_node("Timer")

var _can_let_item=true

# Comme les voleurs de Golden Axe : quelques bouteilles dans le sac, puis il s'enfuit
const KNOCKBACK_DISTANCE:=10.0
const HURT_HOP_HEIGHT:=8.0
const FLEE_SPEED_FACTOR:=3.0
var _items_left:=3
var _is_fleeing:=false
var _return_target : Marker2D

@onready var _bodyPivot:=get_node("BodyPivot")
@onready var _sprite:=get_node("BodyPivot/AnimatedSprite2D")
@onready var _sprite_base_y:float=_sprite.position.y


var look_direction = Vector2(1, 0): set = set_look_direction

func increment_combo_count():
	_combo_count+=1
	
func get_combo_count():
	return _combo_count

func reset_combo_count():
	_combo_count=0


func get_type():
	return _type

func update_enemy_life(start_value:float, end_value:float)->void:

	_enemy_progress_bar.visible=true

	var health = float(clamp(end_value, _enemy_progress_bar.min_value, _enemy_progress_bar.max_value))
	# Here, notice we call `interpolate_method()`. We have the `Tween` node
	# repeatedly call the `_update_health_bar()` method on this node.
	
	var tween := create_tween()
	tween.tween_method(Callable(self, "_update_enemy_health_bar"), start_value, health, 0.33)
	
	
	#yield(get_tree().create_timer(1.0), "timeout")

func can_let_item():
	return _can_let_item and _items_left > 0

func let_item(from_position: Vector2):
	_can_let_item=false
	_timer.start()
	_items_left-=1

	_stateMachine.set_state_idle()

	# Recule en sautillant, écrasé par le coup, puis repart
	var side := 1.0 if global_position.x >= from_position.x else -1.0
	Fx.squash(_bodyPivot, Vector2(1.3, 0.7))

	var knockback := create_tween()
	knockback.tween_property(self, "global_position:x", global_position.x + side * KNOCKBACK_DISTANCE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var hop := create_tween()
	hop.tween_property(_sprite, "position:y", _sprite_base_y - HURT_HOP_HEIGHT, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(_sprite, "position:y", _sprite_base_y, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	hop.tween_interval(0.25)
	hop.tween_callback(_end_hurt.bind(side))

	var blink := create_tween().set_loops(3)
	blink.tween_property(_sprite, "modulate:a", 0.3, 0.06)
	blink.tween_property(_sprite, "modulate:a", 1.0, 0.06)

func _end_hurt(side: float):
	if _items_left <= 0:
		_flee(side)
	_stateMachine.set_state_walk()

# Sac vide : il file vers la sortie opposée au joueur
func _flee(side: float):
	_is_fleeing=true
	_animationPlayer.speed_scale=2.0
	if _return_target and (_return_target.global_position.x - _player.global_position.x) * side > 0:
		_player=_return_target

func get_speed_factor()->float:
	return FLEE_SPEED_FACTOR if _is_fleeing else 1.0

# Arrivé au bout du trajet : fait demi-tour, ou disparaît s'il s'enfuit
func on_target_reached():
	if _is_fleeing:
		queue_free()
		return
	if _return_target == null:
		return
	var previous_target=_player
	_player=_return_target
	_return_target=previous_target

func allow_let_item():
	_can_let_item=true


func hide_progressbar():
	_enemy_progress_bar.visible=false	


func _update_enemy_health_bar(health_target: float) -> void:
	_enemy_progress_bar.value = health_target
	

func set_look_direction(value):
	look_direction = value

	
func setTarget(player: Marker2D, return_target: Marker2D = null):
	_player= player
	_return_target= return_target
	set_physics_process(true)

	
func _ready() -> void:
	_animationPlayer.connect("animation_finished", Callable(_stateMachine, "_on_animation_finished"))
	_timer.timeout.connect(allow_let_item)
	_stateMachine.set_state_walk()
	
	_enemy_progress_bar.set_max(MAX_LIFE)

	Fx.shadow(self, 14).position = Vector2(0, -1)
	Fx.character_material(get_node("BodyPivot/AnimatedSprite2D"))

	
func get_life():
	return _life


func update_life(newLife:int):

	Events.emit_signal("actor_health_changed",self,_life,newLife)
	
	_life=newLife
	
func took_damage(damage:int):
	if _life <=0:
		return
		
	update_life(_life - damage)
	
	_stateMachine.set_state_damaged()
	
	var tween := create_tween()
	tween.tween_property(self,"modulate",Color.RED,0.3)
	tween.tween_property(self,"modulate",Color.WHITE,0.2)
	
		
	if get_life() <= 0.0:
		_stateMachine.set_state_died()
	
func get_target_position()->Vector2:
	return _player.global_position
	
func get_target_offset_position()->Vector2:
	
	if _player == null:
		return Vector2.ZERO
	
	var target_offset=Vector2(_near_distance/2,0)
	
	if global_position.x < _player.global_position.x:
		target_offset.x*=-1
	
	return _player.global_position + target_offset
			
	
func get_target_direction()->Vector2:
	var direction := Vector2.ZERO
	
	if _player == null:
		return direction
		
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
