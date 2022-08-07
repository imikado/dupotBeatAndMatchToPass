extends KinematicBody2D

const LEFT="left"
const RIGHT="right"

var _direction
var _speed=50
var _damage=20

var _is_finishing=false

onready var _animation = get_node("AnimatedSprite")



func _ready() -> void:
	set_physics_process(false)
	pass
	

func explode():
	_is_finishing=true
	_animation.play("explode")
	set_physics_process(false)
	
func set_direction(side):
	if side == LEFT:
		_direction=Vector2(-1,0)
	else:
		_direction=Vector2(1,0)
	
	_animation.play("default")
	set_physics_process(true)
	
	
func _physics_process(delta: float) -> void:
	move_and_collide(delta*_speed*_direction)

		

func _on_VisibilityNotifier2D_screen_exited() -> void:
	print("bullet deleted")
	queue_free()
	pass # Replace with function body.


func _on_Hit_body_entered(body: Node) -> void:
	if body is Player:
		Events.emit_signal("actor_took_damage_by_bullet",body,_damage,self)
	pass # Replace with function body.


func _on_AnimatedSprite_animation_finished() -> void:
	if _is_finishing:
		queue_free()
	pass # Replace with function body.
