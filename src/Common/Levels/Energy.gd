extends KinematicBody2D

var _target=null
var _speed=100

func set_target(target):
	_target=target
	
func _process(delta: float) -> void:
	
	if _target==null:
		return
	
	#var direction = direction_to
	var direction = global_position.direction_to(_target.global_position)
	
	move_and_collide(direction*delta*_speed)
	
	var distance = global_position.distance_to(_target.global_position)
	if distance < 5:
		_target.increment()
		queue_free()
		print("unlock barriere")
	
	pass
