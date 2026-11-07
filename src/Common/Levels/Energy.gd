extends CharacterBody2D

var _target=null
var _speed=100

func _ready() -> void:
	$AnimatedSprite2D.play()

func set_target(target):
	_target=target
	# teinte et traînée de la couleur de la barrière visée
	var color := Fx.enemy_color(target.get_type())
	$AnimatedSprite2D.self_modulate = color.lightened(0.45)
	Fx.trail(self, Color(color, 0.8), 8)
	
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
