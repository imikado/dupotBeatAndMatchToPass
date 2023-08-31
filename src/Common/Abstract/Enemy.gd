class_name Enemy
extends Actor


var _player : KinematicBody2D
var _near_distance:=10
var _damage:=10
const MAX_LIFE=50.0
var _life:=50.0
var _type= Game.ENEMY_TYPE_LIST.ANT

var _combo_count=0

onready var _animationPlayer:=get_node("BodyPivot/AnimationPlayer")
onready var _stateMachine := get_node("EnemyStateMachine")
onready var _enemy_progress_bar := get_node("BodyPivot/Control/ProgressBar")
onready var _timer:=get_node("Timer")

onready var _hitBox:=get_node("BodyPivot/HitBox")

var look_direction = Vector2(1, 0) setget set_look_direction

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
	tween.tween_method(self,"_update_enemy_health_bar", start_value, health, 0.33)
	
	
	#yield(get_tree().create_timer(1.0), "timeout")
	
	_timer.start()
	
	


func hide_progressbar():
	_enemy_progress_bar.visible=false	


func _update_enemy_health_bar(health_target: float) -> void:
	_enemy_progress_bar.value = health_target
	

func set_look_direction(value):
	look_direction = value

	
func setPlayer(player: KinematicBody2D):
	_player= player
	set_physics_process(true)

	
func _ready() -> void:
	_animationPlayer.connect("animation_finished",_stateMachine,"_on_animation_finished")
	_stateMachine.set_state_walk()
	
	_enemy_progress_bar.set_max(MAX_LIFE)
	_hitBox.connect("body_entered",self,"_on_HitBox_body_entered")
	_timer.connect("timeout",self,"hide_progressbar")
	
	
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
	tween.tween_property(self,"modulate",Color.red,0.3)
	tween.tween_property(self,"modulate",Color.white,0.2)
	
		
	if get_life() <= 0.0:
		_stateMachine.set_state_died()
	
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
