class_name Player
extends Actor

const MAX_LIFE=100.0
var _life:=100.0

var _damage=10

#onready var _animationTree := get_node("AnimationTree")
onready var _camera:=get_node("Camera2D")
onready var _tween:=get_node("Tween")
onready var _stateDisplay:=get_node("stateDisplay")

onready var _stateMachine:=get_node("StateMachine")

var look_direction = Vector2(1, 0) setget set_look_direction

var _cameraLimitRect: ReferenceRect

func _ready() -> void:
	updateLife(_life)
	
	_stateDisplay.visible=Game.is_debug()
	
func set_look_direction(value):
	look_direction = value
	emit_signal("direction_changed", value)

func updateLife(newLife:int):
	_life=newLife
	Events.emit_signal("player_health_changed", (_life/MAX_LIFE)*100 )


func took_damage(damage:int):
	updateLife(_life - damage)
	_stateMachine.set_damaged()
	
	_tween.interpolate_property(
		self, "modulate", Color.white, Color.red, 0.1
	)
	_tween.interpolate_property(
		self, "modulate", Color.red, Color.white, 0.1
	)

	_tween.start()


func set_camera_limit_rect(referenceRect : ReferenceRect):
	_cameraLimitRect=referenceRect
	
	var cameraLimitRectGlobalPosition=_cameraLimitRect.rect_global_position
	var cameraLimitRectSize=_cameraLimitRect.rect_size+cameraLimitRectGlobalPosition
	
	_camera.limit_left=cameraLimitRectGlobalPosition.x
	_camera.limit_top=cameraLimitRectGlobalPosition.y
	_camera.limit_right=cameraLimitRectSize.x
	_camera.limit_bottom=cameraLimitRectSize.y



func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage",body,_damage)
	pass # Replace with function body.



